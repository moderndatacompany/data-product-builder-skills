MODEL (
  name testawslhnewdepot.tpch_sparkv1.tpch_customer_sf1,
  kind VIEW,
  description 'Base layer view over TPC-H customer dimension. Provides customer identity, contact, financial and segmentation attributes.',
  grains (c_custkey),
  tags (base, dimension, customer, tpch),
  terms (customer_master, customer_dimension, customer_data),
  columns (
    c_custkey BIGINT,
    c_name VARCHAR,
    c_address VARCHAR,
    c_nationkey BIGINT,
    c_phone VARCHAR,
    c_acctbal DECIMAL(12, 2),
    c_mktsegment VARCHAR,
    c_comment VARCHAR
  ),
  column_descriptions (
    c_custkey = 'Unique customer identifier',
    c_name = 'Customer name',
    c_address = 'Customer mailing address',
    c_nationkey = 'Foreign key to nation dimension',
    c_phone = 'Customer phone number',
    c_acctbal = 'Customer account balance',
    c_mktsegment = 'Market segment the customer belongs to',
    c_comment = 'Free-form comment on the customer'
  ),
  column_tags (
    c_custkey = (identifier, primary_key, grain, unique),
    c_name = (dimension, descriptive, pii),
    c_address = (dimension, descriptive, pii),
    c_nationkey = (foreign_key, dimension, geographic),
    c_phone = (dimension, contact, pii),
    c_acctbal = (measure, financial, balance),
    c_mktsegment = (dimension, segmentation, marketing),
    c_comment = (dimension, descriptive)
  ),
  column_terms (
    c_custkey = (customer_id, customer_key),
    c_name = (customer_name, name),
    c_nationkey = (nation_id, nation_key),
    c_acctbal = (account_balance, balance),
    c_mktsegment = (market_segment, segment)
  ),
  profiles (c_custkey, c_acctbal, c_mktsegment, c_nationkey)
);


SELECT
  c_custkey,
  c_name,
  c_address,
  c_nationkey,
  c_phone,
  c_acctbal,
  c_mktsegment,
  c_comment FROM testawslhnewdepot.tpch_sf1v1.customer limit 2; 



