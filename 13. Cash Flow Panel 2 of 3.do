/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do  Determines Periodicy of Disbursements  and completes the              *
*            Second Pannel of the the Cash Flow                                    *
*  Updated: 8-4-2017                                                              *
*#################################################################################*/


version 12.1
set more off
clear all 


if "$FXCurrency" == "Yes" {
	use "$Output_Path\Compressed Life Table USD.dta", replace
		keep Repayment_Date Payment_Frequency period Payment_Frequency_Months Disbursement Principal Interest Fees ///
		FX_Forward USD_2SD_Exposure UPB_SOP UPB_EOP Obligation DSRA_SOP DSRA_EOP ///
		DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE
		}
else {
	use "$Output_Path\Compressed Life Table.dta", replace
		keep Repayment_Date Payment_Frequency period Payment_Frequency_Months Disbursement Principal Interest Fees ///
		UPB_SOP UPB_EOP Obligation DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee ///
		DSRA_Draw_Def Shared_Fees Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE
}

drop if Obligation ~= 0 & Disbursement == 0
drop Obligation
rename Repayment_Date Date

** Appreciation Cover
generate Initial_Disb2=Date if period==0
egen Initial_Disb=max(Initial_Disb2)

generate repayment_timing=(Date-Initial_Disb)/365
generate fy_eight2=1 if repayment_timing>=8
replace fy_eight2=0 if repayment_timing<8
egen fy_eight=max(fy_eight2)
generate repayment_timing2=repayment_timing
replace repayment_timing=0 if repayment_timing>=8
egen max_timing=max(repayment_timing)
replace repayment_timing2=0 if Principal==0 & Interest==0 & Fees==0 /* Create repayment timing variable for borrower repayments only. Projected recoveries with 2-year delay should be excluded. */
egen max_timing2=max(repayment_timing2)

bysort Payment_Frequency: generate count=_n if UPB_SOP!=0
egen max_count=max(count)
gen AppreciationCover="$AnticipatedAppreciationCoverR"
destring AppreciationCover, replace

generate double APC_Disbursement=AppreciationCover if count==max_count & fy_eight==0
*generate double APC_Principal=AppreciationCover if count==max_count & fy_eight==0
generate double APC_Principal=AppreciationCover if repayment_timing2==max_timing2

replace APC_Disbursement=AppreciationCover if repayment_timing==max_timing & fy_eight==1
*replace APC_Principal=AppreciationCover if repayment_timing==max_timing & fy_eight==1

replace APC_Disbursement=0 if APC_Disbursement==.
replace APC_Principal=0 if APC_Principal==.

* Adjust appreciation cover line to convert from local currency to USD amount if project is FX
replace APC_Disbursement=Disbursement if "$FXCurrency"=="Yes" & APC_Disbursement!=0
egen APC_Disbursement2=max(APC_Disbursement)
global FXAppCover=APC_Disbursement2
replace APC_Principal=APC_Disbursement2 if "$FXCurrency"=="Yes" & APC_Principal!=0

drop period AppreciationCover count max_count Initial_Disb2 Initial_Disb repayment_timing repayment_timing2 fy_eight2 fy_eight max_timing max_timing2 APC_Disbursement2 Principal Interest Fees 
*******************

***
**Calculating the time between periods for Timing Keywords**
gen month=month(Date)
gen day=day(Date)
gen year=year(Date)
gen FY = year
replace FY = year + 1 if month >= 10


gen dayselapsed=(Date-mdy(9,30,FY-1))
	format dayselapsed %td
	
if Payment_Frequency=="Monthly"{	
	gen periodfirst=day(Date)
	gen fyperiod = month + 3 if month <= 9
	replace fyperiod = month - 9 if month > 9
	
}
if Payment_Frequency=="Quarterly"{
	gen periodqtr=quarter(Date)+1 
		replace period=1 if period>4
	
	gen lengthperiod1=mdy(12,31,year)-mdy(9,30,year)
	gen lengthperiod2=mdy(3,31,year+1)-mdy(12,31,year)
	gen lengthperiod3=mdy(6,30,year+1)-mdy(3,31,year+1)
	gen lengthperiod4=mdy(9,30,year+1)-mdy(6,30,year+1)

	gen periodfirst=dayselapsed
		replace periodfirst=(dayselapsed-lengthperiod1) if periodqtr==2
		replace periodfirst=(dayselapsed-(lengthperiod1+lengthperiod2)) if periodqtr==3
		replace periodfirst=(dayselapsed-(lengthperiod1+lengthperiod2+lengthperiod3)) if periodqtr==4
		
	gen fyperiod = periodqtr
}
if Payment_Frequency=="Semi-Annual"{
	gen periodsemiannual=halfyear(Date)
		replace period=2 if month(Date)>3
		replace period=1 if month(Date)>9
	
	gen lengthperiod1=mdy(3,31,year+1)-mdy(9,30,year)
	
	gen periodfirst=dayselapsed
		replace periodfirst=(dayselapsed-lengthperiod1) if periodsemiannual==2
		
	gen fyperiod = periodsemiannual
}

