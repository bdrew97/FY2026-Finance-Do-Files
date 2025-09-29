/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file Works with the DSRA                                               *
*  Updated: 10-31-2012                                                              *
*#################################################################################*/
clear all
set more off
version 12.1
***************************************

use "$Output_Path\Life Table with Risk.dta"
gen double DSRA_SOP = $FundedDSRAorLCsecurity

gen FirstLossAmount="$FirstLossAmount"
destring FirstLossAmount, replace
replace DSRA_SOP = FirstLossAmount if FirstLossAmount > 0
drop FirstLossAmount

local riskvars  Default Lost_Fee Recovery
foreach varname of local riskvars {
	replace `varname' = 0 if `varname'==.
	}

if "$DirectGuaranteed" == "Direct Loan"  {
    gen double DSRA_EOP = DSRA_SOP + Default
    sort Repayment_Date Disbursement_Number

    local END = _N
    forvalues i=2(1)`END' {
	  replace DSRA_SOP = DSRA_EOP[_n-1] if `i'==_n
      replace DSRA_EOP = DSRA_SOP + Default if `i'==_n
      }

      gen double DSRA_Draw = DSRA_SOP - DSRA_EOP if DSRA_EOP>=0
      replace DSRA_Draw = DSRA_SOP if DSRA_SOP>0 & DSRA_EOP<=0
      replace DSRA_Draw = 0 if DSRA_SOP <=0	
		replace DSRA_SOP = 0 if DSRA_SOP < 0
		replace DSRA_EOP = 0 if DSRA_EOP < 0
	  
    replace Default = round(Default + DSRA_Draw,.01)
    replace Recovery = round(-1*Recovery_Rate*(Default),.01)
	
}

if "$DirectGuaranteed" ~= "Direct Loan"  {
    gen double DSRA_MOP = DSRA_SOP - Default
	gen double DSRA_EOP = DSRA_MOP + Lost_Fee
	sort Repayment_Date Disbursement_Number
	
	local END = _N
    forvalues i=2(1)`END' {
      replace DSRA_SOP = DSRA_EOP[_n-1] if `i'==_n
	  replace DSRA_MOP = DSRA_SOP - Default if `i'==_n
      replace DSRA_EOP = DSRA_MOP + Lost_Fee if `i'==_n
      }
	  
	  gen double DSRA_Draw_Def = DSRA_SOP - DSRA_MOP if DSRA_MOP>=0
      replace DSRA_Draw_Def = DSRA_SOP if DSRA_SOP>0 & DSRA_MOP<=0
      replace DSRA_Draw_Def = 0 if DSRA_SOP <=0
	  
	  gen double DSRA_Draw_Fee = DSRA_MOP - DSRA_EOP if DSRA_MOP>=0
	  replace DSRA_Draw_Fee = DSRA_MOP if DSRA_MOP>0 &  DSRA_EOP<=0
	  replace DSRA_Draw_Fee = 0 if DSRA_EOP <=0
	  	replace DSRA_SOP = 0 if DSRA_SOP < 0
		replace DSRA_MOP = 0 if DSRA_MOP < 0 
		replace DSRA_EOP = 0 if DSRA_EOP < 0
	  
	  gen double DSRA_Draw = DSRA_Draw_Fee + DSRA_Draw_Def
	  
	  replace Default = round(Default - DSRA_Draw_Def,.01)
	  replace Lost_Fee = round(Lost_Fee + DSRA_Draw_Fee,.01)
      replace Recovery = round(-1*Recovery_Rate*(Default - Lost_Fee),.01)
	  }
	  
/*	  *** First Loss Code Adjustments ***
if "$DirectGuaranteed" == "Direct Loan" {
	  gen FirstLossAmount="$FirstLossAmount"
	  destring FirstLossAmount, replace
	  
	  gen DFCLoan="$DFCLoan"
	  destring DFCLoan, replace
	  
	  gen double FirstLossCap=DFCLoan-FirstLossAmount

	  gen double DefaultSum=-sum(Default)
	  	  
	  gen FirstLoss=_n if DefaultSum>FirstLossCap
	  replace FirstLoss=1000 if DefaultSum<=FirstLossCap 
	  egen minFirstLoss=min(FirstLoss)
	  replace FirstLoss=0 if DefaultSum<=FirstLossCap
	  
	  gen double DefaultLower=DefaultSum-FirstLossCap if minFirstLoss==FirstLoss
	  replace DefaultLower=Default if minFirstLoss<FirstLoss
	  
	  replace DefaultLower=-DefaultLower if "$DirectGuaranteed" == "Direct Loan" & DefaultLower>0
	  replace DefaultLower=0 if DefaultLower==.

	  replace Default = round(Default-DefaultLower, .01)
	  replace Recovery = round(-1*Recovery_Rate*(Default - Lost_Fee),.01)
}

if "$DirectGuaranteed" ~= "Direct Loan" {
	  gen FirstLossAmount="$FirstLossAmount"
	  destring FirstLossAmount, replace
	  
	  gen DFCLoan="$DFCLoan"
	  destring DFCLoan, replace
	  
	  gen double FirstLossCap=DFCLoan-FirstLossAmount
	  
	  gen double DefaultSum = sum(Default)	  
	  gen double LostFeeSum = -sum(Lost_Fee)
	  gen double TotalDefaultSum = DefaultSum+LostFeeSum
	  	  
	  gen FirstLoss=_n if TotalDefaultSum>FirstLossCap
	  replace FirstLoss=1000 if TotalDefaultSum<=FirstLossCap 
	  egen minFirstLoss=min(FirstLoss)
	  replace FirstLoss=0 if TotalDefaultSum<=FirstLossCap
	  
	  gen double LostFeeLower=TotalDefaultSum-FirstLossCap if minFirstLoss==FirstLoss
	  replace LostFeeLower=-Lost_Fee if minFirstLoss==FirstLoss & -Lost_Fee<LostFeeLower
	  replace LostFeeLower=-Lost_Fee if minFirstLoss<FirstLoss

	  gen double DefaultLower=TotalDefaultSum-LostFeeLower-FirstLossCap if minFirstLoss==FirstLoss
	  replace DefaultLower=Default if minFirstLoss==FirstLoss & Default<DefaultLower
	  replace DefaultLower=Default if minFirstLoss<FirstLoss
	  
	  replace LostFeeLower=0 if LostFeeLower==.
	  replace DefaultLower=0 if DefaultLower==.

	  replace Lost_Fee = round(Lost_Fee+LostFeeLower, .01)
	  replace Default = round(Default-DefaultLower, .01)
	  replace Recovery = round(-1*Recovery_Rate*(Default - Lost_Fee),.01)

	  drop LostFeeSum TotalDefaultSum LostFeeLower

}
	  drop FirstLossAmount DFCLoan FirstLoss DefaultSum minFirstLoss
	  
	  *********************************** */
	  
	  save "$Output_Path\Life Table with Risk.dta", replace 
