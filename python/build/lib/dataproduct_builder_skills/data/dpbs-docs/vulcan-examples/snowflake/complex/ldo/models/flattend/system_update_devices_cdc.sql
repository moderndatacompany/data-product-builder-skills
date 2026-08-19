MODEL (
  name lenovo.ldo.system_update_devices_cdc,
  kind FULL,
  grains (ID),
  tags ('system_updates', 'package_management', 'cdc', 'device_updates'),
  terms ('system.updates', 'package.status', 'update.tracking'),
  description 'CDC-processed device system update records with package details. Aggregates update package information per device including installation status, severity, and filtering groups for comprehensive update management',
  column_descriptions (
    class = 'Record class classification',
    id = 'Unique device update record identifier',
    org_id = 'Organization identifier',
    device_id = 'Unique device identifier',
    device_display_name = 'Device display name',
    device_serial_number = 'Device serial number',
    device_product_name = 'Device product model name',
    created_at = 'Record creation timestamp',
    last_modified_date = 'Record last modification timestamp',
    package_details = 'Aggregated array of package update details',
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    class = ('dimension', 'classification'),
    id = ('identifier', 'primary_key'),
    org_id = ('identifier', 'organization'),
    device_id = ('identifier', 'device'),
    device_display_name = ('dimension', 'device'),
    device_serial_number = ('identifier', 'device', 'hardware'),
    device_product_name = ('dimension', 'device'),
    created_at = ('temporal', 'timestamp', 'audit'),
    last_modified_date = ('temporal', 'timestamp', 'audit'),
    package_details = ('array', 'nested', 'package_info'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    id = ('entity.identifier', 'record.id'),
    device_id = ('device.identifier', 'entity.reference'),
    package_details = ('package.collection', 'update.details'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
                      SELECT 
                        class,
                        id,
                        org_id,
                        device_id,
                        device_display_name,
                        device_serial_number,
                        device_product_name,
                        created_at,
                        last_modified_date,
                        package_details,
                __op,
                        __source_ts_ms,
                        __deleted
                      FROM (
                        SELECT
      _class AS class,
      _id AS id,
                          org_id,
                          device_id,
                          device_display_name,
                          device_serial_number,
                          device_product_name,
      TO_TIMESTAMP_NTZ(created_at / 1000) AS created_at,
      TO_TIMESTAMP_NTZ(last_modified_date / 1000) AS last_modified_date,
      ARRAY_AGG(
        OBJECT_CONSTRUCT(
          'package_id', pd.value:packageId::STRING,
          'installation_status', pd.value:installationStatus::STRING,
          'last_modified_date', pd.value:lastModifiedDate::STRING,
          'package_severity', pd.value:packageSeverity::STRING,
          'filtering_group_name', pd.value:filteringGroupName::STRING
        )
      ) WITHIN GROUP (ORDER BY pd.index) AS package_details,
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
                          ROW_NUMBER() OVER (
                            PARTITION BY _id
                            ORDER BY
                              CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
                              CAST(_source_ts_ms AS BIGINT) DESC
                          ) AS rn
                        FROM lenovo.ldo.system_update_devices_seed_model,
                        LATERAL FLATTEN(input => PARSE_JSON(package_details)) pd
                        GROUP BY _class, _id, org_id, device_id, device_display_name, 
                                 device_serial_number, device_product_name, created_at, 
                                 last_modified_date, _op, _source_ts_ms, deleted
                      )
                      WHERE rn = 1
)

SELECT * FROM cleaned_cdc_data;
