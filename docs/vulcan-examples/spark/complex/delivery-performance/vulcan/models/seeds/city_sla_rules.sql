MODEL (
  name s3depot.qcommerce_delivery_bronze.city_sla_rules,
  kind SEED (
    path '../../seeds/city_sla_rules.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [city, delivery_mode],
  description 'Reference SLA rules by city and delivery mode used to evaluate promised delivery windows and delivery priority for quick-commerce operations.',
  tags ('seed', 'bronze', 'delivery', 'sla', 'reference-data'),
  terms ('city_sla_rules', 'delivery_sla', 'priority_weight'),
  columns (
    city STRING,
    delivery_mode STRING,
    sla_minutes INT,
    priority_weight DOUBLE
  ),
  assertions (
    not_null(columns := (city, delivery_mode, sla_minutes)),
    accepted_range(column := sla_minutes, min_v := 1, max_v := 180),
    accepted_range(column := priority_weight, min_v := 0.1, max_v := 5.0)
  )
);
