MODEL (
  name lenovo.ldo.issue,
  kind SEED (
    path '../seeds/issue.csv'
  ),
  columns (
    issue_uuid STRING,
    bucket_id STRING,
    incident_category STRING,
    error_code STRING,
    details STRING,
    hardware_id STRING,
    reported_at STRING,
    resolved_at STRING,
    incident_status STRING,
    timeline STRING,
    updated_at STRING,
    value STRING,
    battery_id STRING,
    device_id STRING,
    insight_id STRING,
    storage_id STRING,
    generate_ticket STRING,
    has_ticket STRING,
    is_hidden STRING,
    insight_item_id STRING,
    resolved_by_user_at STRING
  ),
  grains (ISSUE_UUID)
);