if Payment_Frequency=="Annual"{
	gen periodfirst=dayselapsed
	gen fyperiod = FY
}

	
***Calculating Beginning, Middle or End Timing for Disbursements***
gen double weigtheddays=Disbursement*periodfirst
egen totalweighteddays=sum(weigtheddays)
egen totaldisbursed=sum(Disbursement)
gen weightedavg=totalweighteddays/totaldisbursed

if Payment_Frequency=="Monthly"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/36
		replace period="Middle" if weightedavg>=365.2425/36&weightedavg<365.2425/18
		replace period="End" if weightedavg>=365.2425/18
}

if Payment_Frequency=="Quarterly"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/12
		replace period="Middle" if weightedavg>=365.2425/12&weightedavg<365.2425/6
		replace period="End" if weightedavg>=365.2425/6
}

if Payment_Frequency=="Semi-Annual"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/6
		replace period="Middle" if weightedavg>=365.2425/6&weightedavg<365.2425/3
		replace period="End" if weightedavg>=365.2425/3
}

if Payment_Frequency=="Annual"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/3
		replace period="Middle" if weightedavg>=365.2425/3&weightedavg<365.2425/1.5
		replace period="End" if weightedavg>=365.2425/1.5
}

if Payment_Frequency ~= "Annual"{
    gen dib_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])  +  ":" +  string(fyperiod[1])
    gen start = string(FY[1])  +  ":" +  string(fyperiod[1])
	}
	
***Creating the keyword combo for frequency, timing within period, and starting period***	
else {
    gen dib_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])
	gen start = string(FY[1])
	}

global disb_frequency_tag = dib_f_tag[1]
global start = start[1] 

if "$FXCurrency" == "No" {
keep Disbursement period*	fyperiod year FY Payment_Frequency	UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE APC_Disbursement APC_Principal 

	if "$DirectGuaranteed" == "Direct Loan"  {
		if Payment_Frequency=="Monthly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY fyperiod)	
		}

		if Payment_Frequency=="Quarterly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY periodqtr)	
		}

		if Payment_Frequency=="Semi-Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY periodsemiannual)	
		}

		if Payment_Frequency=="Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY)	
		}
	}
	if "$DirectGuaranteed" != "Direct Loan"  {
		if Payment_Frequency=="Monthly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY fyperiod)	
		}

		if Payment_Frequency=="Quarterly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY periodqtr)	
		}

		if Payment_Frequency=="Semi-Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY periodsemiannual)	
		}

		if Payment_Frequency=="Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY)	
		}
	}
}

if "$FXCurrency" == "Yes" {
keep Disbursement period* fyperiod year FY Payment_Frequency FX_Forward USD_2SD_Exposure UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE APC_Disbursement APC_Principal 

	if "$DirectGuaranteed" == "Direct Loan"  {
		if Payment_Frequency=="Monthly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY fyperiod)	
		}

		if Payment_Frequency=="Quarterly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY periodqtr)	
		}

		if Payment_Frequency=="Semi-Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY periodsemiannual)	
		}

		if Payment_Frequency=="Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY)	
		}
	}
	if "$DirectGuaranteed" != "Direct Loan"  {
		if Payment_Frequency=="Monthly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY fyperiod)	
		}

		if Payment_Frequency=="Quarterly"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY periodqtr)	
		}

		if Payment_Frequency=="Semi-Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY periodsemiannual)	
		}

		if Payment_Frequency=="Annual"{
			collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP FX_Forward (lastnm) USD_2SD_Exposure UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY)	
		}
	}
	
}

order FY

***Transposing the data into CSC input cashflow format***
drop Payment_Frequency

