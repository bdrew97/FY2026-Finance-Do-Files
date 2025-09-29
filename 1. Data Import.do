/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file imports data from the Model's UI                                  *
*  Updated: 9/25/2020 - Updated for Version Control                                *
*#################################################################################*/
clear all
set more off
version 12.1
***************************************

**Latest Excel Version Check**
import excel "$path1\Documentation\Subsidy Model Version Control.xls", sheet("Finance - Version Control") cellrange(A7:D257) firstrow
capture drop if ExcelVersion==""
egen lastupdate=max(ModelDate)
drop if ModelDate!=lastupdate
global new_excel_version = ExcelVersion

**Terms**
clear
import excel "${Output_Path}\DFC Obligation UI Stata Input_StataInput.xls", firstrow
global current_excel_version=ExcelVersion
if "$new_excel_version"!= "$current_excel_version" { 
	dis as error _newline "ATTENTION: The version of the Excel Model Template that you are using is not the most recent." ///
	_newline _column(12) "Please use latest model template downloaded from SharePoint. To exit STATA, type 'q'."
	window stopbox stop "ATTENTION: The version of the Excel Model Template that you are using is not the most recent." "Please use latest model template downloaded from SharePoint."
	pause
	exit, STATA
	}
save "$Output_Path\Terms.dta", replace

**Disbursement Schedule**
clear
import excel "${Output_Path}\DFC Obligation UI Stata Input_DisbursementSchedule.xls", cellrange(C11:G111) firstrow
capture destring No, replace
capture gen temp = date(Date, "DMY")
if _rc == 0 {
	drop Date
	rename temp Date
	format Date %td
}
save "$Output_Path\Disbursement Schedule.dta", replace

**Interest Rates, John added SOFR**
clear
import excel "${Output_Path}\DFC Obligation UI Stata Input_InterestCalculations.xls", cellrange(R12:X329) firstrow
rename DateofRepayment Repayment_Date
capture destring RepayNo , replace
capture destring FloatTreasury , replace
capture destring FloatLIBOR , replace
capture destring FloatSOFR , replace
capture destring FloatOther , replace
capture gen temp = date(Repayment_Date ,"MDY")
if _rc == 0 {
	drop Repayment_Date
	rename temp Repayment_Date
}
format Repayment_Date %td
drop if RepayNo ==.
save "$Output_Path\FloatingInterestRates.dta", replace

**Custom Principal Schedule**
clear
dis "$PrincipalPaymentStructure"
if "$PrincipalPaymentStructure" == "Custom" { 
    import excel "${Output_Path}\DFC Obligation UI Stata Input_PrincipalSchedule.xls", cellrange(E13)
    
	***Cleaning The Data and Renaming Variables***
capture drop if E == . 
capture drop if E == "" 
capture destring E, replace
capture destring G, replace
rename E Number
capture gen Repayment_Date = date(F,"MDY")
capture rename F Repayment_Date
capture drop F
format Repayment_Date %td
order Number Repayment_Date

format G - AF %16.2fc
	
	
	save "$Output_Path\Principal Custom.dta", replace
}

**Custom Fees Schedule**
clear
dis "$OtherSubFees"
if "$OtherSubFees" == "Yes" { 
    import excel "${Output_Path}\DFC Obligation UI Stata Input_OtherFeesSchedule.xls", cellrange(E9)
    
	***Cleaning The Data and Renaming Variables***
drop G
rename E Number
rename H Aggregate_Fees
capture gen Repayment_Date = date(F,"MDY")
capture rename F Repayment_Date
capture drop F
format Repayment_Date %td
order Number Repayment_Date
drop if _n==2 | _n==3

foreach var of varlist I-AF {
	capture destring `var', replace
	if `var'[1]==0 | `var'[1]==. { /* Drop Empty Disbursements to align number convention with Disbursement Schedule macros in 5.3 DoFile*/
		drop `var'
		}
	}	
drop if _n==1
capture drop if Number == . 
capture drop if Number == ""
destring Number Aggregate_Fees, replace 

	save "$Output_Path\Other Subsidy Fees.dta", replace
}

**Fee Sharing Schedule**
clear
dis "$FeeSharing"
if "$FeeSharing" == "Yes" { 
    import excel "${Output_Path}\DFC Obligation UI Stata Input_FeeSharingSchedule.xls", cellrange(E9)

	***Cleaning The Data and Renaming Variables***
drop G
rename E Number
rename H Fee_Sharing_Percent
capture gen Repayment_Date = date(F,"MDY")
capture rename F Repayment_Date
capture drop F
format Repayment_Date %td
order Number Repayment_Date
drop if _n==2 | _n==3

foreach var of varlist I-AF {
	capture destring `var', replace
	if `var'[1]==0 | `var'[1]==. { /* Drop Empty Disbursements to align number convention with Disbursement Schedule macros in 5.3 DoFile*/
		drop `var'
		}
	}	
drop if _n==1
capture drop if Number == . 
capture drop if Number == ""
destring Number Fee_Sharing_Percent, replace 
gen period = Number

	save "$Output_Path\Fee Sharing.dta", replace
}

**FX Inputs**
if "$FXCurrency" == "Yes" { 
	import excel "${Output_Path}\DFC Obligation UI Stata Input_FXInputs.xls", clear
	keep E F H I J
	rename (E F H I J) (No Date FX_Forward USD_2SD_Exposure Int_Forward)
	drop if _n<5
	destring _all, replace
	drop if No==.
	rename No period
	gen Repayment_Date=date(Date,"MDY")
	format Repayment_Date %td
	drop Date
	
***Develop ObPeriod for Merge based on date of obligation***
egen minperiod=min(period)
gen obperiod=period-minperiod
drop minperiod

	save "$Output_Path\FX Inputs.dta", replace	
	
}
