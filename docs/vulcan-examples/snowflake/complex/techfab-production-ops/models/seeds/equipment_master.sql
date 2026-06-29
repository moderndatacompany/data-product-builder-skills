MODEL (
  name MES_PLATFORM.SEED.EQUIPMENT_MASTER,
  kind SEED (
    path '../../seeds/equipment_master.csv'
  ),
  columns (
    equipment_id VARCHAR(20),
    equipment_name VARCHAR(100),
    equipment_type VARCHAR(50),
    plant_code VARCHAR(10),
    work_center VARCHAR(20),
    manufacturer VARCHAR(100),
    acquisition_date DATE,
    theoretical_capacity_hour INTEGER,
    installation_status VARCHAR(20)
  ),
  grain EQUIPMENT_ID,
  owner 'shreyasikarwartmdcio',
  profiles (EQUIPMENT_ID, EQUIPMENT_NAME, EQUIPMENT_TYPE, PLANT_CODE, WORK_CENTER, INSTALLATION_STATUS),
  tags ('reference-data', 'dimension', 'master-data', 'equipment', 'asset', 'seed-data', 'manufacturing', 'oee'),
  terms ('reference_data', 'equipment_dimension', 'asset_master', 'manufacturing_asset'),
  description 'Equipment master dimension containing reference data for 1,250 manufacturing equipment items across 10 plants. Provides comprehensive asset catalog including equipment specifications, work center assignments, capacity ratings, and maintenance status for OEE analysis, capacity planning, and asset lifecycle management.',
  
  column_descriptions (
    EQUIPMENT_ID = 'Unique equipment identifier with plant prefix (format: EQ- plant_code - sequence ) - Primary key for equipment tracking and reference across all manufacturing systems',
    EQUIPMENT_NAME = 'Equipment name/designation for business reporting and operational identification (e.g., SMT Line Alpha, Reflow Oven A, AOI Inspector 1)',
    EQUIPMENT_TYPE = 'Equipment type classification for capability grouping (SMT Assembly, Soldering, Test Station, Pick and Place, Inspection, Coating, Printing, Reflow, Wave Solder, X-Ray)',
    PLANT_CODE = 'Plant code where equipment is physically installed (P01-P10) - Foreign key to plant_master for plant-equipment relationship',
    WORK_CENTER = 'Work center assignment identifier (format: WC- type - sequence ) - defines operational area and production cell for scheduling and routing',
    MANUFACTURER = 'Equipment manufacturer/vendor name (e.g., Fuji Corporation, Panasonic, Yamaha, Keysight) - used for maintenance support and warranty tracking',
    ACQUISITION_DATE = 'Date equipment was acquired/purchased by the organization - used for depreciation calculations and asset age analysis',
    THEORETICAL_CAPACITY_HOUR = 'Theoretical maximum production capacity in units per hour under ideal conditions - baseline for performance and efficiency calculations in OEE analysis',
    INSTALLATION_STATUS = 'Current operational status of equipment (Active, Maintenance) - determines availability for production scheduling and capacity planning'
  ),
  
  column_tags (
    EQUIPMENT_ID = ('identifier', 'primary-key', 'reference-data', 'grain', 'unique', 'business-key', 'asset-id'),
    EQUIPMENT_NAME = ('display-name', 'asset-name', 'reference-data', 'descriptive'),
    EQUIPMENT_TYPE = ('classification', 'category', 'capability', 'grouping', 'hierarchy'),
    PLANT_CODE = ('foreign-key', 'relationship', 'reference-data', 'location', 'organizational'),
    WORK_CENTER = ('organizational', 'grouping', 'scheduling', 'routing', 'production-area'),
    MANUFACTURER = ('vendor', 'supplier', 'external-party', 'maintenance-support'),
    ACQUISITION_DATE = ('temporal', 'metadata', 'financial', 'audit', 'asset-lifecycle'),
    THEORETICAL_CAPACITY_HOUR = ('capacity', 'performance', 'target', 'planning', 'oee-baseline', 'measure'),
    INSTALLATION_STATUS = ('status', 'operational-state', 'availability', 'classification', 'maintenance')
  ),
  
  column_terms (
    EQUIPMENT_ID = ('equipment_id', 'asset_id', 'equipment_code'),
    EQUIPMENT_NAME = ('equipment_name', 'asset_name', 'equipment_description'),
    EQUIPMENT_TYPE = ('equipment_type', 'asset_type', 'equipment_category'),
    PLANT_CODE = ('plant_code', 'facility_code', 'location_code'),
    WORK_CENTER = ('work_center', 'production_cell', 'manufacturing_area'),
    MANUFACTURER = ('manufacturer', 'vendor', 'supplier', 'oem'),
    ACQUISITION_DATE = ('acquisition_date', 'purchase_date', 'install_date'),
    THEORETICAL_CAPACITY_HOUR = ('theoretical_capacity', 'max_capacity', 'rated_capacity', 'units_per_hour'),
    INSTALLATION_STATUS = ('status', 'operational_status', 'equipment_status')
  )
);
