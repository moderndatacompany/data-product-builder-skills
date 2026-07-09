MODEL (
  name web_analytics_silver.ORDERS,
  kind FULL,
  owner 'rohitrajtmdcio',
  grains [ORDER_PK],
  description 'Silver layer order transaction fact table with order status and fulfillment tracking',
  tags ('silver', 'transformed', 'cleaned', 'fact', 'orders'),
  terms ('orders')
);

-- Replicates (as closely as possible) the SQL logic in:
-- sgws-web-analytics-artifacts/redshidt-table-artifacts/wf-orders-efdp.yaml

WITH
  orders_dataos AS (
    SELECT * FROM web_analytics_bronze.V_F_ORDER
  )
SELECT /*+ REPARTITION(1) */
  order_sk AS order_pk,
  concat(cast(site_id AS STRING), '-', cast(item_no AS STRING)) AS site_item_pk_order,
  concat(cast(customer_no AS STRING), '-', cast(site_id AS STRING), '-', cast(item_no AS STRING), '-', to_varchar(coalesce(try_to_timestamp(to_varchar(order_entry_dt), 'YYYY-MM-DD'), try_to_timestamp(cast(order_entry_dt AS STRING), 'YYYYMMDD')), 'YYYYMMDD')) AS order_last_purchase_fk,
  concat(cast(site_id AS STRING), '-', cast(customer_no AS STRING)) AS order_account_id,
  order_no,
  item_no,
  cases_dec_equivalent AS qty_dec_equ,
  order_net_amt,
  invoice_no,
  warehouse_no,
  site_id AS site_number,
  order_entry_cd AS entry_origin,
  order_cases_qty AS cases,
  order_bottle_qty AS bottles,
  coalesce(
    try_to_timestamp(to_varchar(order_entry_dt), 'YYYY-MM-DD'),
    try_to_timestamp(cast(order_entry_dt AS STRING), 'YYYYMMDD')
  ) AS order_entry_dt,
  CASE WHEN order_entry_cd IN ('G', 'H', 'Q') THEN 'Proof' ELSE 'Non-proof' END AS source,
  order_external_id,
  invoice_line_no,
  order_line_no,
  invoice_dt,
  customer_no,
  order_status_cd,
  order_reject_cd,
  order_reject_dt,
  order_reject_time,
  order_reject_by,
  order_price_per_case,
  order_dsct_per_case,
  posting_period AS posting_prd,
  load_dt,
  cast(modified_dt AS STRING) AS modified_dt,
  try_to_timestamp(cast(posting_period AS STRING), 'YYYYMM') AS posting_period,
  current_timestamp() AS last_modified_dt
FROM orders_dataos
;

