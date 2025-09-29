/*##########################################################################################*    
*  U.S. International Development Finance Corporation 							   			*
*  Obligation/Budget Formulation Model    										   			*
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
* Generate Marginal Prepayment Rates
sort Forecasted_Period
gen double Unconditional_Marginal_PR = Cumulative_PrepayRate - Cumulative_PrepayRate[_n-1] if _n>1
replace Unconditional_Marginal_PR = Cumulative_PrepayRate if _n==1
replace Unconditional_Marginal_PR = Unconditional_Marginal_PR/100
replace Cumulative_PrepayRate = Cumulative_PrepayRate/100
* Save Prepayment Assumptions .dta file
save "$Output_Path\Prepayment Assumptions.dta", replace

*************************************************
* PART 1 - Default Rate Condtioned on Survival, 
*		   (not defaulting in prior years)
*************************************************
clear
import excel "$ICRAS_Path"
drop if missing(B)

*Rename Variables
	*ICRAS Ratings cannot be used directly as variable names due to "-" signs
local i=1
foreach var in B C D E F G H I J {
	rename (`var') (rating`i')
	local i=`i'+1
	}

rename A Year
drop if _n==1
destring Year, replace

*Reshape
reshape long rating, i(Year) j(numrating)
rename rating Cumulative_DefaultRate
rename Year Forecasted_Period
sort numrating Forecasted_Period

destring Cumulative_DefaultRate, replace
tostring numrating, generate(icras_rating)

replace icras_rating="A" if numrating==1
replace icras_rating="B" if numrating==2
replace icras_rating="C" if numrating==3
replace icras_rating="C-" if numrating==4
replace icras_rating="D" if numrating==5
replace icras_rating="D-" if numrating==6
replace icras_rating="E" if numrating==7
replace icras_rating="E-" if numrating==8
replace icras_rating="F" if numrating==9

drop numrating

bys icras_rating (Forecasted_Period): gen Unconditional_Marginal_DR = Cumulative_DefaultRate -Cumulative_DefaultRate[_n-1]
replace Unconditional_Marginal_DR = Cumulative_DefaultRate if Forecasted_Period==1

gen CMDR1 = Unconditional_Marginal_DR

bys icras_rating (Forecasted_Period): egen max_Pd=max(Forecasted_Period)
local Limit=max_Pd
drop max_Pd

forvalues i = 2(1)`Limit' {
    bys icras_rating (Forecasted_Period): gen double CMDR`i' = CMDR1/(1-Cumulative_DefaultRate[`i'-1]) if Forecasted_Period >= `i'
	}

forvalues i = 1(1)`Limit' {
    bys icras_rating (Forecasted_Period): gen double CCDR`i' = sum(CMDR`i') if Forecasted_Period >= `i'
	}

reshape long CMDR CCDR , i(icras_rating Forecasted_Period) j(Period_of_Disbursement)
sort icras_rating Period_of_Disbursement Forecasted_Period
rename (CMDR CCDR) (CMDR_noprepay CCDR_noprepay)

** Generate ICRAS Recovery Assumption; fixed for NHSG & AAD
gen double Recovery_Rate=0.51 if "${DirectGuaranteed}"=="Investment Guaranty - NHSG"
replace Recovery_Rate=0.85 if "${DirectGuaranteed}"=="Arbital Award Decision"

** Save Default Curves, to merge with Prepay Assumption
save "$Output_Path\Risk Table_Cond Default.dta", replace
merge m:1 Forecasted_Period using "$Output_Path\Prepayment Assumptions.dta", keepus(Cumulative_PrepayRate Unconditional_Marginal_PR)
drop if _merge==2
drop _merge

*****************************************************************
* PART 2 - Default Rate & Prepayment Rate Condtioned on Survival, 
*		   (not defaulting OR Prepaying in prior years)
*****************************************************************
* Generate Survival Rate (Probability of not defaulting OR prepaying in prior years)
gen double UMDR = Unconditional_Marginal_DR
gen double UMPR = Unconditional_Marginal_PR
replace UMDR = 0 if Period_of_Disbursement>Forecasted_Period
replace UMPR = 0 if Period_of_Disbursement>Forecasted_Period

bys Period_of_Disbursement icras_rating (Forecasted_Period): gen double defcond=UMDR if _n==1
bys Period_of_Disbursement icras_rating (Forecasted_Period): gen double precond=UMPR if _n==1
bys Period_of_Disbursement icras_rating (Forecasted_Period): gen double survivalrate=1-defcond-precond if _n==1
replace survivalrate=0 if UMDR==1

mvencode survivalrate defcond precond, mv(0) override

local i=2
forvalues i=2/30 {
bys Period_of_Disbursement icras_rating (Forecasted_Period): replace defcond=UMDR*survivalrate[_n-1] if _n==`i'
bys Period_of_Disbursement icras_rating (Forecasted_Period): replace precond=UMPR*survivalrate[_n-1] if _n==`i'
bys Period_of_Disbursement icras_rating (Forecasted_Period): replace survivalrate=survivalrate[_n-1]-defcond-precond if _n==`i'
local i=`i'+1
}

bys Period_of_Disbursement icras_rating (Forecasted_Period): gen double jointCCDR=defcond if _n==1
bys Period_of_Disbursement icras_rating (Forecasted_Period): gen double jointCCPR=precond if _n==1
bys Period_of_Disbursement icras_rating (Forecasted_Period): replace jointCCDR=defcond+jointCCDR[_n-1] if _n!=1
bys Period_of_Disbursement icras_rating (Forecasted_Period): replace jointCCPR=precond+jointCCPR[_n-1] if _n!=1

rename (defcond precond) (jointCMDR jointCMPR)
replace jointCCPR=0 if jointCCDR==1

gen check = jointCCPR+jointCCDR+survivalrate
codebook check

** Save Full Risk Table
save "$Output_Path\Full Risk Table_Cond Default and Prepay.dta", replace
keep if icras_rating == "$ICRASRiskRating"
** Save Risk Table with Project Credit Rating only
save "$Output_Path\Risk Table_Cond Default and Prepay.dta", replace
