/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file creates the third panel of the cash flow                          *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/
version 12.1
set more off

global defvar = cond("${DefaultMethodology}" == "FY2014 Risk Methodology" , "Default_Rate" , "*DR" , "*DR")
global apcvar = cond(${ForeignCurrencyAppreciationCo} ~=0, "APC*", "")
global exposure_var = cond("${FXCurrency}" =="Yes"  & "$DirectGuaranteed" != "Direct Loan", "Principal_Exp", "Exposure")

if "$FXCurrency" == "Yes" {
	use "$Output_Path\Compressed Life Table USD.dta", replace
		* Brandon Edits
		egen WC_Fees_Max=max(WC_Fees)
		gen Other_Inflow_Temp = WC_Fees_Max if _n==3
		replace Other_Inflow_Temp=0 if (WC_Fees_Max==. | WC_Fees_Max==0)
		replace Other_Inflow_Temp=0 if Other_Inflow_Temp==.
		drop WC_Fees_Max
		*
		if "$DirectGuaranteed" != "Direct Loan" {
		gen Other_Inflow_FXP =0
		gen Other_Inflow_FXI =0
		gen Other_Inflow_FXF =0
		}	
	}
if "$FXCurrency" == "No" {
	use "$Output_Path\Compressed Life Table.dta", replace
	gen Other_Inflow_FXP =0
	gen Other_Inflow_FXI =0
	gen Other_Inflow_FXF =0
	gen Other_Inflow_Temp =0
	}

if "$FXCurrency" == "Yes" {
	if "$DirectGuaranteed" == "Direct Loan"{
	drop if Disbursement ~=0 & Principal == 0 & Other_Inflow_FXP == 0 & Interest == 0 & Other_Inflow_FXI == 0 & Fees == 0 & Other_Inflow_FXF == 0 & Commitment_Fees == 0 & Default == 0 & Lost_Fee == 0 & Recovery == 0 & Cap_Interest == 0 | Obligation ~=0
	drop if Obligation ~= 0 & Disbursement == 0
	}
	if "$DirectGuaranteed" != "Direct Loan"{
	drop if Disbursement ~=0 & Principal == 0 & Interest == 0 & Fees == 0 & Commitment_Fees == 0 & Default == 0 & Lost_Fee == 0 & Recovery == 0 & Cap_Interest == 0 | Obligation ~=0
	drop if Obligation ~= 0 & Disbursement == 0
	}
}

if "$FXCurrency" == "No" {
	drop if Disbursement ~=0 & Principal == 0 & Interest == 0 & Fees == 0 & Commitment_Fees == 0 & Default == 0 & Lost_Fee == 0 & Recovery == 0 & Cap_Interest == 0 | Obligation ~=0
	drop if Obligation ~= 0 & Disbursement == 0
}

keep Repayment_Date Payment_Frequency Payment_Frequency_Months Commitment_Fees Principal Interest Fees  ///
    Default Lost_Fee Recovery Cap_Interest Exposure ${defvar} ${apcvar} ${PrepayVar} ${exposure_var} Other_Inflow*

gen double Fees_Other = 0
gen double Upfront_Fee = 0 if "$DirectGuaranteed" != "Direct Loan"
sort Repayment_Date
replace Upfront_Fee = ${UpfrontFee} if _n==1 & "$DirectGuaranteed" != "Direct Loan"
if "$FXCurrency" == "Yes"  & "$DirectGuaranteed" != "Direct Loan" {
replace Upfront_Fee = ${UpfrontFee} * ${FXSpotRateFXCurrencyUSD} if _n==1 & "$DirectGuaranteed" != "Direct Loan"
}

gen rep_month = month(Repayment_Date)
gen maintenance = 1 if rep_month == month($DateofFirstPayment)
replace maintenance = 0 if maintenance == .
replace maintenance = 0 if Repayment_Date <= $DateofFirstPayment
replace maintenance = 0 if Repayment_Date > $DateofFinalRepayment
replace Fees_Other = $MaintenanceFee if maintenance == 1
replace Fees_Other = $GiftAuthority if _n == 1 & "$FXCurrency" == "No" /* Brandon Edits */
replace Fees_Other = Other_Inflow_Temp if _n == 1 & "$FXCurrency" == "Yes" /* Brandon Edits */
drop maintenance rep_month Other_Inflow_Temp

/*###################################################################################
  # Determining the Timing Keywords for Each Line Item                              #
  #################################################################################*/

rename Repayment_Date Date

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
	global start2 = fyperiod[1]
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

		global start2 = periodqtr[1]
		}
