MODEL (
  name lenovo.ldo.device_network_seed_model,
  kind SEED (
    path '../seeds/seed_device_uptime_cdc.csv'
  ),
  columns (
    _id STRING,
    device_id STRING,
    network STRING,
    last_change_to_online BIGINT,
    last_change_to_offline BIGINT,
    total_minutes_online BIGINT,
    total_minutes_offline BIGINT,
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

