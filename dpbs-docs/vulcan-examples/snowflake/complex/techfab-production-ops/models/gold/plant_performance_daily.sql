MODEL (
  name MES_PLATFORM.GOLD.PLANT_PERFORMANCE_DAILY,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [PLANT_CODE, CONFIRMATION_DATE],
  description 'Gold layer daily plant performance metrics aggregating production output, quality indicators, and efficiency metrics by plant and date for executive dashboards and plant benchmarking',
  tags ('gold', 'aggregated', 'plant', 'performance', 'kpi'),
  terms ('plant_performance', 'daily_metrics', 'operational_kpi'),
  columns (
    plant_code VARCHAR(10),
    plant_name VARCHAR(100),
    plant_region VARCHAR(20),
    confirmation_date DATE,
    total_confirmations INTEGER,
    total_good_quantity INTEGER,
    total_scrap_quantity INTEGER,
    total_rework_quantity INTEGER,
    total_quantity INTEGER,
    avg_scrap_rate_pct FLOAT,
    avg_rework_rate_pct FLOAT,
    avg_first_pass_yield_pct FLOAT,
    avg_efficiency_pct FLOAT,
    total_production_hours FLOAT,
    avg_units_per_hour FLOAT,
    unique_equipment_used INTEGER,
    unique_operators INTEGER,
    s1_confirmations INTEGER,
    s2_confirmations INTEGER,
    s3_confirmations INTEGER,
    quality_target_met BOOLEAN,
    efficiency_target_met BOOLEAN
  ),
  
  column_descriptions (
    plant_code = 'Plant identifier',
    plant_name = 'Official plant name',
    plant_region = 'Geographic region',
    confirmation_date = 'Production date',
    total_confirmations = 'Total number of production confirmations',
    total_good_quantity = 'Total good units produced',
    total_scrap_quantity = 'Total scrapped units',
    total_rework_quantity = 'Total reworked units',
    total_quantity = 'Total units processed',
    avg_scrap_rate_pct = 'Average scrap rate percentage',
    avg_rework_rate_pct = 'Average rework rate percentage',
    avg_first_pass_yield_pct = 'Average first pass yield percentage',
    avg_efficiency_pct = 'Average equipment efficiency percentage',
    total_production_hours = 'Total production duration in hours',
    avg_units_per_hour = 'Average production rate (units/hour)',
    unique_equipment_used = 'Number of unique equipment used',
    unique_operators = 'Number of unique operators',
    s1_confirmations = 'Shift 1 confirmations',
    s2_confirmations = 'Shift 2 confirmations',
    s3_confirmations = 'Shift 3 confirmations',
    quality_target_met = 'Boolean: TRUE if scrap rate < 4%',
    efficiency_target_met = 'Boolean: TRUE if efficiency > 80%'
  ),
  
  column_tags (
    plant_code = ('identifier', 'dimension', 'grain'),
    confirmation_date = ('temporal', 'partition_key', 'grain'),
    total_good_quantity = ('measure', 'count', 'performance'),
    avg_scrap_rate_pct = ('measure', 'percentage', 'kpi', 'quality'),
    avg_first_pass_yield_pct = ('measure', 'percentage', 'kpi', 'quality'),
    avg_efficiency_pct = ('measure', 'percentage', 'kpi', 'performance'),
    quality_target_met = ('flag', 'kpi', 'target'),
    efficiency_target_met = ('flag', 'kpi', 'target')
  ),
  
  assertions (
    not_null(columns := (plant_code, confirmation_date)),
    accepted_range(column := avg_scrap_rate_pct, min_v := 0, max_v := 100)
  )
);

SELECT
  plant_code,
  plant_name,
  plant_region,
  confirmation_date,
  
  -- Production metrics
  COUNT(DISTINCT confirmation_id) AS total_confirmations,
  SUM(good_quantity) AS total_good_quantity,
  SUM(scrap_quantity) AS total_scrap_quantity,
  SUM(rework_quantity) AS total_rework_quantity,
  SUM(total_quantity) AS total_quantity,
  
  -- Quality metrics (KPIs)
  ROUND(AVG(scrap_rate_pct), 2) AS avg_scrap_rate_pct,
  ROUND(AVG(rework_rate_pct), 2) AS avg_rework_rate_pct,
  ROUND(AVG(first_pass_yield_pct), 2) AS avg_first_pass_yield_pct,
  
  -- Efficiency metrics
  ROUND(AVG(efficiency_pct), 2) AS avg_efficiency_pct,
  ROUND(SUM(duration_minutes) / 60.0, 2) AS total_production_hours,
  ROUND(AVG(units_per_hour), 2) AS avg_units_per_hour,
  
  -- Resource utilization
  COUNT(DISTINCT equipment_id) AS unique_equipment_used,
  COUNT(DISTINCT operator_id) AS unique_operators,
  
  -- Shift distribution
  SUM(CASE WHEN shift = 'S1' THEN 1 ELSE 0 END) AS s1_confirmations,
  SUM(CASE WHEN shift = 'S2' THEN 1 ELSE 0 END) AS s2_confirmations,
  SUM(CASE WHEN shift = 'S3' THEN 1 ELSE 0 END) AS s3_confirmations,
  
  -- Target achievement flags
  CASE WHEN AVG(scrap_rate_pct) < 4.0 THEN TRUE ELSE FALSE END AS quality_target_met,
  CASE WHEN AVG(efficiency_pct) > 80.0 THEN TRUE ELSE FALSE END AS efficiency_target_met
  
FROM MES_PLATFORM.SILVER.PRODUCTION_ENRICHED
GROUP BY plant_code, plant_name, plant_region, confirmation_date
ORDER BY confirmation_date DESC, plant_code;

