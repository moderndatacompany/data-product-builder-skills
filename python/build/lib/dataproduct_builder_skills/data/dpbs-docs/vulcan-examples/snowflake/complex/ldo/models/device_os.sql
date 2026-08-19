MODEL (
  name lenovo.ldo.device_os,
  kind SEED (
    path '../seeds/device_os.csv'
  ),
  grains (UUID),
  columns (
    uuid STRING,
    device_id STRING,
    current_os_id STRING,
    device_os_created_at STRING,
    device_os_updated_at STRING,
    os_name STRING,
    os_version STRING
  )
);

