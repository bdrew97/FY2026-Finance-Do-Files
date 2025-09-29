/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file imports and creates a schedule of commitment fees                 *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/
clear all
set more off
version 12.1
**********************************************************

***Creating an row for the Obligation***
set obs 1
gen double Obligation = $LoanorTotalGuaranteedAmount
format Obligation %16.2fc
gen double Date = $ObligationDate
format Date %td

***Adding the disbursement schedule and removing unnecesary variables***
append using  "$Output_Path\Disbursement Schedule.dta"
keep Obligation Date No Amount
rename Amount Disbursement


***establishing the monthly interval between payments**
gen        Payment_Frequency= "$PaymentFrequency"
gen double Payment_Frequency_Months= 0
replace    Payment_Frequency_Months=1     if Payment_Frequency=="Monthly"
replace    Payment_Frequency_Months=3     if Payment_Frequency=="Quarterly"
replace    Payment_Frequency_Months=6     if Payment_Frequency=="Semi-Annual"
replace    Payment_Frequency_Months=12    if Payment_Frequency=="Annual"

***Creating a row for the first repayment date***
expand 2 if No == . , gen(Repayment)
replace Obligation = 0                   if Repayment == 1
replace Date = ${DateofFirstPayment}     if Repayment ==1
replace Obligation = 0                   if Obligation == .
replace Disbursement = 0                 if Disbursement == .

***Creating rows for each fee payment after the first interest payment***
gen  newmonth=.
gen newday=.
gen newyear=.
gen newrepday =.

forvalues i = 1(1)99999 {
	expand 2 if Repayment == 1 , gen (new`i')
	replace Repayment = 1+`i' if new`i'==1
	replace newmonth= month(Date) + Payment_Frequency_Months*`i'   if new`i'==1
	replace newyear = year(Date)+floor((newmonth-1)/12)            if new`i'==1
	replace newmonth= mod((newmonth-1),12)+1                       if new`i'==1
	replace newrepday = mdy(newmonth,day(Date),newyear)            if new`i'==1
	replace newrepday = mdy(newmonth,(day(Date)-1),newyear)        if new`i'==1 & newrepday == .
	replace newrepday = mdy(newmonth,(day(Date)-2),newyear)        if new`i'==1 & newrepday == .
	replace newrepday = mdy(newmonth,(day(Date)-3),newyear)        if new`i'==1 & newrepday == .

	format %td newrepday
	replace Date = newrepday if new`i'==1
	drop new`i'
	egen double maxdate = max(Date)
	if maxdate > $LastDisbDate  {
		continue , break
	    }
	drop maxdate
	}

***Creating a row for each claim payment to occur before the first interest payment***
forvalues i = 1(1)99999 {
	expand 2  if Repayment == 1 , gen (new`i')
	replace Repayment = 1+`i'                                             if new`i'==1
	replace newmonth  = month(Date) + 12 - (Payment_Frequency_Months)*`i'   if new`i'==1
	replace newyear   = year(Date)+floor((newmonth-1)/12)-1                 if new`i'==1
	replace newmonth  = mod((newmonth-1),12)+1                              if new`i'==1
	replace newrepday = mdy(newmonth,day(Date),newyear)                   if new`i'==1
	replace newrepday = mdy(newmonth,(day(Date)-1),newyear)               if new`i'==1 & newrepday == .
	replace newrepday = mdy(newmonth,(day(Date)-2),newyear)               if new`i'==1 & newrepday == .
	replace newrepday = mdy(newmonth,(day(Date)-3),newyear)               if new`i'==1 & newrepday == .
	
	format %td newrepday
	replace Date = newrepday if new`i'==1
	drop new`i'
	egen double mindate = min(Date)
	if mindate < $ObligationDate  {
	    continue, break
		}
		drop mindate
		}
drop if Date < $ObligationDate
		
drop newmonth newday newyear maxdate mindate newrepday
sort Date

***Calculating the Commitment Fee***

***Generating the commitment fee and undisbursed amounts***		
gen double comfeepercent   = $CommitmentFee
gen double undisbursed_SOP = 0
gen double undisbursed_EOP = Obligation
format undisbursed* %16.2fc

***creating and ID variable and a macro to be used for looping***
sort Date (Repayment)
gen double id  = _n
egen cnt = max(id)
global cnt = cnt

***Calculating the running undisbursed amount***
forvalues i =  2(1)$cnt {
	replace undisbursed_SOP = undisbursed_EOP[_n-1]            if id == `i'
	replace undisbursed_EOP = undisbursed_SOP - Disbursement   if id == `i'
	}
	
***Calculating the number of dayse between periods and the number of days in each year***
gen double days = Date - Date[_n-1] 
gen double leapyear = (mod(year(Date),4) == 0 & mod(year(Date),100) != 0) | mod(year(Date),400) == 0
gen double days_in_year = 365 + leapyear

***Calculating the commitment fee accruued for each period***
gen double Commitment_Fees = undisbursed_SOP*comfeepercent*days/days_in_year     if id > 1
replace Commitment_Fees = 0                                                      if Commitment_Fees==.
format Commitment_Fees %16.2fc

***Moving the commitment ammounts from disbursement rows to repayment rows to create the prorated commitment fee for each repayment period***
forvalues i = 2(1)$cnt {
    replace Commitment_Fees = Commitment_Fees + Commitment_Fees[_n-1] if Repayment[_n-1]==0 & id == `i'
	}
replace Commitment_Fees = 0 if Repayment==0 

***Removing the disbursement rows and any unnecessary columns***
drop if Commitment_Fees == 0 & id ~= 1
keep Date Commitment_Fees Payment_Frequency_Months Obligation Payment_Frequency comfeepercent

***Changing Date's name for merging and creating a subperiod***
rename Date Repayment_Date 
gen subperiod = _n-1

***Adjusting the commitment fee for guarantees***
if "$DirectGuaranteed" ~= "Direct Loan"  {
    replace Commitment_Fees = Commitment_Fees*${GuaranteedPercent}
	}
	
replace Commitment_Fees = round(Commitment_Fees,.01)
	
***Saving***	
save "$Output_Path\commitment fees.dta", replace 
