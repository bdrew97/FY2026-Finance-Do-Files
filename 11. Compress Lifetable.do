/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file collapses the life table based on date                            *
*  Updated: 8-4-2017                                                               *
*#################################################################################*/

clear all
set more off
version 12.1

use "$Output_Path\Life Table Step 4.dta"

global apcvar = cond(${ForeignCurrencyAppreciationCo} ~=0, "APC*", "")
global apcvar2 = cond(${ForeignCurrencyAppreciationCo} ~=0, "APC_Default APC_Recovery", "")
global PrepayVar = cond("${PrepaymentRiskonFees}" == "Yes", "Other_Outflow_Prepay Other_Inflow_Prepay","")

** Generate DSRA Balances at Loan Level
* If DSRA is missing from recovery periods related to commitment fees
gen missingdsra=1 if DSRA_SOP==.
replace missingdsra=0 if DSRA_SOP!=.
bys missingdsra Repayment_Date (Disbursement_Number): replace DSRA_SOP = 0 if _n>1 
bys missingdsra Repayment_Date (Disbursement_Number): replace DSRA_EOP = 0 if _n!=_N 
foreach var of varlist DSRA* {
replace `var'=0 if `var'==.
}

collapse  (firstnm) Name ProjectID Payment_Frequency Payment_Frequency_Months period Total_WAL ///
          (sum) Obligation Disbursement Principal Interest Fees Commitment_Fees Default ///
		   Lost_Fee Recovery ${apcvar} ${PrepayVar} Cap_Interest  UPB_SOP UPB_EOP ///
		   DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE Exposure WAL, by(Repayment_Date)   

*Recalculate UPB*
sort Repayment_Date
*replace UPB_SOP=0
replace UPB_EOP = UPB_SOP + Disbursement - Principal if _n == 1
global max = _N
forvalues i = 2(1)$max {
   replace UPB_SOP = round(UPB_EOP[_n-1], .01) if _n == `i'
   replace UPB_EOP = round( UPB_SOP + Disbursement - Principal , .01) if _n == `i'
   }

if "$DirectGuaranteed" ~= "Direct Loan" {
   replace UPB_SOP = UPB_SOP*${GuaranteedPercent}
	replace UPB_EOP = UPB_EOP*${GuaranteedPercent}
}

***Re-entering the Default & Recovery Rates***	
if "$DefaultMethodology" == "FY2014 Risk Methodology" {
    gen double Default_Rate = $DefaultRate
    gen double Recovery_Rate = $RecoveryRate
	}
	    
if "$DefaultMethodology" == "Moody's Risk Methodology" | "$DefaultMethodology" == "ICRAS" {
    
	if "$DirectGuaranteed" == "Direct Loan" {   
		if "$DefaultRiskonFees" == "Yes"  {
		    gen double CDR = (-Default/(Principal + Interest + Fees + Commitment_Fees))
			}
		else {
		 gen double CDR = (-Default/(Principal + Interest))		
			}
	}
	
	if "$DirectGuaranteed" ~= "Direct Loan" & "$DefaultPaymentType" == "Lump Sum Payment" {
		gen double MDR = (Default/(Exposure))
			    
		if "$DefaultRiskonFees" == "Yes" {
			gen double CDR = -Lost_Fee/(Fees + Commitment_Fees)
		}			
	}
	if "$DirectGuaranteed" ~= "Direct Loan" & "$DefaultPaymentType" == "Periodic Payment" {		
		if "$DefaultRiskonFees" == "Yes"  {
		    gen double CDR = ((Default - Lost_Fee)/(((Principal + Interest)*${GuaranteedPercent}) + Fees + Commitment_Fees))
		}
		
		else {
		 gen double CDR = (Default/((Principal + Interest)*${GuaranteedPercent}))		
		}	
	}
}
format Obligation - Exposure %20.2fc
save "$Output_Path\Compressed Life Table.dta", replace	   

