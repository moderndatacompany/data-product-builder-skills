MODEL (
  name lenovo.ldo.device_uptime_seed_model,
  kind SEED (
    path '../seeds/seed_device_uptime.csv'
  ),
  columns (
    _id STRING,
    _class STRING,
    device_id STRING,
    network STRING,
    last_change_to_online BIGINT,
    last_change_to_offline BIGINT,
    total_minutes_online INTEGER,
    total_minutes_offline INTEGER
  ),
  grains (_id)
)

