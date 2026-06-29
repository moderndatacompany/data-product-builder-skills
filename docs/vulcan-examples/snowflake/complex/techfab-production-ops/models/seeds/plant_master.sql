MODEL (
  name MES_PLATFORM.SEED.PLANT_MASTER,
  kind SEED (
    path '../../seeds/plant_master.csv'
  ),
  columns (
    plant_code VARCHAR(10),
    plant_name VARCHAR(100),
    location VARCHAR(100),
    region VARCHAR(20),
    plant_manager VARCHAR(100),
    production_capacity_annual INTEGER,
    operating_shifts INTEGER,
    established_date DATE
  ),
  grain PLANT_CODE,
  owner 'shreyasikarwartmdcio',
  profiles (PLANT_CODE, PLANT_NAME, REGION, OPERATING_SHIFTS),
  tags ('reference-data', 'dimension', 'master-data', 'plant', 'location', 'seed-data', 'manufacturing'),
  terms ('reference_data', 'plant_dimension', 'master_data', 'manufacturing_location'),
  description 'Plant master dimension containing reference data for all TechFab manufacturing plants. Provides hierarchical plant-to-region mappings, operational capacity, and facility management details for standardizing plant analytics across all production operations.',
  
  column_descriptions (
    PLANT_CODE = 'Unique plant identifier code (P01-P10) - Primary key for plant lookup and reference across all production systems',
    PLANT_NAME = 'Official registered plant name for business reporting (e.g., Phoenix Manufacturing Center, Austin Assembly Plant)',
    LOCATION = 'Physical location address with city and state (e.g., "Phoenix, AZ", "Austin, TX") for geographic analysis',
    REGION = 'Geographic business region classification (West, East, South, Midwest) for regional performance comparisons and reporting',
    PLANT_MANAGER = 'Full name of plant manager responsible for facility operations and production oversight',
    PRODUCTION_CAPACITY_ANNUAL = 'Maximum annual production capacity in units - theoretical capacity used for utilization and efficiency calculations',
    OPERATING_SHIFTS = 'Number of active production shifts per day (2 or 3 shifts) - determines operational coverage and scheduling constraints',
    ESTABLISHED_DATE = 'Date when plant facility was established and became operational - used for plant maturity analysis'
  ),
  
  column_tags (
    PLANT_CODE = ('identifier', 'primary-key', 'reference-data', 'grain', 'unique', 'business-key'),
    PLANT_NAME = ('display-name', 'business-name', 'reference-data', 'descriptive'),
    LOCATION = ('geography', 'address', 'physical-location', 'reference-data'),
    REGION = ('geography', 'business-region', 'hierarchy', 'grouping', 'classification'),
    PLANT_MANAGER = ('person', 'contact', 'owner', 'management'),
    PRODUCTION_CAPACITY_ANNUAL = ('capacity', 'target', 'measure', 'planning', 'theoretical'),
    OPERATING_SHIFTS = ('operational-config', 'scheduling', 'capacity-planning', 'shift-pattern'),
    ESTABLISHED_DATE = ('temporal', 'metadata', 'milestone', 'audit', 'historical')
  ),
  
  column_terms (
    PLANT_CODE = ('plant_code', 'facility_code', 'plant_id'),
    PLANT_NAME = ('plant_name', 'facility_name', 'plant_description'),
    LOCATION = ('plant_location', 'facility_address', 'geographic_location'),
    REGION = ('plant_region', 'business_region', 'geographic_region'),
    PLANT_MANAGER = ('plant_manager', 'facility_manager', 'operations_manager'),
    PRODUCTION_CAPACITY_ANNUAL = ('annual_capacity', 'theoretical_capacity', 'max_capacity'),
    OPERATING_SHIFTS = ('shift_count', 'shift_pattern', 'operational_shifts'),
    ESTABLISHED_DATE = ('established_date', 'start_date', 'commissioning_date')
  )
);
