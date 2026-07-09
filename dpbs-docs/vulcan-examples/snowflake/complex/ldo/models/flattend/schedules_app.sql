MODEL (
  name lenovo.ldo.schedules_app,
  kind FULL,
  grains (_ID),
  tags ('app_deployment', 'device_operations', 'package_management', 'cdc', 'scheduling'),
  terms ('application.deployment', 'package.installation', 'device.operations'),
  description 'Application deployment and scheduling operations with CDC event processing. Tracks app package installations, updates, and removals on devices including operation timing, package details, and deployment status for application lifecycle management',
  column_descriptions (
    _id = 'Unique operation record identifier',
    org_id = 'Organization identifier',
    subscription_id = 'Subscription identifier',
    device_id = 'Target device identifier',
    package_id = 'Application package identifier',
    operation_type = 'Type of operation (install, update, remove)',
    status = 'Current operation status',
    actual_date_time = 'Actual operation execution timestamp',
    display_date_time = 'User-facing display timestamp for operation',
    app_package_id = 'Application package identifier',
    package_type = 'Type of application package',
    url = 'Package download URL',
    manifest_url = 'Package manifest file URL',
    package_platform = 'Target platform for package',
    package_name = 'Application package name',
    package_version = 'Application package version',
    package_publisher = 'Package publisher/vendor name',
    package_file_name = 'Package file name',
    class = 'Operation class classification',
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    _id = ('identifier', 'primary_key'),
    org_id = ('identifier', 'organization'),
    subscription_id = ('identifier', 'subscription'),
    device_id = ('identifier', 'device', 'foreign_key'),
    package_id = ('identifier', 'package'),
    operation_type = ('dimension', 'operation'),
    status = ('dimension', 'status'),
    actual_date_time = ('temporal', 'timestamp', 'execution'),
    display_date_time = ('temporal', 'timestamp', 'display'),
    app_package_id = ('identifier', 'package'),
    package_type = ('dimension', 'package', 'classification'),
    url = ('text', 'url', 'download'),
    manifest_url = ('text', 'url', 'manifest'),
    package_platform = ('dimension', 'platform'),
    package_name = ('dimension', 'package'),
    package_version = ('dimension', 'version'),
    package_publisher = ('dimension', 'vendor'),
    package_file_name = ('text', 'filename'),
    class = ('dimension', 'classification'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    _id = ('entity.identifier', 'operation.id'),
    device_id = ('device.identifier', 'entity.reference'),
    org_id = ('organization.identifier', 'entity.owner'),
    operation_type = ('operation.type', 'deployment.action'),
    package_id = ('package.identifier', 'application.reference'),
    actual_date_time = ('operation.timestamp', 'execution.time'),
    status = ('operation.status', 'deployment.state'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
  SELECT *
                      FROM (
                      SELECT
                        _id,
                        org_id,
                        subscription_id,
                        device_id,
                        package_id,
                        operation_type,
                        status,
      TO_TIMESTAMP_NTZ(actual_date_time / 1000) AS actual_date_time,
      TO_TIMESTAMP_NTZ(display_date_time / 1000) AS display_date_time,
      TRY_PARSE_JSON(app_package) AS app_package,
      _class AS class,
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
                        ROW_NUMBER() OVER (
                                PARTITION BY _id
                                ORDER BY
                                  CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
                                  CAST(_source_ts_ms AS BIGINT) DESC
                              ) AS rn
    FROM lenovo.ldo.device_operations_seed_model
                      )
  WHERE rn = 1
),

                      unnested_cdc_data AS (
                        SELECT
                          _id,
                          org_id,
                          subscription_id,
                          device_id,
                          package_id,
                          operation_type,
                          status,
                          actual_date_time,
                          display_date_time,
    app_package:packageId::STRING AS app_package_id,
    app_package:packageType::STRING AS package_type,
    app_package:url::STRING AS url,
    app_package:manifestUrl::STRING AS manifest_url,
    app_package:packagePlatform::STRING AS package_platform,
    app_package:packageName::STRING AS package_name,
    app_package:packageVersion::STRING AS package_version,
    app_package:packagePublisher::STRING AS package_publisher,
    app_package:packageFileName::STRING AS package_file_name,
                          class,
                          __op,
                          __source_ts_ms,
                          __deleted
  FROM cleaned_cdc_data
),

deleted_records AS (
  SELECT
    _id,
    __op,
    __source_ts_ms,
    __deleted
  FROM
    unnested_cdc_data
  WHERE
    __deleted = 'True'
),

cleaned_source_data AS (
  SELECT
    _id,
    org_id,
    subscription_id,
    device_id,
    package_id,
    operation_type,
    status,
    TO_TIMESTAMP_NTZ(actual_date_time / 1000) AS actual_date_time,
    TO_TIMESTAMP_NTZ(display_date_time / 1000) AS display_date_time,
    TRY_PARSE_JSON(app_package) AS app_package,
    _class AS class
  FROM
    lenovo.ldo.schedules_app_seed_model
  WHERE _id IN (
    SELECT
      _id
    FROM
      deleted_records
    WHERE
      __deleted = 'True'
  )
),

unnested_source_data AS (
  SELECT
    _id,
    org_id,
    subscription_id,
    device_id,
    package_id,
    operation_type,
    status,
    actual_date_time,
    display_date_time,
    app_package:packageId::STRING AS app_package_id,
    app_package:packageType::STRING AS package_type,
    app_package:url::STRING AS url,
    app_package:manifestUrl::STRING AS manifest_url,
    app_package:packagePlatform::STRING AS package_platform,
    app_package:packageName::STRING AS package_name,
    app_package:packageVersion::STRING AS package_version,
    app_package:packagePublisher::STRING AS package_publisher,
    app_package:packageFileName::STRING AS package_file_name,
    class
  FROM cleaned_source_data
),

reconstruct_deleted_records AS (
  SELECT
    source.*,
    d.__op,
    d.__source_ts_ms,
    d.__deleted
  FROM unnested_source_data source
  INNER JOIN deleted_records d
  ON d._id = source._id
),

result AS (
  SELECT * FROM reconstruct_deleted_records
  UNION
  SELECT * FROM unnested_cdc_data WHERE __deleted = 'False'
)

SELECT * FROM result;
