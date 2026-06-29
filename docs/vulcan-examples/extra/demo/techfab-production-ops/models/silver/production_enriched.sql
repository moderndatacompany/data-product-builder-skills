MODEL (
  name MES_PLATFORM.SILVER.PRODUCTION_ENRICHED,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [confirmation_id],
  description 'Silver layer enriched production data joining production output with plant and equipment master data, calculating quality metrics and performance indicators for operational analytics',
  tags ('silver', 'fact', 'production', 'enriched', 'quality_metrics'),
  terms ('production', 'manufacturing_output', 'quality_tracking'),
  columns (
    confirmation_id INTEGER,
    work_order_id INTEGER,
    plant_code VARCHAR(10),
    plant_name VARCHAR(100),
    plant_region VARCHAR(20),
    work_center VARCHAR(20),
    equipment_id VARCHAR(20),
    equipment_name VARCHAR(100),
    equipment_type VARCHAR(50),
    manufacturer VARCHAR(100),
    material_number VARCHAR(50),
    confirmation_date DATE,
    shift VARCHAR(10),
    good_quantity INTEGER,
    scrap_quantity INTEGER,
    rework_quantity INTEGER,
    total_quantity INTEGER,
    scrap_rate_pct FLOAT,
    rework_rate_pct FLOAT,
    first_pass_yield_pct FLOAT,
    confirmation_timestamp TIMESTAMP,
    operator_id VARCHAR(20),
    duration_minutes INTEGER,
    units_per_hour FLOAT,
    theoretical_capacity_hour INTEGER,
    efficiency_pct FLOAT
  ),
  
  column_descriptions (
    confirmation_id = 'Unique production confirmation identifier (PK)',
    work_order_id = 'Work order reference number',
    plant_code = 'Plant where production occurred',
    plant_name = 'Official plant name',
    plant_region = 'Geographic region (West, East, South, Midwest)',
    work_center = 'Work center where production took place',
    equipment_id = 'Equipment used for production',
    equipment_name = 'Equipment name/designation',
    equipment_type = 'Type of equipment',
    manufacturer = 'Equipment manufacturer',
    material_number = 'Material/product code being produced',
    confirmation_date = 'Date of production confirmation',
    shift = 'Production shift (S1=Day, S2=Evening, S3=Night)',
    good_quantity = 'Number of good/accepted units produced',
    scrap_quantity = 'Number of scrapped units',
    rework_quantity = 'Number of units requiring rework',
    total_quantity = 'Total units processed (good + scrap + rework)',
    scrap_rate_pct = 'Scrap percentage of total units',
    rework_rate_pct = 'Rework percentage of total units',
    first_pass_yield_pct = 'First pass yield percentage (good / total)',
    confirmation_timestamp = 'Exact timestamp of confirmation',
    operator_id = 'Operator who confirmed production',
    duration_minutes = 'Production duration in minutes',
    units_per_hour = 'Production rate (good quantity / duration hours)',
    theoretical_capacity_hour = 'Theoretical equipment capacity per hour',
    efficiency_pct = 'Efficiency percentage (actual vs theoretical capacity)'
  ),
  
  column_tags (
    confirmation_id = ('identifier', 'primary_key', 'grain'),
    plant_code = ('foreign_key', 'dimension', 'organizational'),
    plant_region = ('geographic', 'grouping'),
    equipment_id = ('foreign_key', 'dimension', 'asset'),
    equipment_type = ('classification', 'category'),
    confirmation_date = ('temporal', 'partition_key'),
    shift = ('temporal', 'grouping'),
    good_quantity = ('measure', 'count', 'performance'),
    scrap_quantity = ('measure', 'count', 'quality'),
    rework_quantity = ('measure', 'count', 'quality'),
    total_quantity = ('measure', 'count', 'derived'),
    scrap_rate_pct = ('measure', 'percentage', 'kpi', 'quality'),
    rework_rate_pct = ('measure', 'percentage', 'kpi', 'quality'),
    first_pass_yield_pct = ('measure', 'percentage', 'kpi', 'quality'),
    units_per_hour = ('measure', 'rate', 'productivity'),
    efficiency_pct = ('measure', 'percentage', 'kpi', 'performance')
  ),
  
  assertions (
    not_null(columns := (confirmation_id, plant_code, equipment_id, confirmation_date)),
    unique_values(columns := (confirmation_id)),
    forall(criteria := (total_quantity >= 0)),
    accepted_range(column := scrap_rate_pct, min_v := 0, max_v := 100),
    accepted_range(column := first_pass_yield_pct, min_v := 0, max_v := 100)
  ),
  
  profiles (
    count_records(name := 'row_count'),
    duplicate_count(columns := (confirmation_id)),
    missing_count(columns := (confirmation_id, plant_code, equipment_id)),
    profile_min(columns := (scrap_rate_pct, rework_rate_pct, first_pass_yield_pct, efficiency_pct)),
    profile_max(columns := (scrap_rate_pct, rework_rate_pct, first_pass_yield_pct, efficiency_pct)),
    profile_mean(columns := (scrap_rate_pct, first_pass_yield_pct, efficiency_pct))
  )
);

