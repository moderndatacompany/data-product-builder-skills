-- Active surveys detail dimension table
-- Filtered view of currently active surveys with enriched metrics, structure counts, and activity classification
MODEL (
  name nilus.views.qualtrics_active_surveys_detail,
  kind VIEW,
  grains [survey_id],
  tags ('dimension', 'filtered', 'active_surveys', 'operational', 'production'),
  terms ('qualtrics.active_survey_dimension', 'survey.active_catalog', 'analytics.operational_surveys'),
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
    survey_id = ('qualtrics.survey_id', 'dimension.active_survey'),
    survey_name = ('survey.name', 'metadata.title'),
    is_active = ('survey.active_status', 'filter.active_only'),
    total_response_count = ('response.total_count', 'metric.engagement'),
    question_count = ('survey.question_count', 'structure.size'),
    days_since_accessed = ('survey.recency', 'usage.staleness'),
    activity_level = ('survey.activity_segment', 'business.engagement_tier')
  ),
  physical_properties (
    format = 'iceberg'
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
    s.total_response_count,
    s.live_response_count,
    ss.surveytype AS survey_type,
    ss.status,
    ss.count_x0020_previews AS count_previews,
    COUNT(DISTINCT qt.question_id) AS question_count,
    COUNT(DISTINCT qt.block_id) AS block_count,
    COUNT(DISTINCT rt.response_id) AS actual_response_count,
    DATEDIFF(CURRENT_DATE(), s.last_accessed_date) AS days_since_accessed,
    CASE 
        WHEN DATEDIFF(CURRENT_DATE(), s.last_accessed_date) < 30
        THEN 'Recently Active'
        WHEN DATEDIFF(CURRENT_DATE(), s.last_accessed_date) < 90
        THEN 'Moderately Active'
        ELSE 'Less Active'
    END AS activity_level
FROM nilus.vulcan.qualtrics_survey_list_table s
INNER JOIN nilus.vulcan.sharepoint_metadata_seed ss
    ON s.survey_id = ss.surveyid
LEFT JOIN nilus.vulcan.qualtrics_definition_flattened qt
    ON s.survey_id = qt.survey_id
LEFT JOIN nilus.vulcan.qualtrics_response_intermediate_table rt
    ON s.survey_id = rt.survey_id
WHERE s.is_active = TRUE
    AND NOT (
        ss.surveytype IN ('Demo', 'Test', 'Template', 'Template_Demo', 'Confidential')
        OR ss.status IN ('Cancelled', 'Testing', 'On Hold', 'Superseded')
    )
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
