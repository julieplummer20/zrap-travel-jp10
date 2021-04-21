CLASS zcl_rap_gen_data_model_JP10 DEFINITION

PUBLIC
  INHERITING FROM cl_xco_cp_adt_simple_classrun
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor.

  PROTECTED SECTION.
    METHODS main REDEFINITION.

  PRIVATE SECTION.
    DATA package_name           TYPE sxco_package .
    DATA unique_group_id        TYPE string.
    DATA dev_system_environment TYPE REF TO if_xco_cp_gen_env_dev_system.
    DATA transport              TYPE sxco_transport .
    DATA table_name_root        TYPE sxco_dbt_object_name.
    DATA table_name_child       TYPE sxco_dbt_object_name.

    TYPES: BEGIN OF t_table_fields,
             field                  TYPE sxco_ad_field_name,
             is_key                 TYPE abap_bool,
             not_null               TYPE abap_bool,
             currencyCode           TYPE sxco_cds_field_name,
             unitOfMeasure          TYPE sxco_cds_field_name,
             data_element           TYPE sxco_ad_object_name,
             built_in_type          TYPE cl_xco_ad_built_in_type=>tv_type,
             built_in_type_length   TYPE cl_xco_ad_built_in_type=>tv_length,
             built_in_type_decimals TYPE cl_xco_ad_built_in_type=>tv_decimals,
           END OF t_table_fields.

    TYPES: tt_fields TYPE STANDARD TABLE OF t_table_fields WITH KEY field.

    METHODS generate_table  IMPORTING io_put_operation        TYPE REF TO if_xco_cp_gen_d_o_put
                                      table_fields            TYPE tt_fields
                                      table_name              TYPE sxco_dbt_object_name
                                      table_short_description TYPE if_xco_cp_gen_tabl_dbt_s_form=>tv_short_description.

    METHODS fill_tables_with_data.

    METHODS get_root_table_fields  RETURNING VALUE(root_table_fields) TYPE tt_fields.

    METHODS get_child_table_fields RETURNING VALUE(child_table_fields) TYPE tt_fields.

    METHODS get_json_string        RETURNING VALUE(json_string) TYPE string.

    METHODS generate_cds_mde         IMPORTING VALUE(io_rap_bo_node) TYPE REF TO /dmo/cl_rap_node.

ENDCLASS.


CLASS zcl_rap_gen_data_model_JP10 IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).

