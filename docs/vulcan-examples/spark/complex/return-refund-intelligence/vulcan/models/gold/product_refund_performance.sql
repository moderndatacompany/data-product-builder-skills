MODEL (
  name qcommerce_returns_gold.product_refund_performance,
  kind FULL,
  owner 'shreyasikarwartmdcio',
  grains [ds, city, product_category],
  description 'Daily product-category refund leakage and performance metrics for finance and operations analytics.',
  tags ('gold', 'refunds', 'products', 'leakage'),
  terms ('product_refund_performance', 'sku_count', 'refund_leakage'),
  columns (
    ds DATE,
    city STRING,
    product_category STRING,
    sku_count INT,
    refund_events INT,
    total_refund_amount DECIMAL(14, 2),
    avg_refund_amount DECIMAL(14, 2)
  )
);

SELECT
  refund_date AS ds,
  city,
  product_category,
  COUNT(DISTINCT sku_id) AS sku_count,
  COUNT(DISTINCT refund_id) AS refund_events,
  ROUND(SUM(refund_amount), 2) AS total_refund_amount,
  ROUND(AVG(refund_amount), 2) AS avg_refund_amount
FROM qcommerce_returns_silver.refund_enriched
GROUP BY
  refund_date,
  city,
  product_category
ORDER BY
  ds DESC,
  city,
  product_category