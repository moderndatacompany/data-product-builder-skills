MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_supplier,
  kind VIEW,
  start '2025-01-01',
  grains (s_suppkey),
  assertions (
    unique_values(columns := s_suppkey),
    not_null(columns := (s_suppkey, s_name))
  ),
  profiles (s_acctbal, s_nationkey),
  column_descriptions (
    s_suppkey = 'Unique supplier identifier',
    s_name = 'Supplier name',
    s_address = 'Supplier address',
    s_nationkey = 'Foreign key to nation',
    s_phone = 'Supplier phone number',
    s_acctbal = 'Account balance',
    s_comment = 'Free-text comment'
  )
);

SELECT
  s_suppkey,
  s_name,
  s_address,
  s_nationkey,
  s_phone,
  s_acctbal,
  s_comment
FROM mys3lh02depot.tpch_sf1.supplier;
