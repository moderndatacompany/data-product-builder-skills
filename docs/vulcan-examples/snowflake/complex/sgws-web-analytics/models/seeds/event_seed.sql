MODEL (
  name web_analytics_seeds.EVENT,
  kind SEED (
    path '../../seeds/event.tsv',
    csv_settings (
      delimiter = '\t'
    )
  ),
  owner 'rohitrajtmdcio',
  description 'Adobe Analytics event type reference data',
  tags ('seed', 'reference_data', 'adobe_analytics', 'lookup'),
  terms ('event'),
  columns (
        event_id BIGINT,
        event_name VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: EVENT
-- ============================================================================

SELECT
  event_id,
  event_name
FROM SEED();