WITH production_base AS (
SELECT
  "confirmation_id"::INTEGER AS confirmation_id,
  "work_order_id"::INTEGER AS work_order_id,
  "plant_code"::VARCHAR(10) AS plant_code,
  "work_center"::VARCHAR(20) AS work_center,
  "equipment_id"::VARCHAR(20) AS equipment_id,
  "material_number"::VARCHAR(50) AS material_number,
  "confirmation_date"::DATE AS confirmation_date,
  "shift"::VARCHAR(10) AS shift,
  "good_quantity"::INTEGER AS good_quantity,
  "scrap_quantity"::INTEGER AS scrap_quantity,
  "rework_quantity"::INTEGER AS rework_quantity,
  "confirmation_timestamp"::TIMESTAMP AS confirmation_timestamp,
  "operator_id"::VARCHAR(20) AS operator_id,
  "duration_minutes"::INTEGER AS duration_minutes
FROM MES_PLATFORM.BRONZE.ACTUAL_PRODUCTION_OUTPUT
),

plant_data AS (
  SELECT
    plant_code,
    plant_name,
    region AS plant_region
  FROM MES_PLATFORM.SEED.PLANT_MASTER
),

equipment_data AS (
  SELECT
    equipment_id,
    equipment_name,
    equipment_type,
    manufacturer,
    theoretical_capacity_hour
  FROM MES_PLATFORM.SEED.EQUIPMENT_MASTER
),

enriched AS (
  SELECT
    p.confirmation_id,
    p.work_order_id,
    p.plant_code,
    pl.plant_name,
    pl.plant_region,
    p.work_center,
    p.equipment_id,
    e.equipment_name,
    e.equipment_type,
    e.manufacturer,
    p.material_number,
    p.confirmation_date,
    p.shift,
    p.good_quantity,
    p.scrap_quantity,
    p.rework_quantity,
    (p.good_quantity + p.scrap_quantity + p.rework_quantity) AS total_quantity,
    CASE 
      WHEN (p.good_quantity + p.scrap_quantity + p.rework_quantity) > 0 
      THEN ROUND((p.scrap_quantity * 100.0) / (p.good_quantity + p.scrap_quantity + p.rework_quantity), 2)
      ELSE 0 
    END AS scrap_rate_pct,
    CASE 
      WHEN (p.good_quantity + p.scrap_quantity + p.rework_quantity) > 0 
      THEN ROUND((p.rework_quantity * 100.0) / (p.good_quantity + p.scrap_quantity + p.rework_quantity), 2)
      ELSE 0 
    END AS rework_rate_pct,
    CASE 
      WHEN (p.good_quantity + p.scrap_quantity + p.rework_quantity) > 0 
      THEN ROUND((p.good_quantity * 100.0) / (p.good_quantity + p.scrap_quantity + p.rework_quantity), 2)
      ELSE 0 
    END AS first_pass_yield_pct,
    p.confirmation_timestamp,
    p.operator_id,
    p.duration_minutes,
    CASE 
      WHEN p.duration_minutes > 0 
      THEN ROUND((p.good_quantity * 60.0) / p.duration_minutes, 2)
      ELSE 0 
    END AS units_per_hour,
    e.theoretical_capacity_hour,
    CASE 
      WHEN p.duration_minutes > 0 AND e.theoretical_capacity_hour > 0
      THEN ROUND(((p.good_quantity * 60.0) / p.duration_minutes / e.theoretical_capacity_hour) * 100, 2)
      ELSE 0 
    END AS efficiency_pct
  FROM production_base p
  LEFT JOIN plant_data pl ON p.plant_code = pl.plant_code
  LEFT JOIN equipment_data e ON p.equipment_id = e.equipment_id
)

SELECT * FROM enriched;

