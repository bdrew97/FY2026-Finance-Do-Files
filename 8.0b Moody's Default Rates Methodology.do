/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file calculates expected default using moody's default curves          *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/

use "$Output_Path\Life Table 1.dta", clear
gen double Forecasted_Period =  ceil((Repayment_Date - ${DisbDate1})/365.25)
replace Forecasted_Period = 1 if Forecasted_Period <= 0 

gen double Period_of_Disbursement = ceil((Disbursement_Date- ${DisbDate1})/365.25)
replace Period_of_Disbursement = 1 if Period_of_Disbursement <= 0 |Period_of_Disbursement==.

*** Merge Default and Prepayment Curves ***
merge m:1 Period_of_Disbursement Forecasted_Period using "$Output_Path\Risk Table_Cond Default and Prepay.dta", keepus(CMDR_noprepay CCDR_noprepay jointCCDR jointCMDR Recovery_Rate) 

sort Disbursement_Number Disbursement_Date Repayment_Date Period_of_Disbursement Forecasted_Period
drop if _merge==2
drop _merge

*** Generate Variable with Appropriate Default Rate, dependedent on "Prepayment Risk" selection in UI
gen double CCDR = 0 
gen double CMDR = 0
replace CCDR = CCDR_noprepay if "$PrepaymentRiskonFees" == "No"
replace CCDR = jointCCDR if "$PrepaymentRiskonFees" == "Yes"
replace CMDR = CMDR_noprepay if "$PrepaymentRiskonFees" == "No"
replace CMDR = jointCMDR if "$PrepaymentRiskonFees" == "Yes"

*** Merge Default and Prepayment Curves if Fee Sharing ***
if "$FeeSharing" == "Yes" {

merge m:1 Period_of_Disbursement Forecasted_Period using "$Output_Path\Risk Table_Cond Default and Prepay FS.dta", keepus(CMDR_noprepay_FS CCDR_noprepay_FS jointCCDR_FS jointCMDR_FS) 
sort Disbursement_Number Disbursement_Date Repayment_Date Period_of_Disbursement Forecasted_Period
drop if _merge==2
drop _merge

*** Generate Variable with Appropriate Default Rate, dependedent on "Prepayment Risk" selection in UI
gen double CCDR_FS = 0 
gen double CMDR_FS = 0
replace CCDR_FS = CCDR_noprepay_FS if "$PrepaymentRiskonFees" == "No"
replace CCDR_FS = jointCCDR_FS if "$PrepaymentRiskonFees" == "Yes"
replace CMDR_FS = CMDR_noprepay_FS if "$PrepaymentRiskonFees" == "No"
replace CMDR_FS = jointCMDR_FS if "$PrepaymentRiskonFees" == "Yes"
}

*##################################################*

