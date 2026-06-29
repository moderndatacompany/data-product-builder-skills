-- Survey metrics aggregate table
-- Comprehensive survey analytics with response statistics, question/block counts, temporal metrics, and performance indicators
MODEL (
  name nilus.views.qualtrics_survey_metrics,
  kind VIEW,
  grains [survey_id],
  tags ('aggregate', 'metric', 'survey_analytics', 'kpi', 'production'),
  terms ('qualtrics.survey_metrics', 'analytics.survey_performance', 'aggregate.survey_stats'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    survey_name = 'Descriptive name or title of the survey',
    survey_description = 'Detailed description or purpose of the survey',
    owner_id = 'Qualtrics user ID of the survey owner or creator',
    organization_id = 'Qualtrics brand or organization ID that owns the survey',
    creation_date = 'Timestamp when the survey was originally created in Qualtrics platform',
    last_modified_date = 'Timestamp of the most recent modification to survey structure or content',
    last_accessed_date = 'Timestamp when the survey was last accessed or viewed in Qualtrics',
    is_active = 'Boolean flag indicating if survey is currently active and accepting responses',
    total_response_count = 'Total count of all responses across all types',
    live_response_count = 'Count of live production responses (status codes 0, 8, 16)',
    test_response_count = 'Count of test responses (status code 2)',
    preview_response_count = 'Count of preview responses (status codes 1, 9, 17)',
    imported_response_count = 'Count of imported responses from external sources (status codes 4, 12)',
    earliest_response_date = 'Timestamp of the earliest response received for this survey',
    latest_response_date = 'Timestamp of the most recent response received for this survey',
    survey_type = 'Survey type from SharePoint metadata',
    status = 'Survey status from SharePoint metadata',
    count_previews = 'Flag indicating whether preview responses should be counted',
    total_questions = 'Total count of unique questions in the survey',
    total_blocks = 'Total count of unique blocks in the survey structure',
    days_since_creation = 'Number of days elapsed since survey was created',
    days_since_last_modified = 'Number of days elapsed since survey was last modified',
    live_response_percentage = 'Percentage of live responses out of total responses'
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
    is_active = ('flag', 'boolean', 'status', 'business_critical'),
    total_response_count = ('measurement', 'count', 'aggregate', 'kpi'),
    live_response_count = ('measurement', 'count', 'aggregate', 'kpi'),
    test_response_count = ('measurement', 'count', 'aggregate', 'quality_metric'),
    preview_response_count = ('measurement', 'count', 'aggregate', 'quality_metric'),
    imported_response_count = ('measurement', 'count', 'aggregate'),
    earliest_response_date = ('temporal', 'timestamp', 'aggregate', 'min'),
    latest_response_date = ('temporal', 'timestamp', 'aggregate', 'max'),
    survey_type = ('classification', 'business_category'),
    status = ('classification', 'business_state'),
    total_questions = ('measurement', 'count', 'aggregate', 'structure'),
    total_blocks = ('measurement', 'count', 'aggregate', 'structure'),
    days_since_creation = ('measurement', 'duration', 'derived', 'lifecycle'),
    days_since_last_modified = ('measurement', 'duration', 'derived', 'audit'),
    live_response_percentage = ('measurement', 'percentage', 'derived', 'quality_metric', 'kpi')
  ),
  column_terms (
    survey_id = ('qualtrics.survey_id', 'aggregate.survey'),
    survey_name = ('survey.name', 'metadata.title'),
    total_response_count = ('response.total_count', 'metric.engagement'),
    live_response_count = ('response.live_count', 'metric.production'),
    total_questions = ('survey.question_count', 'structure.size'),
    total_blocks = ('survey.block_count', 'structure.organization'),
    live_response_percentage = ('response.live_ratio', 'quality.metric')
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
    s.total_response_count,
    s.live_response_count,
    s.test_response_count,
    s.preview_response_count,
    s.imported_response_count,
    s.earliest_response_date,
    s.latest_response_date,
    ss.surveytype AS survey_type,
    ss.status,
    ss.count_x0020_previews AS count_previews,
    COUNT(DISTINCT qt.question_id) AS total_questions,
    COUNT(DISTINCT qt.block_id) AS total_blocks,
    DATEDIFF(CURRENT_DATE(), s.creation_date) AS days_since_creation,
    DATEDIFF(CURRENT_DATE(), s.last_modified_date) AS days_since_last_modified,
    CASE 
        WHEN s.total_response_count > 0 
        THEN ROUND(CAST(s.live_response_count AS DOUBLE) / s.total_response_count * 100, 2)
        ELSE 0 
    END AS live_response_percentage
FROM nilus.vulcan.qualtrics_survey_list_table s
INNER JOIN nilus.vulcan.sharepoint_metadata_seed ss
    ON s.survey_id = ss.surveyid
LEFT JOIN nilus.vulcan.qualtrics_definition_flattened qt
    ON s.survey_id = qt.survey_id
WHERE NOT (
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
    s.total_response_count,
    s.live_response_count,
    s.test_response_count,
    s.preview_response_count,
    s.imported_response_count,
    s.earliest_response_date,
    s.latest_response_date,
    ss.surveytype,
    ss.status,
    ss.count_x0020_previews
