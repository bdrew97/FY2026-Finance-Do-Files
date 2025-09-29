/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file exports the life table to excel                                   *
*  Updated: 8-4-2017                                                              *
*#################################################################################*/
*Exports Life Table to Excel*
clear all
set more off
version 12.1

use "$Output_Path\Life Table Step 4.dta"

global apcvars = cond(${ForeignCurrencyAppreciationCo} ~=0, "APC_Default APC_Recovery", "")
global PrepayVar = cond("${PrepaymentRiskonFees}" == "Yes", "Other_Outflow_Prepay Other_Inflow_Prepay","")

if "$DefaultMethodology" == "FY2014 Risk Methodology" {
	
	keep Name ProjectID Repayment_Date Obligation Disbursement Commitment_Fees Principal Cap_Interest Interest Fees Default Lost_Fee Recovery Interest_Rate PostCompletion PreCompletion Borrower_Rate Default_Rate Recovery_Rate UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees Shared_Commitment_Fees Exposure Disbursement_Number Total_WAL Base_Interest_WA $apcvars $PrepayVar
    order Name ProjectID Repayment_Date Obligation Disbursement Commitment_Fees Principal Cap_Interest Interest Fees Default Lost_Fee Recovery ${apcvars} Interest_Rate PostCompletion PreCompletion Borrower_Rate Default_Rate Recovery_Rate UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees Shared_Commitment_Fees Exposure Disbursement_Number Total_WAL Base_Interest_WA
    rename PreCompletion Pre_Completion
    rename PostCompletion Post_Completion
	}
	
if "$DefaultMethodology" == "Moody's Risk Methodology" {

    keep Name ProjectID Repayment_Date Obligation Disbursement Commitment_Fees Principal Cap_Interest Interest Fees Default Lost_Fee Recovery Interest_Rate PostCompletion PreCompletion Borrower_Rate CMDR CCDR Recovery_Rate UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees Shared_Commitment_Fees Exposure Disbursement_Number Total_WAL Base_Interest_WA $apcvars $PrepayVar
    order Name ProjectID Repayment_Date Obligation Disbursement Commitment_Fees Principal Cap_Interest Interest Fees Default Lost_Fee Recovery ${apcvars} Interest_Rate PostCompletion PreCompletion Borrower_Rate CMDR CCDR Recovery_Rate UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees Shared_Commitment_Fees Exposure Disbursement_Number Total_WAL Base_Interest_WA
    rename PreCompletion Pre_Completion
    rename PostCompletion Post_Completion
    rename CMDR Cond_Marginal_Default_Rate
    rename CCDR Cond_Cumulative_Default_Rate
	}
	
if "$DefaultMethodology" == "ICRAS" {

    keep Name ProjectID Repayment_Date Obligation Disbursement Commitment_Fees Principal Cap_Interest Interest Fees Default Lost_Fee Recovery Interest_Rate PostCompletion PreCompletion Borrower_Rate CMDR CCDR Recovery_Rate UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees Shared_Commitment_Fees Exposure Disbursement_Number Total_WAL Base_Interest_WA $apcvars $PrepayVar
    order Name ProjectID Repayment_Date Obligation Disbursement Commitment_Fees Principal Cap_Interest Interest Fees Default Lost_Fee Recovery ${apcvars} Interest_Rate PostCompletion PreCompletion Borrower_Rate CMDR CCDR Recovery_Rate UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees Shared_Commitment_Fees Exposure Disbursement_Number Total_WAL Base_Interest_WA
    rename PreCompletion Pre_Completion
    rename PostCompletion Post_Completion
    rename CCDR Cond_Cumulative_Default_Rate	
	}

*Add working capital fees to the life table	
gen WC_Fees = 0
gen rep_month = month(Repayment_Date)
gen maintenance = 1 if rep_month == month($DateofFirstPayment)
replace maintenance = 0 if maintenance == .
replace maintenance = 0 if Repayment_Date <= $DateofFirstPayment
replace maintenance = 0 if Repayment_Date > $DateofFinalRepayment
replace maintenance = 0 if Fees == 0
replace WC_Fees = $GiftAuthority if _n == 1
replace WC_Fees = $MaintenanceFee if maintenance == 1
drop maintenance rep_month
	
export excel using "$Output_Path\Life Table.xlsx", sheet("Life Table") firstrow(variables) replace 

clear


