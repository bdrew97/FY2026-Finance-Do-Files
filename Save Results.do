/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file imports data from the Model's UI                                  *
*  Updated: 12-2013                                                                *
*#################################################################################*/
clear all
set more off
version 12.1
***************************************
*global input_path = "`1'"
dis "`1'" " " "`2'" " " "`3'" " " "`4'" " " "`5'"

global path1 = "`1'"
global LoanOfficer = "`5'"
global Output_Path  "$path1\Outputs\\${LoanOfficer}"
global UIFilename = "`2'"
global UIFilename2 = "`3'"
global RunID = "`4'"

**Terms**
import excel "${Output_Path}\DFC Obligation UI Stata Input_StataInput.xls", sheet("StataInput") firstrow
replace IRFactor=1 if DirectGuaranteed!="Direct Loan"
/* Shorten variable names */
foreach var of varlist _all {
	local shortname=substr("`var'",1,29)
	rename `var' `shortname'
	}
capture {
	rename Interestbeginsattopofperiod* Interestbeginsattopofperiod
	rename ProjectLocationProvinceCity* ProjectLocationProvinceCity
	}
save "$Output_Path\Terms.dta", replace


/* Save Inputs to Running Table of Inputs */
capture {
	tempfile newinput
	keep in 1
	gen RunTime = "$S_DATE  $S_TIME"
	gen UIFilename = "$UIFilename"
	gen UIFilename2 = "$UIFilename2"
	gen Version = "$path1"
	gen RunID = "$RunID"
	
	format ProjectID %20.0f
	format EquityCash %20.2fc
	format EquityNonCash %20.2fc
	format DFCLoan %20.2fc
	format TotalProjectCost %20.2fc
	format LoanorTotalGuaranteedAmount %20.2fc
	format FeeSharingAmount %20.2fc
	
	destring FundedDSRAorLCsecurity, replace
	format FundedDSRAorLCsecurity %20.2fc
	
	destring AnticipatedAppreciationCoverR, replace
	format AnticipatedAppreciationCoverR %20.2fc
	
	destring FirstLossAmount, replace
	format FirstLossAmount %20.2fc

	format IRFactor %10.0g
	
	if DFCLoanCurrency != "Not Available"{
		format DFCLoanMaxUSDExposureCap %20.2fc
	}
	
	tostring ObligationDate FirstDisbursementDate DateofFirstInterestPayment DateofFirstPrincipalPayment DateofFinalRepayment, replace format(%tdnn/dd/yy) force
	tostring PricingDate, replace format(%tdnn/dd/yy) force
	tostring *, replace force
	
	save `newinput' , replace
	
		**CHANGE FILE PATH BACK FOR DFC**
	use "$path1\Documentation\Loan Galaxy - Final Run Obligation Results.dta", clear
*	use "S:\Summit Consulting\Obligation Model Results\DFC Obligation Results.dta" , clear
*	use "C:\temp\DFC Obligation Results.dta" , clear
*	use "M:\DFC\4 Model Development\Obligation Model\Obligation Model Results\DFC Obligation Results.dta" , clear
	append using `newinput' , force
	save , replace
	export excel using "$path1\Documentation\Loan Galaxy - Final Run Obligation Results.xlsx", sheetreplace firstrow(var)
	}

clear all
	
capture{
	use "$Output_Path\Compressed Life Table.dta"
	tempfile ltstack
	gen RunTime = "$S_DATE  $S_TIME"
	gen UIFilename = "$UIFilename"
	gen UIFilename2 = "$UIFilename2"
	gen Version = "$path1"
	gen RunID = "$RunID"
	save `ltstack', replace
	
	use "$path1\Documentation\Final Run Stacked Life Tables.dta"
	append using `ltstack', force
	save , replace
	export excel using "$path1\Documentation\Final Run Stacked Life Tables.xlsx", sheetreplace firstrow(var)
}
	
clear all
	
capture{
	use "$Output_Path\cscflow complete.dta"
	tempfile cfstack
	gen RunTime = "$S_DATE  $S_TIME"
	gen UIFilename = "$UIFilename"
	gen UIFilename2 = "$UIFilename2"
	gen Version = "$path1"
	gen RunID = "$RunID"
	save `cfstack', replace
	
	use "$path1\Documentation\Final Run Stacked Cash Flows.dta"
	append using `cfstack', force
	order RunTime UIFilename UIFilename2 Version RunID, last
	save , replace
	export excel using "$path1\Documentation\Final Run Stacked Cash Flows.xlsx", sheetreplace firstrow(var)
}

exit, STATA clear
