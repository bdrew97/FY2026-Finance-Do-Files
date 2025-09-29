/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file formats and stores the disbursement schedule for the program      *
*  Updated: 1-24-2013                                                              *
*#################################################################################*/
clear all
set more off
version 12.1
***************************************

use "$Output_Path\Disbursement Schedule.dta"
drop if No==.

destring Amount, replace

drop if Amount == .
drop if Amount == 0
sort Date

capture drop G
capture drop F
**Creating a global macro for each disbursement amount and date**
global NumberofDisbursementPeriods = _N

format Amount %16.2fc

forvalues i = 1(1)$NumberofDisbursementPeriods {
	global DisbDate`i'= Date[`i']
	global DisbAmount`i'= Amount[`i']
	global LastDisbDate = ${DisbDate`i'}
	
	**Creating a global macro for each fixed interest rate, if the loan is using a fixed or all in rate**
		if "${InterestType}"== "Fixed - Treasury" | ("${InterestType}"== "All-In Single Rate" & "$DirectGuaranteed"=="Direct Loan") {
			global BaseInterest`i' = BaseInterestRate[`i']
			}
		if ("${InterestType}"== "All-In Single Rate" & "$DirectGuaranteed"!="Direct Loan") {
			global AllInRate`i' = AllInRate[`i']
			}		
	
	}
	
save "$Output_Path\Disbursement Schedule.dta", replace



