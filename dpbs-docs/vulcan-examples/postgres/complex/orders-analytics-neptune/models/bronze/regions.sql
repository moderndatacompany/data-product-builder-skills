-- Core regions dimension table containing geographic region classifications
-- Used for organizing customers, suppliers, and warehouses by geographic area
MODEL (
  name bronze_v1.regions,
  kind SEED (
    path '../../seeds/seed_regions.csv'
  ),
  columns (
    region_id INTEGER,
    region_name VARCHAR
  ),
  grains (region_id),
  tags ('dimension', 'geography', 'reference_data'),
  terms ('geography.region', 'reference.region'),
  description 'Geographic regions dimension table containing region identifiers and names used to classify customers, suppliers, and warehouse locations',
  column_descriptions (
    region_id = 'Unique identifier for each geographic region',
    region_name = 'Name of the geographic region (North, South, East, West, Central)'
  ),
  column_tags (
    region_id = ('primary_key', 'identifier'),
    region_name = ('dimension', 'label')
  ),
  column_terms (
    region_id = ('geography.region_id', 'reference.region_id'),
    region_name = ('geography.region_name', 'location.region')
  ),
  -- assertions (
  --   unique_values(columns := region_id),
  --   not_null(columns := (region_id, region_name)),
  --   not_empty_string(column := region_name),
  --   accepted_values(column := region_name, is_in := ('North', 'South', 'East', 'West', 'Central'))
  -- ),
  profiles (region_name)
);

