REPORT z_purchase_analytics_top.

*---------------------------------------------------------------------*
* TABLES
*---------------------------------------------------------------------*
TABLES: ekko, ekpo, lfa1.

*---------------------------------------------------------------------*
* TYPES
*---------------------------------------------------------------------*
TYPES: BEGIN OF ty_data,
         ebeln TYPE ekko-ebeln,
         bedat TYPE ekko-bedat,
         lifnr TYPE ekko-lifnr,
         name1 TYPE lfa1-name1,
         matnr TYPE ekpo-matnr,
         menge TYPE ekpo-menge,
         netpr TYPE ekpo-netpr,
         total TYPE ekpo-netpr,
         color TYPE lvc_t_scol,   "for color
       END OF ty_data.

DATA: gt_data TYPE STANDARD TABLE OF ty_data,
      gs_data TYPE ty_data.

*---------------------------------------------------------------------*
* SELECTION SCREEN
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
SELECT-OPTIONS: s_date FOR ekko-bedat,
                s_lifnr FOR ekko-lifnr.
SELECTION-SCREEN END OF BLOCK b1.

INITIALIZATION.
  text-001 = 'Purchase Analytics Filters'.

*---------------------------------------------------------------------*
* START
*---------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM get_data.
  PERFORM process_data.
  PERFORM display_alv.

*---------------------------------------------------------------------*
* FETCH DATA
*---------------------------------------------------------------------*
FORM get_data.

  SELECT a~ebeln a~bedat a~lifnr
         b~matnr b~menge b~netpr
         c~name1
    INTO TABLE @DATA(lt_raw)
    FROM ekko AS a
    INNER JOIN ekpo AS b ON a~ebeln = b~ebeln
    INNER JOIN lfa1 AS c ON a~lifnr = c~lifnr
    WHERE a~bedat IN @s_date
      AND a~lifnr IN @s_lifnr.

ENDFORM.

*---------------------------------------------------------------------*
* PROCESS DATA
*---------------------------------------------------------------------*
FORM process_data.

  LOOP AT lt_raw INTO DATA(ls_raw).

    CLEAR gs_data.

    gs_data-ebeln = ls_raw-ebeln.
    gs_data-bedat = ls_raw-bedat.
    gs_data-lifnr = ls_raw-lifnr.
    gs_data-name1 = ls_raw-name1.
    gs_data-matnr = ls_raw-matnr.
    gs_data-menge = ls_raw-menge.
    gs_data-netpr = ls_raw-netpr.

    gs_data-total = ls_raw-menge * ls_raw-netpr.

*------------------ COLOR LOGIC ------------------*
    IF gs_data-total > 100000.
      DATA(ls_color) = VALUE lvc_s_scol(
          fname = 'TOTAL'
          color-col = 5   "Green
          color-int = 0
          color-inv = 0 ).
      APPEND ls_color TO gs_data-color.
    ENDIF.

    APPEND gs_data TO gt_data.

  ENDLOOP.

ENDFORM.

*---------------------------------------------------------------------*
* DISPLAY ALV
*---------------------------------------------------------------------*
FORM display_alv.

  DATA: lo_alv TYPE REF TO cl_salv_table,
        lo_cols TYPE REF TO cl_salv_columns_table,
        lo_col TYPE REF TO cl_salv_column.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = gt_data ).

*------------------------------------------------------------------*
* SETTINGS
*------------------------------------------------------------------*
      lo_cols = lo_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

*------------------------------------------------------------------*
* COLUMN TEXT
*------------------------------------------------------------------*
      lo_col ?= lo_cols->get_column( 'EBELN' ).
      lo_col->set_long_text( 'PO Number' ).
      lo_col->set_hotspot( abap_true ).

      lo_col ?= lo_cols->get_column( 'TOTAL' ).
      lo_col->set_long_text( 'Total Amount' ).

*------------------------------------------------------------------*
* SORT
*------------------------------------------------------------------*
      DATA(lo_sort) = lo_alv->get_sorts( ).
      lo_sort->add_sort(
        columnname = 'TOTAL'
        sequence   = if_salv_c_sort=>sort_down ).

*------------------------------------------------------------------*
* DISPLAY SETTINGS
*------------------------------------------------------------------*
      lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

*------------------------------------------------------------------*
* FUNCTIONS
*------------------------------------------------------------------*
      lo_alv->get_functions( )->set_all( abap_true ).

*------------------------------------------------------------------*
* EVENTS (HOTSPOT)
*------------------------------------------------------------------*
      DATA(lo_events) = lo_alv->get_event( ).

      CLASS lcl_handler DEFINITION.
        PUBLIC SECTION.
          METHODS: on_click FOR EVENT link_click OF cl_salv_events_table
            IMPORTING row column.
      ENDCLASS.

      CLASS lcl_handler IMPLEMENTATION.
        METHOD on_click.
          READ TABLE gt_data INTO DATA(ls_row) INDEX row.
          IF sy-subrc = 0.
            MESSAGE |PO Clicked: { ls_row-ebeln }| TYPE 'I'.
          ENDIF.
        ENDMETHOD.
      ENDCLASS.

      DATA(lo_handler) = NEW lcl_handler( ).
      SET HANDLER lo_handler->on_click FOR lo_events.

*------------------------------------------------------------------*
* DISPLAY
*------------------------------------------------------------------*
      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg TYPE 'E'.
  ENDTRY.

ENDFORM.