if "$DirectGuaranteed" == "Direct Loan"  {
	if "$FeeSharing" == "No" | "$FeeSharing" == "Not Available" {
    *Calculating the Default Amount on Principal and Interest for Each Period (Direct Loans)*
    replace Default = round(-1*(Principal + Interest)*CCDR, .01)

    *Calculate the Lost Fee (Default on Fees) if applicable*
    replace Default = round(Default - (Fees + Commitment_Fees)* CCDR, .01) if "$DefaultRiskonFees" == "Yes"
    
	*Calculates the nominal recovery on the default for each period*
    replace Recovery = round(-1*Recovery_Rate*(Default), .01)
	}

	*FEE SHARING WITH DIRECT LOANS
	if "$FeeSharing" == "Yes" {
		*Calculate Project Defaults
		gen double DefaultP =-1*(Principal)*CCDR 
		gen double DefaultI =-1*(Interest)*CCDR
		replace Default = DefaultP + DefaultI 

		gen double Default_fees_OPIC = round(-1*(Fees + Commitment_Fees)* (CCDR),.01) if "$DefaultRiskonFees" == "Yes"
		gen double Default_fees_FS = round(-1*(Shared_Fees + Shared_Commitment_Fees)* (CCDR), .01) if "$DefaultRiskonFees" == "Yes"
		gen double Default_fees_RE = round(-1*(Shared_Fees_RE + Shared_Commitment_Fees_RE)* (CCDR), .01) if "$DefaultRiskonFees" == "Yes"
		gen Default_fees = Default_fees_OPIC + Default_fees_FS
		
		*Calculate Fee Sharing Portion of Defaults
		gen double DefaultP_FS=DefaultP*${FeeSharingPercent}
		gen double DefaultI_FS=DefaultI*${FeeSharingPercent}
			*Calculate Defaults of Risk Sharing Entity
			gen double DefaultP_FS_RE=(DefaultP_FS)*CCDR_FS
			gen double DefaultI_FS_RE=(DefaultI_FS)*CCDR_FS
			*Difference is equal to Covered Defaults by Risk Entity
			gen double Default_P_Cov=DefaultP_FS-DefaultP_FS_RE
			gen double Default_I_Cov=DefaultI_FS-DefaultI_FS_RE
				*Risk and Fee Sharing is only for 8 years 
				merge m:1 Repayment_Date using "$Output_Path\Fee Sharing.dta", update keepusing(Fee_Sharing_Percent)
				foreach var of varlist DefaultP_FS - Default_I_Cov {
				replace `var'=0 if Fee_Sharing_Percent==0
				}
				drop Fee_Sharing_Percent
				*Ensure Covered Principal Defaults by Risk Sharing Entity (and associated interest) does not exceed fee sharing amount
				gen double Cov_DefP = 0 
				sort Disbursement_Number Disbursement_Date Repayment_Date Disbursement_Number
				replace Cov_DefP=Default_P_Cov + Cov_DefP[_n-1] if _n>1
				gen double exceeds = 1 if Cov_DefP>${FeeSharingAmount}
				gen double exceedssum=sum(exceeds)
				replace Default_P_Cov=0 if exceedssum>1
				replace Default_I_Cov=0 if exceedssum>1
				gen double difference=Cov_DefP-${FeeSharingAmount} if exceedssum==1
				gen double prorata=difference/Default_P_Cov
				replace Default_P_Cov=Default_P_Cov-difference if exceedssum==1
				replace Default_I_Cov=Default_I_Cov-(Default_I_Cov*prorata)  if exceedssum==1
				drop Cov_DefP exceedssum difference exceeds prorata
				sort Disbursement_Number Disbursement_Date Repayment_Date Period_of_Disbursement Forecasted_Period
			*Calculate Remaining Defaults
			gen double DefaultP_Remain=DefaultP-DefaultP_FS_RE
			gen double DefaultI_Remain=DefaultI-DefaultI_FS_RE
			*Calculate Total OPIC Defaults (Adjusted for Risk Sharing Entity)
			gen double DefaultP_Total=DefaultP-Default_P_Cov
			gen double DefaultI_Total=DefaultI-Default_I_Cov
			replace Default=round(DefaultP_Total+DefaultI_Total, .01)
			gen double Shared_Defaults_RE = round(Default_P_Cov+Default_I_Cov, .01)

			replace Default=Default+Default_fees
	
		*Calculate Fee Sharing Recoveries
		*OPIC and Liberty Recovery on Fees based on how much claim each OPIC and Liberty Experienced, slightly different than pari-passu based on fee sharing amount
		*Recoveries based on coverage % not exposure % (adjusted for Liberty defaults, portion of claim recov OPIC does not split) 
		gen double Recovery_OPIC = round((-1*Recovery_Rate*(Default)), .01)
		replace Recovery=Recovery_OPIC
		gen double Shared_Recoveries_RE = round((-1*Recovery_Rate*(Shared_Defaults_RE+Default_fees_RE)), .01)
		 	
	replace Fees = Fees + Shared_Fees
	replace Commitment_Fees = Commitment_Fees + Shared_Commitment_Fees 
	
	* Adjustment for all-in rate below treasury rate
	if "$InterestType"== "All-In Single Rate" & "${DirectGuaranteed}" == "Direct Loan" {
		replace Interest=Interest+Fees if Fees<0 & All_In_Single_Rate < Interest_Rate
		replace Fees = 0 if Fees<0
	}
	
	drop Shared_Fees Shared_Commitment_Fees Recovery_OPIC Default_fees
	rename Default_fees_RE Shared_Default_RE
	
	capture drop DefaultP - Default_fees_FS 
	capture drop DefaultP_FS - DefaultI_Total *_FS
	capture drop Recovery_Fees - Recovery_Interest
	}	
		
	}

if "$DirectGuaranteed" ~= "Direct Loan"  {
	if "$FeeSharing" == "No" | "$FeeSharing" == "Not Available" {
    replace Exposure = round((Interest + (UPB_SOP/${GuaranteedPercent}) + Cap_Interest)*${GuaranteedPercent}, .01)
	replace Default = round((Principal + Interest)*${GuaranteedPercent}*CCDR,. 01) if "$DefaultPaymentType" == "Periodic Payment"	
	replace Default = round(Exposure*CMDR*(Payment_Frequency_Months/12), .01) if "$DefaultPaymentType" == "Lump Sum Payment"
	
	replace Lost_Fee = round(-1*(Fees + Commitment_Fees)* (CCDR), .01) if "$DefaultRiskonFees" == "Yes"
	
		if "$DirectGuaranteed" == "LPG" | "$DirectGuaranteed" == "Non-LPG" {
			replace Lost_Fee = 0
		}
	
	replace Recovery = round(-1*Recovery_Rate*(Default - Lost_Fee), .01)
	}

	if "$FeeSharing" == "Yes" {
	*Calculate Project Defaults
	replace Exposure = (Interest + (UPB_SOP/${GuaranteedPercent}) + Cap_Interest)*${GuaranteedPercent}
    gen double DefaultP = (Principal)*${GuaranteedPercent}*CCDR if "$DefaultPaymentType" == "Periodic Payment"
	gen double DefaultI = (Interest)*${GuaranteedPercent}*CCDR if "$DefaultPaymentType" == "Periodic Payment"
	replace Default = DefaultP + DefaultI if "$DefaultPaymentType" == "Periodic Payment"

	gen double DefaultEX = Exposure*CMDR*(Payment_Frequency_Months/12) if "$DefaultPaymentType" == "Lump Sum Payment"
	replace Default = DefaultEX if "$DefaultPaymentType" == "Lump Sum Payment"

	gen double Lost_Fee_DFC = round(-1*(Fees + Commitment_Fees)* (CCDR),.01) if "$DefaultRiskonFees" == "Yes"
	gen double Lost_Fee_FS = round(-1*(Shared_Fees + Shared_Commitment_Fees)* (CCDR), .01) if "$DefaultRiskonFees" == "Yes"
	gen double Lost_Fee_RE = round(-1*(Shared_Fees_RE + Shared_Commitment_Fees_RE)* (CCDR), .01) if "$DefaultRiskonFees" == "Yes"
	replace Lost_Fee = Lost_Fee_DFC + Lost_Fee_FS
	
	
	if "$DefaultPaymentType" == "Periodic Payment" {
	*Calculate Fee Sharing Portion of Defaults
	gen double DefaultP_FS=DefaultP*${FeeSharingPercent}
	gen double DefaultI_FS=DefaultI*${FeeSharingPercent}
		*Calculate Defaults of Risk Sharing Entity
		gen double DefaultP_FS_RE=(DefaultP_FS)*${GuaranteedPercent}*CCDR_FS
		gen double DefaultI_FS_RE=(DefaultI_FS)*${GuaranteedPercent}*CCDR_FS
		*Difference is equal to Covered Defaults by Risk Entity
		gen double Default_P_Cov=DefaultP_FS-DefaultP_FS_RE
		gen double Default_I_Cov=DefaultI_FS-DefaultI_FS_RE
			*Risk and Fee Sharing is only for 8 years 
			merge m:1 Repayment_Date using "$Output_Path\Fee Sharing.dta", update keepusing(Fee_Sharing_Percent)
			foreach var of varlist DefaultP_FS - Default_I_Cov {
			replace `var'=0 if Fee_Sharing_Percent==0
			}
			drop Fee_Sharing_Percent
			*Ensure Covered Principal Defaults by Risk Sharing Entity (and associated interest) does not exceed fee sharing amount
			gen double Cov_DefP = 0 
			sort Disbursement_Number Disbursement_Date  Repayment_Date Disbursement_Number
			replace Cov_DefP=Default_P_Cov + Cov_DefP[_n-1] if _n>1
			gen double exceeds = 1 if Cov_DefP>${FeeSharingAmount}
			gen double exceedssum=sum(exceeds)
			replace Default_P_Cov=0 if exceedssum>1
			replace Default_I_Cov=0 if exceedssum>1
			gen double difference=Cov_DefP-${FeeSharingAmount} if exceedssum==1
			gen double prorata=difference/Default_P_Cov
			replace Default_P_Cov=Default_P_Cov-difference if exceedssum==1
			replace Default_I_Cov=Default_I_Cov-(Default_I_Cov*prorata)  if exceedssum==1
			drop Cov_DefP exceedssum difference exceeds prorata
			sort Disbursement_Number Disbursement_Date Repayment_Date Period_of_Disbursement Forecasted_Period
		*Calculate Remaining Defaults
		gen double DefaultP_Remain=DefaultP-DefaultP_FS_RE
		gen double DefaultI_Remain=DefaultI-DefaultI_FS_RE
		*Calculate Total DFC Defaults (Adjusted for Risk Sharing Entity)
		gen double DefaultP_Total=DefaultP-Default_P_Cov
		gen double DefaultI_Total=DefaultI-Default_I_Cov
		replace Default=round(DefaultP_Total+DefaultI_Total, .01)
		gen double Shared_Defaults_RE = round(Default_P_Cov+Default_I_Cov, .01)
	
	*Calculate Fee Sharing Recoveries
	*DFC and Liberty Recovery on Fees based on how much claim each DFC and Liberty Experienced, slightly different than pari-passu based on fee sharing amount
	*Recoveries based on coverage % not exposure % (adjusted for Liberty defaults, portion of claim recov DFC does not split) 
	gen double Recovery_DFC = round((-1*Recovery_Rate*(Default-Lost_Fee)), .01)
	replace Recovery=Recovery_DFC
	gen double Shared_Recoveries_RE = round((-1*Recovery_Rate*(Shared_Defaults_RE-Lost_Fee_RE)), .01)
	} 

	if "$DefaultPaymentType" == "Lump Sum Payment" {
	*Calculate Fee Sharing Portion of Defaults
	gen double DefaultEX_FS=DefaultEX*${FeeSharingPercent}
	*Calculate Fee Sharing Portion of Exposure
	gen double Exposure_FS=Exposure*${FeeSharingPercent}
		*Calculate Defaults of Risk Sharing Entity		
		gen double DefaultEX_FS_RE=Exposure_FS*CMDR_FS*(Payment_Frequency_Months/12)
		*Difference is equal to Covered Defaults by Risk Entity
		gen double Default_EX_Cov=DefaultEX_FS-DefaultEX_FS_RE
			*Risk and Fee Sharing is only for 8 years 
			merge m:1 Repayment_Date using "$Output_Path\Fee Sharing.dta", update keepusing(Fee_Sharing_Percent)
			foreach var of varlist DefaultEX_FS - Default_EX_Cov {
			replace `var'=0 if Fee_Sharing_Percent==0
			}
			drop Fee_Sharing_Percent
			*Ensure Covered Principal Defaults by Risk Sharing Entity (and associated interest) does not exceed fee sharing amount
			gen double Cov_DefEX = 0 
			sort Disbursement_Number Disbursement_Date Repayment_Date Disbursement_Number
			replace Cov_Def=Default_EX_Cov + Cov_DefEX[_n-1] if _n>1
			gen double exceeds = 1 if Cov_DefEX>${FeeSharingAmount}
			gen double exceedssum=sum(exceeds)
			replace Default_EX_Cov=0 if exceedssum>1
			gen double difference=Cov_DefEX-${FeeSharingAmount} if exceedssum==1
			gen double prorata=difference/Default_EX_Cov
			replace Default_EX_Cov=Default_EX_Cov-difference if exceedssum==1
			drop Cov_DefEX exceedssum difference exceeds prorata
			sort Disbursement_Number Disbursement_Date Repayment_Date Period_of_Disbursement Forecasted_Period
		*Calculate Remaining Defaults
		gen double DefaultEX_Remain=DefaultEX-DefaultEX_FS_RE
		*Calculate Total DFC Defaults (Adjusted for Risk Sharing Entity)
		gen double DefaultEX_Total=DefaultEX-Default_EX_Cov
		replace Default=round(DefaultEX_Total, .01)
		gen double Shared_Defaults_RE = round(Default_EX_Cov, .01)
		
	*Calculate Fee Sharing Recoveries
	*DFC and Liberty Recovery on Fees based on how much claim each DFC and Liberty Experienced, slightly different than pari-passu based on fee sharing amount
	*Recoveries based on coverage % not exposure % (adjusted for Liberty defaults, portion of claim recov DFC does not split) 
	gen double Recovery_DFC = round((-1*Recovery_Rate*(Default-Lost_Fee)), .01)
	replace Recovery=Recovery_DFC
	gen double Shared_Recoveries_RE = round((-1*Recovery_Rate*(Shared_Defaults_RE-Lost_Fee_RE)), .01)
	}
		
	replace Fees = Fees + Shared_Fees
	replace Commitment_Fees = Commitment_Fees + Shared_Commitment_Fees 

	* Adjustment for all-in rate below treasury rate
	if "$InterestType"== "All-In Single Rate" & "${DirectGuaranteed}" == "Direct Loan"{
		replace Interest=Interest+Fees if Fees<0 & All_In_Single_Rate < Interest_Rate
		replace Fees = 0 if Fees<0
	}
	
	drop Shared_Fees Shared_Commitment_Fees Recovery_DFC
	rename Lost_Fee_RE Shared_Lost_Fees_RE

	*Periodic payments
	capture drop DefaultP - Lost_Fee_FS 
	capture drop DefaultP_FS - DefaultI_Total *_FS
	capture drop Recovery_Fees - Recovery_Interest
	*Lump Sum payments
	capture drop DefaultEX_FS - DefaultEX_Total *_FS
	capture drop Recovery_EX Recovery_Fees
	}

	}

drop 	Period_of_Disbursement Forecasted_Period

save "$Output_Path\Life Table with Risk.dta", replace