global columns = _N

xpose , clear  format(%16.2fc) v promote

 forvalues i = 1(1)$columns {
    tostring v`i' , replace used force
	}

***Creating Sequence Numbers***	
rename _varname Item
gen SequenceNo = 0

order SequenceNo Item SequenceNo

replace SequenceNo = 120  if  Item == "FY"
replace SequenceNo = 130  if  Item ==  "periodsemiannual" | Item == "periodqtr" | Item == "fyperiod"
replace SequenceNo = 140  if  Item == "Disbursement"
replace SequenceNo = 230  if  Item == "UPB_SOP"
replace SequenceNo = 240  if  Item == "UPB_EOP"
replace SequenceNo = 520  if  Item == "DSRA_SOP"
replace SequenceNo = 530  if  Item == "DSRA_EOP"
replace SequenceNo = 540  if  Item == "DSRA_Draw"
replace SequenceNo = 550  if  Item == "DSRA_Draw_Fee"
replace SequenceNo = 560  if  Item == "DSRA_Draw_Def"
replace SequenceNo = 570  if  Item == "Shared_Fees_RE"
replace SequenceNo = 580  if  Item == "Shared_Commitment_Fees_RE"
replace SequenceNo = 590  if  Item == "Shared_Lost_Fees_RE"
replace SequenceNo = 600  if  Item == "Shared_Defaults_RE"
replace SequenceNo = 610  if  Item == "Shared_Recoveries_RE"
replace SequenceNo = 620  if  Item == "FX_Forward"
replace SequenceNo = 630  if  Item == "USD_2SD_Exposure"
replace SequenceNo = 670  if Item == "APC_Disbursement"
replace SequenceNo = 680  if Item == "APC_Principal"

***Populating CSC Keyword Items***
replace Item = Item + " [" + "$disb_frequency_tag" + "]" if Item == "Disbursement"	
replace Item = "*FY" if Item == "FY"
replace Item = "*Period (Semiannual)" if Item == "periodsemiannual"
replace Item = "*Quarter" if Item == "periodqtr"
replace Item = "*Month(Fiscal)" if Item == "fyperiod"
replace Item = "*UPB SOP" + " [" + "$disb_frequency_tag" + "]" if Item =="UPB_SOP"
replace Item = "*UPB EOP" + " [" + "$disb_frequency_tag" + "]" if Item =="UPB_EOP"
replace Item = "*DSRA SOP" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_SOP"
replace Item = "*DSRA EOP" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_EOP"
replace Item = "*DSRA Draw" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_Draw"
replace Item = "*DSRA Draw Fees" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_Draw_Fee"
replace Item = "*DSRA Draw P&I" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_Draw_Def"
replace Item = "*Shared Fees (Spread)" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Fees_RE"
replace Item = "*Shared Fees (Commitment Fees)" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Commitment_Fees_RE"
replace Item = "*Shared Lost Fees" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Lost_Fees_RE"
replace Item = "*Shared Defaults" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Defaults_RE"
replace Item = "*Shared Recoveries" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Recoveries_RE"
replace Item = "*FX Forward Rate" if Item =="FX_Forward"
replace Item = "*Exposure Cap (2SD)" if Item =="USD_2SD_Exposure"
replace Item = "*Disbursements (Appreciation Cover)" + " [" + "$disb_frequency_tag" + "]" if Item == "APC_Disbursement"
replace Item = "*Principal Payments (Appreciation Cover)" + " [" + "$disb_frequency_tag" + "]" if Item == "APC_Principal"

rename v1 Value

if "$AnticipatedAppreciationCoverR" == "0" {
drop if SequenceNo == 670  | SequenceNo == 680
}
* April 2021 Edits
if "$DirectGuaranteed" == "Direct Loan"  {
drop if SequenceNo==550 | SequenceNo==560
}
**

if "$FXCurrency" == "No" {
drop if SequenceNo==620 | SequenceNo==630
}

if "$FeeSharing" == "No" | "$FeeSharing" == "Not Available" {
drop if SequenceNo==570 | SequenceNo==580 | SequenceNo==590 | SequenceNo==600 | SequenceNo==610
} 

replace Item = "*First Loss SOP" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==520 & "$FirstLossAmount" != "0"
replace Item = "*First Loss EOP" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==530 & "$FirstLossAmount" != "0"
replace Item = "*First Loss Draw" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==540 & "$FirstLossAmount" != "0"
replace Item = "*First Loss Draw Fees" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==550 & "$FirstLossAmount" != "0"
replace Item = "*First Loss Draw P&I" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==560 & "$FirstLossAmount" != "0"

if "$FundedDSRAorLCsecurity" == "0" & "$FirstLossAmount" == "0" {
drop if SequenceNo==520 | SequenceNo==530 | SequenceNo==540 | SequenceNo==550 | SequenceNo==560
} 

save "$Output_Path\cscflow part 2 of 3.dta", replace

********************************************************
*** Copy entirety of above for FX Denominated Cash flow
********************************************************
clear
if "$FXCurrency" == "Yes"  {
	use "$Output_Path\Compressed Life Table.dta", replace
		keep Repayment_Date Payment_Frequency period Payment_Frequency_Months Disbursement Principal Interest Fees UPB_SOP UPB_EOP Obligation DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE

drop if Obligation ~= 0 & Disbursement == 0
drop Obligation
rename Repayment_Date Date

** Appreciation Cover
generate Initial_Disb2=Date if period==0
egen Initial_Disb=max(Initial_Disb2)

generate repayment_timing=(Date-Initial_Disb)/365
generate fy_eight2=1 if repayment_timing>=8
replace fy_eight2=0 if repayment_timing<8
egen fy_eight=max(fy_eight2)
generate repayment_timing2=repayment_timing
replace repayment_timing=0 if repayment_timing>=8
egen max_timing=max(repayment_timing)
replace repayment_timing2=0 if Principal==0 & Interest==0 & Fees==0 /* Create repayment timing variable for borrower repayments only. Projected recoveries with 2-year delay should be excluded. */
egen max_timing2=max(repayment_timing2)

bysort Payment_Frequency: generate count=_n if UPB_SOP!=0
egen max_count=max(count)
gen AppreciationCover="$AnticipatedAppreciationCoverR"
destring AppreciationCover, replace

generate double APC_Disbursement=AppreciationCover if count==max_count & fy_eight==0
*generate double APC_Principal=AppreciationCover if count==max_count & fy_eight==0
generate double APC_Principal=AppreciationCover if repayment_timing2==max_timing2

replace APC_Disbursement=AppreciationCover if repayment_timing==max_timing & fy_eight==1
*replace APC_Principal=AppreciationCover if repayment_timing==max_timing & fy_eight==1

replace APC_Disbursement=0 if APC_Disbursement==.
replace APC_Principal=0 if APC_Principal==.

* Adjust appreciation cover line to convert from local currency to USD amount if project is FX
replace APC_Disbursement=Disbursement if "$FXCurrency"=="Yes" & APC_Disbursement!=0
egen APC_Disbursement2=max(APC_Disbursement)
replace APC_Principal=APC_Disbursement2 if "$FXCurrency"=="Yes" & APC_Principal!=0

drop period AppreciationCover count max_count Initial_Disb2 Initial_Disb repayment_timing repayment_timing2 fy_eight2 fy_eight max_timing max_timing2 APC_Disbursement2 Principal Interest Fees 
*******************

**Calculating the time between periods for Timing Keywords**
gen month=month(Date)
gen day=day(Date)
gen year=year(Date)
gen FY = year
replace FY = year + 1 if month >= 10


gen dayselapsed=(Date-mdy(9,30,FY-1))
	format dayselapsed %td
	
if Payment_Frequency=="Monthly"{	
	gen periodfirst=day(Date)
	gen fyperiod = month + 3 if month <= 9
	replace fyperiod = month - 9 if month > 9
	
}
if Payment_Frequency=="Quarterly"{
	gen periodqtr=quarter(Date)+1 
		replace period=1 if period>4
	
	gen lengthperiod1=mdy(12,31,year)-mdy(9,30,year)
	gen lengthperiod2=mdy(3,31,year+1)-mdy(12,31,year)
	gen lengthperiod3=mdy(6,30,year+1)-mdy(3,31,year+1)
	gen lengthperiod4=mdy(9,30,year+1)-mdy(6,30,year+1)

	gen periodfirst=dayselapsed
		replace periodfirst=(dayselapsed-lengthperiod1) if periodqtr==2
		replace periodfirst=(dayselapsed-(lengthperiod1+lengthperiod2)) if periodqtr==3
		replace periodfirst=(dayselapsed-(lengthperiod1+lengthperiod2+lengthperiod3)) if periodqtr==4
		
	gen fyperiod = periodqtr
}
if Payment_Frequency=="Semi-Annual"{
	gen periodsemiannual=halfyear(Date)
		replace period=2 if month(Date)>3
		replace period=1 if month(Date)>9
	
	gen lengthperiod1=mdy(3,31,year+1)-mdy(9,30,year)
	
	gen periodfirst=dayselapsed
		replace periodfirst=(dayselapsed-lengthperiod1) if periodsemiannual==2
		
	gen fyperiod = periodsemiannual
}

if Payment_Frequency=="Annual"{
	gen periodfirst=dayselapsed
	gen fyperiod = FY
}

***Calculating Beginning, Middle or End Timing for Disbursements***
gen double weigtheddays=Disbursement*periodfirst
egen totalweighteddays=sum(weigtheddays)
egen totaldisbursed=sum(Disbursement)
gen weightedavg=totalweighteddays/totaldisbursed

if Payment_Frequency=="Monthly"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/36
		replace period="Middle" if weightedavg>=365.2425/36&weightedavg<365.2425/18
		replace period="End" if weightedavg>=365.2425/18
}

if Payment_Frequency=="Quarterly"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/12
		replace period="Middle" if weightedavg>=365.2425/12&weightedavg<365.2425/6
		replace period="End" if weightedavg>=365.2425/6
}

if Payment_Frequency=="Semi-Annual"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/6
		replace period="Middle" if weightedavg>=365.2425/6&weightedavg<365.2425/3
		replace period="End" if weightedavg>=365.2425/3
}

if Payment_Frequency=="Annual"{
	gen period="Beginning" if weightedavg>=0&weightedavg<365.2425/3
		replace period="Middle" if weightedavg>=365.2425/3&weightedavg<365.2425/1.5
		replace period="End" if weightedavg>=365.2425/1.5
}

if Payment_Frequency ~= "Annual"{
    gen dib_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])  +  ":" +  string(fyperiod[1])
    gen start = string(FY[1])  +  ":" +  string(fyperiod[1])
	}
	
***Creating the keyword combo for frequency, timing within period, and starting period***	
else {
    gen dib_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])
	gen start = string(FY[1])
	}

global disb_frequency_tag = dib_f_tag[1]
global start = start[1] 

keep Disbursement period*	fyperiod year FY Payment_Frequency	UPB_SOP UPB_EOP DSRA_SOP DSRA_EOP DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE Shared_Lost_Fees_RE Shared_Defaults_RE Shared_Recoveries_RE APC_Disbursement APC_Principal 

if "$DirectGuaranteed" == "Direct Loan"  {
	if Payment_Frequency=="Monthly"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY fyperiod)	
	}

	if Payment_Frequency=="Quarterly"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY periodqtr)	
	}

	if Payment_Frequency=="Semi-Annual"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY periodsemiannual)	
	}

	if Payment_Frequency=="Annual"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE Shared_Defaults_RE (max) Shared_Recoveries_RE, by(FY)	
	}
}
if "$DirectGuaranteed" != "Direct Loan"  {
	if Payment_Frequency=="Monthly"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY fyperiod)	
	}

	if Payment_Frequency=="Quarterly"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY periodqtr)	
	}

	if Payment_Frequency=="Semi-Annual"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY periodsemiannual)	
	}

	if Payment_Frequency=="Annual"{
		collapse (sum) Disbursement (firstnm)Payment_Frequency UPB_SOP DSRA_SOP (lastnm) UPB_EOP DSRA_EOP (max) DSRA_Draw DSRA_Draw_Fee DSRA_Draw_Def Shared_Fees_RE Shared_Commitment_Fees_RE APC_Disbursement APC_Principal (min) Shared_Lost_Fees_RE (max) Shared_Defaults_RE (min) Shared_Recoveries_RE, by(FY)	
	}
}

order FY

***Transposing the data into CSC input cashflow format***
drop Payment_Frequency

global columns = _N

xpose , clear  format(%16.2fc) v promote

 forvalues i = 1(1)$columns {
    tostring v`i' , replace used force
	}

