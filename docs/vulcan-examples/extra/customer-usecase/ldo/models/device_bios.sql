MODEL (
  name lenovo.ldo.device_bios,
  kind SEED (
    path '../seeds/device_bios.csv'
  ),
  grains (UUID),
  columns (
    uuid STRING,
    device_uuid STRING,
    device_bios_created_at TIMESTAMP,
    last_firmware_updated_at TIMESTAMP,
    device_bios_id STRING,
    recommended_bios_id STRING,
    device_id STRING
  )
);

