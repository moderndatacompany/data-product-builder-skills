-- Respondent metadata dimension table
-- Contains survey completion status, timing, and metadata for each response submission without question-specific data
MODEL (
  name nilus.vulcan.qualtrics_response_respondent,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(survey_id),
  grains [survey_id, response_id],
  tags ('dimension', 'respondent', 'metadata', 'completion', 'temporal'),
  terms ('qualtrics.respondent_metadata', 'response.completion_status', 'dimension.respondent'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    response_id = 'Unique identifier for each survey response submission',
    status = 'Response completion status (IP Address indicates completed response)',
    finished = 'Boolean flag indicating if the survey was completed (TRUE=completed, FALSE=incomplete)',
    progress = 'Percentage of survey completion (0-100)',
    user_language = 'Language code used by the respondent (EN, ES, FR, etc.)',
    distribution_channel = 'Survey distribution method (email, anonymous link, social media, etc.)',
    end_date = 'Timestamp when the respondent completed or exited the survey',
    start_date = 'Timestamp when the respondent started the survey',
    duration = 'Total time spent on survey in seconds',
    recorded_date = 'Timestamp when the response was recorded in Qualtrics system'
  ),
  column_tags (
    survey_id = ('identifier', 'foreign_key', 'dimension'),
    response_id = ('identifier', 'primary_key', 'dimension'),
    status = ('classification', 'completion_status'),
    finished = ('flag', 'boolean', 'completion'),
    progress = ('measurement', 'percentage', 'completion'),
    user_language = ('classification', 'locale'),
    distribution_channel = ('classification', 'marketing'),
    end_date = ('temporal', 'timestamp', 'completion'),
    start_date = ('temporal', 'timestamp', 'initiation'),
    duration = ('measurement', 'numeric', 'time'),
    recorded_date = ('temporal', 'timestamp', 'audit')
  ),
  column_terms (
    survey_id = ('qualtrics.survey_id', 'dimension.survey'),
    response_id = ('qualtrics.response_id', 'dimension.response'),
    status = ('qualtrics.completion_status', 'response.status'),
    finished = ('response.completed', 'survey.finished'),
    progress = ('response.progress_percentage', 'completion.metric'),
    user_language = ('respondent.language', 'locale.code'),
    distribution_channel = ('marketing.channel', 'distribution.method'),
    end_date = ('response.end_timestamp', 'completion.time'),
    start_date = ('response.start_timestamp', 'initiation.time'),
    duration = ('response.duration_seconds', 'time.measurement'),
    recorded_date = ('response.recorded_timestamp', 'audit.timestamp')
  ),
  physical_properties (
    format = 'iceberg'
  )
);

WITH unnesting_properties AS (
  SELECT
    REGEXP_EXTRACT(INPUT_FILE_NAME(), '(?:.+\\/)(.+)[\\.]') AS survey_id,
    EXPLODE_OUTER(result.properties.values.properties) AS (questions_key, values1)
  FROM nilus.vulcan.qualtrics_response_schema
), extracting_variable_names AS (
  SELECT
    survey_id,
    questions_key,
    values1.description AS variable_names
  FROM unnesting_properties
  WHERE
    values1.dataType = 'embeddedData'
), response_table_with_variable_names AS (
  SELECT
    a.survey_id,
    a.block_id,
    a.block_description,
    a.block_number,
    a.question_id,
    CASE WHEN b.variable_names IS NULL THEN a.questions_key ELSE b.variable_names END AS questions_key,
    sub_questions_recode,
    choice_recode,
    question_number,
    a.question_name,
    a.question_type,
    a.selector,
    a.sub_selector,
    a.question_text,
    a.image_description,
    a.sub_questions,
    a.choices,
    a.variable_naming,
    a.choice_key,
    a.items,
    a.groups,
    a.regions,
    a.data_export_tag,
    a.sbs_question_number,
    a.sbs_question_text,
    a.sbs_question_type,
    a.sbs_question_selector,
    a.sbs_question_sub_selector,
    a.sbs_choices,
    a.response_id,
    a.response,
    a.response_type,
    a.response_value,
    a.response_type_status,
    a.sub_questions_key
  FROM nilus.vulcan.qualtrics_response_intermediate_table AS a
  LEFT JOIN extracting_variable_names AS b
    ON b.survey_id = a.survey_id AND a.questions_key = b.questions_key
), response_table_null_questions_key_removed AS (
  SELECT
    survey_id,
    block_id,
    block_description,
    block_number,
    question_id,
    CASE WHEN questions_key IS NULL THEN question_id ELSE questions_key END AS questions_key,
    question_number,
    question_name,
    question_type,
    selector,
    sub_selector,
    question_text,
    image_description,
    sub_questions,
    choices,
    variable_naming,
    choice_key,
    items,
    groups,
    regions,
    data_export_tag,
    sbs_question_number,
    sbs_question_text,
    sbs_question_type,
    sbs_question_selector,
    sbs_question_sub_selector,
    sbs_choices,
    response_id,
    response,
    response_type,
    response_value,
    response_type_status,
    sub_questions_recode,
    choice_recode,
    sub_questions_key
  FROM response_table_with_variable_names
), filtering_repeated_choice_text_rows AS (
  SELECT
    *
  FROM response_table_null_questions_key_removed
  WHERE
    CASE
      WHEN (
        NOT question_type IN ('MC', 'Matrix')
        OR (
          question_type IN ('MC', 'Matrix') AND selector = 'TE'
        )
        OR question_type IS NULL
      )
      THEN 0
      WHEN (
        question_type IN ('MC', 'Matrix')
      )
      AND (
        choice_key IS NULL
        OR response_value IS NULL
        OR CASE WHEN choice_recode IS NULL THEN choice_key ELSE choice_recode END::INT = response_value
      )
      THEN 1
      ELSE 2
    END IN (0, 1)
), respondent_metadata_table AS (
  SELECT
    survey_id,
    response_id,
    MAX(CASE WHEN questions_key = 'status' THEN response END) AS status,
    MAX(CASE WHEN questions_key = 'finished' THEN response END)::BOOLEAN AS finished,
    MAX(CASE WHEN questions_key = 'progress' THEN response END)::INT AS progress,
    MAX(CASE WHEN questions_key = 'userLanguage' THEN response END) AS user_language,
    MAX(CASE WHEN questions_key = 'distributionChannel' THEN response END) AS distribution_channel,
    MAX(CASE WHEN questions_key = 'endDate' THEN response END)::TIMESTAMP AS end_date,
    MAX(CASE WHEN questions_key = 'startDate' THEN response END)::TIMESTAMP AS start_date,
    MAX(CASE WHEN questions_key = 'duration' THEN response END)::INT AS duration,
    MAX(CASE WHEN questions_key = 'recordedDate' THEN response END)::TIMESTAMP AS recorded_date
  FROM nilus.vulcan.qualtrics_response_intermediate_table
  WHERE
    questions_key IN (
      'status',
      'finished',
      'progress',
      'userLanguage',
      'distributionChannel',
      'endDate',
      'startDate',
      'duration',
      'recordedDate'
    )
  GROUP BY
    1,
    2
)
SELECT
  *
FROM respondent_metadata_table