if Payment_Frequency=="Semi-Annual"{
	gen periodsemiannual=halfyear(Date)
		replace period=2 if month(Date)>3
		replace period=1 if month(Date)>9
	
	gen lengthperiod1=mdy(3,31,year+1)-mdy(9,30,year)
	
	gen periodfirst=dayselapsed
		replace periodfirst=(dayselapsed-lengthperiod1) if periodsemiannual==2
    
	global start2 = periodsemiannual[1]
		
		}

if Payment_Frequency=="Annual"{
	gen periodfirst=dayselapsed
}

gen weigtheddays=Principal*periodfirst
egen totalweighteddays=sum(weigtheddays)
egen totalPrincipal=sum(Principal)
gen weightedavg=totalweighteddays/totalPrincipal


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
    gen repay_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])  +  ":" + "$start2"
	}
else {
    gen repay_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])
	}
global repay_frequency_tag = repay_f_tag[1] 
drop period periodfirst

/*###################################################################################
  # Converting Data to Cashflow format                                              #
  #################################################################################*/
  
***Cleaning Data***  
if Payment_Frequency== "Monthly" {
    keep Principal Interest Fees Commitment_Fees Default Lost_Fee Recovery month year Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} ${exposure_var} Fees_Other Upfront_Fee Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF
    order year month Commitment_Fees Principal Interest Fees Lost_Fee Default Recovery Cap_Interest  Exposure  ${defvar} ${apcvar} ${PrepayVar} ${exposure_var} Fees_Other Upfront_Fee Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF
	drop year month
	}

else {
    if Payment_Frequency=="Annual"{
	     keep Principal Interest Fees Commitment_Fees Default Lost_Fee Recovery FY Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} ${exposure_var} Fees_Other Upfront_Fee Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF
		 order FY Commitment_Fees Principal Interest Fees Lost_Fee Default Recovery Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} ${exposure_var} Fees_Other Upfront_Fee Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF
		 drop FY
		 }
	
	else {
        keep Principal Interest Fees Commitment_Fees Default Lost_Fee Recovery FY period* Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} ${exposure_var} Fees_Other Upfront_Fee Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF
	    order FY period* Commitment_Fees Principal Interest Fees Lost_Fee Default Recovery Cap_Interest  Exposure  ${defvar} ${apcvar} ${PrepayVar} ${exposure_var} Fees_Other Upfront_Fee Other_Inflow_FXP Other_Inflow_FXI Other_Inflow_FXF
		drop FY period*
	}
	}
	
global columns2 = _N

xpose , clear  format(%16.2fc) v promote

***Creating Sequence Numbers and Keywords***
rename _varname Item
gen SequenceNo = 0

order  SequenceNo Item

replace SequenceNo = 150  if Item == "Commitment_Fees"
replace SequenceNo = 160  if Item == "Principal"
replace SequenceNo = 170  if Item == "Interest"
replace SequenceNo = 180  if Item == "Fees"
replace SequenceNo = 190  if Item == "Lost_Fee"
replace SequenceNo = 200  if Item == "Default"
replace SequenceNo = 210  if Item == "Recovery"
replace SequenceNo = 220  if Item == "Cap_Interest"
replace SequenceNo = 250  if Item == "Exposure" | Item == "Principal_Exp"
replace SequenceNo = 260  if Item == "CDR"
replace SequenceNo = 270  if Item == "MDR"
replace SequenceNo = 280  if Item == "Default_Rate"
replace SequenceNo = 290  if Item == "APC_Default"
replace SequenceNo = 300  if Item == "APC_Recovery"
replace SequenceNo = 310  if Item == "Fees_Other"
replace SequenceNo = 320  if Item == "Upfront_Fee"
replace SequenceNo = 330  if Item == "Other_Outflow_Prepay"
replace SequenceNo = 340  if Item == "Other_Inflow_Prepay"
replace SequenceNo = 640  if Item == "Other_Inflow_FXP"
replace SequenceNo = 650  if Item == "Other_Inflow_FXI"
replace SequenceNo = 660  if Item == "Other_Inflow_FXF"


