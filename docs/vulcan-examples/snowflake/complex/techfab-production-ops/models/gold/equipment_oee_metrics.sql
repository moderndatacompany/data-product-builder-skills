MODEL (
  name MES_PLATFORM.GOLD.EQUIPMENT_OEE_METRICS,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [EQUIPMENT_ID, METRIC_DATE],
  description 'Gold layer equipment OEE (Overall Equipment Effectiveness) metrics calculating availability, performance, and quality components by equipment and date for predictive maintenance and asset optimization',
  tags ('gold', 'aggregated', 'equipment', 'oee', 'maintenance', 'kpi'),
  terms ('equipment_effectiveness', 'oee_metrics', 'asset_performance'),
  columns (
    equipment_id VARCHAR(20),
    equipment_name VARCHAR(100),
    equipment_type VARCHAR(50),
    plant_code VARCHAR(10),
    plant_name VARCHAR(100),
    metric_date DATE,
    total_production_runs INTEGER,
    total_downtime_events INTEGER,
    total_planned_downtime_hours FLOAT,
    total_unplanned_downtime_hours FLOAT,
    total_downtime_hours FLOAT,
    total_production_hours FLOAT,
    availability_pct FLOAT,
    performance_pct FLOAT,
    quality_pct FLOAT,
    oee_pct FLOAT,
    good_units INTEGER,
    total_units INTEGER,
    mttr_hours FLOAT,
    mtbf_hours FLOAT,
    oee_world_class BOOLEAN,
    oee_good BOOLEAN,
    availability_good BOOLEAN
  ),
  column_descriptions (
    equipment_id = 'Unique equipment identifier with plant prefix (format: EQ-plant_code sequence) - Primary key for equipment tracking and reference across all manufacturing systems',
    equipment_name = 'Equipment name',
    equipment_type = 'Type of equipment',
    plant_code = 'Plant identifier',
    plant_name = 'Plant name',
    metric_date = 'Production date',
    total_production_runs = 'Total production confirmations',
    total_downtime_events = 'Total downtime events',
    total_planned_downtime_hours = 'Total planned downtime in hours',
    total_unplanned_downtime_hours = 'Total unplanned downtime in hours',
    total_downtime_hours = 'Total downtime in hours',
    total_production_hours = 'Total production time in hours',
  ),
  
  column_tags (
    equipment_id = ('identifier', 'dimension', 'grain'),
    metric_date = ('temporal', 'partition_key', 'grain'),
    availability_pct = ('measure', 'percentage', 'oee_component', 'kpi'),
    performance_pct = ('measure', 'percentage', 'oee_component', 'kpi'),
    quality_pct = ('measure', 'percentage', 'oee_component', 'kpi'),
    oee_pct = ('measure', 'percentage', 'kpi', 'primary'),
    mttr_hours = ('measure', 'duration', 'reliability'),
    mtbf_hours = ('measure', 'duration', 'reliability'),
    oee_world_class = ('flag', 'kpi', 'target')
  ),
  
  assertions (
    not_null(columns := (equipment_id, metric_date))  )
);

WITH production_metrics AS (
  SELECT
    equipment_id,
    equipment_name,
    equipment_type,
    plant_code,
    plant_name,
    confirmation_date AS metric_date,
    COUNT(DISTINCT confirmation_id) AS total_production_runs,
    SUM(duration_minutes) / 60.0 AS total_production_hours,
    SUM(good_quantity) AS good_units,
    SUM(total_quantity) AS total_units,
    AVG(first_pass_yield_pct) AS avg_quality_pct,
    AVG(efficiency_pct) AS avg_performance_pct
  FROM MES_PLATFORM.SILVER.PRODUCTION_ENRICHED
  GROUP BY equipment_id, equipment_name, equipment_type, plant_code, plant_name, confirmation_date
),

downtime_metrics AS (
  SELECT
    equipment_id,
    downtime_date AS metric_date,
    COUNT(DISTINCT downtime_id) AS total_downtime_events,
    SUM(CASE WHEN is_planned THEN duration_hours ELSE 0 END) AS total_planned_downtime_hours,
    SUM(CASE WHEN is_unplanned THEN duration_hours ELSE 0 END) AS total_unplanned_downtime_hours,
    SUM(duration_hours) AS total_downtime_hours,
    CASE 
      WHEN SUM(CASE WHEN is_unplanned THEN 1 ELSE 0 END) > 0 
      THEN SUM(CASE WHEN is_unplanned THEN duration_hours ELSE 0 END) / SUM(CASE WHEN is_unplanned THEN 1 ELSE 0 END)
      ELSE 0 
    END AS mttr_hours,
    CASE 
      WHEN SUM(CASE WHEN is_equipment_failure THEN 1 ELSE 0 END) > 1
      THEN (MAX(metric_date) - MIN(metric_date)) * 24.0 / SUM(CASE WHEN is_equipment_failure THEN 1 ELSE 0 END)
      ELSE 0
    END AS mtbf_hours
    FROM MES_PLATFORM.SILVER.DOWNTIME_ENRICHED
  GROUP BY equipment_id, downtime_date
),

oee_calculation AS (
  SELECT
    p.equipment_id,
    p.equipment_name,
    p.equipment_type,
    p.plant_code,
    p.plant_name,
    p.metric_date,
    p.total_production_runs,
    COALESCE(d.total_downtime_events, 0) AS total_downtime_events,
    COALESCE(d.total_planned_downtime_hours, 0) AS total_planned_downtime_hours,
    COALESCE(d.total_unplanned_downtime_hours, 0) AS total_unplanned_downtime_hours,
    COALESCE(d.total_downtime_hours, 0) AS total_downtime_hours,
    p.total_production_hours,
    
    -- OEE Component 1: Availability (Operating Time / Planned Production Time)
    CASE 
      WHEN (p.total_production_hours + COALESCE(d.total_unplanned_downtime_hours, 0)) > 0
      THEN ROUND((p.total_production_hours / (p.total_production_hours + COALESCE(d.total_unplanned_downtime_hours, 0))) * 100, 2)
      ELSE 0 
    END AS availability_pct,
    
    -- OEE Component 2: Performance (already calculated as efficiency)
    ROUND(p.avg_performance_pct, 2) AS performance_pct,
    
    -- OEE Component 3: Quality (Good Units / Total Units)
    ROUND(p.avg_quality_pct, 2) AS quality_pct,
    
    p.good_units,
    p.total_units,
    COALESCE(d.mttr_hours, 0) AS mttr_hours,
    COALESCE(d.mtbf_hours, 0) AS mtbf_hours
    
  FROM production_metrics p
  LEFT JOIN downtime_metrics d ON p.equipment_id = d.equipment_id AND p.metric_date = d.metric_date
)

SELECT
  *,
  -- Overall Equipment Effectiveness = Availability × Performance × Quality
  ROUND((availability_pct / 100.0) * (performance_pct / 100.0) * (quality_pct / 100.0) * 100, 2) AS oee_pct,
  
  -- Target achievement flags
  CASE 
    WHEN ((availability_pct / 100.0) * (performance_pct / 100.0) * (quality_pct / 100.0) * 100) >= 85 
    THEN TRUE ELSE FALSE 
  END AS oee_world_class,
  CASE 
    WHEN ((availability_pct / 100.0) * (performance_pct / 100.0) * (quality_pct / 100.0) * 100) >= 70 
    THEN TRUE ELSE FALSE 
  END AS oee_good,
  CASE WHEN availability_pct >= 90 THEN TRUE ELSE FALSE END AS availability_good
  
FROM oee_calculation
ORDER BY metric_date DESC, oee_pct DESC;

