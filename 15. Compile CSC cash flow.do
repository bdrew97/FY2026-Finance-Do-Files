/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file completes and exports the csc cash flow for the program          *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/
version 12.1
set more off
clear all 

use "$Output_Path\cscflow part 1 of 3.dta"

append using "$Output_Path\cscflow part 2 of 3.dta", force 

append using "$Output_Path\cscflow part 3 of 3.dta", force 

sort SequenceNo Item

gen Project_ID = "$ProjectID"

** Adjust obligation amount for FX projects so it includes appreciation cover **
generate AppCoverAdj="$FXAppCover" if "$FXCurrency"=="Yes"
generate ObligationAdj="$USD_Obligation" if "$FXCurrency"=="Yes"
destring AppCoverAdj ObligationAdj, replace
replace AppCoverAdj=round(AppCoverAdj,0.01)
generate ObligationAdj2=AppCoverAdj+ObligationAdj
replace ObligationAdj2=round(ObligationAdj2,0.01)
global FXObligation_AppCover=ObligationAdj2
* Direct Loans are excluded from this obligation amount replace because the obligation amount already includes the
* apprecation cover in it. Refer to the creation of the USD_Obligation macro in do file "10.3 Convert FX Cash Flow to USD (DI).do"
replace Value = "$FXObligation_AppCover" if SequenceNo == 110  & "$FXCurrency" == "Yes"  & "$DirectGuaranteed" != "Direct Loan"
drop AppCoverAdj ObligationAdj ObligationAdj2
**

*###################################################*
* Add Source filenames/directory to end of Cashflow *
*###################################################*

order Project_ID SequenceNo

local obs =_N
local obsplus=`obs'+10
noi dis "obsplus = `obsplus'"
set obs `obsplus'
local start= `obs'+2
noi dis "start = `start'"

tostring SequenceNo, replace
replace SequenceNo = "" if SequenceNo == "."

qui replace Project_ID = "Input Files:" in `start'
local start = `start' + 1
qui replace SequenceNo = "Terms:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_StataInput.xls" in `start'
local start = `start' + 1
qui replace SequenceNo = "Disbursement Schedule:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_DisbursementSchedule.xls" in `start'
local start = `start' + 1
qui replace SequenceNo = "Interst Rates:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_InterestCalculations.xls" in `start'
local start = `start' + 1
qui replace SequenceNo = "Fee Sharing Schedule:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_OtherFeesSchedule.xls" in `start'
local start = `start' + 1
if "$PrincipalPaymentStructure" == "Custom" {
    qui replace SequenceNo = "Custom Principal Schedule:" in `start'
    qui replace Item = "$Output_Path Obligation UI Stata Input_PrincipalSchedule.xls" in `start' 
    local start = `start' + 1
	}
if "$DefaultMethodology" == "Moody's Risk Methodology"  {
    qui replace SequenceNo = "Risk Matrix:" in `start'
    qui replace Item = "$Risk_Path" in `start'
    }
	
local start = `start' + 2
qui replace Project_ID = "Date and Time of Model Run:" in `start'
qui replace SequenceNo ="$S_TIME  $S_DATE" in `start'

save "$Output_Path\cscflow complete.dta" , replace
export excel using "$Output_Path\CSC Cashflow.xlsx", sheet("Cashflow") firstrow(variables) replace 

********************************************************
*** Copy entirety of above for FX Denominated Cash flow
********************************************************
clear
if "$FXCurrency" == "Yes"  {
use "$Output_Path\cscflow part 1 of 3 FX.dta"

append using "$Output_Path\cscflow part 2 of 3 FX.dta", force 

append using "$Output_Path\cscflow part 3 of 3 FX.dta", force 

sort SequenceNo

gen Project_ID = "$ProjectID"

*###################################################*
* Add Source filenames/directory to end of Cashflow *
*###################################################*

order Project_ID SequenceNo

local obs =_N
local obsplus=`obs'+10
noi dis "obsplus = `obsplus'"
set obs `obsplus'
local start= `obs'+2
noi dis "start = `start'"

tostring SequenceNo, replace
replace SequenceNo = "" if SequenceNo == "."

qui replace Project_ID = "Input Files:" in `start'
local start = `start' + 1
qui replace SequenceNo = "Terms:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_StataInput.xls" in `start'
local start = `start' + 1
qui replace SequenceNo = "Disbursement Schedule:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_DisbursementSchedule.xls" in `start'
local start = `start' + 1
qui replace SequenceNo = "Interst Rates:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_InterestCalculations.xls" in `start'
local start = `start' + 1
qui replace SequenceNo = "Fee Sharing Schedule:" in `start'
qui replace Item = "$Output_Path Obligation UI Stata Input_OtherFeesSchedule.xls" in `start'
local start = `start' + 1
if "$PrincipalPaymentStructure" == "Custom" {
    qui replace SequenceNo = "Custom Principal Schedule:" in `start'
    qui replace Item = "$Output_Path Obligation UI Stata Input_PrincipalSchedule.xls" in `start' 
    local start = `start' + 1
	}
if "$DefaultMethodology" == "Moody's Risk Methodology"  {
    qui replace SequenceNo = "Risk Matrix:" in `start'
    qui replace Item = "$Risk_Path" in `start'
    }
	
local start = `start' + 2
qui replace Project_ID = "Date and Time of Model Run:" in `start'
qui replace SequenceNo ="$S_TIME  $S_DATE" in `start'

save "$Output_Path\cscflow complete.dta" , replace
export excel using "$Output_Path\CSC Cashflow FX.xlsx", sheet("Cashflow") firstrow(variables) replace 
}

