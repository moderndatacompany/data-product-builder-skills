MODEL (
  name lenovo.ldo.package_testing_seed_model,
  kind SEED (
    path '../seeds/seed_system_update_testing_cdc.csv'
  ),
  columns (
    _id STRING,
    package_release_date BIGINT,
    readme_url STRING,
    org_id STRING,
    package_id STRING,
    test_state STRING,
    device_ids STRING,
    start_date BIGINT,
    end_date BIGINT,
    _class STRING,
    deleted STRING,
    _op STRING,
    _collection STRING,
    _source_ts_ms BIGINT,
    _db STRING,
    _nilus_load_id STRING,
    _nilus_id STRING,
    test_state_last_updated_at BIGINT,
    tested_version STRING,
    package_name STRING,
    package_description STRING,
    package_severity STRING,
    package_type STRING,
    package_reboot_type STRING,
    testing_group_name STRING
  ),
  grains (_id, _nilus_id)
)

