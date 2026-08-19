MODEL (
  name mys3lh02depot.tpch_lakehouse.stg_customer,
  kind VIEW,
  start '2025-01-01',
  grains (c_custkey),
  assertions (
    unique_values(columns := c_custkey),
    not_null(columns := (c_custkey, c_name))
  ),
  profiles (c_acctbal, c_mktsegment, c_nationkey),
  column_descriptions (
    c_custkey = 'Unique customer identifier',
    c_name = 'Customer name',
    c_address = 'Customer address',
    c_nationkey = 'Foreign key to nation',
    c_phone = 'Customer phone number',
    c_acctbal = 'Account balance',
    c_mktsegment = 'Market segment (AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY)',
    c_comment = 'Free-text comment'
  )
);

SELECT
  c_custkey,
  c_name,
  c_address,
  c_nationkey,
  c_phone,
  c_acctbal,
  c_mktsegment,
  c_comment
FROM mys3lh02depot.tpch_sf1.customer;
