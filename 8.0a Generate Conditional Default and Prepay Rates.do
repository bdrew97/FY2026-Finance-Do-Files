/*##########################################################################################*    
*  U.S. International Development Finance Corporation 							            *
*  Obligation/Budget Formulation Model    										            *
*  Prepared by Summit Consulting, LLC                                              			*
*                                                                 		  	       			*
*  This .do file generates the following conditional rates:						   			*
* 	(1) Default Rates Conditioned on Survival (not defaulting in prior years)				*
*	(2) Default Rates Conditioned on Survival (not defaulting OR prepaying in prior years)	*
*	(3) Prepaymet Rates Conditioned on Suvival (not defaulting OR prepaying in prior years)	*
* Updated: 11/4/2015                                                              			*
*###########################################################################################*/
clear all
set more off
version 12.1
********************
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

* Save Prepayment Assumptions .dta file
save "$Output_Path\Prepayment Assumptions.dta", replace

*************************************************
* PART 1 - Default Rate Condtioned on Survival, 
*		   (not defaulting in prior years)
*************************************************
clear
import excel "$Risk_Path"

drop if B ==.

rename A Rating

*Rename V Recovery_Rate

if _N == 22 {
local varlist B C D E F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE AF AG AH AI AJ AK AL AM AN AO AP AQ AR AS AT AU AV AW AX AY
}

else {
local varlist B C D E F G H I J K L M N O P Q R S T U
}

foreach namevar of local varlist { 
    rename (`namevar') (Cumulative_DefaultRate`=`namevar'[1]')
	}

drop if _n==1

**destring Recovery, replace
gen double Recovery_Rate = $RecoveryRate
	
reshape long Cumulative_DefaultRate, i(Rating) j(Forecasted_Period)	

replace Cumulative_DefaultRate = Cumulative_DefaultRate/100

global RecoveryRate = Recovery_Rate[1]

bys Rating (Forecasted_Period): gen double Unconditional_Marginal_DR = Cumulative_DefaultRate -Cumulative_DefaultRate[_n-1]
replace Unconditional_Marginal_DR = Cumulative_DefaultRate if Forecasted_Period==1

gen double CMDR1 = Unconditional_Marginal_DR

bys Rating (Forecasted_Period): egen max_Pd=max(Forecasted_Period)
local Limit=max_Pd
drop max_Pd

forvalues i = 2(1)`Limit' {
    bys Rating (Forecasted_Period): gen double CMDR`i' = CMDR1/(1-Cumulative_DefaultRate[`i'-1]) if Forecasted_Period >= `i'
	}

forvalues i = 1(1)`Limit' {
    bys Rating (Forecasted_Period): gen double CCDR`i' = sum(CMDR`i') if Forecasted_Period >= `i'
	}

reshape long CMDR CCDR , i(Rating Forecasted_Period) j(Period_of_Disbursement)
sort Rating Period_of_Disbursement Forecasted_Period
rename (CMDR CCDR) (CMDR_noprepay CCDR_noprepay)

** Save Default Curves, to merge with Prepay Assumption
save "$Output_Path\Risk Table_Cond Default.dta", replace
merge m:1 Forecasted_Period using "$Output_Path\Prepayment Assumptions.dta", keepus(Cumulative_PrepayRate Cumulative_PrepayRate_L Cumulative_PrepayRate_S Unconditional_Marginal_PR Unconditional_Marginal_PR_L Unconditional_Marginal_PR_S)
drop if _merge==2
drop _merge

*****************************************************************
* PART 2 - Default Rate & Prepayment Rate Condtioned on Survival, 
*		   (not defaulting OR Prepaying in prior years)
*****************************************************************
* Generate Survival Rate (Probability of not defaulting OR prepaying in prior years)
gen double UMDR = Unconditional_Marginal_DR
gen double UMDR_L = Unconditional_Marginal_DR
gen double UMDR_S = Unconditional_Marginal_DR

gen double UMPR = Unconditional_Marginal_PR
gen double UMPR_L = Unconditional_Marginal_PR_L
gen double UMPR_S = Unconditional_Marginal_PR_S

replace UMDR = 0 if Period_of_Disbursement>Forecasted_Period
replace UMDR_L = 0 if Period_of_Disbursement>Forecasted_Period
replace UMDR_S = 0 if Period_of_Disbursement>Forecasted_Period

replace UMPR = 0 if Period_of_Disbursement>Forecasted_Period
replace UMPR_L = 0 if Period_of_Disbursement>Forecasted_Period
replace UMPR_S = 0 if Period_of_Disbursement>Forecasted_Period

bys Period_of_Disbursement Rating (Forecasted_Period): gen double defcond=UMDR if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double defcond_L=UMDR_L if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double defcond_S=UMDR_S if _n==1

bys Period_of_Disbursement Rating (Forecasted_Period): gen double precond=UMPR if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double precond_L=UMPR_L if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double precond_S=UMPR_S if _n==1

bys Period_of_Disbursement Rating (Forecasted_Period): gen double survivalrate=1-defcond-precond if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double survivalrate_L=1-defcond_L-precond_L if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double survivalrate_S=1-defcond_S-precond_S if _n==1

replace survivalrate=0 if UMDR==1
replace survivalrate_L=0 if UMDR_L==1
replace survivalrate_S=0 if UMDR_S==1

mvencode survivalrate* defcond* precond*, mv(0) override

local i=2
forvalues i=2/50 {
bys Period_of_Disbursement Rating (Forecasted_Period): replace defcond=UMDR*survivalrate[_n-1] if _n==`i'
bys Period_of_Disbursement Rating (Forecasted_Period): replace defcond_L=UMDR_L*survivalrate_L[_n-1] if _n==`i'
bys Period_of_Disbursement Rating (Forecasted_Period): replace defcond_S=UMDR_S*survivalrate_S[_n-1] if _n==`i'

