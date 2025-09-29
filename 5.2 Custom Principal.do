/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file formats the custom principal schedule input at either Loan Level, *
*  Disbursement Level, or Both.						                               *
*  Updated: 04/2014                                                                *
*#################################################################################*/
clear all
set more off
version 12.1

use "$Output_Path\Principal Custom.dta", replace

*** Rename Variables ***
drop G
rename H Aggregate_Princ
	*** Drop empty disbursements - necessary if some disbursements=0 and Repayments specified at Disbursement Level ***
foreach var of varlist I-AF {
	replace `var'=0 if `var'==.
	egen double t`var'=total(`var')
	if t`var'==0 {
		drop `var' t`var'
		}
	else {
		drop t`var'
		}
	}
	*** Rename remaining disbursments ***
foreach var of varlist _all {
	local x "`x' `var'"
	dis "`x'"
	}
	
local numbx : word count `x'
dis `numbx'

if `numbx' == 3 {
	forval i=1/$NumberofDisbursementPeriods {
		gen double Disb`i'=.
		}
	}
if `numbx'>3 {
	local j=1
	forval i=4/`numbx' {
		local vars `: word `i' of `x''
		dis "`vars'" " " "Disb`j'"
		rename `vars' Disb`j'
		local j=`j'+1
			}
	}

keep Number Repayment_Date Aggregate_Princ Disb*
sort Number

*** Identify if User specified Aggregate Principal Level, Disbursement Level Principal, or Both ***
egen double TotPrinc_Loan=total(Aggregate_Princ)
forval i = 1/$NumberofDisbursementPeriods {
	egen double TotPrinc_D`i'=total(Disb`i')
	}
egen double Sum_DisbPrinc=rowtotal(TotPrinc_D*)
gen double Diff=TotPrinc_Loan-Sum_DisbPrinc
drop TotPrinc* Sum_DisbPrinc
	*** User specified Disbursement Level Principal ***
if Diff <= abs(0.01) {
	keep Number Repayment_Date Disb* Diff
	reshape long Disb, i(Number) j(Disbursement_Number)
	sort Disbursement_Number Repayment_Date
	}

	*** User specified only Aggregate Level Principal ***
if Diff > abs(0.01) {
*** Generate variables used for principal disaggregation ***
	*Disbursements-to-Date
forval i = 1/$NumberofDisbursementPeriods {
	gen double UPBSOP_D`i'= ${DisbAmount`i'} if Repayment_Date>${DisbDate`i'}
	}
mvencode UPBSOP_D*, mv(0) override
egen double Disb_to_date=rowtotal(UPBSOP_D*)
drop UPBSOP_D*
	*Loan Level UPB
gen double LoanUPB_SOP=Disb_to_date if _n==1
gen double CumRepay_Loan=sum(Aggregate_Princ)
replace LoanUPB_SOP=Disb_to_date-CumRepay_Loan[_n-1] if _n>1

reshape long Disb, i(Number) j(Disbursement_Number)
sort Disbursement_Number Repayment_Date

*** Prorate using Disbursement UPB / Loan UPB ***
gen disbursed=0
gen double DisbUPB_SOP=0
*mvencode Disb, mv(0) override
forval i=1/$NumberofDisbursementPeriods {
	replace DisbUPB_SOP = ${DisbAmount`i'} if Disbursement_Number==`i' & Repayment_Date>${DisbDate`i'}
	replace disbursed=1 if Disbursement_Number==`i' & Repayment_Date>${DisbDate`i'}
	}
	*Period 1
replace Disb=(DisbUPB_SOP/LoanUPB_SOP)*Aggregate_Princ if Number==1 & disbursed==1
	*Remaining Periods
egen NumPds=max(Number)
local NumPds=NumPds
forval i=2/`NumPds' {
	bys Disbursement_Number (Number): replace DisbUPB_SOP=DisbUPB_SOP[_n-1]-Disb[_n-1] if Number==`i' & disbursed[_n-1]==1
	replace Disb=(DisbUPB_SOP/LoanUPB_SOP)*Aggregate_Princ if Number==`i' & disbursed==1
	}
/* QC */
mvencode Aggregate_Princ Disb, mv(0) override
bys Repayment_Date (Disbursement_Number): egen double SumbyPd=total(Disb)
bys Disbursement_Number (Repayment_Date): egen double SumbyDisb=total(Disb)
assert SumbyPd-Aggregate_Princ<=abs(.01)
gen double DisbAmount=0
forval i=1/$NumberofDisbursementPeriods {
	replace DisbAmount=${DisbAmount`i'} if Disbursement_Number==`i'	
	assert SumbyDisb-DisbAmount<=abs(.01) if Disbursement_Number==`i'	
	}
	*Rounding - add difference to last period
	replace Disb=round(Disb,.01)
	replace DisbAmount=round(DisbAmount,.01)
	bys Disbursement_Number (Repayment_Date): egen double RoundSumbyDisb=total(Disb)
	gen double Rounding_Diff=DisbAmount-RoundSumbyDisb
	bys Disbursement_Number (Repayment_Date): replace Disb=Disb+Rounding_Diff if _n==_N

}
keep Number Disbursement_Number Repayment_Date Disb
sort Disbursement_Number Repayment_Date
rename Disb Principal
order Number Repayment_Date Principal Disbursement_Number

***Develop Period for Merge based on date of first payment***
bys Disbursement_Number : gen period = _n-1
replace period=period+$Principalbeginsendofperiod

***Finalizing and Saving the Dataset***
format Principal %16.2fc
drop if Principal == .

save "$Output_Path\Custom Principal Formatted.dta", replace
