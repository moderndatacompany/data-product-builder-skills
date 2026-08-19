MODEL (
  name b2b_saas.usage_events_seed,
  kind SEED (
    path '../../seeds/usage_events.csv'
  ),
  columns (
    event_id INTEGER,
    user_id INTEGER,
    event_date DATE,
    event_type VARCHAR,
    feature_name VARCHAR,
    session_duration INTEGER,
    event_count INTEGER
  ),
  audits (
    not_null(columns := (event_id, user_id, event_date, event_type)),
    unique_values(columns := (event_id)),
    accepted_values(column := event_type, is_in := ('login', 'feature_use', 'api_call', 'export'))
  )
);
