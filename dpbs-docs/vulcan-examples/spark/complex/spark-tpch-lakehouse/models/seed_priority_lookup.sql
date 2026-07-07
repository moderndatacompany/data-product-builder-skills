MODEL (
  name mys3lh02depot.tpch_lakehouse.seed_priority_lookup,
  kind SEED (
    path '../seeds/priority_lookup.csv'
  ),
  columns (
    priority_id INT,
    priority_name STRING,
    priority_description STRING,
    sla_days INT
  ),
  grain (priority_id),
  assertions (
    unique_values(columns := priority_id),
    not_null(columns := (priority_id, priority_name))
  )
);
