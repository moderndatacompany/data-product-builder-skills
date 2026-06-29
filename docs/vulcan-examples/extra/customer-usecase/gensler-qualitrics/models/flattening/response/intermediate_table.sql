-- Intermediate fact table joining questions with responses
-- Complex transformation layer matching response values to question choices with business logic for different question types
MODEL (
  name GENSLER.RAW.QUALTRICS_RESPONSE_INTERMEDIATE_TABLE,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(survey_id),
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, RESPONSE_ID, QUESTION_ID, QUESTIONS_KEY, QUESTION_TYPE, RESPONSE_VALUE, RESPONSE),
  grains [SURVEY_ID, RESPONSE_ID, QUESTION_ID, QUESTIONS_KEY],
  description 'Intermediate response fact table performing complex transformation to match response values with question definitions, applying business logic for different question types, and enriching with complete question metadata for analytical processing',
  tags ('fact', 'response', 'intermediate', 'transformation', 'complex_logic'),
  terms ('response_intermediate', 'fact', 'enriched'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    block_id = 'Survey block identifier where the question appears',
    block_description = 'Descriptive name or label for the survey block',
    block_number = 'Sequential order number of the block in the survey flow',
    question_id = 'Unique Qualtrics question identifier',
    questions_key = 'Complete export variable name used in response data',
    sub_questions_recode = 'Numeric recode value for sub-questions',
    choice_recode = 'Recode value for choice options',
    question_number = 'Sequential order number of the question within its block',
    question_name = 'Data export tag or variable name for the question',
    question_type = 'Qualtrics question type (MC, TE, Matrix, Slider, etc.)',
    selector = 'Question selector defining interaction method',
    sub_selector = 'Additional selector refinement',
    question_text = 'Full question text displayed to respondents',
    image_description = 'Description or alt text for images used in questions',
    sub_questions = 'Sub-questions or rows in matrix-type questions',
    choices = 'Answer choices or columns available for selection',
    variable_naming = 'Custom variable naming convention for export',
    choice_key = 'Numeric key for answer choices',
    items = 'Items or options in ranking/ordering questions',
    groups = 'Question grouping or categorization tags',
    regions = 'Geographic or clickable regions, or coordinates for heatmap responses',
    data_export_tag = 'Data export tag for the question field',
    sbs_question_number = 'Sub-question number for side-by-side questions',
    sbs_question_text = 'Text of side-by-side sub-questions',
    sbs_question_type = 'Question type for side-by-side sub-questions',
    sbs_question_selector = 'Selector for side-by-side sub-questions',
    sbs_question_sub_selector = 'Sub-selector for side-by-side sub-questions',
    sbs_choices = 'Available choices for side-by-side sub-questions',
    sub_questions_key = 'Unique key combining question and sub-question identifiers',
    response_id = 'Unique identifier for each survey response submission',
    response = 'Response value with special handling (only_empty_response, no_response_file, blank_response_file, etc.)',
    response_type = 'Human-readable response status label',
    response_type_status = 'Numeric status code indicating response type',
    response_value = 'Numeric or coded value of the response'
  ),
  column_tags (
    survey_id = ('identifier', 'partition_key', 'fact'),
    response_id = ('identifier', 'fact', 'grain'),
    question_id = ('identifier', 'foreign_key'),
    questions_key = ('identifier', 'export_variable', 'join_key'),
    question_type = ('classification', 'metadata'),
    response = ('measurement', 'fact', 'response_data'),
    response_value = ('measurement', 'numeric', 'coded_value'),
    response_type = ('classification', 'status'),
    response_type_status = ('classification', 'status_code'),
    block_number = ('sequence', 'ordering'),
    question_number = ('sequence', 'ordering'),
    choice_key = ('numeric', 'reference'),
    choice_recode = ('numeric', 'recode')
  ),
  column_terms (
    survey_id = ('survey_id', 'survey'),
    response_id = ('response_id', 'response'),
    question_id = ('question_id', 'question'),
    questions_key = ('export_key', 'variable'),
    question_type = ('question_type', 'classification'),
    response = ('value', 'measurement'),
    response_value = ('coded_value', 'numeric_value'),
    response_type = ('status_label', 'status')
  )
);

