MODEL (
  name lenovo.ldo.system_update_v2,
  kind FULL,
  tags ('system_updates', 'package_catalog', 'cdc', 'update_management'),
  terms ('update.catalog', 'package.metadata', 'update.inventory'),
  grains (_ID),
  description 'System update package catalog with CDC event processing. Maintains comprehensive package metadata including versions, release dates, severity levels, reboot requirements, and test states for update management and compliance tracking',
  column_descriptions (
    class = 'Package record class classification',
    _id = 'Unique package record identifier',
    package_id = 'Update package identifier',
    package_name = 'Update package name',
    package_description = 'Detailed package description',
    package_version = 'Package version number',
    current_installed_version = 'Currently installed version reference',
    package_release_date = 'Package release/publication date',
    package_type = 'Package type (driver, firmware, application, etc.)',
    category = 'Package category classification',
    package_severity = 'Package severity level (critical, important, moderate, low)',
    package_reboot_type = 'Reboot requirement (immediate, delayed, none)',
    org_id = 'Organization identifier',
    last_modified_date = 'Package record last modification timestamp',
    test_state = 'Package testing/approval state',
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    class = ('dimension', 'classification'),
    _id = ('identifier', 'primary_key'),
    package_id = ('identifier', 'package'),
    package_name = ('dimension', 'package'),
    package_description = ('text', 'details'),
    package_version = ('dimension', 'version'),
    current_installed_version = ('dimension', 'version'),
    package_release_date = ('temporal', 'date', 'release'),
    package_type = ('dimension', 'classification'),
    category = ('dimension', 'classification'),
    package_severity = ('dimension', 'severity', 'priority'),
    package_reboot_type = ('dimension', 'requirement'),
    org_id = ('identifier', 'organization'),
    last_modified_date = ('temporal', 'timestamp', 'audit'),
    test_state = ('dimension', 'status', 'qa'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    _id = ('entity.identifier', 'package.record_id'),
    package_id = ('package.identifier', 'update.reference'),
    package_severity = ('severity.level', 'update.priority'),
    package_type = ('package.type', 'update.classification'),
    test_state = ('test.status', 'approval.state'),
    package_release_date = ('release.date', 'publication.timestamp'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
  SELECT 
    class,
    _id,
    package_id,
    package_name,
    package_description,
    package_version,
    current_installed_version,
    package_release_date,
    package_type,
    category,
    package_severity,
    package_reboot_type,
    org_id,
    last_modified_date,
    test_state,
    __op,
    __source_ts_ms,
    __deleted
  FROM (
    SELECT
      _class AS class,
      _id,
      package_id,
      package_name,
      package_description,
      package_version,
      current_installed_version,
      TO_TIMESTAMP_NTZ(package_release_date / 1000) AS package_release_date,
      package_type,
      category,
      package_severity,
      package_reboot_type,
      org_id,
      TO_TIMESTAMP_NTZ(last_modified_date / 1000) AS last_modified_date,
      test_state,
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
      ROW_NUMBER() OVER (
        PARTITION BY _id
        ORDER BY
          CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
          CAST(_source_ts_ms AS BIGINT) DESC
      ) AS rn
    FROM lenovo.ldo.system_update_v2_seed_model
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
    _class AS class,
    _id,
    package_id,
    package_name,
    package_description,
    package_version,
    current_installed_version,
    TO_TIMESTAMP_NTZ(package_release_date / 1000) AS package_release_date,
    package_type,
    category,
    package_severity,
    package_reboot_type,
    org_id,
    TO_TIMESTAMP_NTZ(last_modified_date / 1000) AS last_modified_date,
    test_state
  FROM
    lenovo.ldo.system_update_v2_seed_model_non_cdc
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
