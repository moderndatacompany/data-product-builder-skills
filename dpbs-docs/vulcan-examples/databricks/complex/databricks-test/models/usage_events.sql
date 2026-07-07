MODEL (
  name b2b_saas.usage_events,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column event_date
  ),
  owner 'animesh',
  grains (event_id),
  profiles (event_date, event_type, feature_name, feature_category),
  tags ('usage', 'telemetry', 'events', 'product'),
  terms ('product.usage_events', 'telemetry.events'),
  description 'Product usage telemetry table capturing user interactions, feature adoption, and engagement with computed engagement scores and feature categorization for the last 90 days',
  column_descriptions (
    event_id = 'Unique identifier for each usage event',
    user_id = 'Foreign key to the user who performed this action',
    event_date = 'Timestamp when the usage event occurred',
    event_type = 'Type of user action (api_call, feature_use, export)',
    feature_name = 'Name of the product feature used (dashboard, reports, analytics, integrations, api_access)',
    session_duration = 'Duration of the session in minutes',
    event_count = 'Number of events in this aggregation',
    engagement_score = 'Computed engagement score based on event type and count (api_call: count * 20, feature_use: count * 1.5, export: count * 3)',
    feature_category = 'Computed feature classification (core, advanced, developer, other)'
  ),
  column_tags (
    event_id = ('primary_key', 'identifier'),
    user_id = ('foreign_key', 'reference'),
    event_date = ('temporal', 'timestamp'),
    event_type = ('classification', 'event'),
    feature_name = ('feature', 'product'),
    engagement_score = ('metric', 'engagement', 'computed'),
    feature_category = ('classification', 'computed')
  ),
  column_terms (
    event_id = ('product.event_id', 'telemetry.event_id'),
    user_id = ('customer.user_id', 'reference.user_id'),
    event_date = ('product.event_date', 'temporal.event_timestamp'),
    event_type = ('product.event_type', 'classification.event_type'),
    feature_name = ('product.feature_name', 'feature.name'),
    engagement_score = ('product.engagement_score', 'metric.engagement'),
    feature_category = ('product.feature_category', 'classification.feature')
  )
);

-- Enriched usage events with engagement scoring
SELECT 
  event_id,
  user_id,
  event_date::TIMESTAMP AS event_date,
  event_type,
  feature_name,
  session_duration,
  event_count,
  
  -- Engagement scoring
  CASE 
    WHEN event_type = 'api_call' THEN event_count * 20
    WHEN event_type = 'feature_use' THEN event_count * 1.5
    WHEN event_type = 'export' THEN event_count * 3
    ELSE event_count
  END as engagement_score,
  
  -- Feature categorization
  CASE 
    WHEN feature_name IN ('dashboard', 'reports') THEN 'core'
    WHEN feature_name IN ('analytics', 'integrations') THEN 'advanced'
    WHEN feature_name = 'api_access' THEN 'developer'
    ELSE 'other'
  END as feature_category

FROM b2b_saas.usage_events_seed
WHERE event_date >= CURRENT_DATE - INTERVAL '90 days';  -- Incremental logic