clear		  		  
if "$Currency" != "USD" {
use "$Output_Path\Life Table Step 4 USD.dta"

global apcvar = cond(${ForeignCurrencyAppreciationCo} ~=0, "APC*", "")
global apcvar2 = cond(${ForeignCurrencyAppreciationCo} ~=0, "APC_Default APC_Recovery", "")
global PrepayVar = cond("${PrepaymentRiskonFees}" == "Yes", "Other_Outflow_Prepay Other_Inflow_Prepay","")
global DIFXvar = cond("${DirectGuaranteed}" =="Direct Loan" & "${DFCLoanCurrency}" != "USD", "Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF", "")
global FXForward = cond("${DFCLoanCurrency}" != "USD", "FX_Forward", "")
global exposure_var = cond("${FXCurrency}" =="Yes"  & "$DirectGuaranteed" != "Direct Loan", "Principal_Exp", "")


** Generate DSRA Balances at Loan Level
* If DSRA is missing from recovery periods related to commitment fees
bys missingdsra Repayment_Date (Disbursement_Number): replace DSRA_SOP = 0 if _n>1 
bys missingdsra Repayment_Date (Disbursement_Number): replace DSRA_EOP = 0 if _n!=_N 
foreach var of varlist DSRA* {
replace `var'=0 if `var'==.
}

* Brandon edit - Deleted Other_Inflow_FXP, Other_Inflow_FXI, and Other_Inflow_FXF
collapse  (firstnm) Name ProjectID Payment_Frequency Payment_Frequency_Months period Total_WAL ${FXForward} USD_2SD_Exposure  ///
          (sum) Obligation Disbursement Principal Interest Fees Commitment_Fees Default ///
		   Lost_Fee Recovery ${apcvar} ${PrepayVar} ${DIFXvar} ${exposure_var} WC_Fees Cap_Interest  UPB_SOP UPB_EOP ///
		   DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE ///
		   Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE Exposure WAL, by(Repayment_Date)   
		   
*Recalculate UPB*
sort Repayment_Date
replace UPB_SOP=0
replace UPB_EOP = UPB_SOP + Disbursement - Principal if _n == 1
global max = _N
forvalues i = 2(1)$max {
   replace UPB_SOP = round(UPB_EOP[_n-1], .01) if _n == `i'
   replace UPB_EOP = round( UPB_SOP + Disbursement - Principal , .01) if _n == `i'
   }

***Re-entering the Default & Recovery Rates***	
if "$DefaultMethodology" == "FY2014 Risk Methodology" {
    gen double Default_Rate = $DefaultRate
    gen double Recovery_Rate = $RecoveryRate
	}
	    
if "$DefaultMethodology" == "Moody's Risk Methodology" | "$DefaultMethodology" == "ICRAS" {
    
	if "$DirectGuaranteed" == "Direct Loan" {   
		if "$DefaultRiskonFees" == "Yes"  {
		    gen double CDR = (-Default/(Principal + Interest + Fees + Commitment_Fees))
			}
		else {
		 gen double CDR = (-Default/(Principal + Interest))		
			}
	}
	
	if "$DirectGuaranteed" ~= "Direct Loan" & "$DefaultPaymentType" == "Lump Sum Payment" {
		gen double MDR = (Default/(Exposure))
			    
		if "$DefaultRiskonFees" == "Yes" {
			gen double CDR = -Lost_Fee/(Fees + Commitment_Fees)
		}			
	}
	if "$DirectGuaranteed" ~= "Direct Loan" & "$DefaultPaymentType" == "Periodic Payment" {		
		if "$DefaultRiskonFees" == "Yes"  {
		    gen double CDR = ((Default - Lost_Fee)/(((Principal + Interest)*${GuaranteedPercent}) + Fees + Commitment_Fees))
		}
		
		else {
		 gen double CDR = (Default/((Principal + Interest)*${GuaranteedPercent}))		
		}	
	}
}

format Obligation - Exposure %20.2fc
save "$Output_Path\Compressed Life Table USD.dta", replace	   
}

clear

*Format for IRR Calculation
if "$Currency" == "USD" & "$PrepaymentRiskonFees" == "Yes" {

use "$Output_Path\Compressed Life Table.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees Default  ///
Lost_Fee Recovery Shared_Fees_RE Shared_Commitment_Fees_RE 					 ///
Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE 			 	 ///
Other_Outflow_Prepay Other_Inflow_Prepay, by(FY)

replace Disbursement = -Disbursement
replace Default = -abs(Default)
replace Lost_Fee = -abs(Lost_Fee)
replace Recovery = abs(Recovery)
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Shared_Lost_Fees_RE = -abs(Shared_Lost_Fees_RE)
replace Shared_Defaults_RE = -abs(Shared_Defaults_RE)
replace Shared_Recoveries_RE = abs(Shared_Recoveries_RE)
replace Other_Outflow_Prepay = -abs(Other_Outflow_Prepay)
replace Other_Inflow_Prepay = abs(Other_Inflow_Prepay)
gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1
* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow
export excel using "$Output_Path\IRR Calc.xlsx", replace
}
		  		  
