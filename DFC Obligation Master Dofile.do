/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file is the master                                                     *
*  Updated: 8-4-2017                                                              *
*#################################################################################*/
clear all
set more off
set update_query off
version 12.1

pause on
*global input_path = "`1'"
global path1 = "`1'"
global PrincipalPaymentStructure = "`2'"
capture noisily global version "`3'"
global OtherSubFees = "`4'"
global FeeSharing = "`5'"
global FXCurrency = "`6'"
global Currency = "`7'"
global LoanType = "`8'"

if "$version"!="v1_2026_FinanceModel" { 
	dis as error _newline "ATTENTION: The version of the Excel Model Template that you are using is not compatible with this version of the Stata program files." ///
	_newline _column(12) "Please use latest model template and files. To exit STATA, type 'q'."
	pause
	exit, STATA
	}

global Dofile_Path  "$path1\DoFiles\v1_2026_FinanceModel"
global Output_Path  "$path1\Outputs\\${LoanType}"

capture log close
capture log using "$Output_Path\Obligation Run.log",replace

dis "1 = `1'"
dis "2 = `2'"
*dis "3 = `3'"

***Import Data***

do "$Dofile_Path\1. Data Import.do"

***Establish Macros***

do "$Dofile_Path\2. Establishing Global Macros.do"

***Storing the Disbursement Schedule***

do "$Dofile_Path\3. Storing the Disbursement Schedule.do"

***Life Table Creation: Principal, Interest, and Fees***
   
   ***Commitment Fee Calculation***
   
   do "$Dofile_Path\4. Calculating Commitment Fee.do"
   
   ***Custom Principal Calculation***

   if "$PrincipalPaymentStructure" == "Custom" { 
    do "$Dofile_Path\5.2 Custom Principal.do"
	}
   *** Custom Fee Schedule ***
   if "$OtherSubFees" == "Yes" { 
    do "$Dofile_Path\5.3 Other Subsidy Fees.do"
	}

   ***Lifetable Creation***

   do "$Dofile_Path\6. Lifetable Creation.do"
   
***Life Table Creation: Defaults and Recoveries***

    ***Defaults & Recoveries Calculation FY 2014 Methodology (Risk Matrix)***
	
	if "$DefaultMethodology" == "FY2014 Risk Methodology" {
	do "$Dofile_Path\7.0a FY 2014 Conditional Prepay Rates.do"
	do "$Dofile_Path\7. FY 2014 Default Rates Methodology.do"
	}
	
	***Default & Recoveries Calculation Moody's Risk Methodology ***

	if "$DefaultMethodology" == "Moody's Risk Methodology"  {
	do "$Dofile_Path\8.0a Generate Conditional Default and Prepay Rates.do"
	do "$Dofile_Path\8.0b Moody's Default Rates Methodology.do"
	}

	if "$DefaultMethodology" == "ICRAS" {
	do "$Dofile_Path\8.1a Generate Conditional ICRAS Default and Prepay Rates.do"
	do "$Dofile_Path\8.1 ICRAS Default Rates Methodology.do"
	}
	
		if 0<$FundedDSRAorLCsecurity | "$FirstLossAmount" != "0"{
	do "$Dofile_Path\DSRA 2012.do" /*DSRA and first loss work*/
	}

	***Recoveries Date Adjustments***

	do "$Dofile_Path\9. Recovery Date Adjustments.do"

	if "$PrepaymentRiskonFees" == "Yes" {
	do "$Dofile_Path\9.1 Prepayments.do"
	}
***Weighted Average Life Calculation***

do "$Dofile_Path\10. WAL Calculation.do"

***Export To Excel***

    do "$Dofile_Path\10.2 Export Life Table.do"

if "$FXCurrency" == "Yes" & "$DirectGuaranteed" == "Direct Loan" {
	do "$Dofile_Path\10.3 Convert FX Cash Flow to USD (DI).do"
	}
if "$FXCurrency" == "Yes" & "$DirectGuaranteed" != "Direct Loan" {
	do "$Dofile_Path\10.4 Convert FX Cash Flow to USD (IG).do"
	}

***Formatting Into a Cashflow***

	***Compressing the Life Table***
	
	do "$Dofile_Path\11. Compress Lifetable.do"
	
	***Part 1 of 3 for the Cash Flow***
	
	do "$Dofile_Path\12. Cash Flow Panel 1 of 3.do"
	
	***Part 2 of 3 for the Cash Flow***
	
	do "$Dofile_Path\13. Cash Flow Panel 2 of 3.do"
	
	***Part 3 of 3 for the Cash Flow***
	
	do "$Dofile_Path\14. Cash Flow Panel 3 of 3.do"
	
	***Compile CSC Cash Flow***
	
	do "$Dofile_Path\15. Compile CSC cash flow.do"

*** Exit Stata

exit, STATA clear






