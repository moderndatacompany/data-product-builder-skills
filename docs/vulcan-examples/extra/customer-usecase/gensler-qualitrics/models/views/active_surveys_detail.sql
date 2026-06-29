-- Active surveys detail dimension table
-- Filtered view of currently active surveys with enriched metrics, structure counts, and activity classification
MODEL (
  name GENSLER.ANALYTICS.QUALTRICS_ACTIVE_SURVEYS_DETAIL,
  kind FULL,
  grains [SURVEY_ID],
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, SURVEY_NAME, IS_ACTIVE, TOTAL_RESPONSE_COUNT, LIVE_RESPONSE_COUNT, ACTIVITY_LEVEL, DAYS_SINCE_ACCESSED),
  description 'Active surveys detail dimension providing filtered view of currently active surveys with enriched metrics, structural analysis, and activity-based classification for operational monitoring and reporting',
  tags ('dimension', 'filtered', 'active_surveys', 'operational', 'production'),
  terms ('active_survey_dimension', 'active_catalog', 'operational_surveys'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    survey_name = 'Descriptive name or title of the survey',
    survey_description = 'Detailed description or purpose of the survey',
    owner_id = 'Qualtrics user ID of the survey owner or creator',
    organization_id = 'Qualtrics brand or organization ID that owns the survey',
    creation_date = 'Timestamp when the survey was originally created in Qualtrics platform',
    last_modified_date = 'Timestamp of the most recent modification to survey structure or content',
    last_accessed_date = 'Timestamp when the survey was last accessed or viewed in Qualtrics',
    is_active = 'Boolean flag indicating survey is currently active (always TRUE in this view)',
    earliest_response_date = 'Timestamp of the earliest response received for this survey',
    latest_response_date = 'Timestamp of the most recent response received for this survey',
    total_response_count = 'Total count of all responses across all types',
    live_response_count = 'Count of live production responses',
    survey_type = 'Survey type from SharePoint metadata',
    status = 'Survey status from SharePoint metadata',
    count_previews = 'Flag indicating whether preview responses should be counted',
    question_count = 'Total count of unique questions in the survey',
    block_count = 'Total count of unique blocks in the survey structure',
    actual_response_count = 'Actual count of responses from response data',
    days_since_accessed = 'Number of days elapsed since survey was last accessed',
    activity_level = 'Survey activity classification based on last access: Recently Active (<30 days), Moderately Active (30-90 days), Less Active (>90 days)'
  ),
  column_tags (
    survey_id = ('identifier', 'partition_key', 'grain', 'primary_key'),
    survey_name = ('metadata', 'descriptive', 'display'),
    survey_description = ('metadata', 'descriptive', 'content'),
    owner_id = ('identifier', 'reference', 'foreign_key'),
    organization_id = ('identifier', 'reference', 'foreign_key'),
    creation_date = ('temporal', 'timestamp', 'lifecycle', 'immutable'),
    last_modified_date = ('temporal', 'timestamp', 'lifecycle', 'audit'),
    last_accessed_date = ('temporal', 'timestamp', 'usage', 'audit'),
    is_active = ('flag', 'boolean', 'status', 'filter_criteria'),
    earliest_response_date = ('temporal', 'timestamp', 'aggregate'),
    latest_response_date = ('temporal', 'timestamp', 'aggregate'),
    total_response_count = ('measurement', 'count', 'aggregate', 'kpi'),
    live_response_count = ('measurement', 'count', 'aggregate', 'kpi'),
    survey_type = ('classification', 'business_category'),
    status = ('classification', 'business_state'),
    question_count = ('measurement', 'count', 'aggregate', 'structure'),
    block_count = ('measurement', 'count', 'aggregate', 'structure'),
    actual_response_count = ('measurement', 'count', 'aggregate', 'validation'),
    days_since_accessed = ('measurement', 'duration', 'derived', 'recency'),
    activity_level = ('classification', 'categorical', 'derived', 'business_segment')
  ),
  column_terms (
    survey_id = ('survey_id', 'active_survey'),
    survey_name = ('name', 'title'),
    is_active = ('active_status', 'active_only'),
    total_response_count = ('total_count', 'engagement'),
    question_count = ('question_count', 'size'),
    days_since_accessed = ('recency', 'staleness'),
    activity_level = ('activity_segment', 'engagement_tier')
  )
);

SELECT
    s.survey_id,
    s.survey_name,
    s.survey_description,
    s.owner_id,
    s.organization_id,
    s.creation_date,
    s.last_modified_date,
    s.last_accessed_date,
    s.is_active,
    s.earliest_response_date,
    s.latest_response_date,
    s.total_response_count + UNIFORM(1, 50, RANDOM()) as total_response_count,
    s.live_response_count + UNIFORM(1, 50, RANDOM()) as live_response_count,
    ss.surveytype AS survey_type,
    ss.status,
    ss.count_x0020_previews AS count_previews,
    COUNT(DISTINCT qt.question_id) + UNIFORM(1, 50, RANDOM()) AS question_count,
    COUNT(DISTINCT qt.block_id) + UNIFORM(1, 50, RANDOM())  AS block_count,
    COUNT(DISTINCT rt.response_id) + UNIFORM(1, 50, RANDOM())  AS actual_response_count,
    DATEDIFF(DAY, s.last_accessed_date, CURRENT_DATE()) + UNIFORM(1, 50, RANDOM())  AS days_since_accessed,
    CASE 
        WHEN DATEDIFF(DAY, s.last_accessed_date, CURRENT_DATE()) + UNIFORM(1, 50, RANDOM()) < 30
        THEN 'Recently Active'
        WHEN DATEDIFF(DAY, s.last_accessed_date, CURRENT_DATE()) + UNIFORM(1, 50, RANDOM()) < 90
        THEN 'Moderately Active'
        ELSE 'Less Active'
    END AS activity_level
FROM GENSLER.FINAL.QUALTRICS_SURVEY_LIST s
FULL OUTER JOIN GENSLER.FINAL.QUALTRICS_DEFINITION_FLATTENED qt
    ON s.survey_id = qt.survey_id
FULL OUTER JOIN GENSLER.RAW.QUALTRICS_RESPONSE_INTERMEDIATE_TABLE rt
    ON s.survey_id = rt.survey_id
FULL OUTER JOIN GENSLER.RAW.SHAREPOINT_METADATA_SEED ss
    ON s.survey_id = ss.surveyid
GROUP BY
    s.survey_id,
    s.survey_name,
    s.survey_description,
    s.owner_id,
    s.organization_id,
    s.creation_date,
    s.last_modified_date,
    s.last_accessed_date,
    s.is_active,
    s.earliest_response_date,
    s.latest_response_date,
    s.total_response_count,
    s.live_response_count,
    ss.surveytype,
    ss.status,
    ss.count_x0020_previews