if "$Currency" != "USD" & "$PrepaymentRiskonFees" == "Yes" & "$DirectGuaranteed" == "Direct Loan"{

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees Default  ///
Lost_Fee Recovery Shared_Fees_RE Shared_Commitment_Fees_RE 					 ///
Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE 				 ///
Other_Outflow_Prepay Other_Inflow_Prepay Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF, by(FY)

replace Disbursement = -Disbursement
replace Default = -abs(Default)
replace Lost_Fee = -abs(Lost_Fee)
replace Recovery = abs(Recovery)
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Shared_Lost_Fees_RE = -abs(Shared_Lost_Fees_RE)
replace Shared_Defaults_RE = -abs(Shared_Defaults_RE)
replace Shared_Recoveries_RE = abs(Shared_Recoveries_RE)
replace Other_Outflow_Prepay = -abs(Other_Outflow_Prepay)
replace Other_Inflow_Prepay = abs(Other_Inflow_Prepay)

replace Other_Inflow_FXP = abs(Other_Inflow_FXP)
replace Other_Inflow_FXI = abs(Other_Inflow_FXI)
replace Other_Inflow_FXF = abs(Other_Inflow_FXF)

gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\IRR Calc.xlsx", replace
}

** Brandon edit - For IG in FX **
if "$Currency" != "USD" & "$PrepaymentRiskonFees" == "Yes" & "$DirectGuaranteed" != "Direct Loan"{

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees Default  ///
Lost_Fee Recovery Shared_Fees_RE Shared_Commitment_Fees_RE 					 ///
Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE 				 ///
Other_Outflow_Prepay Other_Inflow_Prepay, by(FY)

replace Disbursement = -Disbursement
replace Default = -abs(Default)
replace Lost_Fee = -abs(Lost_Fee)
replace Recovery = abs(Recovery)
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Shared_Lost_Fees_RE = -abs(Shared_Lost_Fees_RE)
replace Shared_Defaults_RE = -abs(Shared_Defaults_RE)
replace Shared_Recoveries_RE = abs(Shared_Recoveries_RE)
replace Other_Outflow_Prepay = -abs(Other_Outflow_Prepay)
replace Other_Inflow_Prepay = abs(Other_Inflow_Prepay)

gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\IRR Calc.xlsx", replace
}
**

if "$Currency" == "USD" & "$PrepaymentRiskonFees" != "Yes" {

use "$Output_Path\Compressed Life Table.dta", clear


gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Default Lost_Fee Recovery Shared_Fees_RE Shared_Commitment_Fees_RE 			 ///
Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE, by(FY)

replace Disbursement = -Disbursement
replace Default = -abs(Default)
replace Lost_Fee = -abs(Lost_Fee)
replace Recovery = abs(Recovery)
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Shared_Lost_Fees_RE = -abs(Shared_Lost_Fees_RE)
replace Shared_Defaults_RE = -abs(Shared_Defaults_RE)
replace Shared_Recoveries_RE = abs(Shared_Recoveries_RE)
gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\IRR Calc.xlsx", replace
}

if "$Currency" != "USD" & "$PrepaymentRiskonFees" != "Yes" & "$DirectGuaranteed" == "Direct Loan"{

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Default Lost_Fee Recovery Shared_Fees_RE Shared_Commitment_Fees_RE 			 ///
Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF, by(FY)

replace Disbursement = -Disbursement
replace Default = -abs(Default)
replace Lost_Fee = -abs(Lost_Fee)
replace Recovery = abs(Recovery)
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Shared_Lost_Fees_RE = -abs(Shared_Lost_Fees_RE)
replace Shared_Defaults_RE = -abs(Shared_Defaults_RE)
replace Shared_Recoveries_RE = abs(Shared_Recoveries_RE)

replace Other_Inflow_FXP = abs(Other_Inflow_FXP)
replace Other_Inflow_FXI = abs(Other_Inflow_FXI)
replace Other_Inflow_FXF = abs(Other_Inflow_FXF)

gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\IRR Calc.xlsx", replace
}

** Brandon edit - For IG FX
if "$Currency" != "USD" & "$PrepaymentRiskonFees" != "Yes" & "$DirectGuaranteed" != "Direct Loan"{

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Default Lost_Fee Recovery Shared_Fees_RE Shared_Commitment_Fees_RE 			 ///
Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE, by(FY)

replace Disbursement = -Disbursement
replace Default = -abs(Default)
replace Lost_Fee = -abs(Lost_Fee)
replace Recovery = abs(Recovery)
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Shared_Lost_Fees_RE = -abs(Shared_Lost_Fees_RE)
replace Shared_Defaults_RE = -abs(Shared_Defaults_RE)
replace Shared_Recoveries_RE = abs(Shared_Recoveries_RE)

gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\IRR Calc.xlsx", replace
}

