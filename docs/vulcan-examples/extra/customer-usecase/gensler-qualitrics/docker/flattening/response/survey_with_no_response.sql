-- Intermediate transformation merging all survey responses with status flags
-- Handles surveys with no responses, only metadata, or empty response files, ensuring complete coverage for all surveys
MODEL (
  name nilus.vulcan.repartition_merging_survey_id_with_no_response_files,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(survey_id),
  grains [survey_id, response_id, values_key],
  tags ('transformation', 'response', 'merging', 'data_quality', 'fact'),
  terms ('qualtrics.response_completeness', 'data_quality.coverage', 'response.fact'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    response_id = 'Unique identifier for each survey response submission (NULL for surveys without responses)',
    response_type_status = 'Numeric status code indicating response type (0=Live, 1=Preview, 2=Test, 4=Imported, etc.)',
    response_type = 'Human-readable response status label (IP Address, Survey Preview, etc.)',
    values_key = 'Question identifier or variable name for the response field',
    response_value = 'Numeric or coded value of the response',
    response = 'Human-readable response value or special status (no_file, empty_response, only_respondent_metadata)',
    row_num = 'Row number assigned to responses for processing and joining logic'
  ),
  column_tags (
    survey_id = ('identifier', 'foreign_key', 'survey'),
    response_id = ('identifier', 'response', 'nullable'),
    response_type_status = ('classification', 'status_code'),
    response_type = ('classification', 'status_label'),
    values_key = ('identifier', 'question_key'),
    response_value = ('measurement', 'response_data'),
    response = ('measurement', 'response_data', 'display_value'),
    row_num = ('technical', 'processing')
  ),
  column_terms (
    survey_id = ('qualtrics.survey_id', 'survey.identifier'),
    response_id = ('qualtrics.response_id', 'response.identifier'),
    response_type_status = ('qualtrics.status_code', 'response.status'),
    response_type = ('qualtrics.status_label', 'response.status_description'),
    values_key = ('question.export_key', 'response.variable'),
    response_value = ('response.coded_value', 'data.numeric_value'),
    response = ('response.display_value', 'data.label'),
    row_num = ('processing.row_number', 'technical.sequence')
  ),
  physical_properties (
    format = 'iceberg'
  )
);


