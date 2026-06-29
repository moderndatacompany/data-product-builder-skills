MODEL (
  name lenovo.ldo.system_update_devices_seed_model,
  kind SEED (
    path '../seeds/seed_update_devices_cdc.csv'
  ),
  columns (
    _id STRING,
    org_id STRING,
    device_id STRING,
    device_display_name STRING,
    device_serial_number STRING,
    device_product_name STRING,
    created_at BIGINT,
    last_modified_date BIGINT,
    package_details STRING,
    _class STRING,
    deleted STRING,
    _op STRING,
    _collection STRING,
    _source_ts_ms BIGINT,
    _db STRING,
    _nilus_load_id STRING,
    _nilus_id STRING,
    groups STRING,
    groups_1 STRING
  ),
  grains (_id, _nilus_id)
)

