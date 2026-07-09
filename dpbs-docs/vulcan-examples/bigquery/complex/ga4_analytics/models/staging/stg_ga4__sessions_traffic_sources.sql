-- Session Traffic Sources Model
-- Captures first traffic source attribution for each session
MODEL (
  name ga4_analytics.stg_ga4__sessions_traffic_sources,
  kind FULL,
  cron '@daily',
  tags ('ga4', 'sessions', 'attribution', 'traffic_source'),
  grains (session_key),
  description 'First-touch traffic source attribution for each session. Captures source, medium, campaign at session start.',
  column_descriptions (
    session_key = 'Unique session identifier',
    session_source = 'Traffic source for the session',
    session_medium = 'Traffic medium for the session',
    session_campaign = 'Campaign name for the session',
    session_content = 'Campaign content parameter',
    session_term = 'Campaign search term',
    session_default_channel_grouping = 'Default channel grouping based on source/medium',
    session_source_category = 'Category of the traffic source (Organic, Paid, etc.)'
  )
);

-- Get first event per session to establish session attribution
WITH session_first_event AS (
  SELECT
    session_key,
    event_timestamp,
    event_source,
    event_medium,
    event_campaign,
    event_content,
    event_term,
    user_source,
    user_medium,
    user_campaign,
    page_referrer,
    ROW_NUMBER() OVER (
      PARTITION BY session_key
      ORDER BY event_timestamp ASC
    ) AS event_rank
  FROM ga4_analytics.stg_ga4__events
  WHERE session_key IS NOT NULL
),

-- Select only the first event per session
first_event_only AS (
  SELECT
    session_key,
    -- Use event-level source/medium/campaign if available, otherwise fall back to user-level
    COALESCE(event_source, user_source) AS session_source,
    COALESCE(event_medium, user_medium) AS session_medium,
    COALESCE(event_campaign, user_campaign) AS session_campaign,
    event_content AS session_content,
    event_term AS session_term,
    page_referrer
  FROM session_first_event
  WHERE event_rank = 1
),

-- Apply default channel grouping logic
with_channel_grouping AS (
  SELECT
    *,
    CASE
      -- Direct traffic
      WHEN session_source IS NULL OR session_source = '(direct)' THEN 'Direct'
      WHEN session_medium = '(none)' THEN 'Direct'
      
      -- Organic Search
      WHEN session_medium = 'organic' THEN 'Organic Search'
      
      -- Paid Search
      WHEN session_medium IN ('cpc', 'ppc', 'paidsearch') THEN 'Paid Search'
      WHEN session_medium = 'cp' AND session_source = 'google' THEN 'Paid Search'
      
      -- Paid Social
      WHEN REGEXP_CONTAINS(session_medium, r'(.*)(social|facebook|instagram|twitter|linkedin|pinterest)(.*)')
        AND REGEXP_CONTAINS(session_medium, r'(.*)(cpc|ppc|paid|ad)(.*)')
        THEN 'Paid Social'
      
      -- Organic Social
      WHEN REGEXP_CONTAINS(session_source, r'(facebook|instagram|twitter|linkedin|pinterest|youtube|reddit|tiktok)')
        OR REGEXP_CONTAINS(session_medium, r'social')
        THEN 'Organic Social'
      
      -- Email
      WHEN session_medium IN ('email', 'e-mail', 'e_mail', 'e mail') THEN 'Email'
      
      -- Affiliates
      WHEN session_medium = 'affiliate' THEN 'Affiliates'
      
      -- Referral
      WHEN session_medium = 'referral' THEN 'Referral'
      
      -- Display
      WHEN session_medium IN ('display', 'cpm', 'banner') THEN 'Display'
      
      -- Video
      WHEN REGEXP_CONTAINS(session_medium, r'video') THEN 'Video'
      
      -- Other
      ELSE 'Other'
    END AS session_default_channel_grouping,
    
    CASE
      WHEN session_medium = 'organic' THEN 'Organic'
      WHEN session_medium IN ('cpc', 'ppc', 'paidsearch') THEN 'Paid'
      WHEN session_source IS NULL OR session_source = '(direct)' THEN 'Direct'
      WHEN session_medium IN ('email', 'referral', 'social') THEN 'Other'
      ELSE 'Other'
    END AS session_source_category
    
  FROM first_event_only
)

SELECT * FROM with_channel_grouping;

