MODEL (
  name lenovo.ldo.device_context,
  kind SEED (
    path '../seeds/device_context.csv'
  ),
  grains (DEVICE_ID),
  columns (
    tenant STRING,
    device_id STRING,
    os_name STRING,
    os_version STRING,
    udc_version STRING,
    device_brand STRING,
    language_code STRING,
    device_bios_version STRING,
    os_update_description STRING
  )
);

