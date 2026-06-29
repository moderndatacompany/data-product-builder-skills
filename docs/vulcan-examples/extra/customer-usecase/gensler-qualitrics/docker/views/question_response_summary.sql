-- Question response summary aggregate table
-- Provides aggregated response statistics per question with response counts, value ranges, and completion metrics
MODEL (
  name nilus.views.qualtrics_question_response_summary,
  kind VIEW,
  grains [survey_id, question_id],
  tags ('aggregate', 'metric', 'question_analytics', 'summary', 'production'),
  terms ('qualtrics.question_metrics', 'analytics.response_summary', 'aggregate.question_stats'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    question_id = 'Unique Qualtrics question identifier (e.g., QID1, QID2)',
    question_name = 'Data export tag or variable name for the question',
    question_type = 'Qualtrics question type (MC, TE, Matrix, Slider, etc.)',
    question_text = 'Full question text displayed to respondents',
    data_export_tag = 'Data export tag for the question field',
    variable_naming = 'Custom variable naming convention for export',
    total_responses = 'Total count of all responses received for this question across all response types',
    unique_response_values = 'Count of distinct response values provided for this question',
    complete_responses = 'Count of complete responses (status codes 0, 4, 8, 12, 16) for this question',
    preview_responses = 'Count of preview responses (status codes 1, 9, 17) for this question',
    min_response_value = 'Minimum numeric or coded response value received for this question',
    max_response_value = 'Maximum numeric or coded response value received for this question'
  ),
  column_tags (
    survey_id = ('identifier', 'partition_key', 'foreign_key'),
    question_id = ('identifier', 'grain', 'foreign_key'),
    question_name = ('metadata', 'export_tag'),
    question_type = ('classification', 'metadata'),
    question_text = ('content', 'display_text'),
    data_export_tag = ('metadata', 'export_field'),
    variable_naming = ('metadata', 'custom_naming'),
    total_responses = ('measurement', 'count', 'aggregate', 'kpi'),
    unique_response_values = ('measurement', 'count', 'aggregate', 'diversity'),
    complete_responses = ('measurement', 'count', 'aggregate', 'quality_metric'),
    preview_responses = ('measurement', 'count', 'aggregate', 'quality_metric'),
    min_response_value = ('measurement', 'numeric', 'aggregate', 'min'),
    max_response_value = ('measurement', 'numeric', 'aggregate', 'max')
  ),
  column_terms (
    survey_id = ('qualtrics.survey_id', 'aggregate.survey'),
    question_id = ('qualtrics.question_id', 'aggregate.question'),
    question_type = ('qualtrics.question_type', 'question.classification'),
    total_responses = ('response.total_count', 'metric.engagement'),
    unique_response_values = ('response.diversity', 'metric.variety'),
    complete_responses = ('response.complete_count', 'metric.completion'),
    preview_responses = ('response.preview_count', 'metric.testing')
  ),
  physical_properties (
    format = 'iceberg'
  )
);

SELECT
    rt.survey_id,
    rt.question_id,
    rt.question_name,
    rt.question_type,
    rt.question_text,
    qt.data_export_tag,
    qt.variable_naming,
    COUNT(DISTINCT rt.response_id) AS total_responses,
    COUNT(DISTINCT rt.response_value) AS unique_response_values,
    COUNT(DISTINCT CASE 
        WHEN rt.response_type_status IN (0, 4, 8, 12, 16) 
        THEN rt.response_id 
    END) AS complete_responses,
    COUNT(DISTINCT CASE 
        WHEN rt.response_type_status IN (1, 9, 17) 
        THEN rt.response_id 
    END) AS preview_responses,
    MIN(rt.response_value) AS min_response_value,
    MAX(rt.response_value) AS max_response_value
FROM nilus.vulcan.qualtrics_response_intermediate_table rt
INNER JOIN nilus.vulcan.qualtrics_definition_flattened qt
    ON rt.survey_id = qt.survey_id 
    AND rt.question_id = qt.question_id
INNER JOIN nilus.vulcan.sharepoint_metadata_seed ss
    ON rt.survey_id = ss.surveyid
WHERE (
    rt.response_type_status IN (0, 4, 8, 12, 16)
    OR (ss.count_x0020_previews = 'true' AND rt.response_type_status IN (1, 9, 17))
)
GROUP BY
    rt.survey_id,
    rt.question_id,
    rt.question_name,
    rt.question_type,
    rt.question_text,
    qt.data_export_tag,
    qt.variable_naming
