MODEL (
  name b2b_saas.usage_sessions,
  kind SEED (
    path '../seeds/usage_sessions.csv'
  ),
  grains (session_id),
  tags (
    'session', 
    'usage', 
    'engagement'
  ),
  terms (
      'product.usage_sessions', 
      'engagement.sessions'
  ),
  description 'User session aggregation table grouping usage events into distinct sessions with duration tracking, action counts, page views, and device type information',
  column_descriptions (
    session_id = 'Unique identifier for each user session',
    event_id = 'Foreign key linking to the primary event in this session',
    session_start = 'Timestamp when the session began',
    session_end = 'Timestamp when the session ended',
    session_duration_minutes = 'Total duration of the session in minutes',
    actions_count = 'Number of actions performed during the session',
    pages_viewed = 'Number of pages viewed during the session',
    device_type = 'Type of device used (desktop, mobile, tablet)'
  )
);

-- User session data aggregated from events
-- Each session groups multiple usage events
SELECT
  session_id::TEXT AS session_id,
  event_id::INT AS event_id,
  session_start::TIMESTAMP AS session_start,
  session_end::TIMESTAMP AS session_end,
  session_duration_minutes::INT AS session_duration_minutes,
  actions_count::INT AS actions_count,
  pages_viewed::INT AS pages_viewed,
  device_type::TEXT AS device_type
FROM @this_model;

