MODEL (
  name CUSTOMER_PLATFORM.GOLD.FCT_CUSTOMER_RFM,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [CUSTOMER_ID],
  description 'RFM score calculations with recency, frequency, monetary metrics and segment assignment for customer prioritization and targeted marketing campaigns. Combines customer master, sales order history, and RFM segment rules to classify each customer.',
  tags ('gold', 'fact', 'rfm', 'customer-scoring', 'segmentation'),
  terms ('rfm_analysis', 'customer_scoring', 'behavioral_metrics'),
  columns (
    customer_id VARCHAR(50),
    customer_name VARCHAR(200),
    customer_type VARCHAR(50),
    account_tier VARCHAR(50),
    recency_days INTEGER,
    frequency_count INTEGER,
    monetary_value NUMERIC(15,2),
    recency_score INTEGER,
    frequency_score INTEGER,
    monetary_score INTEGER,
    rfm_score VARCHAR(10),
    segment_id VARCHAR(20),
    segment_name VARCHAR(50),
    engagement_strategy VARCHAR(200),
    calculated_at TIMESTAMP
  ),
  
  column_descriptions (
    customer_id = 'Unique customer identifier (PK) - links to customer master',
    customer_name = 'Customer legal entity name for business reporting',
    customer_type = 'Customer classification: OEM, Distributor, Direct',
    account_tier = 'Account tier: Strategic, Standard, Small',
    recency_days = 'Days since customers last completed order - lower is better',
    frequency_count = 'Total number of completed orders in last 365 days',
    monetary_value = 'Total net order value (USD) in last 365 days',
    recency_score = 'Recency score (1-5, where 5 is most recent buyer)',
    frequency_score = 'Frequency score (1-5, where 5 is most frequent buyer)',
    monetary_score = 'Monetary score (1-5, where 5 is highest spender)',
    rfm_score = 'Combined RFM score string (e.g., 555 for best customers)',
    segment_id = 'FK to customer_segments_rfm - assigned segment identifier',
    segment_name = 'Assigned RFM segment name (Champions, Loyal, At Risk, etc.)',
    engagement_strategy = 'Recommended engagement approach for this customer based on segment',
    calculated_at = 'Timestamp when RFM scores were last calculated'
  ),
  
  column_tags (
    customer_id = ('identifier', 'primary-key', 'grain'),
    customer_name = ('customer', 'display-name'),
    customer_type = ('customer', 'classification', 'category'),
    account_tier = ('customer', 'classification', 'category'),
    recency_days = ('recency', 'measure', 'rfm-component'),
    frequency_count = ('frequency', 'measure', 'rfm-component'),
    monetary_value = ('monetary', 'measure', 'rfm-component', 'revenue'),
    recency_score = ('score', 'rfm-component', 'kpi'),
    frequency_score = ('score', 'rfm-component', 'kpi'),
    monetary_score = ('score', 'rfm-component', 'kpi'),
    rfm_score = ('score', 'composite', 'kpi'),
    segment_id = ('foreign-key', 'segment', 'classification'),
    segment_name = ('segment', 'display-name', 'classification'),
    engagement_strategy = ('strategy', 'recommendation'),
    calculated_at = ('temporal', 'audit', 'metadata')
  ),
  
  assertions (
    not_null(columns := (customer_id, recency_days, frequency_count, monetary_value, rfm_score, segment_id)),
    unique_values(columns := (customer_id)),
    accepted_range(column := recency_score, min_v := 1, max_v := 5),
    accepted_range(column := frequency_score, min_v := 1, max_v := 5),
    accepted_range(column := monetary_score, min_v := 1, max_v := 5),
    forall(criteria := (monetary_value >= 0, frequency_count >= 0, recency_days >= 0))
  ),
  
  profiles (
    count_records(name := 'row_count'),
    duplicate_count(columns := (customer_id)),
    missing_count(columns := (customer_id, segment_id, rfm_score)),
    profile_min(columns := (recency_days, frequency_count, monetary_value, recency_score, frequency_score, monetary_score)),
    profile_max(columns := (recency_days, frequency_count, monetary_value, recency_score, frequency_score, monetary_score)),
    profile_mean(columns := (recency_days, frequency_count, monetary_value))
  )
);

