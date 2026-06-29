MODEL (
  name CUSTOMER_PLATFORM.SEED.CUSTOMER_SEGMENTS_RFM,
  kind SEED (
    path '../../seeds/customer_segments_rfm.csv'
  ),
  columns (
    segment_id VARCHAR(20),
    segment_name VARCHAR(50),
    recency_min INTEGER,
    recency_max INTEGER,
    frequency_min INTEGER,
    frequency_max INTEGER,
    monetary_min NUMERIC(15,2),
    monetary_max NUMERIC(15,2),
    engagement_strategy VARCHAR(200)
  ),
  grain SEGMENT_ID,
  owner 'shreyasikarwartmdcio',
  profiles (SEGMENT_ID, SEGMENT_NAME),
  tags ('reference-data', 'dimension', 'rfm', 'segmentation-rules', 'seed-data', 'customer-analytics'),
  terms ('rfm_model', 'customer_segments', 'segmentation_thresholds'),
  description 'RFM segmentation rules defining customer segments with recency, frequency, and monetary thresholds for automated customer classification and targeting. Contains 10 segments from Champions to Lost with engagement strategy recommendations.',
  
  column_descriptions (
    SEGMENT_ID = 'Unique segment identifier (SEG-001 through SEG-010) - Primary key for segment lookup and classification across all customer analytics',
    SEGMENT_NAME = 'Human-readable segment label (Champions, Loyal Customers, At Risk, Lost, etc.) for business reporting and dashboards',
    RECENCY_MIN = 'Minimum days since last order for segment qualification - lower bound of recency threshold',
    RECENCY_MAX = 'Maximum days since last order for segment qualification - upper bound of recency threshold',
    FREQUENCY_MIN = 'Minimum order count in last 12 months for segment qualification - lower bound of frequency threshold',
    FREQUENCY_MAX = 'Maximum order count in last 12 months for segment qualification - upper bound of frequency threshold',
    MONETARY_MIN = 'Minimum total spend in last 12 months (USD) for segment qualification - lower bound of monetary threshold',
    MONETARY_MAX = 'Maximum total spend in last 12 months (USD) for segment qualification - upper bound of monetary threshold',
    ENGAGEMENT_STRATEGY = 'Recommended engagement approach and action plan for customers in this segment - guides sales and marketing teams'
  ),
  
  column_tags (
    SEGMENT_ID = ('identifier', 'primary-key', 'reference-data', 'grain', 'unique', 'business-key'),
    SEGMENT_NAME = ('display-name', 'business-name', 'reference-data', 'descriptive'),
    RECENCY_MIN = ('threshold', 'recency', 'configuration', 'rule'),
    RECENCY_MAX = ('threshold', 'recency', 'configuration', 'rule'),
    FREQUENCY_MIN = ('threshold', 'frequency', 'configuration', 'rule'),
    FREQUENCY_MAX = ('threshold', 'frequency', 'configuration', 'rule'),
    MONETARY_MIN = ('threshold', 'monetary', 'configuration', 'rule'),
    MONETARY_MAX = ('threshold', 'monetary', 'configuration', 'rule'),
    ENGAGEMENT_STRATEGY = ('strategy', 'recommendation', 'action-plan', 'business-guidance')
  ),
  
  column_terms (
    SEGMENT_ID = ('segment_id', 'segment_code', 'rfm_segment_id'),
    SEGMENT_NAME = ('segment_name', 'segment_label', 'rfm_segment_name'),
    RECENCY_MIN = ('recency_minimum', 'min_recency_days', 'recency_lower_bound'),
    RECENCY_MAX = ('recency_maximum', 'max_recency_days', 'recency_upper_bound'),
    FREQUENCY_MIN = ('frequency_minimum', 'min_order_count', 'frequency_lower_bound'),
    FREQUENCY_MAX = ('frequency_maximum', 'max_order_count', 'frequency_upper_bound'),
    MONETARY_MIN = ('monetary_minimum', 'min_spend', 'monetary_lower_bound'),
    MONETARY_MAX = ('monetary_maximum', 'max_spend', 'monetary_upper_bound'),
    ENGAGEMENT_STRATEGY = ('engagement_strategy', 'action_plan', 'customer_engagement')
  )
);