***Creating Sequence Numbers***	
rename _varname Item
gen SequenceNo = 0

order SequenceNo Item SequenceNo

replace SequenceNo = 120  if  Item == "FY"
replace SequenceNo = 130  if  Item ==  "periodsemiannual" | Item == "periodqtr" | Item == "fyperiod"
replace SequenceNo = 140  if  Item == "Disbursement"
replace SequenceNo = 230  if  Item == "UPB_SOP"
replace SequenceNo = 240  if  Item == "UPB_EOP"
replace SequenceNo = 520  if  Item == "DSRA_SOP"
replace SequenceNo = 530  if  Item == "DSRA_EOP"
replace SequenceNo = 540  if  Item == "DSRA_Draw"
replace SequenceNo = 550  if  Item == "DSRA_Draw_Fee"
replace SequenceNo = 560  if  Item == "DSRA_Draw_Def"
replace SequenceNo = 570  if  Item == "Shared_Fees_RE"
replace SequenceNo = 580  if  Item == "Shared_Commitment_Fees_RE"
replace SequenceNo = 590  if  Item == "Shared_Lost_Fees_RE"
replace SequenceNo = 600  if  Item == "Shared_Defaults_RE"
replace SequenceNo = 610  if  Item == "Shared_Recoveries_RE"
replace SequenceNo = 670  if Item == "APC_Disbursement"
replace SequenceNo = 680  if Item == "APC_Principal"

