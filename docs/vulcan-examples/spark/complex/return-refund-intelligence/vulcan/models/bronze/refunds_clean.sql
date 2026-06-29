MODEL (
  name qcommerce_returns_bronze.refunds_clean,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [refund_id],
  description 'Standardized refund events at one row per refund request for return and refund intelligence use cases.',
  tags ('bronze', 'refunds', 'returns', 'events'),
  terms ('refunds_clean', 'refund_event', 'refund_request'),
  columns (
    refund_id STRING,
    order_id STRING,
    order_item_id STRING,
    refund_ts TIMESTAMP,
    refund_date DATE,
    raw_refund_reason STRING,
    refund_amount DECIMAL(12, 2),
    refund_status STRING,
    issue_owner STRING
  )
);

SELECT
  CAST(refund_id AS STRING) AS refund_id,
  CAST(order_id AS STRING) AS order_id,
  CAST(order_item_id AS STRING) AS order_item_id,
  CAST(refund_ts AS TIMESTAMP) AS refund_ts,
  TO_DATE(CAST(refund_ts AS TIMESTAMP)) AS refund_date,
  LOWER(TRIM(CAST(raw_refund_reason AS STRING))) AS raw_refund_reason,
  CAST(refund_amount AS DECIMAL(12, 2)) AS refund_amount,
  LOWER(TRIM(CAST(refund_status AS STRING))) AS refund_status,
  LOWER(TRIM(CAST(issue_owner AS STRING))) AS issue_owner
FROM qcommerce_returns_ext_raw.refunds