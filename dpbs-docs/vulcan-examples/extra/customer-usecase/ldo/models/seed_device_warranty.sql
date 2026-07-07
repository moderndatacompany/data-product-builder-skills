MODEL (
  name lenovo.ldo.warranties_seed_model,
  kind SEED (
    path '../seeds/seed_device_warranty_cdc.csv'
  ),
  columns (
    _id STRING,
    org_id STRING,
    device_id STRING,
    device_name STRING,
    serial_number STRING,
    device_category STRING,
    created_at BIGINT,
    last_updated BIGINT,
    warranty_id STRING,
    warranty_number STRING,
    warranty_type STRING,
    warranty_start BIGINT,
    warranty_end BIGINT,
    _class STRING,
    deleted STRING,
    _op STRING,
    _collection STRING,
    _source_ts_ms BIGINT,
    _db STRING,
    _nilus_load_id STRING,
    _nilus_id STRING,
    warranty_name STRING,
    warranty_category STRING,
    warranty_delivery_type STRING,
    warranty_description STRING,
    warranty_duration BIGINT,
    warranty_service_profile STRING,
    warranty_response_profile STRING
  ),
  grains (_id, _nilus_id)
)

