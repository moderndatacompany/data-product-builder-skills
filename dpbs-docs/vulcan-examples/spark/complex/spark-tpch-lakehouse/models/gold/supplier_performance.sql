MODEL (
  name mys3lh02depot.tpch_lakehouse.supplier_performance,
  kind FULL,
  start '2025-01-01',
  owner 'rohitrajtmdcio',
  tags (supplier, analytics, gold),
  grains (s_suppkey),
  physical_properties (
    format = 'iceberg'
  ),
  assertions (
    unique_values(columns := s_suppkey),
    not_null(columns := (s_suppkey, s_name)),
    forall(criteria := (total_revenue >= 0)),
    forall(criteria := (parts_supplied >= 0))
  ),
  profiles (total_revenue, line_count, parts_supplied, n_name),
  column_descriptions (
    s_suppkey = 'Supplier key',
    s_name = 'Supplier name',
    s_acctbal = 'Supplier account balance',
    n_name = 'Nation name',
    r_name = 'Region name',
    total_revenue = 'Total revenue from line items supplied',
    line_count = 'Total line items supplied',
    parts_supplied = 'Number of distinct parts supplied',
    avg_supply_cost = 'Average supply cost across part-supplier relationships'
  )
);

SELECT
  s.s_suppkey,
  s.s_name,
  s.s_acctbal,
  n.n_name,
  r.r_name,
  COALESCE(SUM(oi.net_amount), 0) AS total_revenue,
  COUNT(oi.l_linenumber) AS line_count,
  COUNT(DISTINCT ps.ps_partkey) AS parts_supplied,
  AVG(ps.ps_supplycost) AS avg_supply_cost
FROM mys3lh02depot.tpch_lakehouse.stg_supplier s
JOIN mys3lh02depot.tpch_lakehouse.stg_nation n ON n.n_nationkey = s.s_nationkey
JOIN mys3lh02depot.tpch_lakehouse.stg_region r ON r.r_regionkey = n.n_regionkey
LEFT JOIN mys3lh02depot.tpch_lakehouse.stg_partsupp ps ON ps.ps_suppkey = s.s_suppkey
LEFT JOIN mys3lh02depot.tpch_lakehouse.int_order_items oi ON oi.l_suppkey = s.s_suppkey
GROUP BY
  s.s_suppkey,
  s.s_name,
  s.s_acctbal,
  n.n_name,
  r.r_name;
