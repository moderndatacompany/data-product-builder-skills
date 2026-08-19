MODEL (
  name lenovo.ldo.system_update_reports,
  kind FULL,
  grains (_ID),
  tags ('system_updates', 'installation_reports', 'cdc', 'package_deployment', 'troubleshooting'),
  terms ('update.installation', 'deployment.report', 'failure.analysis'),
  description 'System update installation reports with CDC event processing. Tracks update package installations including status, version information, reboot requirements, resource requirements, and failure details for deployment monitoring and troubleshooting',
  column_descriptions (
    _id = 'Unique installation report identifier',
    org_id = 'Organization identifier',
    device_id = 'Target device identifier',
    package_id = 'Update package identifier',
    installation_status = 'Installation status (pending, installed, failed, etc.)',
    package_name = 'Update package name',
    package_version = 'Package version being installed',
    current_installed_version = 'Currently installed version before update',
    package_vendor = 'Package vendor/publisher name',
    package_reboot_type = 'Reboot requirement (immediate, delayed, none)',
    coreq_package_id = 'Co-requisite package identifier (dependent packages)',
    package_size = 'Package download size in bytes',
    disk_space_required = 'Disk space required for installation in bytes',
    device_serial_number = 'Device serial number',
    device_product_name = 'Device product model name',
    last_modified_date = 'Report last modification timestamp',
    failure_reason = 'Installation failure reason code',
    failure_reason_details = 'Detailed failure reason description',
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    _id = ('identifier', 'primary_key'),
    org_id = ('identifier', 'organization'),
    device_id = ('identifier', 'device', 'foreign_key'),
    package_id = ('identifier', 'package'),
    installation_status = ('dimension', 'status'),
    package_name = ('dimension', 'package'),
    package_version = ('dimension', 'version'),
    current_installed_version = ('dimension', 'version'),
    package_vendor = ('dimension', 'vendor'),
    package_reboot_type = ('dimension', 'requirement'),
    coreq_package_id = ('identifier', 'package', 'dependency'),
    package_size = ('measure', 'size', 'bytes'),
    disk_space_required = ('measure', 'size', 'bytes'),
    device_serial_number = ('identifier', 'device', 'hardware'),
    device_product_name = ('dimension', 'device'),
    last_modified_date = ('temporal', 'timestamp', 'audit'),
    failure_reason = ('dimension', 'error', 'code'),
    failure_reason_details = ('text', 'error', 'details'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    _id = ('entity.identifier', 'report.id'),
    device_id = ('device.identifier', 'entity.reference'),
    package_id = ('package.identifier', 'update.reference'),
    installation_status = ('installation.status', 'deployment.state'),
    failure_reason = ('error.code', 'failure.reason'),
    package_size = ('package.size', 'download.bytes'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
  SELECT 
    _id,
    org_id,
    device_id,
    package_id,
    installation_status,
    package_name,
    package_version,
    current_installed_version,
    package_vendor,
    package_reboot_type,
    coreq_package_id,
    package_size,
    disk_space_required,
    device_serial_number,
    device_product_name,
    last_modified_date,
    failure_reason,
    failure_reason_details,
    __op,
    __source_ts_ms,
    __deleted
  FROM (
    SELECT
      _id,
      org_id,
      device_id,
      package_id,
      installation_status,
      package_name,
      package_version,
      current_installed_version,
      package_vendor,
      package_reboot_type,
      coreq_package_id,
      package_size,
      disk_space_required,
      device_serial_number,
      device_product_name,
      TO_TIMESTAMP_NTZ(last_modified_date / 1000) AS last_modified_date,
      CAST(NULL AS STRING) AS failure_reason,
      CAST(NULL AS STRING) AS failure_reason_details,
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
      ROW_NUMBER() OVER (
        PARTITION BY _id
        ORDER BY
          CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
          CAST(_source_ts_ms AS BIGINT) DESC
      ) AS rn
    FROM lenovo.ldo.system_update_report_seed_model
  )
  WHERE rn = 1
),

deleted_records AS (
  SELECT
    _id,
    __op,
    __source_ts_ms,
    __deleted
  FROM
    cleaned_cdc_data
  WHERE
    __deleted = 'True'
),

cleaned_source_data AS (
  SELECT
    _id,
    org_id,
    device_id,
    package_id,
    installation_status,
    package_name,
    package_version,
    current_installed_version,
    package_vendor,
    package_reboot_type,
    coreq_package_id,
    package_size,
    disk_space_required,
    device_serial_number,
    device_product_name,
    TO_TIMESTAMP_NTZ(last_modified_date / 1000) AS last_modified_date
  FROM
    lenovo.ldo.system_update_reports_seed_model
  WHERE _id IN (
    SELECT
      _id
    FROM
      deleted_records
    WHERE
      __deleted = 'True'
  )
),

reconstruct_deleted_records AS (
  SELECT
    source.*,
    CAST(NULL AS STRING) AS failure_reason,
    CAST(NULL AS STRING) AS failure_reason_details,
    d.__op,
    d.__source_ts_ms,
    d.__deleted
  FROM cleaned_source_data source
  INNER JOIN deleted_records d
  ON d._id = source._id
),

result AS (
  SELECT * FROM reconstruct_deleted_records
  UNION
  SELECT * FROM cleaned_cdc_data WHERE __deleted = 'False'
)

SELECT * FROM result;
