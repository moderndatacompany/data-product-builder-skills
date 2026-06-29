MODEL (
  name QMS_PLATFORM.SEED.DEFECT_CODES,
  kind SEED (
    path '../../seeds/defect_codes_master.csv'
  ),
  columns (
    defect_code VARCHAR(20),
    defect_name VARCHAR(100),
    defect_category VARCHAR(50),
    severity VARCHAR(20),
    description VARCHAR(500),
    standard_cost_usd DECIMAL(10,2)
  ),
  grain DEFECT_CODE,
  owner 'shreyasikarwartmdcio',
  profiles (DEFECT_CODE, DEFECT_NAME, DEFECT_CATEGORY, SEVERITY, DESCRIPTION, STANDARD_COST_USD),
  tags ('reference-data', 'defect-codes', 'quality', 'seed-data'),
  terms ('defect-classification', 'defect-codes', 'quality-taxonomy'),
  description 'Standardized defect classification codes with categories and severity levels for consistent defect tracking and root cause analysis',

  column_descriptions (
    DEFECT_CODE = 'Defect code identifier (e.g., DEF-001) - Primary key for defect classification lookup',
    DEFECT_NAME = 'Human-readable defect name for reporting and analysis',
    DEFECT_CATEGORY = 'Defect category: Dimensional, Functional, Cosmetic, Assembly',
    SEVERITY = 'Defect severity level: Critical, Major, Minor',
    DESCRIPTION = 'Detailed description of the defect type and its impact',
    STANDARD_COST_USD = 'Standard cost per defect occurrence in USD for cost-of-quality calculations'
  ),

  column_tags (
    DEFECT_CODE = ('identifier', 'primary-key', 'reference-data', 'grain', 'unique', 'business-key'),
    DEFECT_NAME = ('display-name', 'reference-data', 'descriptive'),
    DEFECT_CATEGORY = ('classification', 'category', 'grouping'),
    SEVERITY = ('classification', 'severity', 'priority'),
    DESCRIPTION = ('metadata', 'business-context'),
    STANDARD_COST_USD = ('cost', 'financial', 'measure')
  ),

  column_terms (
    DEFECT_CODE = ('defect_code', 'defect_id', 'defect_classification'),
    DEFECT_NAME = ('defect_name', 'defect_description'),
    DEFECT_CATEGORY = ('defect_category', 'defect_type', 'defect_group'),
    SEVERITY = ('defect_severity', 'severity_level', 'defect_priority'),
    DESCRIPTION = ('defect_description', 'defect_detail'),
    STANDARD_COST_USD = ('defect_cost', 'scrap_cost', 'standard_cost')
  )
);

