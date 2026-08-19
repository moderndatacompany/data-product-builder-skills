MODEL (
  name lenovo.ldo.update_devices_seed_model,
  kind SEED (
    path '../seeds/seed_update_devices.csv'
  ),
  columns (
    _class STRING,
    _id STRING,
    org_id STRING,
    device_id STRING,
    device_display_name STRING,
    device_serial_number STRING,
    device_product_name STRING,
    -- created_at BIGINT,
    last_modified_date BIGINT,
    package_details STRING
  ),
  grains (_id)
)

