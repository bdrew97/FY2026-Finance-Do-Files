/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file converts FX cash flow to USD (Direct Loans)                       *
*  Updated: 		                                                               *
*#################################################################################*/

clear all
set more off
version 12.1

use "$Output_Path\Life Table Step 4.dta"
global USD_1_apcvars = cond(${ForeignCurrencyAppreciationCo} ~=0, "USD_1_APC_Default USD_1_APC_Recovery", "")
global USD_1_PrepayVar = cond("${PrepaymentRiskonFees}" == "Yes", "USD_1_Other_Outflow_Prepay USD_1_Other_Inflow_Prepay","")

* Fill-in period number if missing (for merge)
*bys Repayment_Date: egen period_no = max(period)
*assert period_no == period if period!=.
*replace period = period_no if period==.
*drop period_no

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

* For dates prior to the First Payment Date, use FX Forward Rate corresponding to first payment date
gen double pd1_FXrate = FX_Forward if period==1
egen double pd1_FXrate_fillin = max(pd1_FXrate)
replace FX_Forward = pd1_FXrate_fillin if FX_Forward==. & period==0 | ///
										  FX_Forward==. & period==. | ///
										  FX_Forward==. & Obligation!=0
assert FX_Forward!=.
drop pd1_FXrate pd1_FXrate_fillin

* Identify appropriate conversion rate
	* FOR DI: Obligation Conversion Rate is Fixed @ Spot Rate at Obligation, Disbursement Conversion Rate is Forward Rate corresponding to disbursement timing
	gen spot_ind = cond(Obligation!= 0, 1, 0)
	gen double conversion_rate = 0
	replace conversion_rate = FX_Forward if spot_ind!=1
	replace conversion_rate = FXspotrate if spot_ind==1
	assert conversion_rate!=0

* For Disbursements
drop _merge
rename (FX_Forward Int_Forward period) (FX_Forward_1 Int_Forward_1 period_1)
gen period = period_1 + 1
merge m:1 period using "$Output_Path\FX Inputs.dta", keepusing(FX_Forward Int_Forward)
rename FX_Forward conversion_2
drop Int_Forward period
rename (FX_Forward_1 Int_Forward_1 period_1) (FX_Forward Int_Forward period)

* Generate USD Cash Flows at conversion rate
* USD_1_ cash flows --> FX Cash Flows at conversion rate
* USD_2_ cash flows --> USD_1 cash flows adjusted: rescaled principal = expected disbursement, & recalculated UPB, Int, & Fees	
local conv_varlist Obligation Disbursement Principal Interest Fees WC_Fees Commitment_Fees Default Lost_Fee ///
			   Recovery Cap_Interest UPB_SOP UPB_EOP Exposure ${PrepayVar} DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def
foreach var of local conv_varlist {
	gen double USD_1_`var' = conversion_rate*`var'
	replace USD_1_`var' = round(USD_1_`var', .01)
	
	if "`var'" == "Disbursement" {
		replace USD_1_`var' = conversion_rate*`var'
		replace USD_1_`var' = round(USD_1_`var', .01)
	}
	
}

******CHRISTINE ADDED
*Account for appreciation of during period of disbursement and limit disbursement to the cap

*Starred out code to be used if adjustment to disbursements needs to be made for last disbursements instead of pro-rata
*sort Repayment_Date
*gen double FWD_Disb_adj=sum(USD_1_Disbursement)
*egen double cap_adj=max(FWD_Disb_adj)
*replace cap_adj=Exposure_Cap-cap_adj
*gen double cap_difference=Exposure_Cap-FWD_Disb_adj
*gen double USD_1_Disbursement_cap=USD_1_Disbursement if cap_difference>=0
*replace USD_1_Disbursement_cap=USD_1_Disbursement+cap_difference if USD_1_Disbursement>0 & cap_difference<0 & cap_difference!=cap_adj

egen double FWD_Disb=sum(USD_1_Disbursement)
gen double prorata_appreciation=Exposure_Cap/FWD_Disb
replace prorata_appreciation=1 if prorata_appreciation>1
foreach var of varlist USD_1_*{
replace `var'=`var'*prorata_appreciation
replace `var'= round(`var', .01)
}

*Calculate USD_2 components
sort Disbursement_Number Repayment_Date	
local keep_varlist Obligation Disbursement Commitment_Fees WC_Fees Default Lost_Fee Recovery DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def
foreach var of local keep_varlist {
	gen double USD_2_`var' = USD_1_`var'
}

