MODEL (
  name MES_PLATFORM.SILVER.DOWNTIME_ENRICHED,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [downtime_id],
  description 'Silver layer enriched downtime events data joining downtime with plant and equipment master data, calculating MTTR/MTBF metrics and categorizing by root cause for maintenance analytics',
  tags ('silver', 'fact', 'downtime', 'maintenance', 'enriched'),
  terms ('downtime', 'maintenance_tracking', 'reliability_metrics'),
  columns (
    downtime_id INTEGER,
    equipment_id VARCHAR(20),
    equipment_name VARCHAR(100),
    equipment_type VARCHAR(50),
    manufacturer VARCHAR(100),
    plant_code VARCHAR(10),
    plant_name VARCHAR(100),
    plant_region VARCHAR(20),
    downtime_start TIMESTAMP,
    downtime_end TIMESTAMP,
    downtime_date DATE,
    duration_minutes INTEGER,
    duration_hours FLOAT,
    downtime_category VARCHAR(20),
    downtime_reason VARCHAR(100),
    downtime_reason_detail TEXT,
    reported_by VARCHAR(20),
    is_planned BOOLEAN,
    is_unplanned BOOLEAN,
    is_equipment_failure BOOLEAN,
    is_material_shortage BOOLEAN,
    is_quality_hold BOOLEAN,
    is_pm BOOLEAN,
    severity VARCHAR(20)
  ),
  
  column_descriptions (
    downtime_id = 'Unique downtime event identifier (PK)',
    equipment_id = 'Equipment that experienced downtime',
    equipment_name = 'Equipment name/designation',
    equipment_type = 'Type of equipment',
    manufacturer = 'Equipment manufacturer',
    plant_code = 'Plant where downtime occurred',
    plant_name = 'Official plant name',
    plant_region = 'Geographic region',
    downtime_start = 'Timestamp when downtime started',
    downtime_end = 'Timestamp when downtime ended',
    downtime_date = 'Date of downtime event (derived from start)',
    duration_minutes = 'Total downtime duration in minutes',
    duration_hours = 'Total downtime duration in hours (derived)',
    downtime_category = 'Category: Planned or Unplanned',
    downtime_reason = 'High-level reason code',
    downtime_reason_detail = 'Detailed description of downtime cause',
    reported_by = 'Supervisor who reported the downtime',
    is_planned = 'Boolean flag: TRUE if planned downtime',
    is_unplanned = 'Boolean flag: TRUE if unplanned downtime',
    is_equipment_failure = 'Boolean flag: TRUE if reason is Equipment Failure',
    is_material_shortage = 'Boolean flag: TRUE if reason is Material Shortage',
    is_quality_hold = 'Boolean flag: TRUE if reason is Quality Hold',
    is_pm = 'Boolean flag: TRUE if reason is Preventive Maintenance',
    severity = 'Downtime severity classification based on duration'
  ),
  
  column_tags (
    downtime_id = ('identifier', 'primary_key', 'grain'),
    equipment_id = ('foreign_key', 'dimension', 'asset'),
    equipment_type = ('classification', 'category'),
    plant_code = ('foreign_key', 'dimension', 'organizational'),
    plant_region = ('geographic', 'grouping'),
    downtime_start = ('temporal', 'event_time'),
    downtime_date = ('temporal', 'partition_key'),
    duration_minutes = ('measure', 'duration', 'performance'),
    duration_hours = ('measure', 'duration', 'derived'),
    downtime_category = ('classification', 'category'),
    downtime_reason = ('classification', 'root_cause'),
    is_planned = ('flag', 'classification'),
    is_unplanned = ('flag', 'classification'),
    is_equipment_failure = ('flag', 'root_cause'),
    severity = ('classification', 'impact')
  ),
  
  assertions (
    not_null(columns := (downtime_id, equipment_id, plant_code, downtime_start)),
    unique_values(columns := (downtime_id)),
    accepted_values(column := downtime_category, is_in := ('Planned', 'Unplanned')),
    forall(criteria := (downtime_end >= downtime_start, duration_minutes > 0))
  ),
  
  profiles (
    count_records(name := 'row_count'),
    duplicate_count(columns := (downtime_id)),
    missing_count(columns := (downtime_id, equipment_id, plant_code)),
    profile_min(columns := (duration_minutes, duration_hours)),
    profile_max(columns := (duration_minutes, duration_hours)),
    profile_mean(columns := (duration_minutes, duration_hours))
  )
);

WITH downtime_base AS (
SELECT
  "downtime_id"::INTEGER AS downtime_id,
  "equipment_id"::VARCHAR(20) AS equipment_id,
  "plant_code"::VARCHAR(10) AS plant_code,
  "downtime_start"::TIMESTAMP AS downtime_start,
  "downtime_end"::TIMESTAMP AS downtime_end,
  "duration_minutes"::INTEGER AS duration_minutes,
  "downtime_category"::VARCHAR(20) AS downtime_category,
  "downtime_reason"::VARCHAR(100) AS downtime_reason,
  "downtime_reason_detail"::TEXT AS downtime_reason_detail,
  "reported_by"::VARCHAR(20) AS reported_by
FROM MES_PLATFORM.BRONZE.DOWNTIME_EVENTS
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
    manufacturer
  FROM MES_PLATFORM.SEED.EQUIPMENT_MASTER
),

enriched AS (
  SELECT
    d.downtime_id,
    d.equipment_id,
    e.equipment_name,
    e.equipment_type,
    e.manufacturer,
    d.plant_code,
    pl.plant_name,
    pl.plant_region,
    d.downtime_start,
    d.downtime_end,
    DATE(d.downtime_start) AS downtime_date,
    d.duration_minutes,
    ROUND(d.duration_minutes / 60.0, 2) AS duration_hours,
    d.downtime_category,
    d.downtime_reason,
    d.downtime_reason_detail,
    d.reported_by,
    
    -- Categorization flags
    CASE WHEN d.downtime_category = 'Planned' THEN TRUE ELSE FALSE END AS is_planned,
    CASE WHEN d.downtime_category = 'Unplanned' THEN TRUE ELSE FALSE END AS is_unplanned,
    CASE WHEN d.downtime_reason = 'Equipment Failure' THEN TRUE ELSE FALSE END AS is_equipment_failure,
    CASE WHEN d.downtime_reason = 'Material Shortage' THEN TRUE ELSE FALSE END AS is_material_shortage,
    CASE WHEN d.downtime_reason = 'Quality Hold' THEN TRUE ELSE FALSE END AS is_quality_hold,
    CASE WHEN d.downtime_reason = 'Preventive Maintenance' THEN TRUE ELSE FALSE END AS is_pm,
    
    -- Severity classification
    CASE 
      WHEN d.duration_minutes <= 30 THEN 'Low'
      WHEN d.duration_minutes <= 120 THEN 'Medium'
      WHEN d.duration_minutes <= 240 THEN 'High'
      ELSE 'Critical'
    END AS severity
    
  FROM downtime_base d
  LEFT JOIN plant_data pl ON d.plant_code = pl.plant_code
  LEFT JOIN equipment_data e ON d.equipment_id = e.equipment_id
)

SELECT * FROM enriched;

