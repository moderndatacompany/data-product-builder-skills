MODEL (
  name ERP_PLATFORM.GOLD.FCT_SUPPLIER_PERFORMANCE,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [SUPPLIER_PERF_KEY],
  description 'Supplier performance scorecard with delivery, quality, and lead time metrics. Aggregation (averages, totals, weighted scores) is handled by the semantic layer.',
  tags ('gold', 'fact', 'supplier-performance', 'procurement'),
  terms ('supplier-metrics', 'vendor-performance', 'on-time-delivery'),
  columns (
    supplier_perf_key VARCHAR(100),
    supplier_id VARCHAR(20),
    supplier_name VARCHAR(200),
    supplier_category VARCHAR(50),
    evaluation_period VARCHAR(20),
    period_start_date DATE,
    period_end_date DATE,
    total_pos INTEGER,
    total_po_value_usd DECIMAL(15,2),
    on_time_deliveries INTEGER,
    on_time_delivery_rate DECIMAL(5,2),
    quality_acceptance_rate DECIMAL(5,2),
    average_lead_time_days DECIMAL(5,1),
    supplier_score DECIMAL(5,2),
    calculated_at TIMESTAMP
  ),

  column_descriptions (
    supplier_perf_key = 'Surrogate key (supplier_id || evaluation_period || period_start_date)',
    supplier_id = 'Supplier identifier (FK to supplier_master)',
    supplier_name = 'Supplier company name from master data',
    supplier_category = 'Supplier category from master data',
    evaluation_period = 'Performance evaluation period: Monthly',
    period_start_date = 'Evaluation period start date',
    period_end_date = 'Evaluation period end date',
    total_pos = 'Total purchase orders placed in evaluation period',
    total_po_value_usd = 'Total PO value in USD for the period',
    on_time_deliveries = 'Count of on-time deliveries (actual <= promised)',
    on_time_delivery_rate = 'On-time delivery percentage (on_time / total * 100)',
    quality_acceptance_rate = 'Quality acceptance percentage (simulated 85-100%)',
    average_lead_time_days = 'Average actual lead time in days for the period',
    supplier_score = 'Composite supplier score (0-100): 40% OTD + 30% quality + 30% lead time',
    calculated_at = 'Record calculation timestamp'
  ),

  column_tags (
    supplier_perf_key = ('identifier', 'primary-key', 'surrogate-key', 'grain'),
    supplier_id = ('foreign-key', 'supplier', 'identifier'),
    supplier_name = ('supplier', 'display-name'),
    supplier_category = ('category', 'dimension'),
    evaluation_period = ('period', 'dimension'),
    period_start_date = ('temporal', 'date', 'period'),
    period_end_date = ('temporal', 'date', 'period'),
    total_pos = ('count', 'measure'),
    total_po_value_usd = ('value', 'measure', 'financial'),
    on_time_deliveries = ('count', 'measure', 'delivery'),
    on_time_delivery_rate = ('percentage', 'kpi', 'delivery'),
    quality_acceptance_rate = ('percentage', 'kpi', 'quality'),
    average_lead_time_days = ('duration', 'measure', 'lead-time'),
    supplier_score = ('score', 'kpi', 'composite'),
    calculated_at = ('temporal', 'audit', 'metadata')
  ),

  assertions (
    not_null(columns := (supplier_perf_key, supplier_id, evaluation_period, period_start_date, total_pos)),
    unique_values(columns := (supplier_perf_key)),
    forall(criteria := (total_pos >= 0, on_time_delivery_rate >= 0, on_time_delivery_rate <= 100, supplier_score >= 0, supplier_score <= 100))
  ),

  profiles (SUPPLIER_PERF_KEY, SUPPLIER_ID, SUPPLIER_NAME, SUPPLIER_CATEGORY, EVALUATION_PERIOD, PERIOD_START_DATE, PERIOD_END_DATE, TOTAL_POS, TOTAL_PO_VALUE_USD, ON_TIME_DELIVERIES, ON_TIME_DELIVERY_RATE, QUALITY_ACCEPTANCE_RATE, AVERAGE_LEAD_TIME_DAYS, SUPPLIER_SCORE, CALCULATED_AT)
);

