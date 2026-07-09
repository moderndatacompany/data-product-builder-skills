MODEL (
  name lenovo.ldo.system_update_testing,
  kind FULL,
  grains (UUID),
  tags ('system_updates', 'update_testing', 'qa', 'flattened', 'cdc'),
  terms ('update.testing', 'qa.validation', 'test.deployment'),
  description 'Flattened system update testing records by device. Explodes device IDs to create individual test records showing package testing details, test states, and testing groups for update validation and quality assurance tracking',
  column_descriptions (
    uuid = 'Unique composite identifier for test-device combination',
    id = 'Primary testing record identifier',
    class = 'Record class classification',
    device_id = 'Target device identifier for testing (flattened)',
    end_date = 'Testing period end date',
    org_id = 'Organization identifier',
    package_description = 'Update package description',
    package_id = 'Update package identifier',
    package_name = 'Update package name',
    package_reboot_type = 'Package reboot requirement',
    package_release_date = 'Package release date',
    package_severity = 'Package severity level',
    package_type = 'Package type classification',
    readme_url = 'Package readme documentation URL',
    start_date = 'Testing period start date',
    tested_version = 'Package version being tested',
    testing_group_name = 'Testing group/ring name',
    test_state = 'Current test state (pending, in_progress, passed, failed)',
    test_state_last_updated_at = 'Test state last update timestamp',
    __op = 'CDC operation type',
    __source_ts_ms = 'Source system timestamp',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    uuid = ('identifier', 'primary_key', 'composite'),
    id = ('identifier', 'test_record'),
    class = ('dimension', 'classification'),
    device_id = ('identifier', 'device'),
    end_date = ('temporal', 'date', 'testing_period'),
    org_id = ('identifier', 'organization'),
    package_description = ('text', 'package'),
    package_id = ('identifier', 'package'),
    package_name = ('dimension', 'package'),
    package_reboot_type = ('dimension', 'requirement'),
    package_release_date = ('temporal', 'date'),
    package_severity = ('dimension', 'severity'),
    package_type = ('dimension', 'classification'),
    readme_url = ('text', 'url', 'documentation'),
    start_date = ('temporal', 'date', 'testing_period'),
    tested_version = ('dimension', 'version'),
    testing_group_name = ('dimension', 'group', 'test_ring'),
    test_state = ('dimension', 'status', 'qa'),
    test_state_last_updated_at = ('temporal', 'timestamp', 'audit'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    uuid = ('entity.identifier', 'composite.key'),
    device_id = ('device.identifier', 'test.target'),
    package_id = ('package.identifier', 'update.reference'),
    test_state = ('test.status', 'qa.state'),
    testing_group_name = ('test.ring', 'deployment.group'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH explode_device_ids AS (
  SELECT
    id,
    class,
    f.value::STRING AS device_id,
    end_date,
    org_id,
    package_description,
    package_id,
    package_name,
    package_reboot_type,
    package_release_date,
    package_severity,
    package_type,
    readme_url,
    start_date,
    tested_version,
    testing_group_name,
    test_state,
    test_state_last_updated_at,
    __op,
    __source_ts_ms,
    __deleted
  FROM lenovo.ldo.system_update_testing_cdc,
    LATERAL FLATTEN(input => device_ids, outer => true) f
),
  unique_records AS (
    SELECT
      CONCAT(id, '_',device_id) AS uuid,
      *
    FROM explode_device_ids
  )
  SELECT * FROM unique_records;