@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View forTravel'
@Search.searchable: true
define root view entity ZC_RAP_TRAVEL_JP10
  as projection on ZI_RAP_TRAVEL_JP10
{
  key TravelUUID,
  
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.90 
  TravelID,
  
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: '/DMO/I_Agency', 
      element: 'AgencyID'
    }
  } ]
  @ObjectModel.text.element: ['AgencyName']
  @Search.defaultSearchElement: true
  AgencyID,
  _Agency.Name       as AgencyName,
  
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: '/DMO/I_Customer', 
      element: 'CustomerID'
    }
  } ]

  @ObjectModel.text.element: ['CustomerName']
  @Search.defaultSearchElement: true
  CustomerID,
  _Customer.LastName as CustomerName,
  
  BeginDate,
  
  EndDate,
  
  @Semantics.amount.currencyCode: 'CurrencyCode'
  BookingFee,
  
  @Semantics.amount.currencyCode: 'CurrencyCode'
  TotalPrice,
  
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: 'I_Currency', 
      element: 'Currency'
    }
  } ]
  CurrencyCode,
  
  Description,
  
  TravelStatus,
  
  CreatedBy,
  
  CreatedAt,
  
  LastChangedBy,
  
  LastChangedAt,
  
  LocalLastChangedAt,
  
  _Booking : redirected to composition child ZC_RAP_BOOKING_JP10,
  
  _Agency,
  
  _Currency,
  
  _Customer
}
