MODEL (
  name mys3lh02depot.tpch_lakehouse.daily_order_metrics,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column o_orderdate,
    batch_size 30,
    batch_concurrency 2,
    lookback 7,
    forward_only false
  ),
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (orders, incremental, daily, metrics),
  grains (o_orderdate),
  physical_properties (
    format = 'iceberg'
  ),
  allow_partials true,
  assertions (
    unique_values(columns := o_orderdate),
    not_null(columns := (o_orderdate, order_count)),
    forall(criteria := (order_count >= 0)),
    forall(criteria := (total_revenue >= 0))
  ),
  profiles (order_count, total_revenue, avg_order_value),
  column_descriptions (
    o_orderdate = 'Order date (grain)',
    order_count = 'Number of distinct orders placed on this date',
    total_revenue = 'Total revenue for the date',
    avg_order_value = 'Average order value for the date',
    total_quantity = 'Total quantity of items ordered'
  )
);

SELECT
  oi.o_orderdate,
  COUNT(DISTINCT oi.l_orderkey) AS order_count,
  COALESCE(SUM(oi.net_amount), 0) AS total_revenue,
  COALESCE(
    SUM(oi.net_amount) / NULLIF(COUNT(DISTINCT oi.l_orderkey), 0),
    0
  ) AS avg_order_value,
  SUM(oi.l_quantity) AS total_quantity
FROM mys3lh02depot.tpch_lakehouse.int_order_items oi
WHERE oi.o_orderdate BETWEEN @start_ds AND @end_ds
GROUP BY oi.o_orderdate;
