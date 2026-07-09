MODEL (
  name lenovo.ldo.system_update_testing_seed_model,
  kind SEED (
    path '../seeds/seed_system_update_testing.csv'
  ),
  columns (
    _id STRING,
    _class STRING,
    device_ids STRING,
    end_date BIGINT,
    org_id STRING,
    package_description STRING,
    package_id STRING,
    package_name STRING,
    package_reboot_type STRING,
    package_release_date BIGINT,
    package_severity STRING,
    package_type STRING,
    readme_url STRING,
    start_date BIGINT,
    tested_version STRING,
    testing_group_name STRING,
    test_state STRING,
    test_state_last_updated_at BIGINT
  ),
  grains (_id)
)