if "$DirectGuaranteed" == "Direct Loan" {
    replace Item = "Fees and Other Income (Commitment Fees)" + " [" + "$repay_frequency_tag" + "]" if Item == "Commitment_Fees"
	replace Item = "Principal Payments, Scheduled" + " [" + "$repay_frequency_tag" + "]" if Item == "Principal"
	replace Item = "Interest Payments, Scheduled" + " [" + "$repay_frequency_tag" + "]" if Item == "Interest"
	replace Item = "Fees and Other Income (Spread)"+ " [" + "$repay_frequency_tag" + "]" if Item == "Fees"
	replace Item = "Default Effect on Cash Flows" + " [" + "$repay_frequency_tag" + "]" if Item == "Default"
	replace Item = "Recoveries" + " [" + "$repay_frequency_tag" + "]" if Item == "Recovery"
	replace Item = "*Capitalized Interest" + " [" + "$repay_frequency_tag" + "]"  if Item =="Cap_Interest"
	drop if Item == "Exposure"
	drop if Item == "Lost_Fee"
	replace Item = "*Cumulative Default Rate" if Item =="CDR"
	replace Item = "*Default Rate" if Item == "Default_Rate"
	replace Item = "Default Payments(Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Default"
	replace Item = "Recoveries on Defaults (Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Recovery"
	replace Item = "Fees and Other Income (Other Fees)" + " [" + "$repay_frequency_tag" + "]" if Item =="Fees_Other"
	drop if Item == "Upfront_Fee"
	replace Item = "Other Outflows (-) (Lost Fees due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Outflow_Prepay"
	replace Item = "Other Inflows (+) (Annual Fees Received due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Inflow_Prepay"
	replace Item = "Other Inflows (Gains or Losses due to FX appreciation/depreciation, Principal)" + " [" + "$repay_frequency_tag" + "]" if Item == "Other_Inflow_FXP"
	replace Item = "Other Inflows (Gains or Losses due to FX appreciation/depreciation, Interest)" + " [" + "$repay_frequency_tag" + "]" if Item == "Other_Inflow_FXI"
	replace Item = "Other Inflows (Gains or Losses due to FX appreciation/depreciation, Fees)"+ " [" + "$repay_frequency_tag" + "]" if Item == "Other_Inflow_FXF"
	
	}
if "$DirectGuaranteed" ~= "Direct Loan" {
    replace Item = "Annual Fees Received (Commitment Fees)" + " [" + "$repay_frequency_tag" + "]" if Item == "Commitment_Fees"
	replace Item = "*Principal" + " [" + "$repay_frequency_tag" + "]" if Item == "Principal"
	replace Item = "*Interest" + " [" + "$repay_frequency_tag" + "]" if Item == "Interest"
	replace Item = "Annual Fees Received (Guarantee Fees)" + " [" + "$repay_frequency_tag" + "]" if Item == "Fees"
	replace Item = "Lost Fees" + " [" + "$repay_frequency_tag" + "]" if Item == "Lost_Fee"
	replace Item = "Default Payments" + " [" + "$repay_frequency_tag" + "]" if Item == "Default"
	replace Item = "Recoveries on Defaults" + " [" + "$repay_frequency_tag" + "]" if Item =="Recovery"
	replace Item = "*Capitalized Interest" + " [" + "$repay_frequency_tag" + "]" if Item =="Cap_Interest"
	replace Item = "*Exposure" if Item == "Exposure"
	replace Item = "*Principal Exposure" if Item == "Principal_Exp"
	replace Item = "*Cumulative Default Rate" if Item =="CDR"
	replace Item = "*Marginal Default Rate" if Item =="MDR"
	replace Item = "*Default Rate" if Item == "Default_Rate"
	replace Item = "Default Payments(Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Default"
	replace Item = "Recoveries on Defaults (Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Recovery"	
	replace Item = "Annual Fees Received (Other Fees)" + " [" + "$repay_frequency_tag" + "]" if Item =="Fees_Other"
	replace Item = "Upfront Fee" + " [" + "$repay_frequency_tag" + "]" if Item =="Upfront_Fee"
	replace Item = "Other Outflows (-) (Lost Fees due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Outflow_Prepay"
	replace Item = "Other Inflows (+) (Annual Fees Received due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Inflow_Prepay"
	}
if "$FXCurrency" != "Yes" | "$DirectGuaranteed" ~= "Direct Loan" {	
drop if SequenceNo == 640  | SequenceNo == 650  | SequenceNo == 660
}	
	
