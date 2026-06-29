MODEL (
  name ERP_PLATFORM.SEED.SUPPLIER_MASTER,
  kind SEED (
    path '../../seeds/supplier_master.csv'
  ),
  columns (
    supplier_id VARCHAR(20),
    supplier_name VARCHAR(200),
    supplier_category VARCHAR(50),
    country VARCHAR(50),
    lead_time_days INTEGER,
    payment_terms VARCHAR(50),
    supplier_rating VARCHAR(20),
    active_status VARCHAR(20)
  ),
  grain SUPPLIER_ID,
  owner 'shreyasikarwartmdcio',
  profiles (SUPPLIER_ID, SUPPLIER_NAME, SUPPLIER_CATEGORY, COUNTRY, LEAD_TIME_DAYS, PAYMENT_TERMS, SUPPLIER_RATING, ACTIVE_STATUS),
  tags ('reference-data', 'suppliers', 'procurement', 'seed-data'),
  terms ('supplier-directory', 'vendor-master', 'supplier-catalog'),
  description 'Supplier directory with vendor attributes, lead times, and rating information.',

  column_descriptions (
    SUPPLIER_ID = 'Unique supplier identifier (e.g., SUP-001) - Primary key for supplier lookup',
    SUPPLIER_NAME = 'Supplier company name for reporting and analysis',
    SUPPLIER_CATEGORY = 'Supplier category: Electronics, Mechanical, Raw Materials, Packaging, Services',
    COUNTRY = 'Supplier country of origin',
    LEAD_TIME_DAYS = 'Standard lead time in days for order fulfillment',
    PAYMENT_TERMS = 'Payment terms (e.g., Net 30, Net 60)',
    SUPPLIER_RATING = 'Supplier rating: Preferred, Approved, Probation',
    ACTIVE_STATUS = 'Active/Inactive status indicator'
  ),

  column_tags (
    SUPPLIER_ID = ('identifier', 'primary-key', 'reference-data', 'grain', 'unique', 'business-key'),
    SUPPLIER_NAME = ('display-name', 'reference-data', 'descriptive'),
    SUPPLIER_CATEGORY = ('classification', 'category', 'grouping'),
    COUNTRY = ('geography', 'location', 'dimension'),
    LEAD_TIME_DAYS = ('duration', 'lead-time', 'measure'),
    PAYMENT_TERMS = ('payment-terms', 'financial', 'terms'),
    SUPPLIER_RATING = ('rating', 'classification', 'priority'),
    ACTIVE_STATUS = ('status', 'flag', 'operational')
  ),

  column_terms (
    SUPPLIER_ID = ('supplier_id', 'vendor_id', 'supplier_code'),
    SUPPLIER_NAME = ('supplier_name', 'vendor_name', 'company_name'),
    SUPPLIER_CATEGORY = ('supplier_category', 'vendor_type', 'supplier_class'),
    COUNTRY = ('country', 'supplier_country', 'origin_country'),
    LEAD_TIME_DAYS = ('lead_time_days', 'delivery_lead_time', 'standard_lead_time'),
    PAYMENT_TERMS = ('payment_terms', 'terms_of_payment', 'net_terms'),
    SUPPLIER_RATING = ('supplier_rating', 'vendor_rating', 'supplier_tier'),
    ACTIVE_STATUS = ('active_status', 'is_active', 'vendor_status')
  )
);


