/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file converts collapsed life table to appropriate USD				   *
*  Updated:                                                             		   *
*#################################################################################*/

clear all
set more off
version 12.1

global USD_prepayvar = cond("$PrepaymentRiskonFees"=="Yes", "USD_Other*", "")
global defvar = cond("${DefaultMethodology}" == "FY2014 Risk Methodology" , "Default_Rate" , "*DR" , "*DR")

use "$Output_Path\Life Table Step 4.dta"

* Brandon edit - added in WC_Fees *
*Add working capital fees to the life table	
gen WC_Fees = 0
gen rep_month = month(Repayment_Date)
gen maintenance = 1 if rep_month == month($DateofFirstPayment)
replace maintenance = 0 if maintenance == .
replace maintenance = 0 if Repayment_Date <= $DateofFirstPayment
replace maintenance = 0 if Repayment_Date > $DateofFinalRepayment
replace maintenance = 0 if Fees == 0
replace WC_Fees = $GiftAuthority if _n == 1
replace WC_Fees = $MaintenanceFee if maintenance == 1
drop maintenance rep_month

* Merge in FX Inputs
merge m:1 period using "$Output_Path\FX Inputs.dta", keepusing(FX_Forward USD_2SD_Exposure Int_Forward)
	*Drop if period before first payment date
	drop if _merge==2
	drop _merge
	*Merge on subperiod for commitment fees
	gen obperiod=subperiod if period==.
	merge m:1 obperiod using "$Output_Path\FX Inputs.dta", keepusing(FX_Forward USD_2SD_Exposure Int_Forward)
	drop if _merge==2
	drop obperiod

gen double FXspotrate = ${FXSpotRateFXCurrencyUSD}
egen double Exposure_Cap = max(USD_2SD_Exposure)
*tab _merge
* For Obligation Date, use FX Forward Rate corresponding to current spot rate
gen double pd1_FXrate = FX_Forward if period==0
egen double pd1_FXrate_fillin = max(pd1_FXrate)
replace FX_Forward = pd1_FXrate_fillin if FX_Forward==. & period==0 | ///
										  FX_Forward==. & period==. | ///
										  FX_Forward==. & Obligation!=0
assert FX_Forward!=.
drop pd1_FXrate pd1_FXrate_fillin

* Identify appropriate conversion rate
* Generate USD Cash Flows at conversion rate
* FOR IG: Disbursements & Obligation Conversion Rate is NOT Fixed @ Spot Rate from Obligation i.e. uses then current spot rate like all other transactions
gen double conversion_rate = FX_Forward
* Brandon edit - added in WC_Fees *
local conv_varlist Obligation Disbursement Principal Interest Fees Commitment_Fees Default Lost_Fee WC_Fees ///
		DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Recovery Cap_Interest Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE ${PrepayVar}
foreach var of local conv_varlist {
	gen double USD_`var' = conversion_rate*`var'
}				   	
	
* Adjustment for Defaults, IGs:
* CF Defaults are adjusted by the ratio of Exposure Cap (2 standard deviation appreciation of FX) to Sum of Outstanding Principal at FX Forward Rates.
	* Generate Principal Exposure: sum of scheduled principal payments remaining, adjusted prorata for disbursements to date
sort Repayment_Date
bys Disbursement_Number (Repayment_Date): egen double USD_Principal_Tot = total(USD_Principal)
bys Disbursement_Number (Repayment_Date): gen double USD_Principal_todate = sum(USD_Principal)
bys Disbursement_Number (Repayment_Date): gen double USD_Principal_Exp = USD_Principal_Tot if UPB_SOP!=0
bys Disbursement_Number (Repayment_Date): replace USD_Principal_Exp = USD_Principal_Tot - USD_Principal_todate[_n-1] if _n>1

egen double USD_Disbursement_Tot = total(USD_Disbursement)
bys Disbursement_Number (Repayment_Date): gen double USD_Disbursement_todate = sum(USD_Disbursement)
bys Disbursement_Number (Repayment_Date): gen double prorata_disb_adj = USD_Disbursement_todate/USD_Disbursement_Tot
bys Disbursement_Number (Repayment_Date): gen double USD_2SD_Exp_adj = USD_2SD_Exposure * prorata_disb_adj

* Generate Limited Exposure: the mininum of Principal Exposure & Exposure given 2 SD of FX appreciation
bys Disbursement_Number (Repayment_Date): gen double Limited_Exposure = USD_Principal_Exp
bys Disbursement_Number (Repayment_Date): replace Limited_Exposure = USD_2SD_Exp_adj if USD_2SD_Exp_adj<USD_Principal_Exp
bys Disbursement_Number (Repayment_Date): gen double Limited_Exposure_ratio = Limited_Exposure/USD_Principal_Exp
bys Disbursement_Number (Repayment_Date): replace Limited_Exposure_ratio = 1 if USD_Principal_Exp==0

	* Generate USD CF Default
gen double effective_DR = Default / (Principal + Interest)
mvencode effective_DR, mv(0) override
gen double USD_CF_Default = (USD_Principal + USD_Interest)* ${GuaranteedPercent} * effective_DR * Limited_Exposure_ratio
	* Generate USD CF Recovery: Equal to percentage of FX Default & Lost Fees, delayed 2 years & converted at Forward Rate at time of recovery
