MODEL (
  name lenovo.ldo.system_update_testing_cdc,
  kind FULL,
  grains (ID),
  tags ('system_updates', 'update_testing', 'qa', 'cdc'),
  terms ('update.testing', 'qa.validation', 'test.management'),
  description 'CDC-processed system update testing records. Tracks package testing campaigns including device assignment lists, testing periods, test states, and testing group configurations for update quality assurance and staged rollout management',
  column_descriptions (
    id = 'Unique testing campaign identifier',
    class = 'Record class classification',
    device_ids = 'Array of device identifiers assigned to test',
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
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    id = ('identifier', 'primary_key'),
    class = ('dimension', 'classification'),
    device_ids = ('array', 'device', 'assignment'),
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
    id = ('entity.identifier', 'test.campaign_id'),
    package_id = ('package.identifier', 'update.reference'),
    test_state = ('test.status', 'qa.state'),
    testing_group_name = ('test.ring', 'deployment.group'),
    device_ids = ('device.collection', 'test.targets'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
                        SELECT 
                            id,
    class,
                            device_ids,
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
                      FROM (
                      SELECT
      _id AS id,
      _class AS class,
      SPLIT(REGEXP_REPLACE(device_ids, '\\[|\\]|"', ''), ',') AS device_ids,
      TO_TIMESTAMP_NTZ(end_date / 1000) AS end_date,
                        org_id,
                        package_description,
                        package_id,
                        package_name,
                        package_reboot_type,
      TO_TIMESTAMP_NTZ(package_release_date / 1000) AS package_release_date,
                        package_severity,
                        package_type,
                        readme_url,
      TO_TIMESTAMP_NTZ(start_date / 1000) AS start_date,
                        tested_version,
                        testing_group_name,
                        test_state,
      TO_TIMESTAMP_NTZ(test_state_last_updated_at / 1000) AS test_state_last_updated_at,
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
                        ROW_NUMBER() OVER (
                                PARTITION BY _id
                                ORDER BY
                                  CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
                                  CAST(_source_ts_ms AS BIGINT) DESC
                              ) AS rn
    FROM lenovo.ldo.package_testing_seed_model
                      )
  WHERE rn = 1
),

                      deleted_records AS (
                        SELECT
                          id,
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
    _id AS id,
    _class AS class,
    SPLIT(REGEXP_REPLACE(device_ids, '\\[|\\]|"', ''), ',') AS device_ids,
    TO_TIMESTAMP_NTZ(end_date / 1000) AS end_date,
    org_id,
    package_description,
    package_id,
    package_name,
    package_reboot_type,
    TO_TIMESTAMP_NTZ(package_release_date / 1000) AS package_release_date,
    package_severity,
    package_type,
    readme_url,
    TO_TIMESTAMP_NTZ(start_date / 1000) AS start_date,
    tested_version,
    testing_group_name,
    test_state,
    TO_TIMESTAMP_NTZ(test_state_last_updated_at / 1000) AS test_state_last_updated_at
  FROM
    lenovo.ldo.system_update_testing_seed_model
  WHERE _id IN (
    SELECT
      id
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
  ON d.id = source.id
),

result AS (
  SELECT * FROM reconstruct_deleted_records
  UNION
  SELECT * FROM cleaned_cdc_data WHERE __deleted = 'False'
)

SELECT * FROM result;