local new_varlist Principal Interest Fees Cap_Interest UPB_SOP UPB_EOP Exposure ${PrepayVar}  
foreach var of local new_varlist {
	gen double USD_2_`var' = 0
}

*#############################*
*Creating Principal Schedule  *
*#############################*
bys Disbursement_Number: egen double total_USD_Disb=sum(USD_2_Disbursement)
bys Disbursement_Number: egen double total_USD_Principal=sum(USD_1_Principal)
replace USD_2_Principal= USD_1_Principal*(total_USD_Disb/total_USD_Principal)
replace USD_2_Principal= round(USD_2_Principal, .01)
*Adjust for cent difference
bys Disbursement_Number: egen double total_USD_Principal2=sum(USD_2_Principal)
bys Disbursement_Number: gen double total_USD_PrincipalDiff=total_USD_Disb-total_USD_Principal2
bys Disbursement_Number (Repayment_Date): gen last_payment=_n if USD_2_Principal!=0
bys Disbursement_Number (Repayment_Date): egen max_last_payment=max(last_payment)
bys Disbursement_Number	: replace USD_2_Principal= USD_2_Principal + total_USD_PrincipalDiff if last_payment==max_last_payment
drop max_last_payment last_payment total_USD_PrincipalDiff total_USD_Principal2

***Establishing the starting UPBs***
replace USD_2_UPB_SOP = 0                                                        			if subperiod==0
replace USD_2_UPB_EOP = USD_2_UPB_SOP + USD_2_Disbursement                                  if subperiod==0
bys Disbursement_Number (Repayment_Date) : replace USD_2_UPB_SOP = USD_2_UPB_EOP[_n-1] 		if subperiod==1

if "$DirectGuaranteed" == "Direct Loan"  {
     replace  Interest_Rate = Interest_Rate*${IRFactor}
	 }
*########################################*
*Creating Capitalized Interest Schedule  *
*########################################*
***Populates capitalized interest from first period to period before the first interst payment
***Any spreads (Pre/Post fee) is included in the capitalized amount***
if "$DirectGuaranteed"=="Direct Loan" {
if ${Interestbeginsattopofperiod} > 1 {
	forvalues i = 1(1)$Interestbeginsattopofperiod  {
		replace USD_2_Cap_Interest = round(USD_2_UPB_SOP*Borrower_Rate*days/days_in_year,.01) if subperiod==`i' & period < $Interestbeginsattopofperiod
		replace USD_2_UPB_EOP = USD_2_UPB_SOP + USD_2_Cap_Interest if subperiod==`i' & period < $Interestbeginsattopofperiod
		bys Disbursement_Number (Repayment_Date) : replace USD_2_UPB_SOP = USD_2_UPB_EOP[_n-1] if subperiod == `i'+1
		}
		}
}	
***Populates UPB(s) for periods up to the first principal payment. Necessary for future calculations***
	forvalues i = $Interestbeginsattopofperiod(1)$Principalbeginsendofperiod {
		replace USD_2_UPB_EOP = USD_2_UPB_SOP if period== `i' & subperiod ~= 0
		bys Disbursement_Number (Repayment_Date) : replace USD_2_UPB_SOP = USD_2_UPB_EOP[_n-1] if period== `i' + 1
		}

*#######################################*
*Principal Payment Amortization Prep    *
*#######################################*
***Generates the number of principal payments that are scheduled to happen for each disbusmement /// 
   *Determines if the first repayment is before or after the principal grace period for each disbursement.///
   *If it is before, then there are fewer principal payments***
  
gen double principalpayments= ${ofPaymentspostGrace}
bys Disbursement_Number : egen double last_payment = max(subperiod) if Principal!=. & Principal>0
bys Disbursement_Number : replace principalpayments = last_payment if last_payment <= principalpayments
bys Disbursement_Number (Repayment_Date) : gen double principal_payment_number = principalpayments - (last_payment - subperiod)

	**Calculates the UPB(s)**
	forvalues i=1(1)$ofPaymentspostGrace {
	   replace USD_2_UPB_EOP = USD_2_UPB_SOP - USD_2_Principal if principal_payment_number == `i' 
	   bys Disbursement_Number (Repayment_Date) : replace USD_2_UPB_SOP = USD_2_UPB_EOP[_n-1] if principal_payment_number == `i' + 1
	   } 

*#####################################################*	
*Interest Calculation: Non-Mortgage/Mortgage Programs *
*#####################################################*
replace USD_2_Interest = round(USD_2_UPB_SOP*Interest_Rate*days/days_in_year, .01) if subperiod>= 1 & period>= $Interestbeginsattopofperiod
 	
*#########################################*	
*Pre/Post Fee Calculation (Guarantee Fee) *
*#########################################*