WITH customer_orders AS (
  SELECT
    o."customer_id"::VARCHAR(50) AS customer_id,
    (CURRENT_DATE - MAX(o."order_date"::DATE)) AS recency_days,
    COUNT(DISTINCT o."order_id") AS frequency_count,
    COALESCE(SUM(o."net_order_value_usd"), 0) AS monetary_value,
    MIN(o."order_date"::DATE) AS first_order_date,
    MAX(o."order_date"::DATE) AS last_order_date
  FROM CUSTOMER_PLATFORM.BRONZE.SALES_ORDER_HISTORY o
  WHERE o."order_status" IN ('Confirmed', 'Shipped', 'Invoiced')
    AND o."order_date"::DATE >= (CURRENT_DATE - INTERVAL '365 days')::DATE
  GROUP BY o."customer_id"
),

customer_base AS (
  SELECT
    c."customer_id"::VARCHAR(50) AS customer_id,
    c."customer_name"::VARCHAR(200) AS customer_name,
    c."customer_type"::VARCHAR(50) AS customer_type,
    c."account_tier"::VARCHAR(50) AS account_tier
  FROM CUSTOMER_PLATFORM.BRONZE.CUSTOMER_MASTER c
  WHERE c."account_status" = 'Active'
),

rfm_raw AS (
  SELECT
    cb.customer_id,
    cb.customer_name,
    cb.customer_type,
    cb.account_tier,
    COALESCE(co.recency_days, 9999) AS recency_days,
    COALESCE(co.frequency_count, 0) AS frequency_count,
    COALESCE(co.monetary_value, 0) AS monetary_value
  FROM customer_base cb
  LEFT JOIN customer_orders co ON cb.customer_id = co.customer_id
),

rfm_scored AS (
  SELECT
    *,
    CASE
      WHEN recency_days <= 30 THEN 5
      WHEN recency_days <= 60 THEN 4
      WHEN recency_days <= 90 THEN 3
      WHEN recency_days <= 180 THEN 2
      ELSE 1
    END AS recency_score,
    CASE
      WHEN frequency_count >= 8 THEN 5
      WHEN frequency_count >= 5 THEN 4
      WHEN frequency_count >= 3 THEN 3
      WHEN frequency_count >= 1 THEN 2
      ELSE 1
    END AS frequency_score,
    CASE
      WHEN monetary_value >= 500000 THEN 5
      WHEN monetary_value >= 200000 THEN 4
      WHEN monetary_value >= 100000 THEN 3
      WHEN monetary_value >= 50000 THEN 2
      ELSE 1
    END AS monetary_score
  FROM rfm_raw
),

rfm_with_composite AS (
  SELECT
    *,
    CONCAT(recency_score::TEXT, frequency_score::TEXT, monetary_score::TEXT) AS rfm_score
  FROM rfm_scored
),

rfm_segmented AS (
  SELECT
    r.customer_id,
    r.customer_name,
    r.customer_type,
    r.account_tier,
    r.recency_days,
    r.frequency_count,
    r.monetary_value,
    r.recency_score,
    r.frequency_score,
    r.monetary_score,
    r.rfm_score,
    s.segment_id,
    s.segment_name,
    s.engagement_strategy,
    CURRENT_TIMESTAMP AS calculated_at,
    ROW_NUMBER() OVER (
      PARTITION BY r.customer_id 
      ORDER BY s.recency_min DESC, s.frequency_min DESC, s.monetary_min DESC
    ) AS rn
  FROM rfm_with_composite r
  LEFT JOIN CUSTOMER_PLATFORM.SEED.CUSTOMER_SEGMENTS_RFM s
    ON r.recency_days BETWEEN s.recency_min AND s.recency_max
    AND r.frequency_count BETWEEN s.frequency_min AND s.frequency_max
    AND r.monetary_value BETWEEN s.monetary_min AND s.monetary_max
)

SELECT
  customer_id,
  customer_name,
  customer_type,
  account_tier,
  recency_days,
  frequency_count,
  monetary_value,
  recency_score,
  frequency_score,
  monetary_score,
  rfm_score,
  COALESCE(segment_id, 'SEG-010') AS segment_id,
  COALESCE(segment_name, 'Lost') AS segment_name,
  COALESCE(engagement_strategy, 'Low-cost re-engagement attempts. Annual check-in.') AS engagement_strategy,
  calculated_at
FROM rfm_segmented
WHERE rn = 1
ORDER BY monetary_value DESC, frequency_count DESC;
