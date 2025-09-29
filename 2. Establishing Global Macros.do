/*##################################################################################    
*  U.S. International Development Finance Corporation 							   *
*  Obligation/Budget Formulation Model    										   *
*  Prepared by Summit Consulting, LLC                                              *
*                                                                                  *
*  This .do file Establishes Global Macros from the terms of the program           *
*  Updated: 10-1-2012                                                              *
*#################################################################################*/
clear all
set more off
version 12.1
***************************************
use "$Output_Path\Terms.dta"

global firstDisbDate = FirstDisbursementDate[1]

local varlist  Name AlternativeNameAlias Description ProjectID Country ProjectLocationProvinceCity BorrowerDUNSNumber ///
      BorrowerLegalName NAICSIndustryCodeofProject DevelopmentScore Tagsseparatebysemicolons EquityCash EquityNonCash ///
	  DFCLoan OtherCoLenders AnticipatedAppreciationCoverR TotalProjectCost Office LoanOfficer Lawyer GuaranteedLender GuarantorsSponsors ///
	  GuarantorsDUNSNumbers ProductLine ProductLine2 ObligationDate DirectGuaranteed LoanorTotalGuaranteedAmount ///
	  GuaranteedPercent ForeignCurrencyAppreciationCo InterestType GuaranteedInterestSpread AllInSingleRate ///
	  BaseinterestWeightedAverage PreCompletion PostCompletion CommitmentFee UpfrontFee OtherSubsidyFees FeeSharing FeeSharingAmount AnnualFlatUtilizationFee ///
	  NumberofDisbursementPeriods FirstDisbursementDate DisbursementSchedule PaymentFrequency PrincipalPaymentStructure AverageSubloanMaturity DateofFirstInterestPayment ///
	  Interestbeginsattopofperiod CompletionPoint Principalbeginsendofperiod ofPaymentspostGrace DateofFirstPrincipalPayment ///
	  DateofFinalRepayment FirstLossAmount FundedDSRAorLCsecurity DefaultRiskonFees PrepaymentRiskonFees DefaultMethodology DefaultPaymentType DefaultRate ///
	  RecoveryRate Risk_Path PDRate DFCRiskRating LGDRate ICRAS_Path ICRASRiskRating IRFactor DFCLoanCurrency FXSpotRateFXCurrencyUSD ///
	  DFCLoanMaxUSDExposureCap FeeSharingRiskRating HurstParameter USDInterestRate FXInterestRate PricingDate MaintenanceFee FacilityFee RunType PreviousFinancingSubsidy

*Ensures this variable is numeric for loop in do file "6. Life Table Creation"
destring PreviousFinancingSubsidy, replace

foreach lname of local varlist {
	global `lname' = `lname'[1]
	}
	
global DateofFirstPayment = $DateofFirstInterestPayment

global Cohortyear = year($ObligationDate)

global GiftAuthority = $FacilityFee

if month(${ObligationDate}) > 9{
   global Cohortyear = 1 + $Cohortyear 
   }
   
if "${DFCLoanCurrency}" == "Not Available" {
	global DFCLoanCurrency = "USD"
}

if "${FeeSharing}" == "Yes" {
	global FeeSharingPercent = FeeSharingAmount/LoanorTotalGuaranteedAmount
}

save "$Output_Path\Terms.dta", replace
