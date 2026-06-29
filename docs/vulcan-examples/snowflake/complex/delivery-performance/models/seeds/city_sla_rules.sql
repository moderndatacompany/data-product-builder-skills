MODEL (
  name QCOMMERCE_PLATFORM.BRONZE.CITY_SLA_RULES,
  kind SEED (
    path '../../seeds/city_sla_rules.csv'
  ),
  columns (
    CITY VARCHAR(100),
    DELIVERY_MODE VARCHAR(50),
    SLA_MINUTES INTEGER,
    PRIORITY_WEIGHT FLOAT
  ),
  grains [CITY, DELIVERY_MODE],
  owner 'shreyasikarwartmdcio',
  description 'Reference SLA rules by city and delivery mode used to evaluate promised delivery windows and delivery priority for quick-commerce operations.',
  tags ('seed', 'bronze', 'delivery', 'sla', 'reference-data'),
  terms ('city_sla_rules', 'delivery_sla', 'priority_weight'),
  profiles (CITY, DELIVERY_MODE, SLA_MINUTES, PRIORITY_WEIGHT),
  column_descriptions (
    CITY = 'City where the delivery SLA rule applies',
    DELIVERY_MODE = 'Delivery service mode such as standard or express',
    SLA_MINUTES = 'Target delivery time in minutes for the city and delivery mode',
    PRIORITY_WEIGHT = 'Relative operational priority weight used to contextualize the SLA rule'
  ),
  column_tags (
    CITY = ('dimension', 'geography', 'grain'),
    DELIVERY_MODE = ('dimension', 'service-level', 'grain'),
    SLA_MINUTES = ('measure', 'duration', 'sla'),
    PRIORITY_WEIGHT = ('measure', 'weight', 'priority')
  ),
  column_terms (
    CITY = ('city', 'delivery_city', 'service_area'),
    DELIVERY_MODE = ('delivery_mode', 'service_type', 'speed_tier'),
    SLA_MINUTES = ('sla_minutes', 'delivery_target_minutes', 'promised_sla'),
    PRIORITY_WEIGHT = ('priority_weight', 'service_priority', 'ops_weight')
  ),
  assertions (
    not_null(columns := (CITY, DELIVERY_MODE, SLA_MINUTES)),
    accepted_range(column := SLA_MINUTES, min_v := 1, max_v := 180),
    accepted_range(column := PRIORITY_WEIGHT, min_v := 0.1, max_v := 5.0)
  )
);
