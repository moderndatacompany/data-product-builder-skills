MODEL (
  name lenovo.ldo.devices,
  kind SEED (
    path '../seeds/devices.csv'
  ),
  grains (DEVICE_ID),
  columns (
    device_id STRING,
    tenant STRING,
    device_org_id STRING,
    device_name STRING,
    device_serial_number STRING,
    device_model STRING,
    device_family STRING,
    category STRING,
    os_platform STRING,
    manufacturer_name STRING,
    device_assigned_date STRING
  )
);


