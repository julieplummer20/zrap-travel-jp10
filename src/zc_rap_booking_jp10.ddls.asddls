@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View forBooking'
@Search.searchable: true
define view entity ZC_RAP_BOOKING_JP10
  as projection on ZI_RAP_BOOKING_JP10
{
  key BookingUUID,
  
  TravelUUID,
  
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.90 
  BookingID,
  
  BookingDate,
  
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
  
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: '/DMO/I_Carrier', 
      element: 'AirlineID'
    }
  } ]

   @ObjectModel.text.element: ['CarrierName']
   CarrierID,
   _Carrier.Name      as CarrierName,
  
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: '/DMO/I_Flight', 
      element: 'ConnectionID'
    }, 
    additionalBinding: [ {
      localElement: 'FlightDate', 
      element: 'FlightDate'
    }, {
      localElement: 'CarrierID', 
      element: 'AirlineID'
    }, {
      localElement: 'FlightPrice', 
      element: 'Price'
    }, {
      localElement: 'CurrencyCode', 
      element: 'CurrencyCode'
    } ]
  } ]
  ConnectionID,
  
  FlightDate,
  
  @Semantics.amount.currencyCode: 'CurrencyCode'
  FlightPrice,
  
  @Consumption.valueHelpDefinition: [ {
    entity: {
      name: 'I_Currency', 
      element: 'Currency'
    }
  } ]
  CurrencyCode,
  
  CreatedBy,
  
  LastChangedBy,
  
  LocalLastChangedAt,
  
  _Travel : redirected to parent ZC_RAP_TRAVEL_JP10,
  
  _Connection,
  
  _Flight,
  
  _Carrier,
  
  _Currency,
  
  _Customer
}
