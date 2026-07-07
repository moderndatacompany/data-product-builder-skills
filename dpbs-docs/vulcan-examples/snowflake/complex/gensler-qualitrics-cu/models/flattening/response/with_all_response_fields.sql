-- Combined dimension table enriching questions with all response variable fields
-- Merges question metadata with discovered response variables including custom embedded data fields not in the definition
MODEL (
  name GENSLER.RAW.RESPONSE_WITH_ALL_RESPONSE_FIELDS,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(SURVEY_ID),
  grains [SURVEY_ID, QUESTION_ID, QUESTIONS_KEY],
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, QUESTION_ID, QUESTIONS_KEY, QUESTION_TYPE, QUESTION_TEXT, SELECTOR, CHOICES),
  description 'Enriched question dimension merging question metadata with discovered response variables including custom embedded data fields not present in survey definitions for complete field catalog and response schema validation',
  tags ('dimension', 'enriched', 'question', 'response_schema', 'reference'),
  terms ('enriched_question_metadata', 'complete_field_catalog', 'master'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    block_id = 'Survey block identifier where the question appears',
    block_description = 'Descriptive name or label for the survey block',
    block_number = 'Sequential order number of the block in the survey flow',
    question_id = 'Qualtrics question identifier or special codes (QID*, EF, SC, RM/VAR)',
    question_number = 'Sequential order number of the question within its block',
    row_id = 'Unique row identifier for processing and deduplication',
    question_name = 'Data export tag or variable name for the question',
    question_type = 'Qualtrics question type (MC, TE, Matrix, Slider, etc.)',
    selector = 'Question selector defining interaction method',
    sub_selector = 'Additional selector refinement',
    sbs_question_number = 'Sub-question number for side-by-side questions',
    sbs_question_type = 'Question type for side-by-side sub-questions',
    sbs_question_selector = 'Selector for side-by-side sub-questions',
    sbs_question_sub_selector = 'Sub-selector for side-by-side sub-questions',
    sbs_choice_key = 'Choice key for side-by-side sub-questions',
    sbs_choices = 'Available choices for side-by-side sub-questions',
    questions_key = 'Complete export variable name used in response data files',
    sub_questions_key = 'Unique key combining question and sub-question identifiers',
    sub_questions_recode = 'Numeric recode value for sub-questions',
    choice_key = 'Numeric key for answer choices',
    srq_id = 'Survey response question identifier for complex questions',
    score_id = 'Scoring identifier for questions with scoring logic',
    scoring_id = 'Scoring category identifier',
    analyze_choice = 'Flag indicating if choice should be included in analysis',
    data_export_struct = 'Data export structure definition for the field',
    variable_naming = 'Custom variable naming convention for export',
    sub_questions = 'Sub-questions or rows in matrix-type questions',
    choices = 'Answer choices or columns available for selection',
    items = 'Items or options in ranking/ordering questions',
    groups = 'Question grouping or categorization tags',
    regions = 'Geographic or clickable regions for heatmap questions',
    image_description = 'Description or alt text for images used in questions',
    sbs_question_text = 'Text of side-by-side sub-questions',
    question_text = 'Full question text displayed to respondents',
    choice_label = 'Display label for answer choices',
    recode_values = 'Recode value mappings for choices'
  ),
  column_tags (
    survey_id = ('identifier', 'dimension'),
    question_id = ('identifier', 'dimension'),
    questions_key = ('identifier', 'export_variable', 'join_key'),
    question_type = ('classification', 'metadata'),
    question_text = ('content', 'display_text'),
    response_id = ('identifier', 'response', 'nullable'),
    block_number = ('sequence', 'ordering'),
    analyze_choice = ('flag', 'boolean'),
    score_id = ('identifier', 'scoring'),
    scoring_id = ('identifier', 'scoring')
  ),
  column_terms (
    survey_id = ('survey_id', 'survey'),
    question_id = ('question_id', 'question'),
    questions_key = ('export_key', 'join_key'),
    question_type = ('question_type', 'classification'),
    question_text = ('text', 'content'),
    choices = ('choices', 'options'),
    data_export_struct = ('export_structure', 'definition')
  )
);
WITH response_with_survey_id AS (
  SELECT
     survey_id,
    parse_json(
      values_parsed    ) AS responses
  FROM GENSLER.RAW.QUALTRICS_RESPONSE
), response_connect AS (
  SELECT 
    *
  FROM response_with_survey_id
), definition_connect AS (
  SELECT
   survey_id AS survey_id
  FROM GENSLER.RAW.QUALTRICS_DEFINITION
), question_table_with_embedded_fields AS (
  SELECT
    *
  FROM GENSLER.RAW.QUALTRICS_QUESTIONS_FLATTENING_PART_001
)

