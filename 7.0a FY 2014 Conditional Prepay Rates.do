/*################################################################################## 
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *   
*  Generate Conditioned Prepayment Curves                                          *
*                                                                                  *
*  This .do file calculates expected default using moody's default curves          *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/

clear all
set more off
version 12.1
****************************

* Import Prepayment Assumptions
import excel "$path1\Inputs\Prepayment Assumptions.xls", firstrow
rename Cumulative_75PSA Cumulative_PrepayRate 
rename Cumulative_PrepayRate_Large Cumulative_PrepayRate_L
rename Cumulative_PrepayRate_Small Cumulative_PrepayRate_S

* Generate Marginal Prepayment Rates
sort Forecasted_Period
gen double Unconditional_Marginal_PR = Cumulative_PrepayRate - Cumulative_PrepayRate[_n-1] if _n>1
gen double Unconditional_Marginal_PR_L = Cumulative_PrepayRate_L - Cumulative_PrepayRate_L[_n-1] if _n>1
gen double Unconditional_Marginal_PR_S = Cumulative_PrepayRate_S - Cumulative_PrepayRate_S[_n-1] if _n>1

replace Unconditional_Marginal_PR = Cumulative_PrepayRate if _n==1
replace Unconditional_Marginal_PR_L = Cumulative_PrepayRate_L if _n==1
replace Unconditional_Marginal_PR_S = Cumulative_PrepayRate_S if _n==1

replace Unconditional_Marginal_PR = Unconditional_Marginal_PR/100
replace Unconditional_Marginal_PR_L = Unconditional_Marginal_PR_L/100
replace Unconditional_Marginal_PR_S = Unconditional_Marginal_PR_S/100

replace Cumulative_PrepayRate = Cumulative_PrepayRate/100
replace Cumulative_PrepayRate_L = Cumulative_PrepayRate_L/100
replace Cumulative_PrepayRate_S = Cumulative_PrepayRate_S/100

gen CMPR1 = Unconditional_Marginal_PR
gen CMPR1_L = Unconditional_Marginal_PR_L
gen CMPR1_S = Unconditional_Marginal_PR_S

egen max_Pd=max(Forecasted_Period)
local Limit=max_Pd
drop max_Pd

forvalues i = 2(1)`Limit' {
	sort Forecasted_Period
    gen double CMPR`i' = CMPR1/(1-Cumulative_PrepayRate[`i'-1]) if Forecasted_Period >= `i'
	}

forvalues i = 2(1)`Limit' {
	sort Forecasted_Period
    gen double CMPR`i'_L = CMPR1_L/(1-Cumulative_PrepayRate_L[`i'-1]) if Forecasted_Period >= `i'
	}
	
forvalues i = 2(1)`Limit' {
	sort Forecasted_Period
    gen double CMPR`i'_S = CMPR1_S/(1-Cumulative_PrepayRate_S[`i'-1]) if Forecasted_Period >= `i'
	}
	
forvalues i = 1(1)`Limit' {
	sort Forecasted_Period
    gen double CCPR`i' = sum(CMPR`i') if Forecasted_Period >= `i'
	}

forvalues i = 1(1)`Limit' {
	sort Forecasted_Period
    gen double CCPR`i'_L = sum(CMPR`i'_L) if Forecasted_Period >= `i'
	}

forvalues i = 1(1)`Limit' {
	sort Forecasted_Period
    gen double CCPR`i'_S = sum(CMPR`i'_S) if Forecasted_Period >= `i'
	}

reshape long CMPR CCPR , i(Forecasted_Period) j(Period_of_Disbursement, string)
gen CMPR_S=CMPR if regexm(Period_of_Disbursement,"_S")
gen CMPR_L=CMPR if regexm(Period_of_Disbursement,"_L")
gen CCPR_S=CCPR if regexm(Period_of_Disbursement,"_S")
gen CCPR_L=CCPR if regexm(Period_of_Disbursement,"_L")
replace CMPR=. if CMPR_S!=. | CMPR_L!=.
replace CCPR=. if CCPR_S!=. | CCPR_L!=.

replace Period_of_Disbursement=subinstr(Period_of_Disbursement,"_L","",.)
replace Period_of_Disbursement=subinstr(Period_of_Disbursement,"_S","",.)
destring(Period_of_Disbursement), replace

collapse (mean) Cumulative_PrepayRate Cumulative_PrepayRate_L Cumulative_PrepayRate_S Unconditional_Marginal_PR Unconditional_Marginal_PR_L Unconditional_Marginal_PR_S ///
(sum) CMPR CCPR CMPR_S CMPR_L CCPR_S CCPR_L, by (Forecasted_Period Period_of_Disbursement)

sort Period_of_Disbursement Forecasted_Period

/* PREPAYMENT ASSUMPTION uses old curves until 2020*/
drop *_L *_S
/*
drop Cumulative_PrepayRate Unconditional_Marginal_PR CMPR CCPR

if $LoanorTotalGuaranteedAmount <= 50000000 {
foreach var of varlist *_L {
drop `var'
}
foreach var of varlist *_S {
local new =subinstr("`var'","_S","",.)
rename `var' `new'
}
}

if $LoanorTotalGuaranteedAmount > 50000000 {
foreach var of varlist *_S {
drop `var'
}
foreach var of varlist *_L {
local new =subinstr("`var'","_L","",.)
rename `var' `new'
}
}
*/

* Save Prepayment Assumptions .dta file
save "$Output_Path\Prepayment Assumptions.dta", replace
