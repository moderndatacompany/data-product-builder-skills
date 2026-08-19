MODEL (
  name lenovo.ldo.device_operations_seed_model,
  kind SEED (
    path '../seeds/seed_schedules_app_cdc.csv'
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
    _class STRING,
    deleted STRING,
    _op STRING,
    _collection STRING,
    _source_ts_ms BIGINT,
    _db STRING,
    _nilus_load_id STRING,
    _nilus_id STRING
  ),
  grains (_id, _nilus_id)
)

