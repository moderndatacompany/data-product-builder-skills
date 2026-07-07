MODEL (
  name web_analytics_seeds.V_F_ORDER,
  kind SEED (
    path '../../seeds/v_f_order.csv'
  ),
  owner 'rohitrajtmdcio',
  description 'Historical order transaction seed data for testing and development',
  tags ('seed', 'reference_data', 'transactional', 'testing'),
  terms ('v_f_order'),
  columns (
        order_sk BIGINT,
        site_id BIGINT,
        item_no BIGINT,
        customer_no BIGINT,
        order_no BIGINT,
        order_line_no BIGINT,
        order_entry_cd VARCHAR,
        order_cases_qty BIGINT,
        order_bottle_qty BIGINT,
        cases_dec_equivalent DECIMAL(15, 3),
        order_net_amt DECIMAL(18, 2),
        order_price_per_case DECIMAL(18, 2),
        order_dsct_per_case DECIMAL(18, 4),
        invoice_no BIGINT,
        invoice_line_no BIGINT,
        invoice_dt DATE,
        warehouse_no BIGINT,
        posting_period BIGINT,
        order_status_cd VARCHAR,
        order_entry_dt DATE,
        order_reject_cd VARCHAR,
        order_reject_dt DATE,
        order_reject_time BIGINT,
        order_reject_by VARCHAR,
        order_external_id VARCHAR,
        is_deleted VARCHAR,
        load_dt VARCHAR,
        modified_dt VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: V_F_ORDER
-- ============================================================================

SELECT
  order_sk,
  site_id,
  item_no,
  customer_no,
  order_no,
  order_line_no,
  order_entry_cd,
  order_cases_qty,
  order_bottle_qty,
  cases_dec_equivalent,
  order_net_amt,
  order_price_per_case,
  order_dsct_per_case,
  invoice_no,
  invoice_line_no,
  invoice_dt,
  warehouse_no,
  posting_period,
  order_status_cd,
  order_entry_dt,
  order_reject_cd,
  order_reject_dt,
  order_reject_time,
  order_reject_by,
  order_external_id,
  is_deleted,
  load_dt,
  modified_dt
FROM SEED();
