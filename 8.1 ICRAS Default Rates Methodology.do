/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file calculates expected defaults for NHSG using ICRAS Default Curves  *
*  Updated: 7-25-2013                                                              *
*#################################################################################*/

clear all
set more off
version 12.1

use "$Output_Path\Life Table 1.dta"

gen double Forecasted_Period =  ceil((Repayment_Date - ${DisbDate1})/365.25)
replace Forecasted_Period = 1 if Forecasted_Period == 0 

gen double Period_of_Disbursement = ceil((Disbursement_Date- ${DisbDate1})/365)
replace Period_of_Disbursement = 1 if Period_of_Disbursement == 0 |Period_of_Disbursement==.

merge m:1 Period_of_Disbursement Forecasted_Period using "$Output_Path\Risk Table_Cond Default and Prepay.dta", keepus(CMDR_noprepay CCDR_noprepay jointCCDR jointCMDR Recovery_Rate) 
sort Disbursement_Number Repayment_Date Period_of_Disbursement Forecasted_Period
drop if _merge==2
drop _merge

*** Generate Variable with Appropriate Default Rate, dependedent on "Prepayment Risk" selection in UI
gen double CCDR = 0 
gen double CMDR = 0
replace CCDR = CCDR_noprepay if "$PrepaymentRiskonFees" == "No"
replace CCDR = jointCCDR if "$PrepaymentRiskonFees" == "Yes"
replace CMDR = CMDR_noprepay if "$PrepaymentRiskonFees" == "No"
replace CMDR = jointCMDR if "$PrepaymentRiskonFees" == "Yes"

*##################################################*

    *Calculating the Default Amount on Principal and Interest for Each Period*
	replace Default = round((Principal + Interest)*CCDR*${GuaranteedPercent},.01) if "$DefaultPaymentType" == "Periodic Payment"
	
    replace Exposure = round((Interest + (UPB_SOP/${GuaranteedPercent}) + Cap_Interest)*${GuaranteedPercent}, .01)
 	replace Default = round(Exposure*CMDR*(Payment_Frequency_Months/12), .01) if "$DefaultPaymentType" == "Lump Sum Payment"
 
 	if "$FeeSharing" == "No" | "$FeeSharing" == "Not Available" {
    *Calculate the Lost Fee (Default on Fees) if applicable*
    replace Lost_Fee = round(-(Fees + Commitment_Fees)* CCDR, .01) if "$DefaultRiskonFees" == "Yes"
	replace Lost_Fee = 0 if "$DefaultRiskonFees" == "No"
 
	*Calculates the nominal recovery on the default for each period*
    replace Recovery = round(-1*Recovery_Rate*(Default-Lost_Fee), .01)
	}
	
	
drop Period_of_Disbursement Forecasted_Period

save "$Output_Path\Life Table with Risk.dta", replace
