MODEL (
  name web_analytics_bronze.V_FACT_SALES,
  kind FULL,
  owner 'rohitrajtmdcio',
  description 'Bronze layer sales transaction fact table with revenue, quantities, and invoice details',
  tags ('bronze', 'raw', 'redshift', 'ingestion', 'fact', 'sales'),
  terms ('sales')
);

-- Explicit VARCHAR for all ID columns so alphanumeric values (e.g. 1ST7MW) are stored as-is; silver coerces to numeric
SELECT
  cast(sales_sk AS VARCHAR) AS sales_sk,
  cast(site AS VARCHAR) AS site,
  cast(customer_no AS VARCHAR) AS customer_no,
  cast(item_no AS VARCHAR) AS item_no,
  posting_dt_sk,
  cast(invoice_no AS VARCHAR) AS invoice_no,
  invoice_dt_sk,
  qty_dec_equ,
  cases,
  bottles,
  ship_dt,
  cast(posting_prd AS VARCHAR) AS posting_prd,
  entry_origin,
  cast(sequence_no AS VARCHAR) AS sequence_no,
  unit_price,
  ext_net,
  ext_cost,
  ext_depl_allow,
  ext_participation,
  ext_guaranteed_adj,
  cqd_amt,
  cast(current_salesperson_sk AS VARCHAR) AS current_salesperson_sk,
  cast(salesman_no AS VARCHAR) AS salesman_no,
  cast(salesperson_sk AS VARCHAR) AS salesperson_sk,
  cast(customer_sk AS VARCHAR) AS customer_sk,
  cast(order_no AS VARCHAR) AS order_no,
  load_dt,
  deal_id,
  modified_dt,
  cast(warehouse_no AS VARCHAR) AS warehouse_no
FROM web_analytics_seeds.V_FACT_SALES;
