MODEL (
  name lenovo.ldo.licenses_seed_model,
  kind SEED (
    path '../seeds/seed_consumed_licenses_cdc.csv'
  ),
  columns (
    _id STRING,
    subscription_id STRING,
    license_type_id STRING,
    billing_subscription_id STRING,
    created_date BIGINT,
    last_modified_date BIGINT,
    status STRING,
    start_date BIGINT,
    commitment_end_date BIGINT,
    order_date BIGINT,
    part_number STRING,
    _class STRING,
    deleted STRING,
    _op STRING,
    _collection STRING,
    _source_ts_ms BIGINT,
    _db STRING,
    _nilus_load_id STRING,
    _nilus_id STRING,
    organization_id STRING,
    entity_id STRING,
    entity_type STRING,
    is_automatic_assignment_enabled STRING,
    _part_number_old STRING,
    subscription STRING,
    _is_part_number_missing_migration STRING,
    effective_start_date BIGINT
  ),
  grains (_id, _nilus_id)
)