WITH responses_for_each_question AS (
  SELECT
    a.survey_id,
    a.block_id,
    a.block_description,
    a.block_number,
    a.question_id,
    a.questions_key,
    a.sub_questions_recode,
    a.choice_recode,
    a.question_number,
    a.question_name,
    a.question_type,
    a.selector,
    a.sub_selector,
    a.question_text,
    a.image_description,
    a.sub_questions,
    a.choices,
    a.items,
    a.groups,
    a.regions,
    a.data_export_struct,
    a.sbs_question_number,
    a.sbs_question_text,
    a.sbs_question_type,
    a.sbs_question_selector,
    a.sbs_question_sub_selector,
    a.sbs_choices,
    a.sub_questions_key,
    b.row_num AS row_num,
    a.row_id,
    a.scoring_id,
    a.variable_naming,
    a.choice_key,
    b.values_key,
    b.response_id,
    b.response,
    b.response_type_status,
    b.response_type,
    b.response_value
  FROM GENSLER.RAW.RESPONSE_WITH_ALL_RESPONSE_FIELDS AS a
  FULL OUTER  JOIN GENSLER.RAW.SURVEY_ID_NO_RESPONSE_FILES AS b
    ON b.survey_id = a.survey_id
), first_case AS (
  SELECT
    survey_id,
    block_id,
    block_description,
    block_number,
    question_id,
    questions_key,
    sub_questions_recode,
    choice_recode,
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
    data_export_struct,
    sbs_question_number,
    sbs_question_text,
    sbs_question_type,
    sbs_question_selector,
    sbs_question_sub_selector,
    sbs_choices,
    sub_questions_key,
    row_num,
    row_id,
    scoring_id,
    values_key,
    response_id,
    CASE
      WHEN question_id = 'QID_null'
      THEN 'blank_definition_response_file'
      WHEN response = 'no_file'
      THEN 'no_response_file'
      WHEN response = 'only_respondent_metadata'
      THEN 'only_respondent_metadata'
      WHEN question_id <> 'QID_null'
      AND (
        values_key IS NULL OR values_key = 'QID_null'
      )
      AND response IS NULL
      THEN 'blank_response_file'
      ELSE response
    END AS response,
    response_type_status,
    response_type,
    response_value
  FROM responses_for_each_question
), second_case AS (
  SELECT
    survey_id,
    block_id,
    block_description,
    block_number,
    question_id,
    questions_key,
    sub_questions_recode,
    choice_recode,
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
    data_export_struct,
    sbs_question_number,
    sbs_question_text,
    sbs_question_type,
    sbs_question_selector,
    sbs_question_sub_selector,
    sbs_choices,
    sub_questions_key,
    row_num,
    row_id,
    scoring_id,
    values_key,
    response_id,
    response,
    CASE
      WHEN response = 'blank_definition_response_file'
      OR response = 'no_response_file'
      OR response = 'only_respondent_metadata'
      OR response = 'blank_response_file'
      THEN ROW_NUMBER() OVER (PARTITION BY survey_id ORDER BY question_id DESC)
      ELSE 0
    END AS filter_blank,
    response_type_status,
    response_type,
    response_value
  FROM first_case
), filtering_repeated_responses AS (
  SELECT
    survey_id,
    block_id,
    block_description,
    block_number,
    question_id,
    questions_key,
    sub_questions_recode,
    choice_recode,
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
    data_export_struct,
    sbs_question_number,
    sbs_question_text,
    sbs_question_type,
    sbs_question_selector,
    sbs_question_sub_selector,
    sbs_choices,
    sub_questions_key,
    response_id,
    CASE
      WHEN (
        sub_questions IS NULL AND choices IS NULL
      ) OR (
        sbs_choices = response
      )
      THEN response
      WHEN (
        question_type = 'MC'
        AND CASE WHEN choice_recode IS NULL THEN choice_key ELSE choice_recode END::INT = response_value
      )
      OR (
        question_type = 'MC' AND response = 'empty_response'
      )
      OR (
        question_type = 'TE' AND NOT choices IS NULL
      )
      OR (
        question_type = 'Matrix' AND selector = 'TE'
      )
      OR (
        question_type = 'HL' AND sub_questions_recode = response_value
      )
      THEN response
      WHEN (
        question_type = 'TE'
        OR question_type = 'Timing'
        OR question_type = 'Meta'
        AND NOT choices IS NULL
      )
      THEN response
      WHEN NOT choices IS NULL AND questions_key LIKE 'QID%TEXT'
      THEN response
      WHEN (
        CASE WHEN choice_recode IS NULL THEN choice_key ELSE choice_recode END::INT = response_value
        OR (
          REGEXP_LIKE(choices, '.*[A-Za-z].*') AND choice_key = response
        )
      )
      OR CASE WHEN choice_recode IS NULL THEN choice_key ELSE choice_recode END::INT = response_value
      AND image_description IS NULL
      THEN response
      WHEN sub_questions_recode = response_value
      THEN response
      WHEN items LIKE '%.png%' AND image_description = response
      THEN response
      WHEN items = response AND image_description IS NULL
      THEN response
      WHEN (
        NOT choices IS NULL
        AND CASE WHEN question_type = 'DD' THEN choice_key ELSE choices END = CASE WHEN question_type = 'DD' THEN response_value ELSE response END
      )
      OR (
        choices LIKE '%.png%' AND image_description = response
      )
      THEN response
      WHEN question_type = 'CS'
      OR question_type = 'RO'
      OR (
        question_type = 'Slider' AND choices IS NULL
      )
      OR (
        question_type = 'Slider'
        AND NOT choices IS NULL
        AND CASE WHEN choice_recode IS NULL THEN choice_key ELSE choice_recode END::INT = response_value
      )
      OR (
        question_type = 'MC' AND image_description = response
      )
      THEN response
      WHEN response = 'no_response_file'
      OR response = 'blank_response_file'
      OR response = 'blank_definition_response_file'
      OR response = 'only_respondent_metadata'
      THEN response
      ELSE NULL
    END AS response,
    response_type_status,
    response_type,
    response_value,
    CASE
      WHEN question_type = 'HeatMap'
      THEN LAG(response) OVER (PARTITION BY question_id, response, response_id ORDER BY survey_id)
      ELSE NULL
    END AS row_num,
    CASE
      WHEN question_type = 'HeatMap'
      THEN ROW_NUMBER() OVER (PARTITION BY question_id, response, response_id ORDER BY survey_id)
      ELSE NULL
    END AS row_num1
  FROM second_case
), responses_heatmap_type_questions AS (
  SELECT
    survey_id,
    block_id,
    block_description,
    block_number,
    question_id,
    questions_key,
    sub_questions_recode,
    choice_recode,
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
    data_export_struct,
    sbs_question_number,
    sbs_question_text,
    sbs_question_type,
    sbs_question_selector,
    sbs_question_sub_selector,
    sbs_choices,
    sub_questions_key,
    response_id,
    CASE
      WHEN question_type = 'HeatMap' AND (
        row_num IS NULL OR response <> row_num
      )
      THEN response
      WHEN question_type <> 'HeatMap' OR question_type IS NULL
      THEN response
      ELSE NULL
    END AS response,
    response_type_status,
    response_type,
    response_value
  FROM filtering_repeated_responses
), responses_table_row_number AS (
  SELECT
    survey_id,
    block_id,
    block_description,
    block_number,
    question_id,
    questions_key,
    sub_questions_recode,
    choice_recode,
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
    CASE
      WHEN question_type = 'HeatMap' AND response = 'Other'
      THEN NULL
      WHEN question_type = 'HeatMap' AND response = 'Other'
      THEN NULL
      WHEN question_type = 'HeatMap' AND response LIKE '\\%{\\%'
      THEN 'coordinates'
      WHEN question_type = 'HeatMap' AND response <> regions
      THEN response
    END AS regions,
    data_export_struct,
    sbs_question_number,
    sbs_question_text,
    sbs_question_type,
    sbs_question_selector,
    sbs_question_sub_selector,
    sbs_choices,
    sub_questions_key,
    response_id,
    response,
    response_type,
    (
      CASE
        WHEN REGEXP_LIKE(response_value, '^\\d*$')
        THEN response_value
        WHEN REGEXP_LIKE(response_value, '^\\d+\\.?\\d*$')
        THEN response_value
        ELSE NULL
      END
    )::DOUBLE AS response_value,
    response_type_status,
    ROW_NUMBER() OVER (PARTITION BY survey_id ORDER BY survey_id) AS row_num
  FROM (
    SELECT
      *
    FROM responses_heatmap_type_questions

  )
), max_row_number AS (
  SELECT
    *,
    CASE
      WHEN response <> 'empty_response'
      THEN MAX(modified_row_num) OVER (PARTITION BY survey_id) + 1
      ELSE MAX(modified_row_num) OVER (PARTITION BY survey_id)
    END AS max_modified_row_num
  FROM (
    SELECT
      survey_id,
      block_id,
      block_description,
      block_number,
      question_id,
      questions_key,
      sub_questions_recode,
      choice_recode,
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
      data_export_struct,
      sbs_question_number,
      sbs_question_text,
      sbs_question_type,
      sbs_question_selector,
      sbs_question_sub_selector,
      sbs_choices,
      sub_questions_key,
      response_id,
      response,
      response_type,
      response_value,
      response_type_status,
      row_num AS old_row_num,
      CASE WHEN response = 'empty_response' THEN 0 ELSE row_num END AS modified_row_num
    FROM responses_table_row_number
  )
), max_comparison_filter AS (
  SELECT
    *
  FROM (
    SELECT
      survey_id,
      block_id,
      block_description,
      block_number,
      question_id,
      questions_key,
      sub_questions_recode,
      choice_recode,
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
      data_export_struct,
      sbs_question_number,
      sbs_question_text,
      sbs_question_type,
      sbs_question_selector,
      sbs_question_sub_selector,
      sbs_choices,
      sub_questions_key,
      response_id,
      CASE
        WHEN modified_row_num = max_modified_row_num
        THEN 'only_empty_response'
        ELSE response
      END AS response,
      response_type,
      response_value,
      response_type_status,
      old_row_num
    FROM max_row_number
  )
), responses_filter AS (
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
    choice_key::INT AS choice_key,
    items,
    groups,
    regions,
    data_export_struct AS data_export_tag,
    sbs_question_number,
    sbs_question_text,
    sbs_question_type,
    sbs_question_selector,
    sbs_question_sub_selector,
    sbs_choices,
    response_id,
    CASE
      WHEN response <> 'only_empty_response' AND filter = 0
      THEN response
      WHEN response = 'only_empty_response' AND filter = 1
      THEN response
      ELSE NULL
    END AS response,
    response_type,
    response_type_status,
    response_value,
    NULLIF(
      CASE
        WHEN LOWER(sub_questions_recode) = 'null'
        THEN NULL
        ELSE sub_questions_recode
      END,
      ''
    )::INT AS sub_questions_recode,
    choice_recode::DECIMAL(15, 2) AS choice_recode,
    sub_questions_key
  FROM (
    SELECT
      *,
      CASE WHEN response = 'only_empty_response' AND old_row_num = 1 THEN 1 ELSE 0 END AS filter
    FROM max_comparison_filter
  )
), response_table AS (
  SELECT DISTINCT
    *
  FROM responses_filter

)
SELECT
  *
FROM response_table