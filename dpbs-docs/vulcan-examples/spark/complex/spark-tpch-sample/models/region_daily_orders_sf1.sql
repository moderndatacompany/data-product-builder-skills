MODEL (
  name lhs3ny001depot.tpch_sparkv3.region_daily_orders_sf1,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by (r_regionkey, o_orderdate),
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (region, incremental, partition),
  grains (region_order_key),
  physical_properties (
    format = 'iceberg'
  ),
  columns(
    r_regionkey BIGINT,
    r_name STRING,
    o_orderdate DATE,
    region_order_key STRING,
    order_count BIGINT
  ),
  allow_partials true,
  -- assertions (
  --   unique_values(columns := region_order_key),
  --   not_null(columns := (r_regionkey, r_name, o_orderdate)),
  --   stddev_in_range(column := order_count, min_v := 0, max_v := 1000)
  -- ),
  profiles (order_count, r_name),
  column_descriptions (
    r_regionkey = 'Region key',
    r_name = 'Region name',
    o_orderdate = 'Order date',
    region_order_key = 'Composite key',
    order_count = 'Order count'
  )
);

SELECT
  r.r_regionkey,
  r.r_name,
  o.o_orderdate,
  CONCAT(CAST(r.r_regionkey AS STRING), '_', CAST(o.o_orderdate AS STRING)) AS region_order_key,
  COUNT(DISTINCT o.o_orderkey) AS order_count
FROM lhs3ny001depot.tpch_sparkv3.tpch_orders_sf1 o
JOIN lhs3ny001depot.tpch_sparkv3.tpch_customer_sf1 c ON c.c_custkey = o.o_custkey
JOIN lhs3ny001depot.tpch_sparkv3.tpch_nation_sf1 n ON n.n_nationkey = c.c_nationkey
JOIN lhs3ny001depot.tpch_sparkv3.tpch_region_sf1 r ON r.r_regionkey = n.n_regionkey
GROUP BY r.r_regionkey, r.r_name, o.o_orderdate;
