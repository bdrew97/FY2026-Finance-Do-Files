/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file calculates expected prepayments using the 75PSA Curve			   *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/

clear all
set more off
version 12.1
****************************

use "$Output_Path\Life Table Step 3.dta"
capture drop Forecasted_Period Period_of_Disbursement

gen double Forecasted_Period = ceil((Repayment_Date-${DisbDate1})/365.25)
replace Forecasted_Period = 1 if Forecasted_Period <= 0 

gen double Period_of_Disbursement = ceil((Disbursement_Date- ${DisbDate1})/365)
replace Period_of_Disbursement = 1 if Period_of_Disbursement <= 0 | Period_of_Disbursement==.

	* Merge 75PSA Assumptions
if "$DefaultMethodology" != "FY2014 Risk Methodology" {
	merge m:1 Period_of_Disbursement Forecasted_Period using "$Output_Path\Risk Table_Cond Default and Prepay.dta", keepus(jointCMPR jointCCPR) 
}
if "$DefaultMethodology" == "FY2014 Risk Methodology" {
	merge m:1 Period_of_Disbursement Forecasted_Period using "$Output_Path\Prepayment Assumptions.dta", keepus(CMPR CCPR)
	gen double jointCMPR = CMPR
	gen double jointCCPR = CCPR
	drop CMPR CCPR
}
sort Disbursement_Number Repayment_Date Period_of_Disbursement Forecasted_Period
drop if _merge==2
drop _merge

*##################################################*
* GENERATE OTHER OUTFLOW (REDUCTION IN FEES) DUE TO PREPAYMENT
*Populate Prepay-Adjusted UPB SOP & Prepayment for First Obs
bys Disbursement_Number (Repayment_Date): gen double prepayadjUPBSOP=0 if _n==1
bys Disbursement_Number (Repayment_Date): gen double MaxPrepay = jointCMPR * (Payment_Frequency_Months/12)* prepayadjUPBSOP if _n==1
bys Disbursement_Number (Repayment_Date): gen double NewPrin = MaxPrepay + Principal if _n==1
	*Generate UPB based on "New Principal", for First Obs
bys Disbursement_Number (Repayment_Date): gen double NewUPBSOP = 0 if _n==1
bys Disbursement_Number (Repayment_Date): gen double NewUPBEOP = NewUPBSOP - NewPrin + Disbursement if _n==1
	*Generate Principal Adj, equal to New Principal, unless NewPrin > UPB
bys Disbursement_Number (Repayment_Date): gen double AdjPrin = NewPrin if NewPrin<=NewUPBSOP & _n==1
bys Disbursement_Number (Repayment_Date): replace AdjPrin = NewUPBSOP  if NewPrin>NewUPBSOP & _n==1

bys Disbursement_Number (Repayment_Date): gen double prepayadjUPBEOP = prepayadjUPBSOP - AdjPrin + Disbursement if _n==1

*Populate Prepay-Adjusted UPB & Prepayment for All Other Observations
bys Disbursement_Number (Repayment_Date): gen N = _N
egen MaxN = max(N) 
local BigN = MaxN
dis `BigN'
forval i = 2/`BigN' {
*Populate Prepay-Adjusted UPB SOP & Prepayment for First Obs
bys Disbursement_Number (Repayment_Date): replace prepayadjUPBSOP = prepayadjUPBEOP[_n-1] if _n==`i'
bys Disbursement_Number (Repayment_Date): replace MaxPrepay = jointCMPR * (Payment_Frequency_Months/12) * prepayadjUPBSOP if _n==`i'
bys Disbursement_Number (Repayment_Date): replace NewPrin = MaxPrepay + Principal if _n==`i'
	*Generate UPB based on "New Principal", for First Obs
bys Disbursement_Number (Repayment_Date): replace NewUPBSOP = NewUPBEOP[_n-1] if _n==`i'
bys Disbursement_Number (Repayment_Date): replace NewUPBEOP = NewUPBSOP - NewPrin + Disbursement if NewPrin + Disbursement <= NewUPBSOP &  _n==`i'
bys Disbursement_Number (Repayment_Date): replace NewUPBEOP = 0 if NewPrin + Disbursement > NewUPBSOP &  _n==`i'
	*Generate Principal Adj, equal to New Principal, unless NewPrin > UPB
bys Disbursement_Number (Repayment_Date): replace AdjPrin = NewPrin if NewPrin<=NewUPBSOP & _n==`i'
bys Disbursement_Number (Repayment_Date): replace AdjPrin = NewUPBSOP  if NewPrin>NewUPBSOP & _n==`i'

bys Disbursement_Number (Repayment_Date): replace prepayadjUPBEOP = prepayadjUPBSOP - AdjPrin + Disbursement if _n==`i'
local i = `i' + 1
}

*Generate Fees based on Adjusted Principal. The Difference between Resulting Fees & Scheduled Fees is an Other Outflow due to Prepayment
bys Disbursement_Number (Repayment_Date): gen double AdjFee = Fees * (prepayadjUPBSOP / UPB_SOP)
mvencode AdjFee, mv(0) override
bys Disbursement_Number (Repayment_Date): gen double Other_Outflow_Prepay = -1*(AdjFee - Fees)

* GENERATE OTHER INFLOW (PREPAYMENT PENALTY FEES) DUE TO PREPAYMENT
gen double Other_Inflow_Prepay = 0
replace Other_Inflow_Prepay = 0.03 * MaxPrepay if Forecasted_Period==1
replace Other_Inflow_Prepay = 0.02 * MaxPrepay if Forecasted_Period==2
replace Other_Inflow_Prepay = 0.01 * MaxPrepay if Forecasted_Period==3

drop N MaxN prepayadjUPB* NewUPB* NewPrin AdjPrin
save "$Output_Path\Life Table Step 3.dta", replace

