MODEL (
  name QMS_PLATFORM.GOLD.FCT_QUALITY_METRICS,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [INSPECTION_ID],
  description 'Inspection-level quality data with pass/fail status, defect details, and scrap cost. Aggregation (totals, defect rates, first pass yield, cost of quality) is handled by the semantic layer.',
  tags ('gold', 'fact', 'quality-metrics', 'inspections'),
  terms ('quality-metrics', 'first-pass-yield', 'cost-of-quality'),
  columns (
    inspection_id INTEGER,
    inspection_date DATE,
    inspection_type VARCHAR(50),
    material_number VARCHAR(50),
    lot_number VARCHAR(50),
    inspector_id VARCHAR(20),
    defect_code VARCHAR(20),
    defect_category VARCHAR(50),
    severity VARCHAR(20),
    sample_size INTEGER,
    defects_found INTEGER,
    pass_fail_status VARCHAR(20),
    scrap_cost_usd DECIMAL(15,2),
    calculated_at TIMESTAMP
  ),

  column_descriptions (
    inspection_id = 'Unique inspection identifier (PK)',
    inspection_date = 'Date of quality inspection',
    inspection_type = 'Type of inspection: Incoming, In-Process, Final',
    material_number = 'Product material number inspected',
    lot_number = 'Lot or batch number inspected',
    inspector_id = 'Inspector who conducted the inspection',
    defect_code = 'Defect code (FK to defect_codes seed)',
    defect_category = 'Defect category from defect_codes (Dimensional, Functional, Cosmetic, Assembly)',
    severity = 'Defect severity from defect_codes (Critical, Major, Minor)',
    sample_size = 'Number of units inspected in this inspection',
    defects_found = 'Number of defects found in this inspection',
    pass_fail_status = 'Inspection result: Pass, Fail, Conditional',
    scrap_cost_usd = 'Estimated scrap cost (defects_found * standard_cost_usd from defect_codes)',
    calculated_at = 'Record calculation timestamp'
  ),

  column_tags (
    inspection_id = ('identifier', 'primary-key', 'grain'),
    inspection_date = ('temporal', 'date', 'partition'),
    inspection_type = ('category', 'dimension', 'inspection'),
    material_number = ('material', 'dimension', 'product'),
    lot_number = ('lot', 'dimension', 'batch'),
    inspector_id = ('inspector', 'dimension', 'personnel'),
    defect_code = ('foreign-key', 'defect', 'reference'),
    defect_category = ('category', 'dimension', 'defect'),
    severity = ('severity', 'dimension', 'priority'),
    sample_size = ('quantity', 'measure'),
    defects_found = ('quantity', 'measure', 'defect'),
    pass_fail_status = ('status', 'dimension', 'quality'),
    scrap_cost_usd = ('cost', 'measure', 'financial'),
    calculated_at = ('temporal', 'audit', 'metadata')
  ),

  assertions (
    not_null(columns := (inspection_id, inspection_date, material_number, pass_fail_status)),
    unique_values(columns := (inspection_id)),
    forall(criteria := (sample_size >= 0, defects_found >= 0, scrap_cost_usd >= 0))
  ),

  profiles (INSPECTION_ID, INSPECTION_DATE, INSPECTION_TYPE, MATERIAL_NUMBER, LOT_NUMBER, INSPECTOR_ID, DEFECT_CODE, DEFECT_CATEGORY, SEVERITY, SAMPLE_SIZE, DEFECTS_FOUND, PASS_FAIL_STATUS, SCRAP_COST_USD, CALCULATED_AT)
);

SELECT
  ir."inspection_id"::INTEGER AS inspection_id,
  ir."inspection_date"::DATE AS inspection_date,
  ir."inspection_type"::VARCHAR(50) AS inspection_type,
  ir."material_number"::VARCHAR(50) AS material_number,
  ir."lot_number"::VARCHAR(50) AS lot_number,
  ir."inspector_id"::VARCHAR(20) AS inspector_id,
  ir."defect_code"::VARCHAR(20) AS defect_code,
  COALESCE(dc.DEFECT_CATEGORY, 'Unknown')::VARCHAR(50) AS defect_category,
  COALESCE(dc.SEVERITY, 'Unknown')::VARCHAR(20) AS severity,
  ir."sample_size"::INTEGER AS sample_size,
  ir."defects_found"::INTEGER AS defects_found,
  ir."pass_fail_status"::VARCHAR(20) AS pass_fail_status,
  ROUND(COALESCE(ir."defects_found" * dc.STANDARD_COST_USD, 0), 2) AS scrap_cost_usd,
  CURRENT_TIMESTAMP() AS calculated_at
FROM QMS_PLATFORM.BRONZE.QUALITY_INSPECTIONS ir
LEFT JOIN QMS_PLATFORM.SEED.DEFECT_CODES dc ON ir."defect_code" = dc.DEFECT_CODE
ORDER BY inspection_date DESC;

