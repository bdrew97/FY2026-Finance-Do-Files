/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file Calculates Recovery Dates and Adjusts Lifetable                   *
*  Updated: 2-14-2014                                                              *
*#################################################################################*/
clear all
set more off
version 12.1
***************************************
use "$Output_Path\Life Table with Risk.dta"
*Generates the date in which the recovery will be received, there is a two year lag for all products except Arbital Award Decision (BoC)*
gen Date_of_Recovery = mdy(month(Repayment_Date),  day(Repayment_Date), year(Repayment_Date) + 2) if "$DirectGuaranteed" ~= "Arbital Award Decision"
replace Date_of_Recovery = Repayment_Date if "$DirectGuaranteed" == "Arbital Award Decision"
replace Date_of_Recovery = mdy(month(Repayment_Date),  day(Repayment_Date)-1, year(Repayment_Date) + 2) if Date_of_Recovery==. & "$DirectGuaranteed" ~= "Arbital Award Decision" 
replace Date_of_Recovery = mdy(month(Repayment_Date),  day(Repayment_Date)-2, year(Repayment_Date) + 2) if Date_of_Recovery==. & "$DirectGuaranteed" ~= "Arbital Award Decision"
replace Date_of_Recovery = mdy(month(Repayment_Date),  day(Repayment_Date)-3, year(Repayment_Date) + 2) if Date_of_Recovery==. & "$DirectGuaranteed" ~= "Arbital Award Decision"
format %td Date_of_Recovery

replace leapyear = (mod(year(Date_of_Recovery),4) == 0 & mod(year(Date_of_Recovery),100) != 0) | mod(year(Date_of_Recovery),400) == 0 & "$DirectGuaranteed" ~= "Arbital Award Decision"
replace Date_of_Recovery = mdy(month(Date_of_Recovery),  day(Date_of_Recovery) + 1, year(Date_of_Recovery)) if leapyear == 1 & day(Date_of_Recovery) == 28 & month(Date_of_Recovery) == 2 & day(${DateofFirstPayment}) > 28 & "$DirectGuaranteed" ~= "Arbital Award Decision"

*###############################################*
***MAKING THE DATES MATCH FOR RECOVERIES        *
*###############################################*

**This section duplicates the life table and then trims them so that there is one for recoveries, and then merges it back into the other life table**

**Saving table**
save "$Output_Path\Life Table Step 2.dta", replace

**Keeping only the information needed for the merge back in and recovery data**
	* In case fees are not shared this will prevent an error
	capture gen double Shared_Recoveries_RE = 0
	
keep Name ProjectID Payment_Frequency Disbursement_Number Recovery Date_of_Recovery Disbursement_Date subperiod period Payment_Frequency_Months Shared_Recoveries_RE

**Changing the date of recovery to be the repayment date and adjusting the periods and subperiods (assumes 24 month recovery lag)**
rename Date_of_Recovery Repayment_Date
drop if subperiod == 0 & Recovery==0
replace period = period + 24/Payment_Frequency_Months if "$DirectGuaranteed" ~= "Arbital Award Decision"
replace subperiod = subperiod + 24/Payment_Frequency_Months if "$DirectGuaranteed" ~= "Arbital Award Decision"
save "$Output_Path\Life Table Step 2a.dta", replace
clear


**Reopening the complete life table**
use "$Output_Path\Life Table Step 2.dta"

** Dropping the recovery variables and merging with the recovery table**
drop Recovery Date_of_Recovery 
capture drop Shared_Recoveries_RE
merge 1:1 Disbursement_Number Repayment_Date using "$Output_Path\Life Table Step 2a.dta"
drop _merge

** Changing the missing values to zero **
local varlist Disbursement Principal Interest Cap_Interest Fees Commitment_Fees UPB_SOP UPB_EOP Exposure Default Lost_Fee new Interest_Rate PostCompletion PreCompletion Obligation Recovery Shared_Recoveries_RE
foreach varname of local varlist {
		replace `varname' = 0 if `varname' == .
		}

**Sorting and Saving **
sort Disbursement_Number Repayment_Date 

*###########################################*
*** Adding Columns for Appreciation Cover ***
*###########################################*

if ${ForeignCurrencyAppreciationCo} ~=0 {
	gen double APC_Default = Default*${ForeignCurrencyAppreciationCo}
	gen double APC_Recovery = Recovery*${ForeignCurrencyAppreciationCo}
	format APC* %16.2fc
	}
********************************************

** Appreciation Cover Adjustments **
bysort Name: generate count=_n if Principal!=0 & Disbursement_Number==1
replace count=0 if count==.
egen max_count=max(count)
gen AppreciationCover="$AnticipatedAppreciationCoverR"
destring AppreciationCover, replace

generate repayment_timing=(Repayment_Date-Disbursement_Date)/365 if Disbursement_Number==1
replace repayment_timing=0 if repayment_timing==.
generate fy_eight2=1 if repayment_timing>=8
replace fy_eight2=0 if repayment_timing<8
egen fy_eight=max(fy_eight2)
generate repayment_timing2=repayment_timing
replace repayment_timing=0 if repayment_timing>8 /* Double Check appreciation cover timing */
egen max_timing=max(repayment_timing)
replace repayment_timing2=0 if Principal==0 & Interest==0 & Fees==0 /* Create repayment timing variable for borrower repayments only. Projected recoveries with 2-year delay should be excluded. */
egen max_timing2=max(repayment_timing2)

replace Disbursement=Disbursement+AppreciationCover if count==max_count & fy_eight==0
replace Principal=Principal+AppreciationCover if repayment_timing2==max_timing2
generate double APC_Disbursement=AppreciationCover if count==max_count & fy_eight==0
generate double APC_Principal=AppreciationCover if repayment_timing2==max_timing2

replace Disbursement=Disbursement+AppreciationCover if repayment_timing==max_timing & fy_eight==1
*replace Principal=Principal+AppreciationCover if repayment_timing==max_timing & fy_eight==1
replace APC_Disbursement=AppreciationCover if repayment_timing==max_timing & fy_eight==1
*replace APC_Principal=AppreciationCover if repayment_timing==max_timing & fy_eight==1

replace APC_Disbursement=0 if APC_Disbursement==.
replace APC_Principal=0 if APC_Principal==.

drop AppreciationCover count max_count fy_eight2 fy_eight repayment_timing repayment_timing2 max_timing max_timing2
**

save "$Output_Path\Life Table Step 3.dta", replace

