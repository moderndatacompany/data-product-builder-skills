MODEL (
  name CUSTOMER_PLATFORM.GOLD.FCT_CUSTOMER_LIFETIME_VALUE,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [CUSTOMER_ID],
  description 'Customer lifetime value calculations with segment assignment and revenue metrics for strategic account prioritization and resource allocation decisions. Derives CLV from RFM scores, order history, and customer tenure.',
  tags ('gold', 'fact', 'clv', 'customer-value', 'revenue'),
  terms ('customer_lifetime_value', 'revenue_metrics', 'customer_prioritization'),
  columns (
    customer_id VARCHAR(50),
    customer_name VARCHAR(200),
    customer_type VARCHAR(50),
    account_tier VARCHAR(50),
    segment_name VARCHAR(50),
    engagement_strategy VARCHAR(200),
    recency_days INTEGER,
    frequency_count INTEGER,
    monetary_value DECIMAL(15,2),
    total_orders INTEGER,
    first_order_date DATE,
    last_order_date DATE,
    customer_tenure_months INTEGER,
    total_revenue DECIMAL(15,2),
    avg_order_value DECIMAL(15,2),
    customer_lifetime_value DECIMAL(15,2),
    calculated_at TIMESTAMP
  ),
  
  column_descriptions (
    customer_id = 'Unique customer identifier (PK) - links to customer master and fct_customer_rfm',
    customer_name = 'Customer legal entity name',
    customer_type = 'Customer classification: OEM, Distributor, Direct',
    account_tier = 'Account tier: Strategic, Standard, Small',
    segment_name = 'RFM segment name from fct_customer_rfm',
    engagement_strategy = 'Recommended engagement approach based on RFM segment',
    recency_days = 'Days since last order from RFM calculation',
    frequency_count = 'Order count from RFM calculation (last 365 days)',
    monetary_value = 'Total spend from RFM calculation (last 365 days)',
    total_orders = 'Total distinct orders across entire customer history',
    first_order_date = 'Date of the customers first order ever',
    last_order_date = 'Date of the customers most recent order',
    customer_tenure_months = 'Customer tenure in months (first order to current date)',
    total_revenue = 'Total lifetime revenue across all orders (net value)',
    avg_order_value = 'Average net order value across all orders',
    customer_lifetime_value = 'Calculated CLV using average monthly revenue multiplied by projected lifetime',
    calculated_at = 'Timestamp when CLV was last calculated'
  ),
  
  column_tags (
    customer_id = ('identifier', 'primary-key', 'grain'),
    customer_name = ('customer', 'display-name'),
    customer_type = ('customer', 'classification'),
    account_tier = ('customer', 'classification'),
    segment_name = ('segment', 'classification'),
    engagement_strategy = ('strategy', 'recommendation'),
    recency_days = ('recency', 'measure'),
    frequency_count = ('frequency', 'measure'),
    monetary_value = ('monetary', 'measure', 'revenue'),
    total_orders = ('count', 'measure', 'lifetime'),
    first_order_date = ('temporal', 'milestone'),
    last_order_date = ('temporal', 'milestone'),
    customer_tenure_months = ('duration', 'measure', 'lifetime'),
    total_revenue = ('revenue', 'kpi', 'lifetime'),
    avg_order_value = ('revenue', 'measure', 'average'),
    customer_lifetime_value = ('revenue', 'kpi', 'primary', 'lifetime'),
    calculated_at = ('temporal', 'audit', 'metadata')
  ),
  
  assertions (
    not_null(columns := (customer_id, total_revenue, customer_lifetime_value)),
    unique_values(columns := (customer_id)),
    forall(criteria := (total_revenue >= 0, avg_order_value >= 0, customer_lifetime_value >= 0))
  ),
  
  profiles (
    count_records(name := 'row_count'),
    duplicate_count(columns := (customer_id)),
    missing_count(columns := (customer_id, customer_lifetime_value, segment_name)),
    profile_min(columns := (total_revenue, avg_order_value, customer_lifetime_value, customer_tenure_months)),
    profile_max(columns := (total_revenue, avg_order_value, customer_lifetime_value, customer_tenure_months)),
    profile_mean(columns := (total_revenue, avg_order_value, customer_lifetime_value, customer_tenure_months))
  )
);

