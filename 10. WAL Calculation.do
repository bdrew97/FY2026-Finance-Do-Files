/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file calculates the weighted average life of the loan                  *
*  Updated: 8-4-2017                                                               *
*#################################################################################*/

clear all
set more off
version 12.1

use "$Output_Path\Life Table Step 3.dta"

***Weighted Average Life Calculation***
gen double WAL = 0 
forvalues i= 1(1)$NumberofDisbursementPeriods {
    replace WAL = (Principal)*((Repayment_Date - Disbursement_Date)/days_in_year) if UPB_SOP <= ${DisbAmount`i'} & Disbursement_Number == `i'
	replace WAL = ((${DisbAmount`i'} - UPB_EOP))*((Repayment_Date - Disbursement_Date)/days_in_year) if UPB_SOP > ${DisbAmount`i'} & UPB_EOP < ${DisbAmount`i'} & Disbursement_Number == `i'
	}
egen Total_WAL = total (WAL)
replace Total_WAL = Total_WAL/(${LoanorTotalGuaranteedAmount} + Cap_Interest)


***Base Interest Weighted Average***
gen double Interest_Dummy = 1 if Interest ~=0 | Cap_Interest ~=0
gen double Days_UPB = days*UPB_SOP if Interest_Dummy == 1
egen double totalupbsdays = total(Days_UPB) if Interest_Dummy == 1
gen  double baseavg = Interest_Rate*Days_UPB/totalupbsdays
egen double Base_Interest_WA = total(baseavg)
drop Interest_Dummy Days_UPB totalupbsdays baseavg

***Include Capitalized Interest in Disbursements and Obligation Amount***	   
if "$DirectGuaranteed"=="Direct Loan" {
if "$PrincipalPaymentStructure" == "Custom" {
bys Disbursement_Number: egen double Total_Principal=sum(Principal_Including_CapInterest)
}
if "$PrincipalPaymentStructure" != "Custom" {
bys Disbursement_Number: egen double Total_Principal=sum(Principal)
}
/*
replace Disbursement=Total_Principal if  Disbursement!=0
egen double Total_Disbursement=sum(Disbursement)
replace Obligation=Total_Disbursement if Obligation!=0
global LoanorTotalGuaranteedAmount=Total_Disbursement
dis $LoanorTotalGuaranteedAmount
drop Total_Principal Total_Disbursement 
*/
capture drop Principal_Including_CapInterest
}

* In case DSRA was 0 this will prevent an error
capture gen double DSRA_SOP = 0
capture gen double DSRA_EOP = 0
capture gen double DSRA_Draw = 0
capture gen double DSRA_Draw_Def = 0
capture gen double DSRA_Draw_Fee = 0

* In case fees are not shared this will prevent an error
capture gen double Shared_Fees_RE = 0
capture gen double Shared_Commitment_Fees_RE = 0
capture gen double Shared_Lost_Fees_RE = 0 
capture gen double Shared_Defaults_RE = 0

save "$Output_Path\Life Table Step 4.dta", replace

