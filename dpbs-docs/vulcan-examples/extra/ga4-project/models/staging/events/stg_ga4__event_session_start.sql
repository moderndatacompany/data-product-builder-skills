-- Session Start Event Model
-- Filters events for session_start to identify new sessions
MODEL (
  name ga4_analytics.stg_ga4__event_session_start,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'events', 'session_start'),
  grains (event_key),
  description 'Session start events marking the beginning of user sessions. Used for session attribution and initialization.'
);

-- Extract session start events
SELECT
  *
FROM ga4_analytics.stg_ga4__events
WHERE event_name = 'session_start';

