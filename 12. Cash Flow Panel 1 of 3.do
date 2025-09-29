/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file creates the first panel of the cash flow                          *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/
*#######################################################*
* Creates Top Panel of Cash Flow                        *
*#######################################################*

clear all
set more off
version 12.1
***************************************

set obs 11
gen SequenceNo = _n*10
gen Item = "."

replace Item = "Name"                                    if SequenceNo == 10
replace Item = "Description"                             if SequenceNo == 20
replace Item = "Purpose"                                 if SequenceNo == 30
replace Item = "Program Type"                            if SequenceNo == 40
replace Item = "*Credit Rating Used"                     if SequenceNo == 50
replace Item = "*Recovery Rate"                          if SequenceNo == 60
replace Item = "*Recovery Delay Used (Months)"           if SequenceNo == 70
replace Item ="Budget Year"                              if SequenceNo == 80
replace Item = "Loan Type"                               if SequenceNo == 90
replace Item =  "Cohort"                                 if SequenceNo == 100
replace Item = "Obligation"                              if SequenceNo == 110 & "$DirectGuaranteed" == "Direct Loan"
replace Item = "Commitment"                              if SequenceNo == 110 & "$DirectGuaranteed" ~= "Direct Loan"

**Populating Line Item Values**

gen Value = "." 

replace Value = "$Name"                                  if SequenceNo == 10
replace Value = "$Description"                           if SequenceNo == 20
replace Value = "Budget Formulation/Obligation"          if SequenceNo == 30
replace Value = "Direct"                                 if SequenceNo == 40 & "$DirectGuaranteed" == "Direct Loan"
replace Value = "Guaranteed"                             if SequenceNo == 40 & "$DirectGuaranteed" ~= "Direct Loan"

if "$DefaultMethodology" == "FY2014 Risk Methodology" {

    replace Value = "$DefaultRate"   					 if SequenceNo == 50
    replace Value = "$RecoveryRate"                      if SequenceNo == 60
	}

if "$DefaultMethodology" == "Moody's Risk Methodology"  {

    replace Value = "$DFCRiskRating"                                if SequenceNo == 50
    replace Value = "$RecoveryRate"                      if SequenceNo == 60
	}

	
replace Value = "24"                                     if SequenceNo == 70
replace Value = "${Cohortyear}"                          if SequenceNo == 80
replace Value = "Construction"                     if SequenceNo == 90 /**Changed from Multiple Like**/
replace Value = "${Cohortyear}"                          if SequenceNo == 100

generate LoanorTotalGuaranteedAmount="$LoanorTotalGuaranteedAmount"
generate AnticipatedAppreciationCoverR= "$AnticipatedAppreciationCoverR"
destring LoanorTotalGuaranteedAmount AnticipatedAppreciationCoverR, replace
replace AnticipatedAppreciationCoverR=0 if AnticipatedAppreciationCoverR==.
replace LoanorTotalGuaranteedAmount=LoanorTotalGuaranteedAmount+AnticipatedAppreciationCoverR
format LoanorTotalGuaranteedAmount %30.2f
tostring LoanorTotalGuaranteedAmount, replace usedisplayformat

replace Value = LoanorTotalGuaranteedAmount          if SequenceNo == 110 

drop LoanorTotalGuaranteedAmount AnticipatedAppreciationCoverR
save "$Output_Path\cscflow part 1 of 3 FX.dta", replace

replace Value = "$USD_Obligation"						 if SequenceNo == 110  & "$FXCurrency" == "Yes" 
save "$Output_Path\cscflow part 1 of 3.dta", replace