**********************************************************************
**  ACTION NEEDED                                                   **
**  Replace #### with your group ID which is used as suffix.        **
**   a combination of max 4 numbers and/or characters               **
**********************************************************************
    unique_group_id        = 'JP10'.   " your group-ID
    package_name           = |ZRAP_TRAVEL_{ unique_group_id }|.
    table_name_root        = |zrap_atrav_{ unique_group_id }|.
    table_name_child       = |zrap_abook_{ unique_group_id }|.
  ENDMETHOD.


  METHOD main.
    package_name    = to_upper( package_name ).
    unique_group_id = to_upper( unique_group_id ).

    out->write( | BEGIN OF GENERATION ({ cl_abap_context_info=>get_system_date(  ) } { cl_abap_context_info=>get_system_time(  ) } UTC) ... | ).
    out->write( | - Package: { package_name } | ).
    out->write( | - Group ID: { unique_group_id } | ).

    "create transport request
    DATA(lo_package) = xco_cp_abap_repository=>object->devc->for( package_name ).
    IF NOT lo_package->exists( ).
      RAISE EXCEPTION TYPE /dmo/cx_rap_generator
        EXPORTING
          textid   = /dmo/cx_rap_generator=>package_does_not_exist
          mv_value = CONV #( package_name ).
    ENDIF.

    DATA(lv_package_software_component) = lo_package->read( )-property-software_component->name.
    DATA(lo_transport_layer)   = lo_package->read(  )-property-transport_layer.
    DATA(lo_transport_target)  = lo_transport_layer->get_transport_target( ).
    DATA(lv_transport_target)  = lo_transport_target->value.
    DATA(lo_transport_request) = xco_cp_cts=>transports->workbench( lo_transport_target->value  )->create_request( | create tables |  ).
    DATA(lv_transport)         = lo_transport_request->value.
    transport                  = lv_transport.
    dev_system_environment     = xco_cp_generation=>environment->dev_system( lv_transport ).
    DATA(transport_request) = lv_transport.

    DATA(json_string)              = get_json_string(  ).

    " get json document
    DATA(root_table_fields)        = get_root_table_fields(  ).
    DATA(lo_objects_put_operation) = dev_system_environment->create_put_operation( ).

    "generate of travel table
    generate_table(
      EXPORTING
        io_put_operation        = lo_objects_put_operation
        table_fields            = root_table_fields
        table_name              = table_name_root
        table_short_description = 'Travel Table'
    ).

    IF table_name_child IS NOT INITIAL.
      DATA(child_table_fields)  = get_child_table_fields(  ).

      "generate of booking table
      generate_table(
        EXPORTING
          io_put_operation        = lo_objects_put_operation
          table_fields            = child_table_fields
          table_name              = table_name_child
          table_short_description = 'Booking Table'
      ).
    ENDIF.

    DATA(lo_result) = lo_objects_put_operation->execute( ).

    " handle findings
    DATA(lo_findings) = lo_result->findings.
    DATA(lt_findings) = lo_findings->get( ).
    IF lt_findings IS NOT INITIAL.
      out->write( lt_findings ).
    ENDIF.

    " fill the tables with sample data
    fill_tables_with_data( ).

    out->write( | - Tables generated and filled with sample data: { table_name_root } & { table_name_child } | ).

    "create RAP BO artefacts according to the JSON document

    DATA(rap_generator) = NEW /dmo/cl_rap_generator( json_string ).
    DATA(todos) = rap_generator->generate_bo(  ).
    DATA(rap_bo_name) = rap_generator->root_node->rap_root_node_objects-service_binding.
    out->write( |RAP BO { rap_bo_name }  generated successfully| ).
    out->write( |Todo's:| ).
    LOOP AT todos INTO DATA(todo).
      out->write( todo ).
    ENDLOOP.

    DATA(lv_my_transport)       = rap_generator->root_node->transport_request.

    " delete and recreate metadata extensions
    DATA: mo_environment   TYPE REF TO if_xco_cp_gen_env_dev_system,
          lv_del_transport TYPE sxco_transport.


    DATA(cts_obj) = xco_cp_abap_repository=>object->for(
    EXPORTING
    iv_type = 'DDLX'
    iv_name = to_upper( rap_generator->root_node->rap_node_objects-meta_data_extension )
    )->if_xco_cts_changeable~get_object( ).
    lv_del_transport = cts_obj->get_lock( )->get_transport( ).
    lv_del_transport = xco_cp_cts=>transport->for( lv_del_transport )->get_request( )->value.


    mo_environment = xco_cp_generation=>environment->dev_system( lv_del_transport ).
    DATA(lo_delete_operation) = mo_environment->for-ddlx->create_delete_operation( ).
    lo_delete_operation->add_object( rap_generator->root_node->rap_node_objects-meta_data_extension ).
    lo_delete_operation->execute( ).

    generate_cds_mde( rap_generator->root_node ).

    out->write( '...END OF GENERATION.' ).

  ENDMETHOD.

  METHOD generate_table.
    DATA(lo_specification) = io_put_operation->for-tabl-for-database_table->add_object( table_name
              )->set_package( package_name
               )->create_form_specification( ).

    lo_specification->set_short_description( table_short_description ).
    lo_specification->set_data_maintenance( xco_cp_database_table=>data_maintenance->allowed_with_restrictions ).
    lo_specification->set_delivery_class( xco_cp_database_table=>delivery_class->c ).

    DATA database_table_field  TYPE REF TO if_xco_gen_tabl_dbt_s_fo_field  .

    LOOP AT table_fields INTO DATA(table_field_line).
      database_table_field = lo_specification->add_field( table_field_line-field  ).

      IF table_field_line-is_key = abap_true.
        database_table_field->set_key_indicator( ).
      ENDIF.
      IF table_field_line-not_null = abap_true.
        database_table_field->set_not_null( ).
      ENDIF.
      IF table_field_line-currencycode IS NOT INITIAL.
        database_table_field->currency_quantity->set_reference_table( CONV #( to_upper( table_name ) ) )->set_reference_field( to_upper( table_field_line-currencycode ) ).
      ENDIF.
      IF table_field_line-unitofmeasure IS NOT INITIAL.
        database_table_field->currency_quantity->set_reference_table( CONV #( to_upper( table_name ) ) )->set_reference_field( to_upper( table_field_line-unitofmeasure ) ).
      ENDIF.
      IF table_field_line-data_element IS NOT INITIAL.
        database_table_field->set_type( xco_cp_abap_dictionary=>data_element( table_field_line-data_element ) ).
      ELSE.
        CASE  to_lower( table_field_line-built_in_type ).
          WHEN 'accp'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->accp ).
          WHEN 'clnt'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->clnt ).
          WHEN 'cuky'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->cuky ).
          WHEN 'dats'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->dats ).
          WHEN 'df16_raw'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->df16_raw ).
          WHEN 'df34_raw'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->df34_raw ).
          WHEN 'fltp'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->fltp ).
          WHEN 'int1'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->int1 ).
          WHEN 'int2'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->int2 ).
          WHEN 'int4'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->int4 ).
          WHEN 'int8'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->int8 ).
          WHEN 'lang'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->lang ).
          WHEN 'tims'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->tims ).
          WHEN 'char'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->char( table_field_line-built_in_type_length  ) ).
          WHEN 'curr'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->curr(
                                              iv_length   = table_field_line-built_in_type_length
                                              iv_decimals = table_field_line-built_in_type_decimals
                                            ) ).
          WHEN 'dec'  .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->dec(
                                              iv_length   = table_field_line-built_in_type_length
                                              iv_decimals = table_field_line-built_in_type_decimals
                                            ) ).
          WHEN 'df16_dec'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->df16_dec(
                                              iv_length   = table_field_line-built_in_type_length
                                              iv_decimals = table_field_line-built_in_type_decimals
                                            ) ).
          WHEN 'df34_dec'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->df34_dec(
                                              iv_length   = table_field_line-built_in_type_length
                                              iv_decimals = table_field_line-built_in_type_decimals
                                            ) ).
          WHEN 'lchr' .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->lchr( table_field_line-built_in_type_length  ) ).
          WHEN 'lraw'  .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->lraw( table_field_line-built_in_type_length  ) ).
          WHEN 'numc'   .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->numc( table_field_line-built_in_type_length  ) ).
          WHEN 'quan' .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->quan(
                                              iv_length   = table_field_line-built_in_type_length
                                              iv_decimals = table_field_line-built_in_type_decimals
                                              ) ).
          WHEN 'raw'  .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->raw( table_field_line-built_in_type_length  ) ).
          WHEN 'rawstring'.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->rawstring( table_field_line-built_in_type_length  ) ).
          WHEN 'sstring' .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->sstring( table_field_line-built_in_type_length  ) ).
          WHEN 'string' .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->string( table_field_line-built_in_type_length  ) ).
          WHEN 'unit'  .
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->unit( table_field_line-built_in_type_length  ) ).
          WHEN OTHERS.
            database_table_field->set_type( xco_cp_abap_dictionary=>built_in_type->for(
                                              iv_type     = to_upper( table_field_line-built_in_type )
                                              iv_length   = table_field_line-built_in_type_length
                                              iv_decimals = table_field_line-built_in_type_decimals
                                            ) ).
        ENDCASE.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_json_string.
    " build the json document for DEV260 (ex1-ex4)
    DATA(transport_request) = ''.

    json_string ='{' && |\r\n|  &&
                 '  "implementationType": "managed_uuid",' && |\r\n|  &&
                 '  "transactionalbehavior" : false,' && |\r\n|  &&
                 '  "publishservice" : false ,' && |\r\n|  &&
                 '  "namespace": "Z",' && |\r\n|  &&
                 |  "transportrequest": "{ transport_request }",| && |\r\n|  &&
                 |  "suffix": "_{ unique_group_id }",| && |\r\n|  &&
                 '  "prefix": "RAP_",' && |\r\n|  &&
                 |  "package": "{ package_name }",| && |\r\n|  &&
                 '  "datasourcetype": "table",' && |\r\n|  &&
                 '  "bindingtype": "odata_v4_ui",' && |\r\n|  &&
                 '  "hierarchy": {' && |\r\n|  &&
                 '    "entityName": "Travel",' && |\r\n|  &&
                 |    "dataSource": "{ table_name_root }",| && |\r\n|  &&
                 '    "objectId": "travel_id",' && |\r\n|  &&
                 '    "uuid": "travel_uuid",' && |\r\n|  &&