if "$OtherSubsidyFees" != "Yes" {
replace USD_2_Fees = round(USD_2_UPB_SOP*PostCompletion*days/days_in_year, .01) if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period >= $CompletionPoint
replace USD_2_Fees = round(USD_2_UPB_SOP*PreCompletion*days/days_in_year, .01)  if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period < $CompletionPoint
}

if "$DirectGuaranteed" ~= "Direct Loan" & "$OtherSubsidyFees" != "Yes" /*Assumes that Fees entered by user are Amount of Fees TO DFC, & thus do not require this adjustment*/ {
    replace USD_2_Fees = round((USD_2_UPB_SOP*PostCompletion*days/days_in_year)*${GuaranteedPercent}, .01) if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period >= $CompletionPoint
	replace USD_2_Fees = round((USD_2_UPB_SOP*PreCompletion*days/days_in_year)*${GuaranteedPercent}, .01)  if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period < $CompletionPoint
	}
	
*#####################################################*	
*Interest & Fee Calculation: All in Single            *
*#####################################################*
if "$InterestType"== "All-In Single Rate" & "$DirectGuaranteed" == "Direct Loan"{
        replace USD_2_Interest = round(USD_2_UPB_SOP*Interest_Rate*days/days_in_year, .01) if subperiod>= 1 & period>= $Interestbeginsattopofperiod
        gen double All_In_Pmnt = round(USD_2_UPB_SOP*All_In_Single_Rate*days/days_in_year, .01) if subperiod>= 1 & period>= $Interestbeginsattopofperiod
		replace USD_2_Fees = All_In_Pmnt - USD_2_Interest if subperiod>= 1 & period>= $Interestbeginsattopofperiod
		drop All_In_Pmnt
		}
	   
*#####################################################
* Other Inflows                                      *
*#####################################################
* Merge Original FX Forward Run without zero-financing
if ${IRFactor} == 1 {
drop if Name==""
save "$Output_Path\Subfolder - DI FX Zero-Fi\Life Table Step 4 USD Original.dta", replace
}

if ${IRFactor} != 1 {
drop _merge
drop if Name==""
merge 1:1 Disbursement_Number Repayment_Date using "$Output_Path\Subfolder - DI FX Zero-Fi\Life Table Step 4 USD Original.dta", ///
keepusing (USD_1_Principal USD_1_Interest USD_1_Fees USD_1_Commitment_Fees USD_1_Default USD_1_Recovery) update replace
}

* Generate Other Inflow/Outflow due to Exchange Rates (difference in Principal, Int, & Fee between USD_1 & USD_2 Cash Flows)
gen double USD_3_Other_Inflow_FXP = USD_1_Principal - USD_2_Principal
gen double USD_3_Other_Inflow_FXI = USD_1_Interest - USD_2_Interest
mvencode USD_1_Fees USD_2_Fees, mv(0) override
gen double USD_3_Other_Inflow_FXF = (USD_1_Fees+USD_1_Commitment_Fees) - (USD_2_Fees+USD_2_Commitment_Fees)

* Generate Additional Macros for CF Formatting
egen double cap_adj_disb=sum(USD_2_Disbursement)
replace USD_2_Obligation = cap_adj_disb if USD_2_Obligation!=0

egen double Max_USD_Obligation = max(cap_adj_disb) /* Brandon edit - 11/29/2020 */
global USD_Obligation = Max_USD_Obligation	

keep Name ProjectID Disbursement_Number Payment_Frequency Payment_Frequency_Months period Total_WAL WAL Repayment_Date ///
     USD_2_Obligation USD_2_Disbursement USD_2_Principal USD_2_Interest USD_2_Fees USD_2_Commitment_Fees USD_2_WC_Fees USD_2_Default ///
	 USD_2_Lost_Fee USD_2_Recovery ${USD_2_apcvar} ${USD_2_PrepayVar} USD_2_Cap_Interest  USD_2_UPB_SOP USD_2_UPB_EOP USD_2_Exposure ///
	 USD_3_Other_Inflow_FXP USD_3_Other_Inflow_FXI USD_3_Other_Inflow_FXF FX_Forward USD_2SD_Exposure ///
	 USD_2_DSRA* Disbursement_Number Shared_*
 
rename USD_2SD_Exposure XUSD_2SD_Exposure

gen missingdsra=1 if USD_2_DSRA_SOP==.
replace missingdsra=0 if USD_2_DSRA_SOP!=.

foreach var of varlist USD_* {
	mvencode `var', mv(0) override
	replace `var' = round(`var', .01)
	format `var' %20.2fc	
	local abbrev = substr("`var'",7,20)
	rename `var' `abbrev'
}

rename XUSD_2SD_Exposure USD_2SD_Exposure

save "$Output_Path\Life Table Step 4 USD.dta", replace
