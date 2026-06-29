MODEL (
  name web_analytics_silver.SALES,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Silver layer sales transaction fact table with revenue, quantities, and invoice details',
  tags ('silver', 'transformed', 'cleaned', 'fact', 'sales'),
  terms ('sales'),
  
  -- ==================== COLUMN DESCRIPTIONS ====================
  column_descriptions (
    SITE_NAME = 'Site Name - site/location field',
    SITE_REGION = 'Site Region - site/location field'
  ),
  
  -- ==================== COLUMN TAGS ====================
  column_tags (
    SITE_NAME = ('location', 'fact'),
    SITE_REGION = ('location', 'fact')
  )
);

-- Replicates (as closely as possible) the SQL logic in:
-- sgws-web-analytics-artifacts/redshidt-table-artifacts/wf-sales-efdp.yaml

WITH
  -- Coerce all ID-like columns at source so no alphanumeric ever reaches numeric context
  sales_dataos AS (
    SELECT
      coalesce(try_cast(sales_sk AS BIGINT), 0) AS sales_sk,
      coalesce(try_cast(site AS BIGINT), 1) AS site,
      coalesce(try_cast(customer_no AS BIGINT), 100000) AS customer_no,
      coalesce(try_cast(item_no AS BIGINT), 0) AS item_no,
      posting_dt_sk,
      coalesce(try_cast(invoice_no AS BIGINT), 0) AS invoice_no,
      invoice_dt_sk,
      qty_dec_equ,
      cases,
      bottles,
      ship_dt,
      coalesce(try_cast(posting_prd AS BIGINT), 0) AS posting_prd,
      entry_origin,
      coalesce(try_cast(sequence_no AS BIGINT), 0) AS sequence_no,
      unit_price,
      ext_net,
      ext_cost,
      ext_depl_allow,
      ext_participation,
      ext_guaranteed_adj,
      cqd_amt,
      coalesce(try_cast(current_salesperson_sk AS BIGINT), 0) AS current_salesperson_sk,
      coalesce(try_cast(salesman_no AS BIGINT), 0) AS salesman_no,
      coalesce(try_cast(salesperson_sk AS BIGINT), 0) AS salesperson_sk,
      coalesce(try_cast(customer_sk AS BIGINT), 0) AS customer_sk,
      coalesce(try_cast(order_no AS BIGINT), 0) AS order_no,
      load_dt,
      deal_id,
      modified_dt,
      coalesce(try_cast(warehouse_no AS BIGINT), 0) AS warehouse_no
    FROM web_analytics_bronze.V_FACT_SALES
  ),
  d_item_dataos AS (
    SELECT * FROM web_analytics_bronze.V_D_CURR_ITEM
  ),
  v_d_curr_corp_item AS (
    SELECT * FROM web_analytics_bronze.V_D_CURR_CORP_ITEM
  ),
  d_site AS (
    SELECT
      site,
      site_state AS site_state,
      appl_display_name AS site_name,
      site_geo_region_short_name AS site_region,
      source_system
    FROM web_analytics_bronze.V_D_SITE
  ),

  final_0 AS (
    SELECT /*+ REPARTITION(1) */ s.*,
      division_cd AS item_division_code,
      ci.pim_9l_case_conversion,
      (ci.pim_9l_case_conversion * qty_dec_equ) AS equivalent_9l
    FROM (
      SELECT
        *,
        row_number() OVER (PARTITION BY site, customer_no, item_no ORDER BY posting_date) AS occurrence,
        lead(coalesce(try_to_date(to_varchar(posting_dt_sk), 'YYYY-MM-DD'), try_to_date(cast(posting_dt_sk AS STRING), 'YYYYMMDD'))) OVER (PARTITION BY site, customer_no, item_no ORDER BY posting_date) AS next_occurrence_dt,
        CASE
          WHEN count(CASE WHEN source = 'Proof' THEN invoice_no ELSE NULL END) OVER (PARTITION BY site, customer_no, item_no, posting_period) > 0
            AND count(CASE WHEN source = 'Non-proof' THEN invoice_no ELSE NULL END) OVER (PARTITION BY site, customer_no, item_no, posting_period) = 0
            THEN 'Only Proof'
          WHEN count(CASE WHEN source = 'Proof' THEN invoice_no ELSE NULL END) OVER (PARTITION BY site, customer_no, item_no, posting_period) = 0
            AND count(CASE WHEN source = 'Non-proof' THEN invoice_no ELSE NULL END) OVER (PARTITION BY site, customer_no, item_no, posting_period) > 0
            THEN 'Only Non Proof'
          ELSE 'Common'
        END AS channel_flag,
        quarter(posting_date) AS posting_date_quarter,
        current_timestamp() AS last_modified_dt
      FROM (
        SELECT
          sales_sk,
          site AS site,
          concat(cast(site AS STRING), '-', cast(coalesce(try_cast(item_no AS BIGINT), 0) AS STRING)) AS site_item_pk_sales,
          concat(
            cast(site AS STRING), '-', cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS STRING), '-', cast(item_no AS STRING), '-',
            cast(invoice_no AS STRING), '-', cast(sequence_no AS STRING)
          ) AS sales_pk,
          concat(cast(site AS STRING), '-', cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS STRING)) AS customer_id,
          invoice_no,
          coalesce(try_to_timestamp(to_varchar(invoice_dt_sk), 'YYYY-MM-DD'), try_to_timestamp(cast(invoice_dt_sk AS STRING), 'YYYYMMDD')) AS invoice_date,
          year(coalesce(try_to_timestamp(to_varchar(invoice_dt_sk), 'YYYY-MM-DD'), try_to_timestamp(cast(invoice_dt_sk AS STRING), 'YYYYMMDD'))) AS invoice_date_year,
          cases,
          bottles,
          coalesce(try_cast(item_no AS BIGINT), 0) AS item_no,
          qty_dec_equ,
          ext_net,
          unit_price,
          ship_dt,
          posting_dt_sk,
          invoice_dt_sk,
          posting_prd,
          coalesce(try_cast(customer_no AS BIGINT), 100000) AS customer_no,
          try_to_timestamp(cast(posting_prd AS STRING), 'YYYYMM') AS posting_period,
          coalesce(try_to_timestamp(to_varchar(posting_dt_sk), 'YYYY-MM-DD'), try_to_timestamp(cast(posting_dt_sk AS STRING), 'YYYYMMDD')) AS posting_date,
          year(coalesce(try_to_timestamp(to_varchar(posting_dt_sk), 'YYYY-MM-DD'), try_to_timestamp(cast(posting_dt_sk AS STRING), 'YYYYMMDD'))) AS posting_date_year,
          trim(cast(entry_origin AS STRING)) AS entry_origin,
          CASE WHEN trim(cast(entry_origin AS STRING)) IN ('G', 'H', 'Q') THEN 'Proof' ELSE 'Non-proof' END AS source,
          ext_cost,
          (ext_net - ext_cost) AS gross_profit,
          date_trunc('MM', coalesce(try_to_timestamp(to_varchar(posting_dt_sk), 'YYYY-MM-DD'), try_to_timestamp(cast(posting_dt_sk AS STRING), 'YYYYMMDD'))) AS posting_date_month_year,
          current_salesperson_sk,
          coalesce(try_cast(salesman_no AS BIGINT), 0) AS salesperson_no,
          salesperson_sk,
          customer_sk,
          sequence_no,
          deal_id,
          cast(modified_dt AS STRING) AS modified_dt,
          warehouse_no,
          order_no,
          load_dt,
          concat(cast(site AS STRING), '-', cast(item_no AS STRING), '-', cast(warehouse_no AS STRING)) AS site_item_fk_sales,
          concat(cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS STRING), '-', cast(site AS STRING), '-', cast(item_no AS STRING), '-', cast(invoice_dt_sk AS STRING)) AS sales_last_purchase_fk,
          concat(cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS STRING), cast(site AS STRING), cast(coalesce(try_cast(salesman_no AS BIGINT), 0) AS STRING)) AS salesperson_fk,
          cast(coalesce(try_cast(concat(lpad(cast(site AS STRING), 4, '0'), lpad(cast(coalesce(try_cast(customer_no AS BIGINT), 100000) AS STRING), 10, '0')) AS BIGINT), 100000) AS VARCHAR) AS gcp_account_id,
          CASE
            WHEN entry_origin IN ('M', 'B') THEN 'SWO'
            WHEN entry_origin IN ('C', 'P', 'U', 'V', 'W') THEN 'Cust Serv'
            WHEN entry_origin IN ('S', 'I', 'R', 'T', 'F', 'X') THEN 'Sales Rep'
            WHEN entry_origin IN ('E', 'Y', 'D') THEN 'EDI'
            WHEN entry_origin = 'H' THEN 'Proof'
            WHEN entry_origin = 'G' THEN 'ASM'
            ELSE 'Other Entry Origins'
          END AS invoice_origin
        FROM sales_dataos
      )
    ) AS s
    LEFT JOIN d_item_dataos AS i
      ON cast(s.site AS VARCHAR) = cast(i.site AS VARCHAR) AND cast(s.item_no AS VARCHAR) = cast(i.item_no AS VARCHAR)
    LEFT JOIN v_d_curr_corp_item ci
      ON cast(i.corp_item_no AS VARCHAR) = cast(ci.corp_item_no AS VARCHAR)
  )

SELECT
  final_0.*,
  d_site.site_name,
  d_site.site_region
FROM final_0
LEFT JOIN d_site
  ON cast(final_0.site AS VARCHAR) = cast(d_site.site AS VARCHAR);

