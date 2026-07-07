MODEL (
  name lenovo.ldo.device_warranty,
  kind FULL,
  grains (_ID),
  tags ('warranty', 'device_management', 'cdc', 'service_contract'),
  terms ('warranty.coverage', 'device.service', 'support.management'),
  description 'Device warranty information with CDC event processing. Tracks warranty coverage periods, service profiles, delivery types, and warranty lifecycle for device support and service management',
  column_descriptions (
    _id = 'Unique warranty record identifier',
    org_id = 'Organization identifier owning the device',
    device_id = 'Unique device identifier',
    device_name = 'Display name of the device',
    serial_number = 'Device serial number',
    device_category = 'Device category/type classification',
    created_at = 'Timestamp when warranty record was created',
    last_updated = 'Timestamp of last warranty record update',
    warranty_id = 'Unique warranty identifier',
    warranty_number = 'Warranty number/reference code',
    warranty_type = 'Type of warranty coverage (standard, extended, etc.)',
    warranty_start = 'Warranty coverage start date',
    warranty_end = 'Warranty coverage end date',
    class = 'Warranty class classification',
    warranty_name = 'Warranty plan/package name',
    warranty_category = 'Warranty category classification',
    warranty_delivery_type = 'Service delivery method (on-site, mail-in, etc.)',
    warranty_description = 'Detailed warranty coverage description',
    warranty_duration = 'Warranty coverage duration in days',
    warranty_service_profile = 'Service level profile (next-day, same-day, etc.)',
    warranty_response_profile = 'Response time profile for warranty service',
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    _id = ('identifier', 'primary_key'),
    org_id = ('identifier', 'organization'),
    device_id = ('identifier', 'device', 'foreign_key'),
    device_name = ('dimension', 'device'),
    serial_number = ('identifier', 'device', 'unique'),
    device_category = ('dimension', 'classification'),
    created_at = ('temporal', 'timestamp', 'audit'),
    last_updated = ('temporal', 'timestamp', 'audit'),
    warranty_id = ('identifier', 'warranty'),
    warranty_number = ('identifier', 'reference'),
    warranty_type = ('dimension', 'classification'),
    warranty_start = ('temporal', 'date', 'validity'),
    warranty_end = ('temporal', 'date', 'validity'),
    class = ('dimension', 'classification'),
    warranty_name = ('dimension', 'warranty'),
    warranty_category = ('dimension', 'classification'),
    warranty_delivery_type = ('dimension', 'service'),
    warranty_description = ('text', 'details'),
    warranty_duration = ('measure', 'duration'),
    warranty_service_profile = ('dimension', 'service_level'),
    warranty_response_profile = ('dimension', 'service_level'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    _id = ('entity.identifier', 'warranty.id'),
    org_id = ('organization.identifier', 'entity.owner'),
    device_id = ('device.identifier', 'entity.reference'),
    warranty_start = ('warranty.begin', 'coverage.start'),
    warranty_end = ('warranty.expiration', 'coverage.end'),
    warranty_type = ('warranty.type', 'coverage.classification'),
    warranty_service_profile = ('service.level', 'support.tier'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
  SELECT 
    _id,
    org_id,
    device_id,
    device_name,
    serial_number,
    device_category,
    created_at,
    last_updated,
    warranty_id,
    warranty_number,
    warranty_type,
    warranty_start,
    warranty_end,
    class,
    warranty_name,
    warranty_category,
    warranty_delivery_type,
    warranty_description,
    warranty_duration,
    warranty_service_profile,
    warranty_response_profile,
    __op,
    __source_ts_ms,
    __deleted
  FROM (
    SELECT
      _id,
      org_id,
      device_id,
      device_name,
      serial_number,
      device_category,
      TO_TIMESTAMP_NTZ(created_at / 1000) AS created_at,
      TO_TIMESTAMP_NTZ(last_updated / 1000) AS last_updated,
      warranty_id,
      warranty_number,
      warranty_type,
      TO_TIMESTAMP_NTZ(warranty_start / 1000) AS warranty_start,
      TO_TIMESTAMP_NTZ(warranty_end / 1000) AS warranty_end,
      _class AS class,
      warranty_name,
      warranty_category,
      warranty_delivery_type,
      warranty_description,
      warranty_duration,
      warranty_service_profile,
      warranty_response_profile,
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
      ROW_NUMBER() OVER (
        PARTITION BY _id
        ORDER BY
          CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
          CAST(_source_ts_ms AS BIGINT) DESC
      ) AS rn
    FROM lenovo.ldo.warranties_seed_model
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
    device_name,
    serial_number,
    device_category,
    TO_TIMESTAMP_NTZ(created_at / 1000) AS created_at,
    TO_TIMESTAMP_NTZ(last_updated / 1000) AS last_updated,
    warranty_id,
    warranty_number,
    warranty_type,
    TO_TIMESTAMP_NTZ(warranty_start / 1000) AS warranty_start,
    TO_TIMESTAMP_NTZ(warranty_end / 1000) AS warranty_end,
    _class AS class,
    warranty_name,
    warranty_category,
    warranty_delivery_type,
    warranty_description,
    warranty_duration,
    warranty_service_profile,
    warranty_response_profile
  FROM
    lenovo.ldo.device_warranty_seed_model
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
