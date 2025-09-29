/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file calculates defaults using DFC's FY 2014 Default Methodology       *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/

clear all
set more off
version 12.1
***************************************
use "$Output_Path\Life Table 1.dta"

*Populating the Default and Recovery Rates From the Global Macros*
gen double Default_Rate = $DefaultRate
gen double Recovery_Rate = $RecoveryRate

if "$DirectGuaranteed" == "Direct Loan"  {
    *Calculating the Default Amount on Principal and Interest for Each Period (Direct Loans)*
    replace Default = round(-1*(Principal + Interest)*Default_Rate,.01)
	
	if "$FeeSharing" == "No" | "$FeeSharing" == "Not Available" {
	*Calculate the Lost Fee (Default on Fees) if applicable*
    replace Default = round(Default - (Fees + Commitment_Fees)*Default_Rate , .01) if "$DefaultRiskonFees" == "Yes"

	*Calculates the nominal recovery on the default for each period*
    replace Recovery = round(-1*Recovery_Rate*(Default),.01)
	}
	}
	
if "$DirectGuaranteed" ~= "Direct Loan"  {
	
	*Calculating the Default Amount on Principal and Interest for Each Period (Direct Loans)*
    replace Default = round((Principal + Interest)*Default_Rate*${GuaranteedPercent},.01)

	if "$FeeSharing" == "No" | "$FeeSharing" == "Not Available" {
    *Calculate the Lost Fee (Default on Fees) if applicable*
    replace Lost_Fee = round(-(Fees + Commitment_Fees)* Default_Rate,.01) if "$DefaultRiskonFees" == "Yes"
	replace Lost_Fee = 0 if "$DefaultRiskonFees" == "No"
	
    *Calculates the nominal recovery on the default for each period*
    replace Recovery = round(-1*Recovery_Rate*(Default - Lost_Fee),.01)
    }
	}
	
save "$Output_Path\Life Table with Risk.dta", replace 
	
