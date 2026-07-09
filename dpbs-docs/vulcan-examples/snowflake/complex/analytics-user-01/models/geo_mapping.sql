MODEL (
  name LENOVO.USDK.GEO_MAPPING,
  kind SEED (
    path '../seeds/geo_mapping.csv'
  ),
  columns (
    __metadata VARCHAR,
    country_code VARCHAR,
    country_name VARCHAR,
    region_key VARCHAR,
    region VARCHAR,
    sub_region_key VARCHAR,
    sub_region VARCHAR,
    additional1_key VARCHAR,
    additional1 VARCHAR,
    additional2_key VARCHAR,
    additional2 VARCHAR
  ),
  grain COUNTRY_CODE,
  owner 'shreyasikarwartmdcio',
  profiles (COUNTRY_CODE, COUNTRY_NAME, REGION, SUB_REGION),
  tags ('reference-data', 'dimension', 'geography', 'iso-codes', 'seed-data', 'master-data'),
  terms ('reference_data', 'geographic_dimension', 'master_data'),
  description 'Geographic mapping reference data providing hierarchical country-to-region mappings for global analytics and reporting. Used for standardizing geographic analysis across all consumer analytics events.',
  column_descriptions (
    __METADATA = 'Internal metadata field for tracking data lineage and versioning',
    COUNTRY_CODE = 'Two-letter ISO 3166-1 alpha-2 country code (e.g., US, CN, GB, DE, JP) - Primary key for geographic lookup',
    COUNTRY_NAME = 'Full country name in English (e.g., United States, China, United Kingdom, Germany, Japan)',
    REGION_KEY = 'Business region code identifier (e.g., NA for North America, EMEA for Europe Middle East Africa, APAC for Asia Pacific)',
    REGION = 'Business region name (e.g., North America, Europe Middle East Africa, Asia Pacific, Latin America)',
    SUB_REGION_KEY = 'Sub-region code for more granular geographic classification within major regions',
    SUB_REGION = 'Sub-region name for detailed geographic segmentation (e.g., Western Europe, Southeast Asia, Caribbean)',
    ADDITIONAL1_KEY = 'First additional classification key for custom geographic groupings or market-specific categorization',
    ADDITIONAL1 = 'First additional classification value for custom geographic groupings',
    ADDITIONAL2_KEY = 'Second additional classification key for extended geographic attributes or business-specific segments',
    ADDITIONAL2 = 'Second additional classification value for extended geographic attributes'
  ),
  column_tags (
    __METADATA = ('system-metadata', 'audit', 'internal'),
    COUNTRY_CODE = ('iso-code', 'primary-key', 'reference-data', 'grain', 'identifier'),
    COUNTRY_NAME = ('geography', 'display-name', 'reference-data'),
    REGION_KEY = ('business-region', 'hierarchy-key', 'reference-data'),
    REGION = ('business-region', 'hierarchy-display', 'reference-data'),
    SUB_REGION_KEY = ('sub-region', 'hierarchy-key', 'reference-data'),
    SUB_REGION = ('sub-region', 'hierarchy-display', 'reference-data'),
    ADDITIONAL1_KEY = ('custom-grouping', 'extensible', 'optional'),
    ADDITIONAL1 = ('custom-grouping', 'extensible', 'optional'),
    ADDITIONAL2_KEY = ('custom-grouping', 'extensible', 'optional'),
    ADDITIONAL2 = ('custom-grouping', 'extensible', 'optional')
  ),
  column_terms (
    __METADATA = ('metadata', 'lineage'),
    COUNTRY_CODE = ('country_code', 'iso_code'),
    COUNTRY_NAME = ('country_name', 'country'),
    REGION_KEY = ('region_key', 'business_region_code'),
    REGION = ('region', 'business_region'),
    SUB_REGION_KEY = ('sub_region_key', 'sub_region_code'),
    SUB_REGION = ('sub_region', 'sub_region_name'),
    ADDITIONAL1_KEY = ('additional_classification_1_key', 'custom_grouping_1_key'),
    ADDITIONAL1 = ('additional_classification_1', 'custom_grouping_1'),
    ADDITIONAL2_KEY = ('additional_classification_2_key', 'custom_grouping_2_key'),
    ADDITIONAL2 = ('additional_classification_2', 'custom_grouping_2')
  )
)