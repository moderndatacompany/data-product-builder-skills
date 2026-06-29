MODEL (
  name lenovo.ldo.schedules_app_seed_model,
  kind SEED (
    path '../seeds/seed_schedules_app.csv'
  ),
  columns (
    _id STRING,
    org_id STRING,
    subscription_id STRING,
    device_id STRING,
    package_id STRING,
    operation_type STRING,
    status STRING,
    actual_date_time BIGINT,
    display_date_time BIGINT,
    app_package STRING,
    _class STRING
  ),
  grains (_id)
)

