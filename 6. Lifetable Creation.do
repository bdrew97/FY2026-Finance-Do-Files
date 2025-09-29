/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file creates the life table for the loan (excluding default/recovery   *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/

clear all
set more off
version 12.1

**Setting up the columns needed for a life table**
local varlist Name ProjectID Payment_Frequency 
foreach varname of local varlist {
	gen `varname'=""
	}
local varlist Disbursement_Number Disbursement_Date Disbursement Repayment_Date Principal ///
              Interest Cap_Interest /*Cap_Interest_Base Cap_Interest_Spread*/ Fees ///
			  Commitment_Fees UPB_SOP UPB_EOP Exposure Default Recovery Lost_Fee 
foreach varname of local varlist {
	gen double `varname'= 0
	format `varname' %16.2fc
	}
**Creating a row for each Disbursement and Populating with program information** 
set obs $NumberofDisbursementPeriods
replace Name= "$Name"
replace ProjectID= "$ProjectID"
replace Disbursement_Number = _n
replace Payment_Frequency= "$PaymentFrequency"
gen Payment_Frequency_Months=.
replace Payment_Frequency_Months=1    if Payment_Frequency=="Monthly"
replace Payment_Frequency_Months=3    if Payment_Frequency=="Quarterly"
replace Payment_Frequency_Months=6    if Payment_Frequency=="Semi-Annual"
replace Payment_Frequency_Months=12   if Payment_Frequency=="Annual"

**Populating the Disbursement amount and date**
forvalues i= 1(1)$NumberofDisbursementPeriods {
	replace Disbursement       = ${DisbAmount`i'}    if  Disbursement_Number==`i'
	replace Disbursement_Date  = ${DisbDate`i'}      if  Disbursement_Number==`i'
	}
format Disbursement_Date %td
format Disbursement %16.2fc
drop if Disbursement == 0

**Creating a row for each first repayment**
expand 2, gen (new)
replace Disbursement =0                        if new==1
replace Repayment_Date = ${DateofFirstPayment} if new==1
format  Repayment_Date %td

**Creating the remaining dates for each repayment**
gen newmonth=.
gen newday=.
gen newyear=.
gen newrepday =.
global term= ${ofPaymentspostGrace} + ${Principalbeginsendofperiod} - 2
forvalues i= 1(1)$term    {
	expand 2 if new == 1 , gen (new`i')
	replace new = 0 if new`i'==1
	replace newmonth  = month(Repayment_Date) + Payment_Frequency_Months*`i'  if new`i'==1
	replace newyear   = year(Repayment_Date)+floor((newmonth-1)/12)           if new`i'==1
	replace newmonth  = mod((newmonth-1),12)+1                                if new`i'==1
	replace newrepday = mdy(newmonth,day(Repayment_Date),newyear)             if new`i'==1
	replace newrepday = mdy(newmonth,(day(Repayment_Date)-1),newyear)         if new`i'==1 & newrepday == .
	replace newrepday = mdy(newmonth,(day(Repayment_Date)-2),newyear)         if new`i'==1 & newrepday == .
	replace newrepday = mdy(newmonth,(day(Repayment_Date)-3),newyear)         if new`i'==1 & newrepday == .
	
	format %td newrepday
	replace Repayment_Date = newrepday if new`i'==1
	drop new`i'
	}
	
***Making the Date for Disbursements match the Disbursement Date For Sorting Purposes*** 	
replace Repayment_Date = Disbursement_Date if Repayment_Date==.
sort Disbursement_Number  Repayment_Date
bys Disbursement_Number Disbursement (Repayment_Date) : gen period = _n
sort Disbursement_Number  Repayment_Date
drop if Repayment_Date <= Disbursement_Date & Disbursement == 0
replace period=period[_n+1]-1 if Disbursement!=0
bys Disbursement_Number : gen subperiod = _n-1 

***Adjust Repayment Date for Leap Year***
gen repayday=month(Repayment_Date)
gen repaymonth=month(Repayment_Date)
gen repayyear=year(Repayment_Date)
gen leapyear=cond(mod(repayyear,400) == 0, 1, ///
        cond(mod(repayyear,100) == 0, 0, ///
        cond(mod(repayyear,4)   == 0, 1, ///
                                 0)))
replace repayday=28 if repayday==29 & repaymonth==2 & repayyear!=1								 
drop repayday repaymonth repayyear leapyear					

*#############################################################*
*Populates Interest Rate  and pre/post completion fees rates  *
*#############################################################*
gen double Interest_Rate  = 0
gen double PostCompletion = $PostCompletion
gen double PreCompletion  = $PreCompletion

**For Flat-Treasury Rate**
if "$InterestType" == "Fixed - Treasury" | ("${InterestType}"== "All-In Single Rate" & "$DirectGuaranteed"=="Direct Loan") {
	forvalues i = 1(1)$NumberofDisbursementPeriods  {
			bys Disbursement_Number : replace Interest_Rate = ${BaseInterest`i'}   if Disbursement_Number == `i'     
			}
			}
**For Floating - Treasury**
if "$InterestType"== "Floating - Treasury" {
	gen RepayNo = period
	merge m:1 RepayNo using "$Output_Path\FloatingInterestRates.dta", keepusing(FloatTreasury)
	replace Interest_Rate = FloatTreasury/100
	drop FloatTreasury RepayNo
	drop _merge
	}
	
**For Floating - LIBOR**
if "$InterestType"== "Floating - LIBOR" {
	gen RepayNo = period
	merge m:1 RepayNo using "$Output_Path\FloatingInterestRates.dta", keepusing(FloatLIBOR)
	replace Interest_Rate = FloatLIBOR/100
	drop FloatLIBOR RepayNo
	drop _merge
	}
**For Floating - SOFR**
if "$InterestType"== "Floating - SOFR" {
	gen RepayNo = period
	merge m:1 RepayNo using "$Output_Path\FloatingInterestRates.dta", keepusing(FloatSOFR)
	replace Interest_Rate = FloatSOFR/100
	drop FloatSOFR RepayNo
	drop _merge
	}	
**For Floating - Other (FX Currency Deals using local interest rates)**
if "$InterestType"== "Floating - Other" {
	gen RepayNo = period
	merge m:1 RepayNo using "$Output_Path\FloatingInterestRates.dta", keepusing(FloatOther)
	replace Interest_Rate = FloatOther/100
	drop FloatOther RepayNo
	drop _merge
	* For 0% floor
	replace Interest_Rate=0 if Interest_Rate==.
	}

*For Loan Guarantees*
if "$DirectGuaranteed" ~= "Direct Loan" & "$InterestType"!="All-In Single Rate" {
    replace Interest_Rate = Interest_Rate + ${GuaranteedInterestSpread} if "$InterestType" ~= "All-In Single Rate"
	}

**For All-In Single Rate (DI), i.e. a fixed rate to the borrower (for Direct Loans)**
if "$InterestType"== "All-In Single Rate" & "$DirectGuaranteed"=="Direct Loan" {
	gen double All_In_Single_Rate = $AllInSingleRate
	replace PostCompletion = 0
	replace PreCompletion  = 0
	}
	
**For All-In Single Rate (IG), i.e. a fixed rate rate from the lender (Base + Guaranteed Int)
if "$InterestType"== "All-In Single Rate" & "$DirectGuaranteed"!="Direct Loan" {
	forvalues i = 1(1)$NumberofDisbursementPeriods  {
			bys Disbursement_Number : replace Interest_Rate = ${AllInRate`i'}   if Disbursement_Number == `i'     
			}
			}

**For Zero Financing**
if "$DirectGuaranteed" == "Direct Loan"  {
     replace  Interest_Rate = Interest_Rate*${IRFactor}
	 }

**Creating an all in borrower rate, used for capitalized interest and mortgage style principal***
if "$DirectGuaranteed" == "Direct Loan"  { 
*Remove Capitalized Spread until after loan is zero-financed
if "$RunType" == "Zero Financing (Interest Goal Seek)" & $Interestbeginsattopofperiod > 1 & abs($PreviousFinancingSubsidy) < 0.00499999 {
    gen double Borrower_Rate = Interest_Rate + PreCompletion
    replace Borrower_Rate = Interest_Rate + PostCompletion if period >= $CompletionPoint
	}
if "$RunType" == "Zero Financing (Interest Goal Seek)" & $Interestbeginsattopofperiod > 1 & (abs($PreviousFinancingSubsidy) >= 0.00499999 | ${IRFactor} == 1) {
    gen double Borrower_Rate = Interest_Rate
	}
if "$RunType" != "Zero Financing (Interest Goal Seek)" | ("$RunType" == "Zero Financing (Interest Goal Seek)" & $Interestbeginsattopofperiod == 1) {
    gen double Borrower_Rate = Interest_Rate + PreCompletion
    replace Borrower_Rate = Interest_Rate + PostCompletion if period >= $CompletionPoint
	}		
	}
else {
    gen double Borrower_Rate = Interest_Rate + PreCompletion*${GuaranteedPercent}
    replace Borrower_Rate = Interest_Rate + PostCompletion*${GuaranteedPercent} if period >= $CompletionPoint
	}
if "$InterestType"== "All-In Single Rate" & "$DirectGuaranteed"=="Direct Loan" {
    replace Borrower_Rate = $AllInSingleRate
	}

gen double Interests_Ratio = Interest_Rate /Borrower_Rate
gen double Fee_Ratio = 1 - Interests_Ratio

*########################################*
*Interest Calculation Setup              *
*########################################*

***Calculating the number of days between repayments***
bys Disbursement_Number (Repayment_Date) : gen double days = Repayment_Date - Repayment_Date[_n-1]

***Identifying Leapyears***
gen double leapyear = (mod(year(Repayment_Date),4) == 0 & mod(year(Repayment_Date),100) != 0) | mod(year(Repayment_Date),400) == 0
gen double days_in_year = 365 + leapyear

***Establishing the starting UPBs***
replace UPB_SOP = 0                                                        if subperiod==0
replace UPB_EOP = UPB_SOP + Disbursement                                   if subperiod==0
bys Disbursement_Number (Repayment_Date) : replace UPB_SOP = UPB_EOP[_n-1] if subperiod==1

*########################################*
*Creating Capitalized Interest Schedule  *
*########################################*
***Populates capitalized interest from first period to period before the first interst payment
***Any spreads (Pre/Post fee) is included in the capitalized amount***
if "$DirectGuaranteed"=="Direct Loan" {
if ${Interestbeginsattopofperiod} > 1 {
	forvalues i = 1(1)$Interestbeginsattopofperiod  {
		replace Cap_Interest = round(UPB_SOP*Borrower_Rate*days/days_in_year,.01) if subperiod==`i' & period < $Interestbeginsattopofperiod
		*replace Cap_Interest_Base = round(UPB_SOP*Interest_Rate*days/days_in_year,.01) if subperiod==`i' & period < $Interestbeginsattopofperiod
		*replace Cap_Interest_Spread = round(UPB_SOP*PreCompletion*days/days_in_year,.01) if subperiod==`i' & period < $Interestbeginsattopofperiod
		*replace Cap_Interest_Spread = round(UPB_SOP*PostCompletion*days/days_in_year,.01) if subperiod==`i' & period < $Interestbeginsattopofperiod & period >= $CompletionPoint
				
		replace UPB_EOP = UPB_SOP + Cap_Interest if subperiod==`i' & period < $Interestbeginsattopofperiod
		bys Disbursement_Number (Repayment_Date) : replace UPB_SOP = UPB_EOP[_n-1] if subperiod == `i'+1
		}
		}
}		
***Populates UPB(s) for periods up to the first principal payment. Necessary for future calculations***
	forvalues i = $Interestbeginsattopofperiod(1)$Principalbeginsendofperiod {
		replace UPB_EOP = UPB_SOP if period== `i' & subperiod ~= 0
		bys Disbursement_Number (Repayment_Date) : replace UPB_SOP = UPB_EOP[_n-1] if period== `i' + 1
		}
		
*#######################################*
*Principal Payment Amortization Prep    *
*#######################################*
***Generates the number of principal payments that are scheduled to happen for each disbusmement /// 
   *Determines if the first repayment is before or after the principal grace period for each disbursement.///
   *If it is before, then there are fewer principal payments***
 
gen double principalpayments= ${ofPaymentspostGrace}
bys Disbursement_Number : egen double last_payment = max(subperiod)
bys Disbursement_Number : replace principalpayments = last_payment if last_payment <= principalpayments
bys Disbursement_Number (Repayment_Date) : gen double principal_payment_number = principalpayments - (last_payment - subperiod)

*#######################################*
*Amortization if Flat Principal         *
*#######################################*
if "$PrincipalPaymentStructure" == "Flat" {

    forvalues i=1(1)$ofPaymentspostGrace  {
	    replace Principal = round( UPB_SOP/(principalpayments + 1 - `i'),.01) if principal_payment_number == `i'
	    replace UPB_EOP = UPB_SOP - Principal if principal_payment_number == `i' 
	    bys Disbursement_Number (Repayment_Date) : replace UPB_SOP = UPB_EOP[_n-1] if principal_payment_number == `i' + 1 
	    }
	replace Principal=0 if Principal==.

}
		
*#######################################*
*Amortization if Mortgage Principal     *  ****NOTE: Some rounding Issues***
*#######################################*

if "$PrincipalPaymentStructure" == "Mortgage" {
   
	gen double pandi = 0
	gen double pmt = 0
	bys Disbursement_Number : egen double total_loan_amount = max(UPB_SOP)
	
	forvalues i=1(1)$ofPaymentspostGrace {
        replace pmt = round(total_loan_amount * ((Borrower_Rate*Payment_Frequency_Months/12)*(1+(Borrower_Rate*Payment_Frequency_Months/12))^principalpayments) / ((1+(Borrower_Rate*Payment_Frequency_Months/12))^principalpayments-1),.01) if principal_payment_number == `i'
        replace Principal   = round(pmt*(1+(Borrower_Rate*Payment_Frequency_Months/12))^(`i'-1) - total_loan_amount*(Borrower_Rate*Payment_Frequency_Months/12)*(1+(Borrower_Rate*Payment_Frequency_Months/12))^(`i'-1),.01) if principal_payment_number == `i'
		replace Principal = UPB_SOP if subperiod == last_payment
        replace Interest = round(pmt - Principal,.01)         if principal_payment_number == `i'
		replace Fees = round(Interest*Fee_Ratio, .01)         if principal_payment_number == `i'
		replace Interest = Interest - Fees                    if principal_payment_number == `i'
		replace UPB_EOP = UPB_SOP - Principal                 if principal_payment_number == `i' 
	    bys Disbursement_Number (Repayment_Date) : replace UPB_SOP = UPB_EOP[_n-1] if principal_payment_number == `i' + 1
		}
	
	replace Interest =  round(UPB_SOP*Interest_Rate*days/days_in_year, .01)                 if principal_payment_number == 1 & subperiod == 1
	replace Interest =  round(UPB_SOP*Interest_Rate*Payment_Frequency_Months/12, .01)       if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod > 1
	replace Interest =  round(UPB_SOP*Interest_Rate*days/days_in_year, .01)                 if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod == 1
	
	if "$InterestType"== "All-In Single Rate" {
	replace Fees =  round(UPB_SOP*(Borrower_Rate-Interest_Rate)*days/days_in_year, .01)                 if principal_payment_number == 1 & subperiod == 1 & period >= $CompletionPoint
	replace Fees =  round(UPB_SOP*(Borrower_Rate-Interest_Rate)*Payment_Frequency_Months/12, .01)       if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod > 1 
	replace Fees =  round(UPB_SOP*(Borrower_Rate-Interest_Rate)*days/days_in_year, .01)                 if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod == 1 
	}
	
	if "$InterestType"!= "All-In Single Rate" {
	replace Fees     =  round(UPB_SOP*PostCompletion*days/days_in_year, .01)                if principal_payment_number == 1 & subperiod == 1 & period >= $CompletionPoint
	replace Fees     =  round(UPB_SOP*PostCompletion*Payment_Frequency_Months/12, .01)      if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod > 1 & period >= $CompletionPoint
	replace Fees     =  round(UPB_SOP*PostCompletion*days/days_in_year, .01)                if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod == 1 & period >= $CompletionPoint
	
	replace Fees     =  round(UPB_SOP*PreCompletion*days/days_in_year, .01)                 if principal_payment_number == 1 & subperiod == 1 & period < $CompletionPoint
	replace Fees     =  round(UPB_SOP*PreCompletion*Payment_Frequency_Months/12, .01)       if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod > 1 & period < $CompletionPoint
	replace Fees     =  round(UPB_SOP*PreCompletion*days/days_in_year, .01)                 if period >= ${Interestbeginsattopofperiod} & principal_payment_number < 1 & subperiod == 1 & period < $CompletionPoint
	}
}
	
*#########################################*	
*Custom Principal Schedule                *
*#########################################*
***Merges the Custom Principal Schedule into the life table**
if "$PrincipalPaymentStructure" == "Custom" {
	merge 1:1 period Disbursement_Number using "$Output_Path\Custom Principal Formatted.dta", update 
	replace Principal=0 if Principal==.
	sort Disbursement_Number Repayment_Date
	***Drop periods before disbursement 
	drop if _merge==2 & Principal==0
	drop _merge
	
	if "$DirectGuaranteed"=="Direct Loan" {
	***Calculate Effective Amortization Rates (To apply to capitalized interest)***
	bys Disbursement_Number: egen double Disbursement_Total=sum(Disbursement)
	gen double Effective_Amort_Rate=Principal/Disbursement_Total
	***Calculates Principal using Effective Amortization Rates and UPB including capitalized interest***
	bys Disbursement_Number: egen double MaxUPB=max(UPB_EOP)
	gen double Principal_Including_CapInterest=Effective_Amort_Rate*MaxUPB
	replace Principal=round(Principal_Including_CapInterest,.01)
		*Adjust for Rounding Differences*
		bys Disbursement_Number: egen double Rounded_Principal=sum(Principal)
		gen double Rounding_Diff=MaxUPB-Rounded_Principal
		bys Disbursement_Number (Repayment_Date): replace Principal=Principal+Rounding_Diff if Principal[_n+1]==0 & Principal!=0
	drop Disbursement_Total Effective_Amort_Rate MaxUPB Rounded_Principal Rounding_Diff
	}
	
	**Calculates the UPB(s)**
	forvalues i=1(1)$ofPaymentspostGrace {
	   replace UPB_EOP = UPB_SOP - Principal if principal_payment_number == `i' 
	   bys Disbursement_Number (Repayment_Date) : replace UPB_SOP = UPB_EOP[_n-1] if principal_payment_number == `i' + 1
	   } 
	   }

	
*#########################################*	
*DCA Principal Schedule	                  *
*#########################################*

/*if "$PrincipalPaymentStructure"=="Straight" {
	bys Disbursement_Number (Repayment_Date): replace Principal = 0 if _n <= $Principalbeginsendofperiod
	bys Disbursement_Number (Repayment_Date): replace Principal = round(Disbursement[1]/(_N-$Principalbeginsendofperiod),.01) if _n > $Principalbeginsendofperiod
	forvalues i = 1(1)40 {
		replace UPB_EOP = UPB_SOP - Principal + Disbursement 
		replace UPB_SOP = UPB_EOP[_n-1] if _n>1
	}
}
*/

if "$PrincipalPaymentStructure"=="Straight" {
	
	bys Disbursement_Number (Repayment_Date): replace Principal = 0 if _n <= $Principalbeginsendofperiod
	bys Disbursement_Number (Repayment_Date): replace Principal = round(Disbursement[1]/($AverageSubloanMaturity),.01) if _n <= ($Principalbeginsendofperiod + $AverageSubloanMaturity) & _n > $Principalbeginsendofperiod
	bys Disbursement_Number (Repayment_Date): replace Principal = 0 if _n > ($Principalbeginsendofperiod + $AverageSubloanMaturity)
	forvalues i = 1(1)$ofPaymentspostGrace {
		bys Disbursement_Number (Repayment_Date): replace UPB_SOP = 0 if _n==1
		bys Disbursement_Number (Repayment_Date): replace UPB_EOP = UPB_SOP - Principal + Disbursement 
		bys Disbursement_Number (Repayment_Date): replace UPB_SOP = UPB_EOP[_n-1] if _n>1
	}
}

if "$PrincipalPaymentStructure"=="Bullet" {
	replace Principal = 0
	bys Disbursement_Number (Repayment_Date): replace Principal = Disbursement[1] if _n == _N
	forvalues i = 1(1)$ofPaymentspostGrace {
		bys Disbursement_Number (Repayment_Date): replace UPB_SOP = 0 if _n==1
		bys Disbursement_Number (Repayment_Date): replace UPB_EOP = UPB_SOP - Principal + Disbursement 
		bys Disbursement_Number (Repayment_Date): replace UPB_SOP = UPB_EOP[_n-1] if _n>1
	}
}
*#########################################*	
*Custom Fee Schedule	                  *
*#########################################*

 if "$OtherSubsidyFees" == "Yes" {
	merge 1:1 period Disbursement_Number using "$Output_Path\Other Subsidy Fees Formatted.dta", update 
	sort Disbursement_Number Repayment_Date
	drop _merge
	if $AggregateFees == 1 {
	*Prorate Fees to Disbursements - Disb UPB / Loan UPB
		bys Repayment_Date (Disbursement_Number): egen double LoanUPB_SOP=total(UPB_SOP)
		replace Fees=(UPB_SOP/LoanUPB_SOP)*AggregateFees
		replace Fees=round(Fees, .01)
		/*Address rounding discrepancies*/
		bys Repayment_Date (Disbursement_Number): egen double FeesbyPd=total(Fees)
		gen double Feediff=round(AggregateFees-FeesbyPd, .01)
			*Assign rounding discrepancy to a single disb
		replace Fees=Fees+Feediff if Disbursement_Number==1
		egen double TotFees=total(Fees)
		egen double TotAggregateFees=total(AggregateFees) if Disbursement_Number==1
		gen double TotFeediff=round(TotFees, .01) - round(TotAggregateFees, .01)
		* Replace total fee difference variable. Due to MTU guaranteed percent adjustments, fee rounding differences tend to be greater.
		replace TotFeediff=round(TotFees, 1) - round(TotAggregateFees, 1) if "$DirectGuaranteed" == "LPG" | "$DirectGuaranteed" == "Non-LPG"
		assert TotFeediff==0 | TotFeediff==.
		drop AggregateFees LoanUPB_SOP-TotFeediff
		}
	}


*#####################################################*	
*Interest Calculation: Non-Mortgage Programs          *
*#####################################################*

if "$PrincipalPaymentStructure" ~= "Mortgage" {
    replace Interest = round(UPB_SOP*Interest_Rate*days/days_in_year, .01) if subperiod>= 1 & period>= $Interestbeginsattopofperiod
    }

*#########################################*	
*Pre/Post Fee Calculation (Guarantee Fee) *
*#########################################*

if "$PrincipalPaymentStructure" ~= "Mortgage" & "$OtherSubsidyFees" != "Yes" {
replace Fees = round(UPB_SOP*PostCompletion*days/days_in_year, .01) if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period >= $CompletionPoint
replace Fees = round(UPB_SOP*PreCompletion*days/days_in_year, .01)  if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period < $CompletionPoint
}

if "$DirectGuaranteed" ~= "Direct Loan" & "$OtherSubsidyFees" != "Yes" /*Assumes that Fees entered by user are Amount of Fees TO DFC, & thus do not require this adjustment*/ {
    replace Fees = round((UPB_SOP*PostCompletion*days/days_in_year)*${GuaranteedPercent}, .01) if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period >= $CompletionPoint
	replace Fees = round((UPB_SOP*PreCompletion*days/days_in_year)*${GuaranteedPercent}, .01)  if subperiod>= 1 & period>= ${Interestbeginsattopofperiod} & period < $CompletionPoint
	}
*#####################################################*	
*Interest & Fee Calculation: All in Single            *
*#####################################################*
if "$InterestType"== "All-In Single Rate" & "$DirectGuaranteed" == "Direct Loan"{
    if "$PrincipalPaymentStructure" ~= "Mortgage" {
        replace Interest = round(UPB_SOP*Interest_Rate*days/days_in_year, .01) if subperiod>= 1 & period>= $Interestbeginsattopofperiod
        gen double All_In_Pmnt = round(UPB_SOP*All_In_Single_Rate*days/days_in_year, .01) if subperiod>= 1 & period>= $Interestbeginsattopofperiod
		replace Fees = All_In_Pmnt - Interest if subperiod>= 1 & period>= $Interestbeginsattopofperiod
		drop All_In_Pmnt
		}
		}
	
*#########################################*
* Commitment Fee Calculation              *
*#########################################*

***Adds rows for commitment fees***
append using "$Output_Path\commitment fees.dta"

***Changes missing values to zeros***
local  varlist Disbursement_Number Disbursement Principal Interest Cap_Interest Fees Commitment_Fees UPB_SOP UPB_EOP Exposure Default Recovery Lost_Fee Payment_Frequency_Months Interest_Rate PostCompletion PreCompletion Obligation new 
	foreach varname of local varlist {
		replace `varname' = 0 if `varname' == .
		}

*#########################################*	
*DCA Fee Schedule	                  *
*#########################################*  

/*if "${AnnualFlatUtilizationFee}" != "Not Available" {
	bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + ((UPB_SOP+UPB_SOP[_n+1])/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod > 1/*_n > 2*/
	bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + (UPB_SOP[_n+1]/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod == 1/*_n == 2*/
}
*/

if "${AnnualFlatUtilizationFee}" != "Not Available" & "${PrincipalPaymentStructure}" == "Custom" {
		bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + ((UPB_EOP+UPB_EOP[_n-1])/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod > 1/*_n > 2*/
		bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + (UPB_EOP/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod == 1/*_n == 2*/
}

if "${AnnualFlatUtilizationFee}" != "Not Available" & "${PrincipalPaymentStructure}" == "Straight" {
	if $AverageSubloanMaturity > 1 {
		bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + ((UPB_EOP+UPB_EOP[_n-1])/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod > 1/*_n > 2*/
		bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + (UPB_EOP/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod == 1/*_n == 2*/
	}	

	if $AverageSubloanMaturity == 1 {
		bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + (UPB_SOP/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod == 1/*_n == 2*/
	}
}

if "${AnnualFlatUtilizationFee}" != "Not Available" & "${PrincipalPaymentStructure}" == "Bullet" {
	bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + ((UPB_EOP+UPB_EOP[_n-1])/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod > 1/*_n > 2*/
	bys Disbursement_Number (Repayment_Date): replace Fees = Fees[_n] + (UPB_EOP/2)*((${AnnualFlatUtilizationFee})/(12/Payment_Frequency_Months)) if subperiod == 1/*_n == 2*/
}


*#########################################*
* Fee Sharing Adjustment                  *
*#########################################*
if "$FeeSharing" == "Yes" {
	merge m:1 period using "$Output_Path\Fee Sharing.dta", update keepusing(Fee_Sharing_Percent)
	drop if _merge==2
	
	replace Name = "$Name"
	replace ProjectID = "$ProjectID"
	
	sort Fee_Sharing_Percent
	replace Fee_Sharing_Percent=Fee_Sharing_Percent[_n-1] if Fee_Sharing_Percent==.
	
	gen double exposure_percent=1-(${FeeSharingAmount}/${LoanorTotalGuaranteedAmount})
	replace Fee_Sharing_Percent=1-Fee_Sharing_Percent
	replace exposure_percent=1 if Fee_Sharing_Percent==1

	gen double DFC_Fees=round((exposure_percent*Fees),.01)
	gen double DFC_Commitment_Fees=round((exposure_percent*Commitment_Fees),.01)
	
	gen double Shared_Fees=round(((1-exposure_percent)*Fees*(Fee_Sharing_Percent)),.01)
	gen double Shared_Commitment_Fees=round(((1-exposure_percent)*Commitment_Fees*(Fee_Sharing_Percent)),.01)	
	
	gen double Shared_Fees_RE=round(((1-exposure_percent)*Fees*(1-Fee_Sharing_Percent)),.01)
	gen double Shared_Commitment_Fees_RE=round(((1-exposure_percent)*Commitment_Fees*(1-Fee_Sharing_Percent)),.01)	
	
	replace Fees=DFC_Fees
	replace Commitment_Fees=DFC_Commitment_Fees
	
	drop comfeepercent Fee_Sharing_Percent _merge DFC_Fees DFC_Commitment_Fees
	format Shared_Fees Shared_Commitment_Fees Shared_Fees_RE Shared_Commitment_Fees_RE %16.2fc
	}
	
	sort Disbursement_Number Repayment_Date	
		

***Cleaning, Sorting, and Saving***
drop newmonth newday newyear newrepday principalpayments last_payment principal_payment_number 
replace Name = "$Name"
replace ProjectID = "$ProjectID"
sort Disbursement_Number Repayment_Date	

***Guarantee Percent Adjustment - Needed for MTU Only after Utilization Fee Adjustments***
if "${DirectGuaranteed}" == "LPG" | "${DirectGuaranteed}" == "Non-LPG" {
	local varlist Interest Cap_Interest Fees Commitment_Fees UPB_SOP UPB_EOP /*Exposure*/ Default ///
				Recovery Lost_Fee
	foreach varname of local varlist {
		replace `varname'= `varname'*${GuaranteedPercent}
	}
}

***Guarantee Percent Adjustment - Needed for All Other IG***
if "${DirectGuaranteed}" ~= "LPG" & "${DirectGuaranteed}" ~= "Non-LPG" & "${DirectGuaranteed}" ~= "Direct Loan" {
	local varlist UPB_SOP UPB_EOP
	foreach varname of local varlist {
		replace `varname'= `varname'*${GuaranteedPercent}
	}
}

* For deals with all-in rates below treasury rate, the fees are negative.
if ("$FeeSharing" == "No" | "$FeeSharing" == "Not Available") & "$InterestType"== "All-In Single Rate" & "${DirectGuaranteed}" == "Direct Loan"{
	replace Interest=Interest+Fees if Fees<0 & All_In_Single_Rate < Interest_Rate
	replace Fees = 0 if Fees<0
}

save "$Output_Path\Life Table 1.dta", replace