, explode_responses AS (
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
    exp_responses:responseId AS response_id,
    exp_responses:"values"."status" AS response_type_status,
    exp_responses:"labels".status AS response_type,
    exp_responses:"values" AS response_values,
    exp_responses:"labels" AS response_labels
  FROM explode_responses
)
, exploded_response_values AS (
  SELECT
    survey_id,
    response_id,
    response_type_status,
    response_type,
    f.key AS values_key,
    f.value AS values_response
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
    f.key AS labels_key,
    f.value AS labels_response
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
      WHEN REGEXP_LIKE(responses, '^\\[\\.*')
      THEN REPLACE(responses, CONCAT(CHAR(125), CHAR(44), CHAR(123)), '}#+\\')
      WHEN REGEXP_LIKE(responses, '^\\[.*')
      THEN REPLACE(responses, '\\",\\"', '#+')
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
      WHEN REGEXP_LIKE(values_response, '^\\[\\.*')
      THEN values_response::STRING
      WHEN REGEXP_LIKE(values_response, '^\\[.*')
      THEN PARSE_JSON(values_response)::STRING
      ELSE values_response
    END AS values_response,
    CASE
      WHEN REGEXP_LIKE(responses, '^\\[\\.*')
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
      WHEN REGEXP_LIKE(values_response, '^\\[\\.*')
      THEN REPLACE(values_response, CONCAT(CHAR(125), CHAR(44), ' ', CHAR(123)), '}#_\\')
      WHEN values_response LIKE '[%'
      THEN REPLACE(values_response, CHAR(44), '#_')
      ELSE values_response
    END AS values_response,
    CASE
      WHEN responses LIKE '[\\%'
      THEN REPLACE(responses, CHAR(44), '#_')
      WHEN responses LIKE '[%'
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
      ELSE ARRAY_CONSTRUCT(
        REPLACE(REGEXP_SUBSTR(values_response, '\\[(.*?)\\]', 1, 1, 'e', 1), '#_', ',')
      )
    END AS response_num_in_array,
    CASE
      WHEN NOT values_key LIKE '%_TEXT%'
      THEN SPLIT(
        REPLACE(REGEXP_SUBSTR(responses, '\\[(.*?)\\]', 1, 1, 'e', 1), '#+', ','),
        ','
      )
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
    GREATEST(ARRAY_SIZE(COALESCE(response_num_in_array, ARRAY_CONSTRUCT())), 
             ARRAY_SIZE(COALESCE(responses_in_array, ARRAY_CONSTRUCT()))) AS max_size
  FROM array_on_all_responses
), array_indices AS (
  SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS idx
  FROM TABLE(GENERATOR(ROWCOUNT => 1000))
)
, 
zipped_all_responses_values AS (
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
), custom_variable_data AS (
  SELECT DISTINCT
    survey_id,
    values_key AS questions_key
  FROM repartition_merging_survey_id_with_no_response_files
  EXCEPT
  SELECT DISTINCT
    survey_id,
    questions_key
  FROM question_table_with_embedded_fields
), questions_table_with_all_response_fields AS (
  SELECT
    *
  FROM question_table_with_embedded_fields
  UNION
  SELECT
    survey_id,
    NULL AS block_id,
    NULL AS block_description,
    0 AS block_number,
    'RM/VAR' AS question_id,
    0 AS question_number,
    NULL AS row_id,
    NULL AS question_name,
    NULL AS question_type,
    NULL AS selector,
    NULL AS sub_selector,
    NULL AS sbs_question_number,
    NULL AS sbs_question_type,
    NULL AS sbs_question_selector,
    NULL AS sbs_question_sub_selector,
    NULL AS sbs_choice_key,
    NULL AS sbs_choices,
    questions_key,
    NULL AS sub_questions_key,
    NULL AS sub_questions_recode,
    NULL AS choice_recode,
    NULL AS srq_id,
    NULL AS score_id,
    NULL AS scoring_id,
    CAST(NULL AS STRING) AS analyze_choice,
    NULL AS data_export_struct,
    NULL AS variable_naming,
    NULL AS sub_questions,
    NULL AS choices,
    NULL AS items,
    NULL AS groups,
    NULL AS regions,
    NULL AS image_description,
    NULL AS sbs_question_text,
    NULL AS question_text,
    NULL AS choice_label,
    NULL AS recode_values
  FROM custom_variable_data
  WHERE
    survey_id IN (
      SELECT
        survey_id
      FROM definition_connect
    )
)
, makeing_null AS (
  SELECT
    survey_id,
    NULLIF(CASE WHEN LOWER(block_id) = 'null' THEN NULL ELSE block_id END, '') AS block_id,
    NULLIF(
      CASE WHEN LOWER(block_description) = 'null' THEN NULL ELSE block_description END,
      ''
    ) AS block_description,
    block_number,
    question_id,
    question_number,
    NULLIF(CASE WHEN LOWER(row_id) = 'null' THEN NULL ELSE row_id END, 0) AS row_id,
    NULLIF(CASE WHEN LOWER(question_name) = 'null' THEN NULL ELSE question_name END, '') AS question_name,
    NULLIF(CASE WHEN LOWER(question_type) = 'null' THEN NULL ELSE question_type END, '') AS question_type,
    NULLIF(CASE WHEN LOWER(selector) = 'null' THEN NULL ELSE selector END, '') AS selector,
    NULLIF(CASE WHEN LOWER(sub_selector) = 'null' THEN NULL ELSE sub_selector END, '') AS sub_selector,
    NULLIF(
      CASE WHEN LOWER(sbs_question_number) = 'null' THEN NULL ELSE sbs_question_number END,
      ''
    ) AS sbs_question_number,
    NULLIF(
      CASE WHEN LOWER(sbs_question_type) = 'null' THEN NULL ELSE sbs_question_type END,
      ''
    ) AS sbs_question_type,
    NULLIF(
      CASE
        WHEN LOWER(sbs_question_selector) = 'null'
        THEN NULL
        ELSE sbs_question_selector
      END,
      ''
    ) AS sbs_question_selector,
    NULLIF(
      CASE
        WHEN LOWER(sbs_question_sub_selector) = 'null'
        THEN NULL
        ELSE sbs_question_sub_selector
      END,
      ''
    ) AS sbs_question_sub_selector,
    NULLIF(CASE WHEN LOWER(sbs_choice_key) = 'null' THEN NULL ELSE sbs_choice_key END, '') AS sbs_choice_key,
    NULLIF(CASE WHEN LOWER(sbs_choices) = 'null' THEN NULL ELSE sbs_choices END, '') AS sbs_choices,
    NULLIF(CASE WHEN LOWER(questions_key) = 'null' THEN NULL ELSE questions_key END, '') AS questions_key,
    NULLIF(
      CASE WHEN LOWER(sub_questions_key) = 'null' THEN NULL ELSE sub_questions_key END,
      ''
    ) AS sub_questions_key,
    NULLIF(
      CASE
        WHEN LOWER(sub_questions_recode) = 'null'
        THEN NULL
        ELSE sub_questions_recode
      END,
      ''
    ) AS sub_questions_recode,
    NULLIF(CASE WHEN LOWER(choice_recode) = 'null' THEN NULL ELSE choice_recode END, '') AS choice_key,
    NULLIF(CASE WHEN LOWER(srq_id) = 'null' THEN NULL ELSE srq_id END, 0) AS srq_id,
    NULLIF(CASE WHEN LOWER(choice_label) = 'null' THEN NULL ELSE choice_label END, '') AS choice_label,
    NULLIF(CASE WHEN LOWER(score_id) = 'null' THEN NULL ELSE score_id END, '') AS score_id,
    NULLIF(CASE WHEN LOWER(scoring_id) = 'null' THEN NULL ELSE scoring_id END, '') AS scoring_id,
    NULLIF(CASE WHEN LOWER(analyze_choice) = 'null' THEN NULL ELSE analyze_choice END, false) AS analyze_choice,
    NULLIF(
      CASE WHEN LOWER(data_export_struct) = 'null' THEN NULL ELSE data_export_struct END,
      ''
    ) AS data_export_struct,
    NULLIF(CASE WHEN LOWER(sub_questions) = 'null' THEN NULL ELSE sub_questions END, '') AS sub_questions,
    NULLIF(CASE WHEN LOWER(choices) = 'null' THEN NULL ELSE choices END, '') AS choices,
    NULLIF(CASE WHEN LOWER(items) = 'null' THEN NULL ELSE items END, '') AS items,
    NULLIF(CASE WHEN LOWER(groups) = 'null' THEN NULL ELSE groups END, '') AS groups,
    NULLIF(CASE WHEN LOWER(regions) = 'null' THEN NULL ELSE regions END, '') AS regions,
    NULLIF(
      CASE WHEN LOWER(image_description) = 'null' THEN NULL ELSE image_description END,
      ''
    ) AS image_description,
    NULLIF(
      CASE WHEN LOWER(sbs_question_text) = 'null' THEN NULL ELSE sbs_question_text END,
      ''
    ) AS sbs_question_text,
    NULLIF(CASE WHEN LOWER(question_text) = 'null' THEN NULL ELSE question_text END, '') AS question_text,
    NULLIF(CASE WHEN LOWER(variable_naming) = 'null' THEN NULL ELSE variable_naming END, '') AS variable_naming,
    NULLIF(CASE WHEN LOWER(recode_values) = 'null' THEN NULL ELSE recode_values END, '') AS choice_recode
  FROM questions_table_with_all_response_fields
), questions_table_with_all_response_fields_01 AS (
  SELECT
    *
  FROM makeing_null
)
SELECT
  *
FROM questions_table_with_all_response_fields_01