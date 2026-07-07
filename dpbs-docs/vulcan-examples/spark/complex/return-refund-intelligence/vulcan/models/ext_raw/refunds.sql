MODEL (
  name qcommerce_returns_ext_raw.refunds,
  kind SEED (
    path '../../seeds/raw_refunds.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [refund_id],
  description 'Raw refund seed input for return and refund intelligence.',
  tags ('seed', 'ext-raw', 'refunds', 'events'),
  terms ('refunds', 'raw_refunds', 'source_input'),
  columns (
    refund_id STRING,
    order_id STRING,
    order_item_id STRING,
    refund_ts TIMESTAMP,
    raw_refund_reason STRING,
    refund_amount DOUBLE,
    refund_status STRING,
    issue_owner STRING
  )
)
