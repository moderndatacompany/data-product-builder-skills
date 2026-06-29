MODEL (
  name lenovo.ldo.system_update_v2_seed_model_non_cdc,
  kind SEED (
    path '../seeds/seed_system_update_v2.csv'
  ),
  columns (
    _class STRING,
    _id STRING,
    package_id STRING,
    package_name STRING,
    package_description STRING,
    package_version STRING,
    current_installed_version STRING,
    package_release_date BIGINT,
    package_type STRING,
    category STRING,
    package_severity STRING,
    package_reboot_type STRING,
    org_id STRING,
    last_modified_date BIGINT,
    test_state STRING
  ),
  grains (_id)
)

