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

use "$Output_Path\Other Subsidy Fees.dta", replace

*** Rename Variables ***
foreach var of varlist _all {
	local x "`x' `var'"
	dis "`x'"
	}
local numbx : word count `x'
dis `numbx'

local j=1
forval i=4/`numbx' {
		local vars `: word `i' of `x''
		dis "`vars'" " " "Disb`j'"
		rename `vars' Disb`j'
		assert `j'==$NumberofDisbursementPeriods if `i'==`numbx'
		local j=`j'+1
			}
	
keep Number Repayment_Date Aggregate_Fees Disb*
sort Number

*** Identify if User specified Aggregate Fees Level, Disbursement Level Fees, or Both ***
egen double TotFees_Loan=total(Aggregate_Fees)
forval i = 1/$NumberofDisbursementPeriods {
	egen double TotFees_D`i'=total(Disb`i')
	}
egen double Sum_DisbFees=rowtotal(TotFees_D*)
gen double Diff=TotFees_Loan-Sum_DisbFees
drop TotFees* Sum_DisbFees

	*** User specified Fees for each Disbursement ***
if Diff <= abs(0.01) {
	global AggregateFees = 0 /*keep same variable name "Fees" in both cases & use the global macro to ID whether variable is aggregate or disbursement level. For use in 6. Lifetable.do */
	keep Number Repayment_Date Disb* Diff
	reshape long Disb, i(Number) j(Disbursement_Number)
	sort Disbursement_Number Repayment_Date
	rename Disb Fees
	order Number Repayment_Date Fees Disbursement_Number
	format Fees %16.2fc
	mvencode Fees, mv(0) override
	replace Fees=Fees/$GuaranteedPercent if "$DirectGuaranteed" ~= "Direct Loan"
	}

	*** User specified Fees on the aggregate ***
if Diff > abs(0.01) {
	global AggregateFees = 1
	forval i = 1/$NumberofDisbursementPeriods {
	replace Disb`i'=Aggregate_Fees if Repayment_Date>${DisbDate`i'}
		}
	keep Number Repayment_Date Disb* Diff
	reshape long Disb, i(Number) j(Disbursement_Number)
	sort Disbursement_Number Repayment_Date
	rename Disb AggregateFees
	order Number Repayment_Date AggregateFees Disbursement_Number
	format AggregateFees %16.2fc
	drop if AggregateFees == .
	replace AggregateFees=AggregateFees/$GuaranteedPercent if "$DirectGuaranteed" ~= "Direct Loan"
	}
drop Diff

***Develop Period for Merge based on date of first payment***
bys Disbursement_Number : gen period = Number

***Finalizing and Saving the Dataset***
save "$Output_Path\Other Subsidy Fees Formatted.dta", replace