WITH rfm_data AS (
  -- Get RFM scores and segment assignment from upstream model
  SELECT
    customer_id,
    customer_name,
    customer_type,
    account_tier,
    segment_name,
    engagement_strategy,
    recency_days,
    frequency_count,
    monetary_value
  FROM CUSTOMER_PLATFORM.GOLD.FCT_CUSTOMER_RFM
),

lifetime_orders AS (
  -- Aggregate all-time order metrics per customer
  SELECT
    o."customer_id"::VARCHAR(50) AS customer_id,
    COUNT(DISTINCT o."order_id") AS total_orders,
    MIN(o."order_date"::DATE) AS first_order_date,
    MAX(o."order_date"::DATE) AS last_order_date,
    COALESCE(SUM(o."net_order_value_usd"), 0) AS total_revenue,
    CASE 
      WHEN COUNT(DISTINCT o."order_id") > 0 
      THEN ROUND(SUM(o."net_order_value_usd") / COUNT(DISTINCT o."order_id"), 2)
      ELSE 0 
    END AS avg_order_value,
    DATEDIFF(MONTH, MIN(o."order_date"::DATE), CURRENT_DATE()) AS customer_tenure_months
  FROM CUSTOMER_PLATFORM.BRONZE.SALES_ORDER_HISTORY o
  WHERE o."order_status" IN ('Confirmed', 'Shipped', 'Invoiced')
  GROUP BY o."customer_id"
),

clv_calculation AS (
  -- Calculate CLV: avg_monthly_revenue * projected_lifetime_months
  -- projected_lifetime = tenure_months * retention_multiplier (based on segment)
  SELECT
    r.customer_id,
    r.customer_name,
    r.customer_type,
    r.account_tier,
    r.segment_name,
    r.engagement_strategy,
    r.recency_days,
    r.frequency_count,
    r.monetary_value,
    COALESCE(lo.total_orders, 0) AS total_orders,
    lo.first_order_date,
    lo.last_order_date,
    COALESCE(lo.customer_tenure_months, 0) AS customer_tenure_months,
    COALESCE(lo.total_revenue, 0) AS total_revenue,
    COALESCE(lo.avg_order_value, 0) AS avg_order_value,
    
    -- CLV Calculation:
    -- avg_monthly_revenue = total_revenue / max(tenure_months, 1)
    -- projected_months = based on segment (Champions=36, Loyal=24, At Risk=6, etc.)
    -- CLV = avg_monthly_revenue * projected_months
    ROUND(
      CASE 
        WHEN COALESCE(lo.customer_tenure_months, 0) > 0 THEN
          (COALESCE(lo.total_revenue, 0) / GREATEST(lo.customer_tenure_months, 1)) *
          CASE r.segment_name
            WHEN 'Champions' THEN 36
            WHEN 'Loyal Customers' THEN 30
            WHEN 'Potential Loyalists' THEN 24
            WHEN 'New Customers' THEN 18
            WHEN 'Promising' THEN 18
            WHEN 'Need Attention' THEN 12
            WHEN 'At Risk' THEN 6
            WHEN 'About to Sleep' THEN 3
            WHEN 'Hibernating' THEN 1
            WHEN 'Lost' THEN 0
            ELSE 6
          END
        ELSE 0
      END, 2
    ) AS customer_lifetime_value,
    
    CURRENT_TIMESTAMP() AS calculated_at
    
  FROM rfm_data r
  LEFT JOIN lifetime_orders lo ON r.customer_id = lo.customer_id
)

SELECT
  customer_id,
  customer_name,
  customer_type,
  account_tier,
  segment_name,
  engagement_strategy,
  recency_days,
  frequency_count,
  monetary_value,
  total_orders,
  first_order_date,
  last_order_date,
  customer_tenure_months,
  total_revenue,
  avg_order_value,
  customer_lifetime_value,
  calculated_at
FROM clv_calculation
ORDER BY customer_lifetime_value DESC;

