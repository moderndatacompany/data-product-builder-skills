-- Core warehouses dimension table containing warehouse location information
-- Used for fulfillment tracking and logistics analytics
MODEL (
  name bronze_v2alpha.warehouses,
  kind FULL,
  grains (warehouse_id),
  cron '*/15 * * * *',
  tags ('dimension', 'warehouse', 'logistics', 'fulfillment'),
  terms ('warehouse.location', 'logistics.warehouse'),
  description 'Warehouse dimension table containing fulfillment center locations with regional classification for logistics and order fulfillment tracking',
  column_descriptions (
    warehouse_id = 'Unique identifier for each warehouse facility',
    region_id = 'Foreign key to regions table - geographic region where warehouse is located',
    name = 'Warehouse facility name or code'
  ),
  column_tags (
    warehouse_id = ('primary_key', 'identifier'),
    region_id = ('foreign_key', 'reference', 'geography'),
    name = ('dimension', 'label', 'facility')
  ),
  column_terms (
    warehouse_id = ('warehouse.warehouse_id', 'logistics.warehouse_id'),
    region_id = ('geography.region_id', 'reference.region_id'),
    name = ('warehouse.name', 'logistics.facility_name')
  ),
  assertions (
    unique_values(columns := warehouse_id),
    not_null(columns := (warehouse_id, region_id, name)),
    not_empty_string(column := name),
    forall(criteria := (
      warehouse_id > 0,
      region_id > 0
    ))
  ),
  profiles (name, region_id)
);

SELECT
  warehouse_id,
  region_id,
  name
FROM vulcan_demo.warehouses

