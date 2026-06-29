-- Intermediate transformation merging all survey responses with status flags
-- Handles surveys with no responses, only metadata, or empty response files, ensuring complete coverage for all surveys
MODEL (
  name GENSLER.RAW.SURVEY_ID_NO_RESPONSE_FILES,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(survey_id),
  grains [SURVEY_ID, RESPONSE_ID, VALUES_KEY],
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, RESPONSE_ID, VALUES_KEY, RESPONSE_TYPE_STATUS, RESPONSE_VALUE, RESPONSE),
  description 'Intermediate transformation merging all survey responses with status flags for data quality coverage, handling surveys with no responses, only metadata, or empty response files to ensure complete survey catalog representation',
  tags ('transformation', 'response', 'merging', 'data_quality', 'fact'),
  terms ('response_completeness', 'coverage', 'fact'),
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
    survey_id = ('survey_id', 'identifier'),
    response_id = ('response_id', 'identifier'),
    response_type_status = ('status_code', 'status'),
    response_type = ('status_label', 'status_description'),
    values_key = ('export_key', 'variable'),
    response_value = ('coded_value', 'numeric_value'),
    response = ('display_value', 'label'),
    row_num = ('row_number', 'sequence')
  )
);

WITH response_with_survey_id AS (
  SELECT
     survey_id,
    PARSE_JSON(values_parsed) AS responses
  FROM GENSLER.RAW.QUALTRICS_RESPONSE
), response_connect AS (
  SELECT
    *
  FROM response_with_survey_id
), definition_connect AS (
  SELECT
    parsed_json:result.SurveyID::STRING AS survey_id
  FROM GENSLER.RAW.QUALTRICS_DEFINITION
), question_table_with_embedded_fields AS (
  SELECT
    *
  FROM GENSLER.RAW.QUALTRICS_QUESTIONS_FLATTENING_PART_001
), explode_responses AS (
  SELECT
    survey_id,
    f.value AS exp_responses
  FROM response_connect,
       LATERAL FLATTEN(
           INPUT => responses,
           OUTER => TRUE
       ) f
), unnest_responses AS (
  SELECT
    survey_id,
    exp_responses:responseId::STRING AS response_id,
    exp_responses:values.status::INT AS response_type_status,
    exp_responses:labels.status::STRING AS response_type,
    exp_responses:values AS response_values,
    exp_responses:labels AS response_labels
  FROM explode_responses
), exploded_response_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    f.key::STRING AS values_key,
    f.value::STRING AS values_response
  FROM unnest_responses,
       LATERAL FLATTEN(
           INPUT => response_values,
           OUTER => TRUE
       ) f
), exploded_response_labels AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    f.key::STRING AS labels_key,
    f.value::STRING AS labels_response
  FROM unnest_responses,
       LATERAL FLATTEN(
           INPUT => response_labels,
           OUTER => TRUE
       ) f
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
      WHEN REGEXP_LIKE(responses, '^\\[\\{.*')
      THEN REPLACE(responses, CONCAT(CHAR(125), CHAR(44), CHAR(123)), '}#+{')
      WHEN REGEXP_LIKE(responses, '^\\[.*')
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
      WHEN REGEXP_LIKE(values_response, '^\\[\\{.*')
      THEN values_response::STRING
      WHEN REGEXP_LIKE(values_response, '^\\[.*')
      THEN PARSE_JSON(values_response)::STRING
      ELSE values_response
    END AS values_response,
    CASE
      WHEN REGEXP_LIKE(responses, '^\\[\\{.*')
      THEN responses::STRING
      WHEN REGEXP_LIKE(responses, '^\\[.*')
      THEN PARSE_JSON(responses)::STRING
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
      WHEN REGEXP_LIKE(values_response, '^\\[\\{.*')
      THEN REPLACE(values_response, CONCAT(CHAR(125), CHAR(44), ' ', CHAR(123)), '}#_{')
      WHEN REGEXP_LIKE(values_response, '^\\[.*')
      THEN REPLACE(values_response, CHAR(44), '#_')
      ELSE values_response
    END AS values_response,
    CASE
      WHEN REGEXP_LIKE(responses, '^\\[\\{.*')
      THEN REPLACE(responses, CHAR(44), '#_')
      WHEN REGEXP_LIKE(responses, '^\\[.*')
      THEN REPLACE(responses, CHAR(44), '#_')
      ELSE REPLACE(responses, CHAR(44), '#_')
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
      THEN SPLIT(REGEXP_SUBSTR(values_response, '\\[(.*?)\\]', 1, 1, 'e', 1), '#_ ')
      ELSE ARRAY_CONSTRUCT(REPLACE(REGEXP_SUBSTR(values_response, '\\[(.*?)\\]', 1, 1, 'e', 1), '#_', ','))
    END AS response_num_in_array,
    CASE
      WHEN NOT values_key LIKE '%_TEXT%'
      THEN SPLIT(REPLACE(REGEXP_SUBSTR(responses, '\\[(.*?)\\]', 1, 1, 'e', 1), '#+', ','), ',')
      ELSE ARRAY_CONSTRUCT(REPLACE(REGEXP_SUBSTR(responses, '\\[(.*?)\\]', 1, 1, 'e', 1), '#_', ','))
    END AS responses_in_array
  FROM fixing_array_responses
), array_zip_prep AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    COALESCE(response_num_in_array, ARRAY_CONSTRUCT()) AS response_num_in_array,
    COALESCE(responses_in_array, ARRAY_CONSTRUCT()) AS responses_in_array,
    GREATEST(
      ARRAY_SIZE(COALESCE(response_num_in_array, ARRAY_CONSTRUCT())), 
      ARRAY_SIZE(COALESCE(responses_in_array, ARRAY_CONSTRUCT()))
    ) AS max_size
  FROM array_on_all_responses
), array_indices AS (
  SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS idx
  FROM TABLE(GENERATOR(ROWCOUNT => 1000))
), zipped_all_responses_values AS (
  SELECT
    a.survey_id,
    a.response_id,
    a.response_type_status,
    a.response_type,
    a.values_key,
    ARRAY_AGG(
      OBJECT_CONSTRUCT(
        '0', CAST(a.response_num_in_array[i.idx] AS STRING),
        '1', CAST(a.responses_in_array[i.idx] AS STRING)
      )
    ) WITHIN GROUP (ORDER BY i.idx) AS zipped_responses_values
  FROM array_zip_prep a
  JOIN array_indices i ON i.idx < a.max_size
  WHERE a.max_size > 0
  GROUP BY 
    a.survey_id,
    a.response_id,
    a.response_type_status,
    a.response_type,
    a.values_key
), explode_zipped_all_responses_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    f.value AS exploded_responses_values
  FROM zipped_all_responses_values,
       LATERAL FLATTEN(
           INPUT => zipped_responses_values,
           OUTER => TRUE
       ) f
), unnest_explode_zipped_all_responses_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    values_key,
    exploded_responses_values:"0"::STRING AS response_value,
    exploded_responses_values:"1"::STRING AS responses
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
  SELECT
    *
  FROM merging_survey_id_with_no_response_files
)
SELECT
  *
FROM repartition_merging_survey_id_with_no_response_files