WITH response_with_survey_id AS (
  SELECT
    REGEXP_EXTRACT(INPUT_FILE_NAME(), '(?:.+\\/)(.+)[\\.]') AS survey_id,
    FROM_JSON(
      `values`,
      'array<struct<responseId:string, values:map<string,string>, labels:map<string,string>>>'
    ) AS responses
  FROM nilus.dummy.qualtrics_responses
), response_connect AS (
  SELECT /*+ REPARTITION(100) */
    *
  FROM response_with_survey_id
), definition_connect AS (
  SELECT
    parsed_json.result.SurveyID AS survey_id
  FROM nilus.vulcan.qualtrics_definition
), question_table_with_embedded_fields AS (
  SELECT /*+ REPARTITION(100) */
    *
  FROM nilus.vulcan.qualtrics_questions_flattening_part_001
), explode_responses AS (
  SELECT
    survey_id,
    EXPLODE_OUTER(responses) AS exp_responses
  FROM response_connect
), unnest_responses AS (
  SELECT
    survey_id,
    exp_responses.responseId AS response_id,
    exp_responses.values.status::INT AS response_type_status,
    exp_responses.labels.status AS response_type,
    exp_responses.values AS response_values,
    exp_responses.labels AS response_labels
  FROM explode_responses
), exploded_response_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    EXPLODE_OUTER(response_values) AS (values_key, values_response)
  FROM unnest_responses
), exploded_response_labels AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    EXPLODE_OUTER(response_labels) AS (labels_key, labels_response)
  FROM unnest_responses
), value_labels_merge AS (
  SELECT
    a.survey_id,
    a.response_id,
    a.response_type_status,
    a.response_type,
    a.values_key,
    a.values_response,
    CASE
      WHEN b.labels_response IS NULL
      THEN a.values_response
      ELSE b.labels_response
    END AS responses
  FROM exploded_response_values AS a
  LEFT JOIN exploded_response_labels AS b
    ON b.survey_id = a.survey_id
    AND b.response_id = a.response_id
    AND b.labels_key = a.values_key
), replacing_comma_from_array_responses AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    values_response,
    CASE
      WHEN responses RLIKE '^\\[\\{.*'
      THEN REPLACE(responses, CONCAT(CHR(125), CHR(44), CHR(123)), '}#+{')
      WHEN responses RLIKE '^\\[.*'
      THEN REPLACE(responses, '","', '#+')
      ELSE responses
    END AS responses
  FROM value_labels_merge
), reading_array_as_string AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    CASE
      WHEN values_response RLIKE '^\\[\\{.*'
      THEN values_response::STRING
      WHEN values_response RLIKE '^\\[.*'
      THEN FROM_JSON(values_response, 'array<string>')::STRING
      ELSE values_response
    END AS values_response,
    CASE
      WHEN responses RLIKE '^\\[\\{.*'
      THEN responses::STRING
      WHEN responses RLIKE '^\\[.*'
      THEN FROM_JSON(responses, 'array<string>')::STRING
      ELSE responses
    END AS responses
  FROM replacing_comma_from_array_responses
), fixing_array_responses AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    CASE
      WHEN values_response RLIKE '^\\[\\{.*'
      THEN REPLACE(values_response, CONCAT(CHR(125), CHR(44), ' ', CHR(123)), '}#_{')
      WHEN values_response RLIKE '^\\[.*'
      THEN REPLACE(values_response, CHR(44), '#_')
      ELSE values_response
    END AS values_response,
    CASE
      WHEN responses RLIKE '^\\[\\{.*'
      THEN REPLACE(responses, CHR(44), '#_')
      WHEN responses RLIKE '^\\[.*'
      THEN REPLACE(responses, CHR(44), '#_')
      ELSE REPLACE(responses, CHR(44), '#_')
    END AS responses
  FROM reading_array_as_string
), array_on_all_responses AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    CASE
      WHEN NOT values_key LIKE '%_TEXT%'
      THEN SPLIT(REGEXP_EXTRACT(values_response, '\\[(.*)\\]'), '#_ ')
      ELSE ARRAY(REPLACE(REGEXP_EXTRACT(values_response, '\\[(.*)\\]'), '#_', ','))
    END AS response_num_in_array,
    CASE
      WHEN NOT values_key LIKE '%_TEXT%'
      THEN SPLIT(REPLACE(REGEXP_EXTRACT(responses, '\\[(.*)\\]'), '#+', ','), ',')
      ELSE ARRAY(REPLACE(REGEXP_EXTRACT(responses, '\\[(.*)\\]'), '#_', ','))
    END AS responses_in_array
  FROM fixing_array_responses
), zipped_all_responses_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    ARRAYS_ZIP(COALESCE(response_num_in_array, ARRAY()), COALESCE(responses_in_array, ARRAY())) AS zipped_responses_values
  FROM array_on_all_responses
), explode_zipped_all_responses_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    EXPLODE_OUTER(zipped_responses_values) AS exploded_responses_values
  FROM zipped_all_responses_values
), unnest_explode_zipped_all_responses_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    exploded_responses_values.`0` AS response_value,
    exploded_responses_values.`1` AS responses
  FROM explode_zipped_all_responses_values
), rename_response_value AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    response_value,
    REPLACE(responses, '#_', ',') AS response
  FROM unnest_explode_zipped_all_responses_values
), all_responses AS (
  SELECT
    *,
    CASE WHEN values_key = 'QID_null' THEN 1 ELSE NULL END AS row_num
  FROM (
    SELECT
      survey_id,
      response_id,
      response_type_status,
      response_type,
      CASE WHEN values_key IS NULL THEN 'QID_null' ELSE values_key END AS values_key,
      response_value,
      CASE WHEN response = '' THEN 'empty_response' ELSE response END AS response
    FROM rename_response_value
  )
), survey_id_response AS (
  SELECT
    response_connect.survey_id
  FROM response_connect
), no_response_flag_filter AS (
  SELECT
    survey_id,
    CASE
      WHEN values_key IS NULL
      THEN NULL
      WHEN values_key LIKE '%QID%'
      THEN '1'
      ELSE 0
    END AS no_response_flag
  FROM exploded_response_values
), only_respondent_metadata_filter AS (
  SELECT
    survey_id,
    CASE WHEN SUM(no_response_flag) = 0 THEN 'only_respondent_metadata' ELSE NULL END AS response
  FROM no_response_flag_filter
  GROUP BY
    1
), flag_row_number AS (
  SELECT
    survey_id,
    NULL AS response_id,
    NULL AS response_type_status,
    NULL AS response_type,
    'QID_null' AS values_key,
    'only_respondent_metadata' AS response_value,
    response,
    1 AS row_num
  FROM only_respondent_metadata_filter
  WHERE
    NOT response IS NULL
), merging_survey_id_with_no_response_files AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    response_value,
    response,
    row_num
  FROM all_responses
  UNION
  SELECT
    survey_id,
    NULL AS response_id,
    NULL AS response_type_status,
    NULL AS response_type,
    'QID_null' AS values_key,
    'no_file' AS response_value,
    'no_file' AS response,
    1 AS row_num
  FROM (
    SELECT
      survey_id
    FROM definition_connect
  )
  WHERE
    NOT survey_id IN (
      SELECT
        survey_id
      FROM survey_id_response
    )
  UNION
  SELECT
    *
  FROM flag_row_number
), repartition_merging_survey_id_with_no_response_files AS (
  SELECT /*+ REPARTITION(100) */
    *
  FROM merging_survey_id_with_no_response_files
)
SELECT
  *
FROM repartition_merging_survey_id_with_no_response_files