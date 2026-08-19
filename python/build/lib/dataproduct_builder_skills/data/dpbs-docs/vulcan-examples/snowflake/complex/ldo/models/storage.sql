MODEL (
  name lenovo.ldo.storage,
  kind SEED (
    path '../seeds/storage.csv'
  ),
  grains (STORAGE_ID),
  columns (
    storage_id VARCHAR,
    device_id VARCHAR,
    storage_condition VARCHAR,
    storage_firmware_revision VARCHAR,
    storage_free_space BIGINT,
    storage_interface_type VARCHAR,
    storage_model VARCHAR,
    storage_serial_number VARCHAR,
    storage_size BIGINT,
    storage_type VARCHAR,
    storage_used_percentage INT,
    storage_created_at BIGINT,
    storage_disk_spec VARCHAR,
    storage_health_status VARCHAR
  )
);

