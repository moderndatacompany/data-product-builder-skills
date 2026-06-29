MODEL (
  name mys3lh02depot.tpch_lakehouse.region_daily_revenue,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by (r_regionkey),
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (region, incremental, partition, revenue),
  grains (region_date_key),
  physical_properties (
    format = 'iceberg'
  ),
  allow_partials true,
  assertions (
    unique_values(columns := region_date_key),
    not_null(columns := (r_regionkey, r_name, o_orderdate)),
    forall(criteria := (order_count >= 0)),
    forall(criteria := (total_revenue >= 0))
  ),
  profiles (order_count, total_revenue, r_name),
  column_descriptions (
    r_regionkey = 'Region key',
    r_name = 'Region name',
    o_orderdate = 'Order date',
    region_date_key = 'Composite key: regionkey_orderdate',
    order_count = 'Number of distinct orders in this region on this date',
    total_revenue = 'Total revenue for this region on this date',
    customer_count = 'Number of distinct customers who ordered'
  )
);

SELECT
  cn.r_regionkey,
  cn.r_name,
  oi.o_orderdate,
  CONCAT(CAST(cn.r_regionkey AS STRING), '_', CAST(oi.o_orderdate AS STRING)) AS region_date_key,
  COUNT(DISTINCT oi.l_orderkey) AS order_count,
  COALESCE(SUM(oi.net_amount), 0) AS total_revenue,
  COUNT(DISTINCT oi.o_custkey) AS customer_count
FROM mys3lh02depot.tpch_lakehouse.int_order_items oi
JOIN mys3lh02depot.tpch_lakehouse.int_customer_nation cn
  ON cn.c_custkey = oi.o_custkey
GROUP BY cn.r_regionkey, cn.r_name, oi.o_orderdate;