forvalues i = 1(1)$columns2 {
    tostring v`i' , replace used force
	}	
	
forvalues i = 1(1)$columns2 {
    replace v`i' = `"="""' if SequenceNo == 160 & v`i'=="0.00"
 	}
	
rename v1 Value	
tostring Value, replace 
save "$Output_Path\cscflow part 3 of 3.dta", replace


********************************************************
*** Copy entirety of above for FX Denominated Cash flow
********************************************************
clear
if "$FXCurrency" == "Yes" {
	use "$Output_Path\Compressed Life Table.dta", replace

drop if Disbursement ~=0 & Principal == 0 & Interest == 0 & Fees == 0 & Commitment_Fees == 0 & Default == 0 & Lost_Fee == 0 & Recovery == 0 & Cap_Interest == 0 | Obligation ~=0
drop if Obligation ~= 0 & Disbursement == 0

keep Repayment_Date Payment_Frequency Payment_Frequency_Months Commitment_Fees Principal Interest Fees  ///
    Default Lost_Fee Recovery Cap_Interest Exposure ${defvar} ${apcvar} ${PrepayVar} ///

gen double Fees_Other = 0
gen double Upfront_Fee = 0 if "$DirectGuaranteed" != "Direct Loan"
sort Repayment_Date
replace Upfront_Fee = ${UpfrontFee} if _n==1 & "$DirectGuaranteed" != "Direct Loan"

/*###################################################################################
  # Determining the Timing Keywords for Each Line Item                              #
  #################################################################################*/

rename Repayment_Date Date

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
	global start2 = fyperiod[1]
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

		global start2 = periodqtr[1]
		}
if Payment_Frequency=="Semi-Annual"{
	gen periodsemiannual=halfyear(Date)
		replace period=2 if month(Date)>3
		replace period=1 if month(Date)>9
	
	gen lengthperiod1=mdy(3,31,year+1)-mdy(9,30,year)
	
	gen periodfirst=dayselapsed
		replace periodfirst=(dayselapsed-lengthperiod1) if periodsemiannual==2
    
	global start2 = periodsemiannual[1]
		
		}

if Payment_Frequency=="Annual"{
	gen periodfirst=dayselapsed
}

gen weigtheddays=Principal*periodfirst
egen totalweighteddays=sum(weigtheddays)
egen totalPrincipal=sum(Principal)
gen weightedavg=totalweighteddays/totalPrincipal


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
    gen repay_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])  +  ":" + "$start2"
	}
else {
    gen repay_f_tag = Payment_Frequency[1] + "," + period[1] + "," + string(FY[1])
	}
global repay_frequency_tag = repay_f_tag[1] 
drop period periodfirst

/*###################################################################################
  # Converting Data to Cashflow format                                              #
  #################################################################################*/
  
***Cleaning Data***  
if Payment_Frequency== "Monthly" {
    keep Principal Interest Fees Commitment_Fees Default Lost_Fee Recovery month year Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} Fees_Other Upfront_Fee
    order year month Commitment_Fees Principal Interest Fees Lost_Fee Default Recovery Cap_Interest  Exposure  ${defvar} ${apcvar} ${PrepayVar} Fees_Other Upfront_Fee
	drop year month
	}

else {
    if Payment_Frequency=="Annual"{
	     keep Principal Interest Fees Commitment_Fees Default Lost_Fee Recovery FY Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} Fees_Other Upfront_Fee
		 order FY Commitment_Fees Principal Interest Fees Lost_Fee Default Recovery Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} Fees_Other Upfront_Fee
		 drop FY
		 }
	
	else {
        keep Principal Interest Fees Commitment_Fees Default Lost_Fee Recovery FY period* Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} Fees_Other Upfront_Fee
	    order FY period* Commitment_Fees Principal Interest Fees Lost_Fee Default Recovery Cap_Interest  Exposure ${defvar} ${apcvar} ${PrepayVar} Fees_Other Upfront_Fee
		drop FY period*
	}
	}

capture drop Principal_Exp_adj 
	
global columns2 = _N

xpose , clear  format(%16.2fc) v promote

***Creating Sequence Numbers and Keywords***
rename _varname Item
gen SequenceNo = 0

order  SequenceNo Item

replace SequenceNo = 150  if Item == "Commitment_Fees"
replace SequenceNo = 160  if Item == "Principal"
replace SequenceNo = 170  if Item == "Interest"
replace SequenceNo = 180  if Item == "Fees"
replace SequenceNo = 190  if Item == "Lost_Fee"
replace SequenceNo = 200  if Item == "Default"
replace SequenceNo = 210  if Item == "Recovery"
replace SequenceNo = 220  if Item == "Cap_Interest"
replace SequenceNo = 250  if Item == "Exposure" 
replace SequenceNo = 260  if Item == "CDR"
replace SequenceNo = 270  if Item == "MDR"
replace SequenceNo = 280  if Item == "Default_Rate"
replace SequenceNo = 290  if Item == "APC_Default"
replace SequenceNo = 300  if Item == "APC_Recovery"
replace SequenceNo = 310  if Item == "Fees_Other"
replace SequenceNo = 320  if Item == "Upfront_Fee"
replace SequenceNo = 330  if Item == "Other_Outflow_Prepay"
replace SequenceNo = 340  if Item == "Other_Inflow_Prepay"

if "$DirectGuaranteed" == "Direct Loan" {
    replace Item = "Fees and Other Income (Commitment Fees)" + " [" + "$repay_frequency_tag" + "]" if Item == "Commitment_Fees"
	replace Item = "Principal Payments, Scheduled" + " [" + "$repay_frequency_tag" + "]" if Item == "Principal"
	replace Item = "Interest Payments, Scheduled" + " [" + "$repay_frequency_tag" + "]" if Item == "Interest"
	replace Item = "Fees and Other Income (Spread)"+ " [" + "$repay_frequency_tag" + "]" if Item == "Fees"
	replace Item = "Default Effect on Cash Flows" + " [" + "$repay_frequency_tag" + "]" if Item == "Default"
	replace Item = "Recoveries" + " [" + "$repay_frequency_tag" + "]" if Item == "Recovery"
	replace Item = "*Capitalized Interest" + " [" + "$repay_frequency_tag" + "]"  if Item =="Cap_Interest"
	drop if Item == "Exposure"
	drop if Item == "Lost_Fee"
	replace Item = "*Cumulative Default Rate" if Item =="CDR"
	replace Item = "*Default Rate" if Item == "Default_Rate"
	replace Item = "Default Payments(Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Default"
	replace Item = "Recoveries on Defaults (Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Recovery"
	replace Item = "Fees and Other Income (Other Fees)" + " [" + "$repay_frequency_tag" + "]" if Item =="Fees_Other"
	drop if Item == "Upfront_Fee"
	replace Item = "Other Outflows (-) (Lost Fees due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Outflow_Prepay"
	replace Item = "Other Inflows (+) (Annual Fees Received due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Inflow_Prepay"
	}
if "$DirectGuaranteed" ~= "Direct Loan" {
    replace Item = "Annual Fees Received (Commitment Fees)" + " [" + "$repay_frequency_tag" + "]" if Item == "Commitment_Fees"
	replace Item = "*Principal" + " [" + "$repay_frequency_tag" + "]" if Item == "Principal"
	replace Item = "*Interest" + " [" + "$repay_frequency_tag" + "]" if Item == "Interest"
	replace Item = "Annual Fees Received (Guarantee Fees)" + " [" + "$repay_frequency_tag" + "]" if Item == "Fees"
	replace Item = "Lost Fees" + " [" + "$repay_frequency_tag" + "]" if Item == "Lost_Fee"
	replace Item = "Default Payments" + " [" + "$repay_frequency_tag" + "]" if Item == "Default"
	replace Item = "Recoveries on Defaults" + " [" + "$repay_frequency_tag" + "]" if Item =="Recovery"
	replace Item = "*Capitalized Interest" + " [" + "$repay_frequency_tag" + "]" if Item =="Cap_Interest"
	replace Item = "*Exposure" if Item == "Exposure"
	replace Item = "*Cumulative Default Rate" if Item =="CDR"
	replace Item = "*Marginal Default Rate" if Item =="MDR"
	replace Item = "*Default Rate" if Item == "Default_Rate"
	replace Item = "Default Payments(Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Default"
	replace Item = "Recoveries on Defaults (Appreciation Cover)" + " [" + "$repay_frequency_tag" + "]" if Item == "APC_Recovery"	
	replace Item = "Annual Fees Received (Other Fees)" + " [" + "$repay_frequency_tag" + "]" if Item =="Fees_Other"
	replace Item = "Upfront Fee" + " [" + "$repay_frequency_tag" + "]" if Item =="Upfront_Fee"
	replace Item = "Other Outflows (-) (Lost Fees due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Outflow_Prepay"
	replace Item = "Other Inflows (+) (Annual Fees Received due to Prepayment)" + " [" + "$repay_frequency_tag" + "]" if Item=="Other_Inflow_Prepay"
	}

forvalues i = 1(1)$columns2 {
    tostring v`i' , replace used force
	}	
	
forvalues i = 1(1)$columns2 {
    replace v`i' = `"="""' if SequenceNo == 160 & v`i'=="0.00"
 	}
	
rename v1 Value	
tostring Value, replace 

save "$Output_Path\cscflow part 3 of 3 FX.dta", replace
}
