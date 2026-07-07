MODEL (
  name QMS_PLATFORM.GOLD.FCT_SPC_MONITORING,
  kind FULL,
  cron '@daily',
  owner 'shreyasikarwartmdcio',
  grains [MEASUREMENT_ID],
  description 'Individual SPC measurement records with control and specification limits plus violation flags. Aggregation (averages, standard deviation, capability indices, violation counts, stability scores) is handled by the semantic layer.',
  tags ('gold', 'fact', 'spc', 'process-control'),
  terms ('spc-monitoring', 'process-capability', 'control-charts'),
  columns (
    measurement_id INTEGER,
    measurement_date DATE,
    equipment_id VARCHAR(20),
    material_number VARCHAR(50),
    parameter_name VARCHAR(100),
    measured_value DECIMAL(10,4),
    target_value DECIMAL(10,4),
    lower_spec_limit DECIMAL(10,4),
    upper_spec_limit DECIMAL(10,4),
    lower_control_limit DECIMAL(10,4),
    upper_control_limit DECIMAL(10,4),
    out_of_control_flag BOOLEAN,
    out_of_spec_flag BOOLEAN,
    calculated_at TIMESTAMP
  ),

  column_descriptions (
    measurement_id = 'Unique measurement identifier (PK)',
    measurement_date = 'Date of SPC measurement',
    equipment_id = 'Equipment identifier being monitored',
    material_number = 'Product material number being manufactured',
    parameter_name = 'Quality parameter measured (Dimension, Resistance, Temperature, etc.)',
    measured_value = 'Actual measured value',
    target_value = 'Target/nominal value for the parameter',
    lower_spec_limit = 'Lower specification limit (LSL)',
    upper_spec_limit = 'Upper specification limit (USL)',
    lower_control_limit = 'Lower control limit (LCL, 3-sigma)',
    upper_control_limit = 'Upper control limit (UCL, 3-sigma)',
    out_of_control_flag = 'Whether measurement is outside control limits',
    out_of_spec_flag = 'Whether measurement is outside specification limits',
    calculated_at = 'Record calculation timestamp'
  ),

  column_tags (
    measurement_id = ('identifier', 'primary-key', 'grain'),
    measurement_date = ('temporal', 'date', 'partition'),
    equipment_id = ('equipment', 'dimension', 'identifier'),
    material_number = ('material', 'dimension', 'product'),
    parameter_name = ('parameter', 'dimension', 'spc'),
    measured_value = ('measurement', 'measure', 'spc'),
    target_value = ('specification', 'reference'),
    lower_spec_limit = ('specification', 'limit', 'lower'),
    upper_spec_limit = ('specification', 'limit', 'upper'),
    lower_control_limit = ('control-limit', 'limit', 'lower'),
    upper_control_limit = ('control-limit', 'limit', 'upper'),
    out_of_control_flag = ('flag', 'alert', 'control'),
    out_of_spec_flag = ('flag', 'alert', 'specification'),
    calculated_at = ('temporal', 'audit', 'metadata')
  ),

  assertions (
    not_null(columns := (measurement_id, measurement_date, equipment_id, material_number, parameter_name, measured_value)),
    unique_values(columns := (measurement_id)),
    forall(criteria := (lower_spec_limit <= upper_spec_limit, lower_control_limit <= upper_control_limit))
  ),

  profiles (MEASUREMENT_ID, MEASUREMENT_DATE, EQUIPMENT_ID, MATERIAL_NUMBER, PARAMETER_NAME, MEASURED_VALUE, TARGET_VALUE, LOWER_SPEC_LIMIT, UPPER_SPEC_LIMIT, LOWER_CONTROL_LIMIT, UPPER_CONTROL_LIMIT, OUT_OF_CONTROL_FLAG, OUT_OF_SPEC_FLAG, CALCULATED_AT)
);

SELECT
  spc."measurement_id"::INTEGER AS measurement_id,
  spc."measurement_timestamp"::DATE AS measurement_date,
  spc."equipment_id"::VARCHAR(20) AS equipment_id,
  spc."material_number"::VARCHAR(50) AS material_number,
  spc."parameter_name"::VARCHAR(100) AS parameter_name,
  spc."measured_value"::DECIMAL(10,4) AS measured_value,
  spc."target_value"::DECIMAL(10,4) AS target_value,
  spc."lower_spec_limit"::DECIMAL(10,4) AS lower_spec_limit,
  spc."upper_spec_limit"::DECIMAL(10,4) AS upper_spec_limit,
  spc."lower_control_limit"::DECIMAL(10,4) AS lower_control_limit,
  spc."upper_control_limit"::DECIMAL(10,4) AS upper_control_limit,
  spc."out_of_control_flag"::BOOLEAN AS out_of_control_flag,
  spc."out_of_spec_flag"::BOOLEAN AS out_of_spec_flag,
  CURRENT_TIMESTAMP() AS calculated_at
FROM QMS_PLATFORM.BRONZE.SPC_DATA spc
ORDER BY measurement_date DESC;

