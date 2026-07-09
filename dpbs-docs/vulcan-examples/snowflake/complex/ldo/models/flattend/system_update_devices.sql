MODEL (
  name lenovo.ldo.system_update_devices,
  kind FULL,
  grain UUID,
  tags ('system_updates', 'package_management', 'device_updates', 'flattened', 'cdc'),
  terms ('system.updates', 'package.deployment', 'update.status'),
  description 'Flattened device system update package details. Explodes package details into individual records showing installation status, severity, and filtering groups per device for system update tracking and compliance monitoring',
  column_descriptions (
    uuid = 'Unique composite identifier for device-package combination',
    org_id = 'Organization identifier',
    id = 'Primary device update record identifier',
    class = 'Record class classification',
    device_id = 'Unique device identifier',
    device_display_name = 'Device display name',
    device_serial_number = 'Device serial number',
    device_product_name = 'Device product model name',
    created_at = 'Record creation timestamp',
    last_modified_date = 'Record last modification timestamp',
    package_id = 'Update package identifier (flattened)',
    installation_status = 'Package installation status (flattened)',
    package_last_modified_date = 'Package record last modified date (flattened)',
    package_severity = 'Package severity level (flattened)',
    filtering_group_name = 'Filtering/deployment group name (flattened)',
    __deleted = 'CDC deletion flag',
    __op = 'CDC operation type',
    __source_ts_ms = 'Source system timestamp'
  ),
  column_tags (
    uuid = ('identifier', 'primary_key', 'composite'),
    org_id = ('identifier', 'organization'),
    id = ('identifier', 'record'),
    class = ('dimension', 'classification'),
    device_id = ('identifier', 'device'),
    device_display_name = ('dimension', 'device'),
    device_serial_number = ('identifier', 'device', 'hardware'),
    device_product_name = ('dimension', 'device'),
    created_at = ('temporal', 'timestamp', 'audit'),
    last_modified_date = ('temporal', 'timestamp', 'audit'),
    package_id = ('identifier', 'package'),
    installation_status = ('dimension', 'status'),
    package_last_modified_date = ('temporal', 'timestamp'),
    package_severity = ('dimension', 'severity'),
    filtering_group_name = ('dimension', 'group'),
    __deleted = ('metadata', 'cdc', 'flag'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal')
  ),
  column_terms (
    uuid = ('entity.identifier', 'composite.key'),
    device_id = ('device.identifier', 'entity.reference'),
    package_id = ('package.identifier', 'update.reference'),
    installation_status = ('installation.status', 'deployment.state'),
    package_severity = ('severity.level', 'update.priority'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH explode_package_details AS (
  SELECT
    org_id,
    id,
    class,
    device_id,
    device_display_name,
    device_serial_number,
    device_product_name,
    created_at,
    last_modified_date,
    f.value AS package_details_,
    __deleted,
    __op,
    __source_ts_ms
  FROM lenovo.ldo.system_update_devices_cdc,
    LATERAL FLATTEN(input => package_details) f
),

flattened_data AS (
  SELECT
    CONCAT(id, '_', package_details_:package_id::STRING) AS uuid,
                        org_id,
                        id,
    class,
                        device_id,
                        device_display_name,
                        device_serial_number,
                        device_product_name,
                        created_at,
    last_modified_date,
    package_details_:package_id::STRING AS package_id,
    package_details_:installation_status::STRING AS installation_status,
    package_details_:last_modified_date::STRING AS package_last_modified_date,
    package_details_:package_severity::STRING AS package_severity,
    package_details_:filtering_group_name::STRING AS filtering_group_name,
                        __deleted,
                        __op,
                        __source_ts_ms
  FROM explode_package_details
)

SELECT * FROM flattened_data;
