MODEL (
  name LENOVO.USDK.MODEL_BRAND_MAPPING,
  kind SEED (
    path '../seeds/model_brand_mapping.csv'
  ),
  columns (
    __metadata VARCHAR,
    mtm VARCHAR,
    product_segment VARCHAR,
    form_factor VARCHAR,
    category VARCHAR,
    series VARCHAR,
    product_name VARCHAR,
    gen VARCHAR,
    brand VARCHAR,
    category_processed VARCHAR,
    processed_date DATE
  ),
  grain MTM,
  owner 'shreyasikarwartmdcio',
  profiles (MTM, PRODUCT_SEGMENT, FORM_FACTOR, CATEGORY, BRAND, GEN),
  tags ('reference-data', 'dimension', 'lenovo-products', 'hardware-mapping', 'seed-data', 'master-data', 'product-catalog'),
  terms ('product_dimension', 'reference_data', 'hardware_catalog'),
  description 'Comprehensive product mapping reference data for Lenovo hardware models. Maps MTM codes to hierarchical product attributes including brand, series, category, form factor, and generation. Essential for product analytics, market segmentation, and hardware lifecycle analysis.',
  column_descriptions (
    __METADATA = 'Internal metadata field for tracking data lineage and versioning',
    MTM = 'Machine Type Model (MTM) - Unique Lenovo hardware identifier code used as primary key',
    PRODUCT_SEGMENT = 'Market segment classification (e.g., Consumer, Commercial, Gaming, Workstation)',
    FORM_FACTOR = 'Physical device form factor (e.g., Laptop, Desktop, Tablet, 2-in-1, All-in-One)',
    CATEGORY = 'Product category classification (e.g., Notebook, ThinkPad, IdeaPad, Legion)',
    SERIES = 'Product series name (e.g., ThinkPad T Series, IdeaPad Gaming, Legion 5)',
    PRODUCT_NAME = 'Full marketing product name (e.g., ThinkPad X1 Carbon Gen 9)',
    GEN = 'Generation number of the product (e.g., Gen 9, Gen 10, Gen 11)',
    BRAND = 'Primary brand name (e.g., ThinkPad, IdeaPad, Legion, Yoga, ThinkCentre)',
    CATEGORY_PROCESSED = 'Standardized and processed category field for analytical consistency',
    PROCESSED_DATE = 'Date when the product mapping data was last processed or updated'
  ),
  column_tags (
    __METADATA = ('system-metadata', 'audit', 'internal'),
    MTM = ('primary-key', 'hardware-id', 'lenovo-code', 'grain', 'identifier'),
    PRODUCT_SEGMENT = ('market-segment', 'business-classification', 'dimension'),
    FORM_FACTOR = ('hardware-type', 'physical-attribute', 'dimension'),
    CATEGORY = ('product-category', 'classification', 'dimension'),
    SERIES = ('product-line', 'brand-hierarchy', 'dimension'),
    PRODUCT_NAME = ('product-name', 'marketing-name', 'display-name', 'dimension'),
    GEN = ('generation', 'version', 'model-year', 'dimension'),
    BRAND = ('brand', 'top-level-category', 'dimension'),
    CATEGORY_PROCESSED = ('processed-field', 'standardized', 'analytics-ready', 'dimension'),
    PROCESSED_DATE = ('timestamp', 'data-quality', 'audit', 'etl-metadata')
  ),
  column_terms (
    __METADATA = ('metadata', 'lineage'),
    MTM = ('mtm', 'machine_type_model'),
    PRODUCT_SEGMENT = ('segment', 'segment'),
    FORM_FACTOR = ('form_factor', 'physical_type'),
    CATEGORY = ('category', 'category'),
    SERIES = ('series', 'product_line'),
    PRODUCT_NAME = ('name', 'product_name'),
    GEN = ('generation', 'generation'),
    BRAND = ('brand', 'brand_name'),
    CATEGORY_PROCESSED = ('category_standardized', 'processed_category'),
    PROCESSED_DATE = ('processed_date', 'update_date')
  )
)