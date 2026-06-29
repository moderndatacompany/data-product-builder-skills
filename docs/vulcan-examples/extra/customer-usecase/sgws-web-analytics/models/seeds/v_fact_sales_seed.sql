MODEL (
  name web_analytics_seeds.V_FACT_SALES,
  kind SEED (
    path '../../seeds/v_fact_sales.csv'
  ),
  owner 'rohitrajtmdcio',
  description 'Historical sales transaction seed data for testing and development',
  tags ('seed', 'reference_data', 'transactional', 'testing'),
  terms ('v_fact_sales'),
  -- ID columns as VARCHAR so alphanumeric values (e.g. 1ST7MW) load without error; silver coerces to numeric
  columns (
        sales_sk VARCHAR,
        site VARCHAR,
        customer_no VARCHAR,
        item_no VARCHAR,
        posting_dt_sk DATE,
        invoice_no VARCHAR,
        invoice_dt_sk DATE,
        qty_dec_equ DECIMAL(15, 3),
        cases BIGINT,
        bottles BIGINT,
        ship_dt VARCHAR,
        posting_prd VARCHAR,
        entry_origin VARCHAR,
        sequence_no VARCHAR,
        unit_price DECIMAL(18, 2),
        ext_net DECIMAL(18, 2),
        ext_cost DECIMAL(18, 2),
        ext_depl_allow DECIMAL(18, 4),
        ext_participation DECIMAL(18, 4),
        ext_guaranteed_adj DECIMAL(18, 4),
        cqd_amt DECIMAL(18, 2),
        current_salesperson_sk VARCHAR,
        salesman_no VARCHAR,
        salesperson_sk VARCHAR,
        customer_sk VARCHAR,
        order_no VARCHAR,
        load_dt VARCHAR,
        deal_id VARCHAR,
        modified_dt VARCHAR,
        warehouse_no VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: V_FACT_SALES
-- ============================================================================

SELECT
  sales_sk,
  site,
  customer_no,
  item_no,
  posting_dt_sk,
  invoice_no,
  invoice_dt_sk,
  qty_dec_equ,
  cases,
  bottles,
  ship_dt,
  posting_prd,
  entry_origin,
  sequence_no,
  unit_price,
  ext_net,
  ext_cost,
  ext_depl_allow,
  ext_participation,
  ext_guaranteed_adj,
  cqd_amt,
  current_salesperson_sk,
  salesman_no,
  salesperson_sk,
  customer_sk,
  order_no,
  load_dt,
  deal_id,
  modified_dt,
  warehouse_no
FROM SEED();
