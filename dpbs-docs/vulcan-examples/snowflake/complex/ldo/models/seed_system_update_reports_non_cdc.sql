MODEL (
  name lenovo.ldo.system_update_reports_seed_model,
  kind SEED (
    path '../seeds/seed_system_update_reports.csv'
  ),
  columns (
    _id STRING,
    org_id STRING,
    device_id STRING,
    package_id STRING,
    installation_status STRING,
    package_name STRING,
    package_version STRING,
    current_installed_version STRING,
    package_vendor STRING,
    package_reboot_type STRING,
    coreq_package_id STRING,
    package_size STRING,
    disk_space_required STRING,
    device_serial_number STRING,
    device_product_name STRING,
    last_modified_date BIGINT
  ),
  grains (_id)
)

