MODEL (
  name DEMODB.VDETRUE.CUSTOMER_SEGMENTS,
  kind SEED (
    path '../seeds/customer_segments.csv'
  ),
  columns (
    SEGMENT_CODE   VARCHAR,
    SEGMENT_NAME   VARCHAR,
    SEGMENT_TIER   INTEGER,
    DISCOUNT_RATE  FLOAT,
    DESCRIPTION    VARCHAR
  ),
  grain SEGMENT_CODE,
  tags ('seed', 'lookup', 'customer', 'segment', 'master_data'),
  terms ('customer.segment_lookup', 'sales.segment_dimension'),
  description 'Static segment lookup loaded from seeds/customer_segments.csv. Maps customer segment codes to tier rank, discount rate, and a human-readable description used to enrich the customers dimension.',
  column_descriptions (
    SEGMENT_CODE  = 'Segment code as referenced by upstream customer records (e.g. Platinum, PlatinumVIP, Corporate, Gold, GoldPlus, Wholesale, Partner, Silver, SilverPlus, Bronze, Student, Retail)',
    SEGMENT_NAME  = 'Human-readable segment name',
    SEGMENT_TIER  = 'Ordinal segment tier (higher = more valuable; Retail = 0)',
    DISCOUNT_RATE = 'Default discount fraction granted to customers in this segment (0.0 to 1.0)',
    DESCRIPTION   = 'Plain-English description of the segment'
  ),
  column_tags (
    SEGMENT_CODE  = ('identifier', 'primary_key', 'grain'),
    SEGMENT_NAME  = ('dimension', 'label'),
    SEGMENT_TIER  = ('measure', 'ordinal', 'rank'),
    DISCOUNT_RATE = ('measure', 'financial', 'percentage'),
    DESCRIPTION   = ('dimension', 'label', 'documentation')
  ),
  column_terms (
    SEGMENT_CODE  = ('customer.segment_code', 'segment.identifier'),
    SEGMENT_NAME  = ('customer.segment_name', 'segment.label'),
    SEGMENT_TIER  = ('customer.segment_tier', 'segment.rank'),
    DISCOUNT_RATE = ('customer.segment_discount', 'pricing.segment_discount_rate')
  )
);