gen recov_ind = cond(Recovery!=0, 1, 0)
gen double Def_and_LostFee = (USD_CF_Default - USD_Lost_Fee) * (1/conversion_rate)
	* Identify Defaults & Lost Fees corresponding to Recovery
gen double correspond_def_date = mdy(month(Repayment_Date),day(Repayment_Date), year(Repayment_Date) - 2)
format correspond_def_date %td
replace correspond_def_date = . if recov_ind==0
drop effective_DR

bys Disbursement_Number recov_ind (Repayment_Date): gen count = _n	
replace count = 0 if recov_ind==0
egen int maxcount = max(count)
local BigN = maxcount
dis `BigN'

gen double corresponding_def = 0
forval i = 1/`BigN' { 
	gen double def_date = correspond_def_date if count == `i'
	bys Disbursement_Number (Repayment_Date): egen double date = max(def_date)
	gen double corresponding_def`i' = Def_and_LostFee if Repayment_Date == date
	bys Disbursement_Number (Repayment_Date): egen double corr_def_fillin = max(corresponding_def`i')
	replace corresponding_def = corr_def_fillin if count == `i'
	drop date def_date corresponding_def`i' corr_def_fillin
	}
	
gen double USD_CF_Recovery = -1 * corresponding_def * ${RecoveryRate} * conversion_rate	

* UPB and Exposure need to be re-calculated using USD cash flows
bys Disbursement_Number Repayment_Date: gen double USD_UPB_SOP = 0 if _n==1
bys Disbursement_Number Repayment_Date: gen double USD_UPB_EOP = USD_UPB_SOP+USD_Disbursement-USD_Principal+USD_Cap_Interest if _n==1
forvalues i=2(1)`=_N' {
bys Disbursement_Number (Repayment_Date): replace USD_UPB_SOP = USD_UPB_EOP[_n-1] if _n==`i'
bys Disbursement_Number (Repayment_Date): replace USD_UPB_EOP = USD_UPB_SOP+USD_Disbursement-USD_Principal+USD_Cap_Interest if _n==`i'
}

gen double USD_Exposure = USD_Interest + USD_UPB_SOP + USD_Cap_Interest

* Formatting for save
foreach var of varlist USD_* {
	replace `var' = round(`var', .01)
}

	* Generate Additional Macros for CF Formatting
egen double Max_USD_Obligation = max(USD_Obligation)
global USD_Obligation = Max_USD_Obligation

gen double USD_Other_Inflow_FXP = 0
gen double USD_Other_Inflow_FXI = 0
gen double USD_Other_Inflow_FXF = 0

keep Repayment_Date Disbursement_Number Name ProjectID Payment_Frequency Payment_Frequency_Months period Total_WAL WAL FX_Forward USD_2SD_Exposure FXspotrate Exposure_Cap ///
	 USD_Obligation USD_Disbursement USD_Principal USD_Interest USD_Fees USD_Commitment_Fees USD_Lost_Fee USD_Cap_Interest ${USD_prepayvar} ///
	 USD_CF_Default USD_CF_Recovery USD_WC_Fees USD_Principal_Exp Limited_Exposure USD_DSRA_SOP USD_DSRA_EOP USD_DSRA_Draw USD_DSRA_Draw_Fee USD_DSRA_Draw_Def USD_Shared_Fees_RE USD_Shared_Commitment_Fees_RE USD_Shared_Lost_Fees_RE USD_Shared_Defaults_RE USD_Shared_Recoveries_RE ///
	 USD_UPB_SOP USD_UPB_EOP USD_Exposure FX_Forward USD_Other_Inflow_FXP USD_Other_Inflow_FXI USD_Other_Inflow_FXF ///
	 ${defvar}

foreach var of varlist USD_Obligation USD_Disbursement USD_Principal USD_Interest USD_Fees USD_Commitment_Fees USD_Lost_Fee USD_Cap_Interest $USD_prepayvar ///
	 USD_CF_Default USD_CF_Recovery USD_WC_Fees USD_DSRA_SOP USD_DSRA_EOP USD_DSRA_Draw USD_DSRA_Draw_Fee USD_DSRA_Draw_Def USD_Shared_Fees_RE USD_Shared_Commitment_Fees_RE USD_Shared_Lost_Fees_RE USD_Shared_Defaults_RE USD_Shared_Recoveries_RE ///
	 USD_UPB_SOP USD_UPB_EOP USD_Exposure USD_Principal_Exp USD_Other_Inflow_FXP USD_Other_Inflow_FXI USD_Other_Inflow_FXF {
		local abbrev = substr("`var'",5,25)
		rename `var' `abbrev'
		format `abbrev' %20.2fc
	 }
	 
rename (CF_Default CF_Recovery) (Default Recovery)
format USD_2SD_Exposure %20.2fc

gen missingdsra=1 if DSRA_SOP==.
replace missingdsra=0 if DSRA_SOP!=.
	 
save "$Output_Path\Life Table Step 4 USD.dta", replace
