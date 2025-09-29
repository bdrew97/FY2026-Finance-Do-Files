
global path1 = "`1'"
global Dofile_Path = "$path1\DoFiles\v4_2019_Prepayments_FX"
global Output_Path  "$path1\Outputs\${LoanOfficer}"

do "$Dofile_Path\2. Establishing Global Macros.do"

*global path="C:\Users\nicolas.meyer\Desktop\OPIC\Requests\INR DI FX\Model Additions"
*Maturity must match a date in forward curves files
global Maturity=$DateofFinalRepayment
*Start Date must match a date in forward file - first disbursement date
global Start_Date=$FirstDisbursementDate
*Foreign Rate
*USD
global r_f=${USDInterestRate}/100
*Domestic Rate
*FX
global r_d=${FXInterestRate}/100
*Option Window - window above and below the futures curve to set the strike price
global option_window=0.05
*Current Time
global t=0
*The length of the data to calculate the volatility and standard deviation
*!!!Not dynamic - see below get sigma interval rangestat
global vol_window=365+1

*Get H (Hurst Parameter) Daily 5Y H(365)
global H=${HurstParameter}

*Set Pricing Date
*global PricingDate = td("22oct2019")

* Get sigma(volatility of currency price), 1 USD to X FX currency
clear 
import excel using "$path1\Inputs\Currency Prices.xlsx", firstrow
rename *CurncyPrice CurrencyPrice
gen double pct_change=(CurrencyPrice-CurrencyPrice[_n-1])/CurrencyPrice[_n-1]
gen count=_n
rangestat (sd) pct_change, interval(count -365, 0)
gen double sigmas=pct_change_sd*(252^0.5)
levelsof sigmas if(_n==${vol_window}), local(sigma)
di "`sigma'"
global sigma = `sigma'

* Get T(Maturity in years) and K(Spot Price at Maturity) and s_t(current price of currency (at time t) - i.e. future price at first disbursement
* 1 USD to X FX currency
clear
*import excel using "$path\Forward Curves.xlsx", firstrow
*rename Dates Date
use "$Output_Path\FX Inputs.dta"
replace FX_Forward = round(1/FX_Forward, 4)
rename FX_Forward Average
*gen Dates=date(Date,"MDY")
format Repayment_Date %td


levelsof Average if(Repayment_Date==$Start_Date), local(s_t)
di "`s_t'"
global s_t=`s_t'

gen int Days = Repayment_Date - $PricingDate
gen double Years=Days/365
format Years %20.16fc
levelsof Days if(Repayment_Date == $Maturity), local(T)
di "`T'"
global T = `T'

levelsof Average if(Repayment_Date == $Maturity), local(K)
di "`K'"
global K = `K'

*Calculate Discount Factor
gen double Discount_Factor=(1+${r_d}-${r_f})^Years
	*Discount Start Date Price
	levelsof Discount_Factor if(Repayment_Date==$Start_Date), local(d_f)
	di "`d_f'"
	global d_f=`d_f'
	global s_t=`s_t'*`d_f'

* Calculate Calls and Puts
gen double param = ${sigma}*(((Years^(2*${H})) - (${t}^(2*${H})))^0.5)
format param %20.16fc

gen double d_1_call = (log(${s_t}/(Average*(1+${option_window})))+ (${r_d} - ${r_f})*(Years-${t}) + (param^2)/2) / param
format d_1_call %20.16fc

gen double d_1_put = (log(${s_t}/(Average*(1-${option_window}))) + (${r_d} - ${r_f})*(Years-${t}) + (param^2)/2) / param
format d_1_put %20.16fc

gen double d_2_call = d_1_call - param
format d_2_call %20.16fc

gen double d_2_put = d_1_put - param
format d_2_put %20.16fc

*Calculate Call and Put Prices
gen double call_price = (${s_t}*(exp(-${r_f}*(Years-${t})))*normal(d_1_call)) - (Average*(1 + ${option_window})*exp(-${r_d}*(Years-${t}))*normal(d_2_call))
format call_price %20.16fc

gen double put_price = (Average*(1 - ${option_window})*exp(-${r_d}*(Years-${t}))*normal(-d_2_put)) - (${s_t}*exp(-${r_f}*(Years-${t}))*normal(-d_1_put))
format put_price %20.16fc

gen Time=Years
gen Spot= $s_t
gen Start_Date=$Start_Date
format Start_Date %td
gen Strike=Average
gen Call_Option_Price=call_price
gen Put_Option_Price=put_price

order Years Repayment_Date Start_Date Spot Strike Discount_Factor Time  Call_Option Put_Option
keep Years Repayment_Date Start_Date Spot Strike Discount_Factor Time  Call_Option Put_Option
foreach var of varlist Years Spot Strike Discount_Factor Time  Call_Option Put_Option {
format `var' % 10.2fc
}

*export excel using "$path\Prices_Avg.xlsx", firstrow(var) replace
save "$Output_Path\Prices_Avg.dta", replace

use "$Output_Path\Life Table Step 4 USD.dta"

keep Repayment_Date Total_WAL Principal Disbursement_Number

duplicates tag Repayment_Date, generate(repeat)
drop if repeat == 1 & Disbursement_Number == 0
merge m:1 Repayment_Date using "$Output_Path\Prices_Avg.dta"

gen Call_Option_Price_USD = Call_Option_Price*1.11 /*both*/
gen Put_Option_Price_USD = Put_Option_Price*1.11 /*update*/
*gen Avg_Option_Price_USD = (Call_Option_Price_USD + Put_Option_Price_USD)/2 /*update*/
gen diff_WAL = abs(Total_WAL - Years) /*both*/
keep Call_Option_Price_USD Put_Option_Price_USD diff_WAL Discount_Factor Principal /*orig*/
*keep Avg_Option_Price_USD diff_WAL Discount_Factor Principal /*update*/
sort diff_WAL /*orig*/
collapse (first) diff_WAL Call_Option_Price_USD Put_Option_Price_USD Discount_Factor (sum)Principal /*orig*/
gen Call_Premium = Call_Option_Price_USD * Discount_Factor * Principal /*orig*/
gen Put_Premium = Put_Option_Price_USD * Discount_Factor * Principal
gen Premium = Call_Premium 
*- Put_Premium
*dis Put_Premium
*dis Call_Premium
*dis Premium
*bob
*collapse (first) diff_WAL Avg_Option_Price_USD Discount_Factor (sum)Principal /*update*/
*gen Premium = Avg_Option_Price_USD * Discount_Factor * Principal /*update*/
keep Premium /*both*/

export excel using "$Output_Path\FX Premium.xls", firstrow(variables)

exit, STATA clear
