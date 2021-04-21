@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'CDS View forTravel'
define root view entity ZI_RAP_TRAVEL_JP10
  as select from ZRAP_ATRAV_JP10
  association [0..1] to /DMO/I_Agency as _Agency on $projection.AgencyID = _Agency.AgencyID
  association [0..1] to I_Currency as _Currency on $projection.CurrencyCode = _Currency.Currency
  association [0..1] to /DMO/I_Customer as _Customer on $projection.CustomerID = _Customer.CustomerID
  composition [0..*] of ZI_RAP_Booking_JP10 as _Booking
{
  key TRAVEL_UUID as TravelUUID,
  
  TRAVEL_ID as TravelID,
  
  AGENCY_ID as AgencyID,
  
  CUSTOMER_ID as CustomerID,
  
  BEGIN_DATE as BeginDate,
  
  END_DATE as EndDate,
  
  @Semantics.amount.currencyCode: 'CurrencyCode'
  BOOKING_FEE as BookingFee,
  
  @Semantics.amount.currencyCode: 'CurrencyCode'
  TOTAL_PRICE as TotalPrice,
  
  CURRENCY_CODE as CurrencyCode,
  
  DESCRIPTION as Description,
  
  OVERALL_STATUS as TravelStatus,
  
  @Semantics.user.createdBy: true
  CREATED_BY as CreatedBy,
  
  @Semantics.systemDateTime.createdAt: true
  CREATED_AT as CreatedAt,
  
  @Semantics.user.lastChangedBy: true
  LAST_CHANGED_BY as LastChangedBy,
  
  @Semantics.systemDateTime.lastChangedAt: true
  LAST_CHANGED_AT as LastChangedAt,
  
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LOCAL_LAST_CHANGED_AT as LocalLastChangedAt,
  
  _Booking,
  
  _Agency,
  
  _Currency,
  
  _Customer
}