WITH monthly_po_stats AS (
  SELECT
    po."supplier_id"::VARCHAR(20) AS supplier_id,
    DATE_TRUNC('MONTH', po."po_date"::DATE) AS period_start,
    LAST_DAY(po."po_date"::DATE) AS period_end,
    COUNT(DISTINCT po."po_id") AS total_pos,
    SUM(po."po_value_usd"::DECIMAL(15,2)) AS total_po_value_usd,
    SUM(CASE WHEN po."actual_delivery_date"::DATE <= po."promised_delivery_date"::DATE THEN 1 ELSE 0 END) AS on_time_deliveries,
    AVG(DATEDIFF('day', po."po_date"::DATE, COALESCE(po."actual_delivery_date"::DATE, po."promised_delivery_date"::DATE))) AS avg_lead_time_days
  FROM ERP_PLATFORM.BRONZE.PURCHASE_ORDER_HISTORY po
  WHERE po."po_status" != 'Cancelled'
  GROUP BY po."supplier_id", DATE_TRUNC('MONTH', po."po_date"::DATE), LAST_DAY(po."po_date"::DATE)
)
SELECT
  (mps.supplier_id || '-Monthly-' || mps.period_start::VARCHAR)::VARCHAR(100) AS supplier_perf_key,
  mps.supplier_id,
  sm.SUPPLIER_NAME::VARCHAR(200) AS supplier_name,
  sm.SUPPLIER_CATEGORY::VARCHAR(50) AS supplier_category,
  'Monthly'::VARCHAR(20) AS evaluation_period,
  mps.period_start::DATE AS period_start_date,
  mps.period_end::DATE AS period_end_date,
  mps.total_pos::INTEGER AS total_pos,
  ROUND(mps.total_po_value_usd, 2) AS total_po_value_usd,
  mps.on_time_deliveries::INTEGER AS on_time_deliveries,
  ROUND(mps.on_time_deliveries * 100.0 / NULLIF(mps.total_pos, 0), 2) AS on_time_delivery_rate,
  -- Simulated quality acceptance rate based on supplier rating
  ROUND(CASE
    WHEN sm.SUPPLIER_RATING = 'Preferred' THEN 95.0 + (HASH(mps.supplier_id || mps.period_start::VARCHAR) % 500) / 100.0
    WHEN sm.SUPPLIER_RATING = 'Approved' THEN 90.0 + (HASH(mps.supplier_id || mps.period_start::VARCHAR) % 800) / 100.0
    ELSE 85.0 + (HASH(mps.supplier_id || mps.period_start::VARCHAR) % 1000) / 100.0
  END, 2) AS quality_acceptance_rate,
  ROUND(mps.avg_lead_time_days, 1) AS average_lead_time_days,
  -- Composite score: 40% OTD + 30% quality + 30% lead time efficiency
  ROUND(
    (mps.on_time_deliveries * 100.0 / NULLIF(mps.total_pos, 0)) * 0.4
    + CASE
        WHEN sm.SUPPLIER_RATING = 'Preferred' THEN 95.0 + (HASH(mps.supplier_id || mps.period_start::VARCHAR) % 500) / 100.0
        WHEN sm.SUPPLIER_RATING = 'Approved' THEN 90.0 + (HASH(mps.supplier_id || mps.period_start::VARCHAR) % 800) / 100.0
        ELSE 85.0 + (HASH(mps.supplier_id || mps.period_start::VARCHAR) % 1000) / 100.0
      END * 0.3
    + GREATEST(0, 100 - mps.avg_lead_time_days * 2) * 0.3,
  2) AS supplier_score,
  CURRENT_TIMESTAMP() AS calculated_at
FROM monthly_po_stats mps
LEFT JOIN ERP_PLATFORM.SEED.SUPPLIER_MASTER sm ON mps.supplier_id = sm.SUPPLIER_ID
ORDER BY mps.supplier_id, mps.period_start;