bys Period_of_Disbursement Rating (Forecasted_Period): replace precond=UMPR*survivalrate[_n-1] if _n==`i'
bys Period_of_Disbursement Rating (Forecasted_Period): replace precond_L=UMPR_L*survivalrate_L[_n-1] if _n==`i'
bys Period_of_Disbursement Rating (Forecasted_Period): replace precond_S=UMPR_S*survivalrate_S[_n-1] if _n==`i'

bys Period_of_Disbursement Rating (Forecasted_Period): replace survivalrate=survivalrate[_n-1]-defcond-precond if _n==`i'
bys Period_of_Disbursement Rating (Forecasted_Period): replace survivalrate_L=survivalrate_L[_n-1]-defcond_L-precond_L if _n==`i'
bys Period_of_Disbursement Rating (Forecasted_Period): replace survivalrate_S=survivalrate_S[_n-1]-defcond_S-precond_S if _n==`i'

local i=`i'+1
}

bys Period_of_Disbursement Rating (Forecasted_Period): gen double jointCCDR=defcond if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double jointCCDR_L=defcond_L if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double jointCCDR_S=defcond_S if _n==1

bys Period_of_Disbursement Rating (Forecasted_Period): gen double jointCCPR=precond if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double jointCCPR_L=precond_L if _n==1
bys Period_of_Disbursement Rating (Forecasted_Period): gen double jointCCPR_S=precond_S if _n==1

bys Period_of_Disbursement Rating (Forecasted_Period): replace jointCCDR=defcond+jointCCDR[_n-1] if _n!=1
bys Period_of_Disbursement Rating (Forecasted_Period): replace jointCCDR_L=defcond_L+jointCCDR_L[_n-1] if _n!=1
bys Period_of_Disbursement Rating (Forecasted_Period): replace jointCCDR_S=defcond_S+jointCCDR_S[_n-1] if _n!=1

bys Period_of_Disbursement Rating (Forecasted_Period): replace jointCCPR=precond+jointCCPR[_n-1] if _n!=1
bys Period_of_Disbursement Rating (Forecasted_Period): replace jointCCPR_L=precond_L+jointCCPR_L[_n-1] if _n!=1
bys Period_of_Disbursement Rating (Forecasted_Period): replace jointCCPR_S=precond_S+jointCCPR_S[_n-1] if _n!=1

rename (defcond precond defcond_L precond_L defcond_S precond_S) (jointCMDR jointCMPR jointCMDR_L jointCMPR_L jointCMDR_S jointCMPR_S)
replace jointCCPR=0 if jointCCDR==1
replace jointCCPR_L=0 if jointCCDR_L==1
replace jointCCPR_S=0 if jointCCDR_S==1

gen check = jointCCPR+jointCCDR+survivalrate
gen check_L = jointCCPR_L+jointCCDR_L+survivalrate_L
gen check_S = jointCCPR_S+jointCCDR_S+survivalrate_S
codebook check check_L check_S

** Save Full Risk Table
save "$Output_Path\Full Risk Table_Cond Default and Prepay.dta", replace
preserve
keep if Rating == "$DFCRiskRating"

/* PREPAYMENT ASSUMPTION uses old curves until 2020*/
drop *_L *_S
/*
drop Cumulative_PrepayRate Unconditional_Marginal_PR UMDR UMPR jointCMDR jointCMPR survivalrate jointCCDR jointCCPR check

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

** Save Risk Table with Project Credit Rating only
save "$Output_Path\Risk Table_Cond Default and Prepay.dta", replace
restore

foreach var of varlist CMDR_noprepay CCDR_noprepay jointCCDR jointCMDR {
rename `var' `var'_FS
}
keep if Rating == "$FeeSharingRiskRating"
save "$Output_Path\Risk Table_Cond Default and Prepay FS.dta", replace