**

 *Format for Risk Adjusted IRR Calculation
if "$Currency" == "USD" & "$PrepaymentRiskonFees" == "Yes" {

use "$Output_Path\Compressed Life Table.dta", clear


gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 	     ///
Shared_Fees_RE Shared_Commitment_Fees_RE Other_Outflow_Prepay 				 ///
Other_Inflow_Prepay, by(FY)

replace Disbursement = -Disbursement
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Other_Outflow_Prepay = -abs(Other_Outflow_Prepay)
replace Other_Inflow_Prepay = abs(Other_Inflow_Prepay)
gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\Risk Adj IRR Calc.xlsx", replace
}
	  		  
if "$Currency" != "USD" & "$PrepaymentRiskonFees" == "Yes" & "$DirectGuaranteed" == "Direct Loan" {

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Shared_Fees_RE Shared_Commitment_Fees_RE Other_Outflow_Prepay 				 ///
Other_Inflow_Prepay Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF, by(FY)

replace Disbursement = -Disbursement
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Other_Outflow_Prepay = -abs(Other_Outflow_Prepay)
replace Other_Inflow_Prepay = abs(Other_Inflow_Prepay)

replace Other_Inflow_FXP = abs(Other_Inflow_FXP)
replace Other_Inflow_FXI = abs(Other_Inflow_FXI)
replace Other_Inflow_FXF = abs(Other_Inflow_FXF)

gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\Risk Adj IRR Calc.xlsx", replace
}

** Brandon edit - For IG FX
if "$Currency" != "USD" & "$PrepaymentRiskonFees" == "Yes" & "$DirectGuaranteed" != "Direct Loan" {

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Shared_Fees_RE Shared_Commitment_Fees_RE Other_Outflow_Prepay 				 ///
Other_Inflow_Prepay, by(FY)

replace Disbursement = -Disbursement
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Other_Outflow_Prepay = -abs(Other_Outflow_Prepay)
replace Other_Inflow_Prepay = abs(Other_Inflow_Prepay)

gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\Risk Adj IRR Calc.xlsx", replace
}
**

if "$Currency" == "USD" & "$PrepaymentRiskonFees" != "Yes" {

use "$Output_Path\Compressed Life Table.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Shared_Fees_RE Shared_Commitment_Fees_RE, by(FY)

replace Disbursement = -Disbursement
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\Risk Adj IRR Calc.xlsx", replace
}

if "$Currency" != "USD" & "$PrepaymentRiskonFees" != "Yes" & "$DirectGuaranteed" == "Direct Loan"{

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Shared_Fees_RE Shared_Commitment_Fees_RE Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF, by(FY)

replace Disbursement = -Disbursement
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)
replace Other_Inflow_FXP = abs(Other_Inflow_FXP)
replace Other_Inflow_FXI = abs(Other_Inflow_FXI)
replace Other_Inflow_FXF = abs(Other_Inflow_FXF)
gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\Risk Adj IRR Calc.xlsx", replace
}

** Brandon edit - For IG FX
if "$Currency" != "USD" & "$PrepaymentRiskonFees" != "Yes" & "$DirectGuaranteed" != "Direct Loan"{

use "$Output_Path\Compressed Life Table USD.dta", clear

gen FY = year(Repayment_Date)
replace FY = FY+1 if month(Repayment_Date[_n]) >= 10

/*
gen Disbursement2=Disbursement[_n-1]
replace Disbursement=Disbursement2
drop Disbursement2
drop if period==0 | period==.
*/

collapse (sum) Disbursement Principal Interest Fees Commitment_Fees 		 ///
Shared_Fees_RE Shared_Commitment_Fees_RE, by(FY)

replace Disbursement = -Disbursement
replace Shared_Fees_RE = abs(Shared_Fees_RE)
replace Shared_Commitment_Fees_RE = abs(Shared_Commitment_Fees_RE)

gen WC_Fees = 0
replace WC_Fees = $MaintenanceFee if _n > 1 & Principal != 0
replace WC_Fees = $GiftAuthority if _n == 1

* Brandon - added upfront fees to IRR calculation
gen UpfrontFees = 0
replace UpfrontFees = $UpfrontFee if _n == 1

xpose , clear  format(%16.2fc) v promote
gen firstrow = 0 if _varname == "FY"
replace firstrow = 1 if firstrow == .
drop _varname
collapse (sum) v*, by(firstrow)
drop firstrow

export excel using "$Output_Path\Risk Adj IRR Calc.xlsx", replace
}
**
