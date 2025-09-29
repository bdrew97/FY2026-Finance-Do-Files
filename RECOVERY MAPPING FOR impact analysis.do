**Recovery For Impact Analysis*
clear all
set more off
version 12.1
****************************

import excel "$path1\Inputs\Master Recovery Map.xls", sheet("Sheet1") firstrow

keep if Rating=="$DFCRiskRating" & Type=="$LoanType"

assert _N==1

global old_recovery=Recovery_Rate[1]