***Populating CSC Keyword Items***
replace Item = Item + " [" + "$disb_frequency_tag" + "]" if Item == "Disbursement"	
replace Item = "*FY" if Item == "FY"
replace Item = "*Period (Semiannual)" if Item == "periodsemiannual"
replace Item = "*Quarter" if Item == "periodqtr"
replace Item = "*Month(Fiscal)" if Item == "fyperiod"
replace Item = "*UPB SOP" + " [" + "$disb_frequency_tag" + "]" if Item =="UPB_SOP"
replace Item = "*UPB EOP" + " [" + "$disb_frequency_tag" + "]" if Item =="UPB_EOP"
replace Item = "*DSRA SOP" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_SOP"
replace Item = "*DSRA EOP" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_EOP"
replace Item = "*DSRA Draw" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_Draw"
replace Item = "*DSRA Draw Fees" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_Draw_Fee"
replace Item = "*DSRA Draw P&I" + " [" + "$disb_frequency_tag" + "]" if Item =="DSRA_Draw_Def"
replace Item = "*Shared Fees (Spread)" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Fees_RE"
replace Item = "*Shared Fees (Commitment Fees)" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Commitment_Fees_RE"
replace Item = "*Shared Lost Fees" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Lost_Fees_RE"
replace Item = "*Shared Defaults" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Defaults_RE"
replace Item = "*Shared Recoveries" + " [" + "$disb_frequency_tag" + "]" if Item =="Shared_Recoveries_RE"
replace Item = "*Disbursements (Appreciation Cover)" + " [" + "$disb_frequency_tag" + "]" if Item == "APC_Disbursement"
replace Item = "*Principal Payments (Appreciation Cover)" + " [" + "$disb_frequency_tag" + "]" if Item == "APC_Principal"