*                 " field mapping
                 '"mapping": [' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "dbtable_field": "overall_status",' && |\r\n|  &&
                 '        "cds_view_field": "TravelStatus"' && |\r\n|  &&
                 '      }' && |\r\n|  &&
                 '    ],' && |\r\n|  &&

                 " value help definitions
                 '    "valueHelps": [' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "alias": "Agency",' && |\r\n|  &&
                 '        "name": "/DMO/I_Agency",' && |\r\n|  &&
                 '        "localElement": "AgencyID",' && |\r\n|  &&
                 '        "element": "AgencyID"' && |\r\n|  &&
                 '      },' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "alias": "Customer",' && |\r\n|  &&
                 '        "name": "/DMO/I_Customer",' && |\r\n|  &&
                 '        "localElement": "CustomerID",' && |\r\n|  &&
                 '        "element": "CustomerID"' && |\r\n|  &&
                 '      },' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "alias": "Currency",' && |\r\n|  &&
                 '        "name": "I_Currency",' && |\r\n|  &&
                 '        "localElement": "CurrencyCode",' && |\r\n|  &&
                 '        "element": "Currency"' && |\r\n|  &&
                 '      }' && |\r\n|  &&
                 '    ],' && |\r\n|  &&
                 '    "associations": [' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "name": "_Agency",' && |\r\n|  &&
                 '        "target": "/DMO/I_Agency",' && |\r\n|  &&
                 '        "cardinality": "zero_to_one",' && |\r\n|  &&
                 '        "conditions": [' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "projectionField": "AgencyID",' && |\r\n|  &&
                 '            "associationField": "AgencyID"' && |\r\n|  &&
                 '          }' && |\r\n|  &&
                 '        ]' && |\r\n|  &&
                 '      },' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "name": "_Currency",' && |\r\n|  &&
                 '        "target": "I_Currency",' && |\r\n|  &&
                 '        "cardinality": "zero_to_one",' && |\r\n|  &&
                 '        "conditions": [' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "projectionField": "CurrencyCode",' && |\r\n|  &&
                 '            "associationField": "Currency"' && |\r\n|  &&
                 '          }' && |\r\n|  &&
                 '        ]' && |\r\n|  &&
                 '      },' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "name": "_Customer",' && |\r\n|  &&
                 '        "target": "/DMO/I_Customer",' && |\r\n|  &&
                 '        "cardinality": "zero_to_one",' && |\r\n|  &&
                 '        "conditions": [' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "projectionField": "CustomerID",' && |\r\n|  &&
                 '            "associationField": "CustomerID"' && |\r\n|  &&
                 '          }' && |\r\n|  &&
                 '        ]' && |\r\n|  &&
                 '      }' && |\r\n|  &&
                 '    ],' && |\r\n|  &&

                 " children
                 '    "children": [' && |\r\n|  &&
                 '      {' && |\r\n|  &&
                 '        "entityName": "Booking",' && |\r\n|  &&
                 |        "dataSource": "{ table_name_child }",| && |\r\n|  &&
                 '        "objectId": "booking_id",' && |\r\n|  &&
                 '        "uuid": "booking_uuid",' && |\r\n|  &&
                 '        "parentUuid": "travel_uuid",' && |\r\n|  &&
                 '        "valueHelps": [' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "alias": "Flight",' && |\r\n|  &&
                 '            "name": "/DMO/I_Flight",' && |\r\n|  &&
                 '            "localElement": "ConnectionID",' && |\r\n|  &&
                 '            "element": "ConnectionID",' && |\r\n|  &&
                 '            "additionalBinding": [' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "localElement": "FlightDate",' && |\r\n|  &&
                 '                "element": "FlightDate"' && |\r\n|  &&
                 '              },' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "localElement": "CarrierID",' && |\r\n|  &&
                 '                "element": "AirlineID"' && |\r\n|  &&
                 '              },' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "localElement": "FlightPrice",' && |\r\n|  &&
                 '                "element": "Price"' && |\r\n|  &&
                 '              },' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "localElement": "CurrencyCode",' && |\r\n|  &&
                 '                "element": "CurrencyCode"' && |\r\n|  &&
                 '              }' && |\r\n|  &&
                 '            ]' && |\r\n|  &&
                 '          },' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "alias": "Currency",' && |\r\n|  &&
                 '            "name": "I_Currency",' && |\r\n|  &&
                 '            "localElement": "CurrencyCode",' && |\r\n|  &&
                 '            "element": "Currency"' && |\r\n|  &&
                 '          },' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "alias": "Airline",' && |\r\n|  &&
                 '            "name": "/DMO/I_Carrier",' && |\r\n|  &&
                 '            "localElement": "CarrierID",' && |\r\n|  &&
                 '            "element": "AirlineID"' && |\r\n|  &&
                 '          },' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "alias": "Customer",' && |\r\n|  &&
                 '            "name": "/DMO/I_Customer",' && |\r\n|  &&
                 '            "localElement": "CustomerID",' && |\r\n|  &&
                 '            "element": "CustomerID"' && |\r\n|  &&
                 '          }' && |\r\n|  &&
                 '        ],' && |\r\n|  &&
                 '        "associations": [' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "name": "_Connection",' && |\r\n|  &&
                 '            "target": "/DMO/I_Connection",' && |\r\n|  &&
                 '            "cardinality": "one_to_one",' && |\r\n|  &&
                 '            "conditions": [' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "CarrierID",' && |\r\n|  &&
                 '                "associationField": "AirlineID"' && |\r\n|  &&
                 '              },' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "ConnectionID",' && |\r\n|  &&
                 '                "associationField": "ConnectionID"' && |\r\n|  &&
                 '              }' && |\r\n|  &&
                 '            ]' && |\r\n|  &&
                 '          },' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "name": "_Flight",' && |\r\n|  &&
                 '            "target": "/DMO/I_Flight",' && |\r\n|  &&
                 '            "cardinality": "one_to_one",' && |\r\n|  &&
                 '            "conditions": [' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "CarrierID",' && |\r\n|  &&
                 '                "associationField": "AirlineID"' && |\r\n|  &&
                 '              },' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "ConnectionID",' && |\r\n|  &&
                 '                "associationField": "ConnectionID"' && |\r\n|  &&
                 '              },' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "FlightDate",' && |\r\n|  &&
                 '                "associationField": "FlightDate"' && |\r\n|  &&
                 '              }' && |\r\n|  &&
                 '            ]' && |\r\n|  &&
                 '          },' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "name": "_Carrier",' && |\r\n|  &&
                 '            "target": "/DMO/I_Carrier",' && |\r\n|  &&
                 '            "cardinality": "one_to_one",' && |\r\n|  &&
                 '            "conditions": [' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "CarrierID",' && |\r\n|  &&
                 '                "associationField": "AirlineID"' && |\r\n|  &&
                 '              }' && |\r\n|  &&
                 '            ]' && |\r\n|  &&
                 '          },' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "name": "_Currency",' && |\r\n|  &&
                 '            "target": "I_Currency",' && |\r\n|  &&
                 '            "cardinality": "zero_to_one",' && |\r\n|  &&
                 '            "conditions": [' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "CurrencyCode",' && |\r\n|  &&
                 '                "associationField": "Currency"' && |\r\n|  &&
                 '              }' && |\r\n|  &&
                 '            ]' && |\r\n|  &&
                 '          },' && |\r\n|  &&
                 '          {' && |\r\n|  &&
                 '            "name": "_Customer",' && |\r\n|  &&
                 '            "target": "/DMO/I_Customer",' && |\r\n|  &&
                 '            "cardinality": "one_to_one",' && |\r\n|  &&
                 '            "conditions": [' && |\r\n|  &&
                 '              {' && |\r\n|  &&
                 '                "projectionField": "CustomerID",' && |\r\n|  &&
                 '                "associationField": "CustomerID"' && |\r\n|  &&
                 '              }' && |\r\n|  &&
                 '            ]' && |\r\n|  &&
                 '          }' && |\r\n|  &&
                 '        ]' && |\r\n|  &&
                 '      }' && |\r\n|  &&
                 '    ]' && |\r\n|  &&
                 '  }' && |\r\n|  &&
                 '}'.
  ENDMETHOD.


  METHOD get_child_table_fields.
    child_table_fields = VALUE tt_fields(
                   ( field         = 'client'
                     data_element  = 'mandt'
                     is_key        = 'X'
                     not_null      = 'X' )
                   ( field         = 'booking_uuid'
                     data_element  = 'sysuuid_x16'
                     is_key        = 'X'
                     not_null      = 'X' )
                   ( field         = 'travel_uuid'
                     data_element  = 'sysuuid_x16'
                     not_null      = 'X' )
                   ( field         = 'booking_id'
                     data_element  = '/dmo/booking_id' )
                   ( field         = 'booking_date'
                     data_element  = '/dmo/booking_date' )
                   ( field         = 'customer_id'
                     data_element  = '/dmo/customer_id' )
                   ( field         = 'carrier_id'
                     data_element  = '/dmo/carrier_id' )
                   ( field         = 'connection_id'
                     data_element  = '/dmo/connection_id' )
                   ( field         = 'flight_date'
                     data_element  = '/dmo/flight_date' )
                   ( field         = 'flight_price'
                     data_element  = '/dmo/flight_price'
                     currencycode  = 'currency_code'  )
                   ( field         = 'currency_code'
                     data_element  = '/dmo/currency_code' )
                   ( field         = 'created_by'
                     data_element  = 'syuname' )
                   ( field         = 'last_changed_by'
                     data_element  = 'syuname' )
                   ( field         = 'local_last_changed_at '
                     data_element  = 'timestampl' )
                   ).
  ENDMETHOD.


  METHOD get_root_table_fields.
    root_table_fields = VALUE tt_fields(
                  ( field         = 'client'
                    data_element  = 'mandt'
                    is_key        = 'X'
                    not_null      = 'X' )
                  ( field         = 'travel_uuid'
                    data_element  = 'sysuuid_x16'
                    is_key        = 'X'
                    not_null      = 'X' )
                  ( field         = 'travel_id'
                    data_element  = '/dmo/travel_id' )
                  ( field         = 'agency_id'
                    data_element  = '/dmo/agency_id' )
                  ( field         = 'customer_id'
                    data_element  = '/dmo/customer_id' )
                  ( field         = 'begin_date'
                    data_element  = '/dmo/begin_date' )
                  ( field         = 'end_date'
                    data_element  = '/dmo/end_date' )
                  ( field         = 'booking_fee'
                    data_element  = '/dmo/booking_fee'
                    currencycode  = 'currency_code' )
                  ( field         = 'total_price'
                    data_element  = '/dmo/total_price'
                    currencycode  = 'currency_code' )
                  ( field         = 'currency_code'
                    data_element  = '/dmo/currency_code' )
                  ( field         = 'description'
                    data_element  = '/dmo/description' )
                  ( field         = 'overall_status'
                    data_element  = '/dmo/overall_status' )
                  ( field         = 'created_by'
                    data_element  = 'syuname' )
                  ( field         = 'created_at'
                    data_element  = 'timestampl' )
                  ( field         = 'last_changed_by'
                    data_element  = 'syuname' )
                  ( field         = 'last_changed_at'
                    data_element  = 'timestampl' )
                  ( field         = 'local_last_changed_at '
                    data_element  = 'timestampl' )
                    ).
  ENDMETHOD.


  METHOD fill_tables_with_data.
    " Fill tables with sample data from ABAP Flight Reference Scenario

    " insert travel demo data
    INSERT (table_name_root) FROM (
        SELECT
          FROM /dmo/travel
          FIELDS
            uuid(  )      AS travel_uuid           ,
            travel_id     AS travel_id             ,
            agency_id     AS agency_id             ,
            customer_id   AS customer_id           ,
            begin_date    AS begin_date            ,
            end_date      AS end_date              ,
            booking_fee   AS booking_fee           ,
            total_price   AS total_price           ,
            currency_code AS currency_code         ,
            description   AS description           ,
            CASE status
              WHEN 'B' THEN 'A'   " accepted
              WHEN 'X' THEN 'X'   " cancelled
              ELSE 'O'            " open
            END           AS overall_status        ,
            createdby     AS created_by            ,
            createdat     AS created_at            ,
            lastchangedby AS last_changed_by       ,
            lastchangedat AS last_changed_at       ,
            lastchangedat AS local_last_changed_at
            ORDER BY travel_id UP TO 200 ROWS
      ).
    COMMIT WORK.

    " define FROM clause dynamically
    DATA: dyn_table_name TYPE string.
    dyn_table_name = | /dmo/booking    AS booking  |
                 && | JOIN  { table_name_root } AS z |
                 && | ON   booking~travel_id = z~travel_id |.

    " insert booking demo data
    INSERT (table_name_child) FROM (
        SELECT
          FROM (dyn_table_name)
          FIELDS
            uuid( )                 AS booking_uuid          ,
            z~travel_uuid           AS travel_uuid           ,
            booking~booking_id      AS booking_id            ,
            booking~booking_date    AS booking_date          ,
            booking~customer_id     AS customer_id           ,
            booking~carrier_id      AS carrier_id            ,
            booking~connection_id   AS connection_id         ,
            booking~flight_date     AS flight_date           ,
            booking~flight_price    AS flight_price          ,
            booking~currency_code   AS currency_code         ,
            z~created_by            AS created_by            ,
            z~last_changed_by       AS last_changed_by       ,
            z~last_changed_at       AS local_last_changed_by
      ).
    COMMIT WORK.
  ENDMETHOD.

  METHOD generate_cds_mde.

    DATA: pos              TYPE i VALUE 0,
          lo_field         TYPE REF TO if_xco_gen_ddlx_s_fo_field,
          lv_del_transport TYPE sxco_transport.




    DATA(cts_obj) = xco_cp_abap_repository=>object->for(
    EXPORTING
    iv_type = 'DDLX'
    iv_name = to_upper( io_rap_bo_node->root_node->rap_node_objects-meta_data_extension )
    )->if_xco_cts_changeable~get_object( ).
    lv_del_transport = cts_obj->get_lock( )->get_transport( ).
    lv_del_transport = xco_cp_cts=>transport->for( lv_del_transport )->get_request( )->value.

    DATA(mo_environment)   = xco_cp_generation=>environment->dev_system( lv_del_transport ).
    DATA(mo_put_operation) = mo_environment->create_put_operation( ).
    DATA(lv_package)       = io_rap_bo_node->root_node->package.

    DATA(lo_specification) = mo_put_operation->for-ddlx->add_object(  io_rap_bo_node->rap_node_objects-meta_data_extension
      )->set_package( lv_package
      )->create_form_specification( ).

    lo_specification->set_short_description( |MDE for { io_rap_bo_node->rap_node_objects-alias }|
      )->set_layer( xco_cp_metadata_extension=>layer->customer
      )->set_view( io_rap_bo_node->rap_node_objects-cds_view_p ). " cds_view_p ).

    lo_specification->add_annotation( 'UI' )->value->build(
    )->begin_record(
        )->add_member( 'headerInfo'
         )->begin_record(
          )->add_member( 'typeName' )->add_string( io_rap_bo_node->rap_node_objects-alias && ''
          )->add_member( 'typeNamePlural' )->add_string( io_rap_bo_node->rap_node_objects-alias && 's'
          )->add_member( 'title'
            )->begin_record(
              )->add_member( 'type' )->add_enum( 'STANDARD'
              )->add_member( 'label' )->add_string( io_rap_bo_node->rap_node_objects-alias && ''
              )->add_member( 'value' )->add_string( io_rap_bo_node->object_id_cds_field_name && ''
        )->end_record(
        )->end_record(
      "presentationVariant: [ { sortOrder: [{ by: 'TravelID', direction:  #DESC }], visualizations: [{type: #AS_LINEITEM}] }] }
      )->add_member( 'presentationVariant'
        )->begin_array(
          )->begin_record(
          )->add_member( 'sortOrder'
            )->begin_array(
             )->begin_record(
               )->add_member( 'by' )->add_string( 'TravelID'
               )->add_member( 'direction' )->add_enum( 'DESC'
             )->end_record(
            )->end_array(
          )->add_member( 'visualizations'
          )->begin_array(
             )->begin_record(
               )->add_member( 'type' )->add_enum( 'AS_LINEITEM'
             )->end_record(
            )->end_array(
          )->end_record(
          )->end_array(
          )->end_record(  ).


    LOOP AT io_rap_bo_node->lt_fields INTO  DATA(ls_header_fields) WHERE name <> io_rap_bo_node->field_name-client.
      "increase position
      pos += 10.
      lo_field = lo_specification->add_field( ls_header_fields-cds_view_field ).

      "put facet annotation in front of the first
      IF pos = 10.
        IF io_rap_bo_node->is_root(  ) = abap_true.
          IF io_rap_bo_node->has_childs(  ).
            lo_field->add_annotation( 'UI.facet' )->value->build(
              )->begin_array(
                )->begin_record(
                  )->add_member( 'id' )->add_string( 'idCollection'
                  )->add_member( 'type' )->add_enum( 'COLLECTION'
                  )->add_member( 'label' )->add_string( io_rap_bo_node->rap_node_objects-alias && ''
                  )->add_member( 'position' )->add_number( 10
                )->end_record(
                )->begin_record(
                  )->add_member( 'id' )->add_string( 'idIdentification'
                  )->add_member( 'parentId' )->add_string( 'idCollection'
                  )->add_member( 'type' )->add_enum( 'IDENTIFICATION_REFERENCE'
                  )->add_member( 'label' )->add_string( 'General Information'
                  )->add_member( 'position' )->add_number( 10
                )->end_record(
                )->begin_record(
                  )->add_member( 'id' )->add_string( 'idLineitem'
                  )->add_member( 'type' )->add_enum( 'LINEITEM_REFERENCE'
                  )->add_member( 'label' )->add_string( io_rap_bo_node->childnodes[ 1 ]->rap_node_objects-alias && ''
                  )->add_member( 'position' )->add_number( 20
                  )->add_member( 'targetElement' )->add_string( '_' && io_rap_bo_node->childnodes[ 1 ]->rap_node_objects-alias
                )->end_record(
              )->end_array( ).
          ELSE.
            lo_field->add_annotation( 'UI.facet' )->value->build(
              )->begin_array(
                )->begin_record(
                  )->add_member( 'id' )->add_string( 'idCollection'
                  )->add_member( 'type' )->add_enum( 'COLLECTION'
                  )->add_member( 'label' )->add_string( io_rap_bo_node->rap_node_objects-alias && ''
                  )->add_member( 'position' )->add_number( 10
                )->end_record(
                )->begin_record(
                  )->add_member( 'id' )->add_string( 'idIdentification'
                  )->add_member( 'parentId' )->add_string( 'idCollection'
                  )->add_member( 'type' )->add_enum( 'IDENTIFICATION_REFERENCE'
                  )->add_member( 'label' )->add_string( 'General Information'
                  )->add_member( 'position' )->add_number( 10
                )->end_record(
              )->end_array( ).
          ENDIF.
        ELSE.
          IF io_rap_bo_node->has_childs(  ).
            lo_field->add_annotation( 'UI.facet' )->value->build(
              )->begin_array(
                )->begin_record(
                  )->add_member( 'id' )->add_string( CONV #( 'id' && io_rap_bo_node->rap_node_objects-alias )
                  )->add_member( 'purpose' )->add_enum( 'STANDARD'
                  )->add_member( 'type' )->add_enum( 'IDENTIFICATION_REFERENCE'
                  )->add_member( 'label' )->add_string( CONV #( io_rap_bo_node->rap_node_objects-alias )
                  )->add_member( 'position' )->add_number( 10
                )->end_record(
                )->begin_record(
                    )->add_member( 'id' )->add_string( 'idLineitem'
                    )->add_member( 'type' )->add_enum( 'LINEITEM_REFERENCE'
                    )->add_member( 'label' )->add_string( io_rap_bo_node->childnodes[ 1 ]->rap_node_objects-alias && ''
                    )->add_member( 'position' )->add_number( 20
                    )->add_member( 'targetElement' )->add_string( '_' && io_rap_bo_node->childnodes[ 1 ]->rap_node_objects-alias
                  )->end_record(
              )->end_array( ).
          ELSE.
            lo_field->add_annotation( 'UI.facet' )->value->build(
              )->begin_array(
                )->begin_record(
                  )->add_member( 'id' )->add_string( CONV #( 'id' && io_rap_bo_node->rap_node_objects-alias )
                  )->add_member( 'purpose' )->add_enum( 'STANDARD'
                  )->add_member( 'type' )->add_enum( 'IDENTIFICATION_REFERENCE'
                  )->add_member( 'label' )->add_string( CONV #( io_rap_bo_node->rap_node_objects-alias )
                  )->add_member( 'position' )->add_number( 10
                )->end_record(
              )->end_array( ).
          ENDIF.
        ENDIF.
      ENDIF.

      CASE to_upper( ls_header_fields-name ).
        WHEN io_rap_bo_node->field_name-uuid.
          "hide technical key field (uuid)
          lo_field->add_annotation( 'UI.hidden' )->value->build(  )->add_boolean( iv_value =  abap_true ).

        WHEN io_rap_bo_node->field_name-last_changed_at OR io_rap_bo_node->field_name-last_changed_by OR
             io_rap_bo_node->field_name-created_at OR io_rap_bo_node->field_name-created_by OR
             io_rap_bo_node->field_name-local_instance_last_changed_at OR
             io_rap_bo_node->field_name-parent_uuid OR io_rap_bo_node->field_name-root_uuid.
          "hide administrative fields and guid-based fields
          lo_field->add_annotation( 'UI.hidden' )->value->build(  )->add_boolean( iv_value =  abap_true ).

        WHEN OTHERS.
          "display field
          DATA(lo_valuebuilder) = lo_field->add_annotation( 'UI.lineItem' )->value->build( ).
          DATA(lo_record) = lo_valuebuilder->begin_array(
          )->begin_record(
              )->add_member( 'position' )->add_number( pos
              )->add_member( 'importance' )->add_enum( 'HIGH').

          "label for fields based on a built-in type
          IF ls_header_fields-is_data_element = abap_false.
            lo_record->add_member( 'label' )->add_string( CONV #( ls_header_fields-cds_view_field ) ).
          ENDIF.
          lo_valuebuilder->end_record( )->end_array( ).

          lo_valuebuilder = lo_field->add_annotation( 'UI.identification' )->value->build( ).
          lo_record = lo_valuebuilder->begin_array(
          )->begin_record(
              )->add_member( 'position' )->add_number( pos ).
          IF ls_header_fields-is_data_element = abap_false.
            lo_record->add_member( 'label' )->add_string( CONV #( ls_header_fields-cds_view_field ) ).
          ENDIF.
          lo_valuebuilder->end_record( )->end_array( ).

          "selection fields
          IF
             ls_header_fields-name = 'CUSTOMER_ID' OR
             ls_header_fields-name = 'AGENCY_ID' .

            lo_field->add_annotation( 'UI.selectionField' )->value->build(
            )->begin_array(
            )->begin_record(
                )->add_member( 'position' )->add_number( pos
              )->end_record(
            )->end_array( ).
          ENDIF.
          IF io_rap_bo_node->is_root(  ) = abap_true AND
             io_rap_bo_node->get_implementation_type( ) = io_rap_bo_node->implementation_type-managed_uuid  AND
             ls_header_fields-name = io_rap_bo_node->object_id.

            lo_field->add_annotation( 'UI.selectionField' )->value->build(
            )->begin_array(
            )->begin_record(
                )->add_member( 'position' )->add_number( pos
              )->end_record(
            )->end_array( ).
          ENDIF.
      ENDCASE.
    ENDLOOP.

    mo_put_operation->execute(  ).

  ENDMETHOD.


ENDCLASS.
