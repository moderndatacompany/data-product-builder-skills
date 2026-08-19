MODEL (
  name lenovo.ldo.live_devices_status_seed_model,
  kind SEED (
    path '../seeds/seed_live_devices_status.csv'
  ),
  columns (
    _id STRING,
    org_id STRING,
    device_id STRING,
    org_device_id STRING,
    subscription_id STRING,
    device_name STRING,
    manufacturer STRING,
    model_type STRING,
    serial_number STRING,
    family STRING,
    enclosure_type STRING,
    category STRING,
    platform STRING,
    os_name STRING,
    network STRING,
    time_zone STRING,
    status STRING,
    version STRING,
    warranty_status STRING,
    warranty_expiration_date STRING,
    country_name STRING,
    device_groups STRING,
    licenses STRING
  ),
  grains (_id)
)