rename v1 Value

if "$AnticipatedAppreciationCoverR" == "0" {
drop if SequenceNo == 670  | SequenceNo == 680
}
* April 2021 Edits
if "$DirectGuaranteed" == "Direct Loan"  {
drop if SequenceNo==550 | SequenceNo==560
}
**

if "$FeeSharing" == "No" | "$FeeSharing" == "Not Available" {
drop if SequenceNo==570 | SequenceNo==580 | SequenceNo==590 | SequenceNo==600 | SequenceNo==610
} 

replace Item = "*First Loss SOP" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==520 & "$FirstLossAmount" != "0"
replace Item = "*First Loss EOP" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==530 & "$FirstLossAmount" != "0"
replace Item = "*First Loss Draw" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==540 & "$FirstLossAmount" != "0"
replace Item = "*First Loss Draw Fees" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==550 & "$FirstLossAmount" != "0"
replace Item = "*First Loss Draw P&I" + " [" + "$disb_frequency_tag" + "]" if SequenceNo==560 & "$FirstLossAmount" != "0"

if "$FundedDSRAorLCsecurity" == "0" & "$FirstLossAmount" == "0" {
drop if SequenceNo==520 | SequenceNo==530 | SequenceNo==540 | SequenceNo==550 | SequenceNo==560
} 

save "$Output_Path\cscflow part 2 of 3 FX.dta", replace
}


