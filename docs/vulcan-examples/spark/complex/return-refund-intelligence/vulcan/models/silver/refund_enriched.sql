MODEL (
  name qcommerce_returns_silver.refund_enriched,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [refund_id],
  description 'Canonical refund fact at one row per refund event with business reason mapping, customer attributes, and product attribution.',
  tags ('silver', 'refunds', 'canonical-fact', 'enriched'),
  terms ('refund_enriched', 'refund_reason_group', 'refund_severity_band'),
  columns (
    refund_id STRING,
    order_id STRING,
    order_item_id STRING,
    customer_id STRING,
    customer_name STRING,
    customer_tier STRING,
    city STRING,
    delivery_mode STRING,
    refund_ts TIMESTAMP,
    refund_date DATE,
    order_date DATE,
    refund_reason_group STRING,
    issue_group STRING,
    refund_amount DECIMAL(12, 2),
    order_amount DECIMAL(12, 2),
    item_amount DECIMAL(12, 2),
    issue_owner STRING,
    product_category STRING,
    product_name STRING,
    sku_id STRING,
    quantity INT,
    refund_status STRING,
    normalized_payment_status STRING,
    refund_severity_band STRING,
    is_delivery_issue BOOLEAN,
    is_product_issue BOOLEAN,
    is_missing_item_issue BOOLEAN,
    is_pricing_issue BOOLEAN
  )
);

SELECT
  r.refund_id,
  r.order_id,
  r.order_item_id,
  o.customer_id,
  o.customer_name,
  o.customer_tier,
  o.city,
  o.delivery_mode,
  r.refund_ts,
  r.refund_date,
  o.order_date,
  COALESCE(m.refund_reason_group, 'unknown') AS refund_reason_group,
  COALESCE(m.issue_group, 'unknown') AS issue_group,
  r.refund_amount,
  o.order_amount,
  i.item_amount,
  r.issue_owner,
  i.product_category,
  i.product_name,
  i.sku_id,
  i.quantity,
  r.refund_status,
  o.normalized_payment_status,

  CASE
    WHEN r.refund_amount >= 150 THEN 'high'
    WHEN r.refund_amount >= 90 THEN 'medium'
    ELSE 'low'
  END AS refund_severity_band,

  CASE
    WHEN COALESCE(m.issue_group, 'unknown') = 'delivery_issue'
    THEN TRUE
    ELSE FALSE
  END AS is_delivery_issue,

  CASE
    WHEN COALESCE(m.issue_group, 'unknown') = 'quality_issue'
    THEN TRUE
    ELSE FALSE
  END AS is_product_issue,

  CASE
    WHEN COALESCE(m.issue_group, 'unknown') = 'missing_item'
    THEN TRUE
    ELSE FALSE
  END AS is_missing_item_issue,

  CASE
    WHEN COALESCE(m.issue_group, 'unknown') = 'pricing_issue'
    THEN TRUE
    ELSE FALSE
  END AS is_pricing_issue

FROM qcommerce_returns_bronze.refunds_clean r

LEFT JOIN qcommerce_returns_bronze.orders_clean o
  ON r.order_id = o.order_id

LEFT JOIN qcommerce_returns_bronze.order_items_clean i
  ON r.order_item_id = i.order_item_id

LEFT JOIN qcommerce_returns_bronze.refund_reason_mapping m
  ON r.raw_refund_reason = m.raw_refund_reason;