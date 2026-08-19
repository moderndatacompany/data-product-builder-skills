MODEL (
  name lenovo.ldo.consumed_licenses,
  kind FULL,
  grains (_ID),
  tags ('license_management', 'subscription', 'cdc', 'device_operations'),
  terms ('license.consumed', 'subscription.management', 'device.assignment'),
  description 'License consumption tracking with CDC event processing. Captures subscription details, billing information, license assignments, and automatic assignment configurations for device license management and compliance tracking',
  column_descriptions (
    _id = 'Unique license record identifier',
    subscription_id = 'Subscription identifier linking to parent subscription',
    license_type_id = 'Type/category of license consumed',
    billing_subscription_id = 'Billing subscription reference for invoicing',
    created_date = 'Timestamp when license record was created',
    last_modified_date = 'Timestamp of last modification to license record',
    status = 'Current status of license (active, inactive, suspended)',
    start_date = 'License validity start date',
    commitment_end_date = 'Commitment period end date',
    order_date = 'Date when license was ordered',
    part_number = 'License part/SKU number',
    class = 'License class/type classification',
    organization_id = 'Organization owning the license',
    entity_id = 'Entity (device/user) assigned to license',
    entity_type = 'Type of entity assigned (device, user, etc.)',
    is_automatic_assignment_enabled = 'Flag indicating if auto-assignment is enabled',
    _part_number_old = 'Previous part number (for migration tracking)',
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    _id = ('identifier', 'primary_key'),
    subscription_id = ('identifier', 'foreign_key'),
    license_type_id = ('identifier', 'classification'),
    billing_subscription_id = ('identifier', 'billing'),
    created_date = ('temporal', 'timestamp', 'audit'),
    last_modified_date = ('temporal', 'timestamp', 'audit'),
    status = ('dimension', 'status'),
    start_date = ('temporal', 'date', 'validity'),
    commitment_end_date = ('temporal', 'date', 'validity'),
    order_date = ('temporal', 'date', 'transaction'),
    part_number = ('identifier', 'sku'),
    class = ('dimension', 'classification'),
    organization_id = ('identifier', 'organization'),
    entity_id = ('identifier', 'assignment'),
    entity_type = ('dimension', 'classification'),
    is_automatic_assignment_enabled = ('flag', 'configuration'),
    _part_number_old = ('identifier', 'historical'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    _id = ('entity.identifier', 'license.id'),
    subscription_id = ('subscription.reference', 'entity.relationship'),
    license_type_id = ('license.type', 'classification.category'),
    status = ('entity.status', 'lifecycle.state'),
    organization_id = ('organization.identifier', 'entity.owner'),
    entity_id = ('assignment.target', 'entity.identifier'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
  SELECT 
                        _id,
                        subscription_id,
                        license_type_id,
                        billing_subscription_id,
                        created_date,
                        last_modified_date,
                        status,
                        start_date,
                        commitment_end_date,
                        order_date,
                        part_number,
                        class,
                        organization_id,
                        entity_id,
                        entity_type,
                        is_automatic_assignment_enabled,
                        _part_number_old,      
                        __op,
                        __source_ts_ms,
                        __deleted
                      FROM (
                      SELECT
                        _id,
                        subscription_id,
                        license_type_id,
                        billing_subscription_id,
      TO_TIMESTAMP_NTZ(created_date / 1000) AS created_date,
      TO_TIMESTAMP_NTZ(last_modified_date / 1000) AS last_modified_date,
                        status,
      TO_TIMESTAMP_NTZ(start_date / 1000) AS start_date,
      TO_TIMESTAMP_NTZ(commitment_end_date / 1000) AS commitment_end_date,
      TO_TIMESTAMP_NTZ(order_date / 1000) AS order_date,
                        part_number,
      _class AS class,
                        organization_id,
                        entity_id,
                        entity_type,
                        is_automatic_assignment_enabled,
                        _part_number_old,      
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
                        ROW_NUMBER() OVER (
                                PARTITION BY _id
                                ORDER BY
                                  CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
                                  CAST(_source_ts_ms AS BIGINT) DESC
                              ) AS rn
    FROM lenovo.ldo.licenses_seed_model
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
    subscription_id,
    license_type_id,
    billing_subscription_id,
    TO_TIMESTAMP_NTZ(created_date / 1000) AS created_date,
    TO_TIMESTAMP_NTZ(last_modified_date / 1000) AS last_modified_date,
    status,
    TO_TIMESTAMP_NTZ(start_date / 1000) AS start_date,
    TO_TIMESTAMP_NTZ(commitment_end_date / 1000) AS commitment_end_date,
    TO_TIMESTAMP_NTZ(order_date / 1000) AS order_date,
    part_number,
    _class AS class,
    organization_id,
    entity_id,
    entity_type,
    is_automatic_assignment_enabled,
    _part_number_old
  FROM
    lenovo.ldo.consumed_licenses_seed_model
  WHERE _id IN (
    SELECT
      _id
    FROM
      deleted_records
    WHERE
      __deleted = true
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
    