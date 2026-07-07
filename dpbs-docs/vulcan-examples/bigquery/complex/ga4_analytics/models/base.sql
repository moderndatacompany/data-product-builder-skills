-- Client Key First and Last Page Views Model
-- Tracks first and last pages viewed by each client/device
MODEL (
  name ga4_analytics.base_ga4__events_dummy,
  kind FULL,
  description 'Base GA4 events table.',

);
select * from `tmdc-platform-engineering`.`vulcan_ga4_demo`.`events_table`