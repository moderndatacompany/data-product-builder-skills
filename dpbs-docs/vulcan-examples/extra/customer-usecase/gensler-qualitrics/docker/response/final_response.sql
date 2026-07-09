-- Final analytical response fact table
-- Clean, analytics-ready survey response data with enriched question metadata and human-readable variable names
MODEL (
  name nilus.vulcan.qualtrics_response_final_response,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(survey_id),
  grains [survey_id, response_id, question_id, questions_key],
  tags ('fact', 'response', 'analytical', 'clean', 'production'),
  terms ('qualtrics.response_fact', 'analytics.response', 'fact.survey_response'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    block_id = 'Survey block identifier where the question appears',
    block_description = 'Descriptive name or label for the survey block',
    block_number = 'Sequential order number of the block in the survey flow',
    question_id = 'Unique Qualtrics question identifier',
    questions_key = 'Complete export variable name with human-readable embedded data labels',
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
    regions = 'Geographic or clickable regions for heatmap questions',
    data_export_tag = 'Data export tag for the question field',
    sbs_question_number = 'Sub-question number for side-by-side questions',
    sbs_question_text = 'Text of side-by-side sub-questions',
    sbs_question_type = 'Question type for side-by-side sub-questions',
    sbs_question_selector = 'Selector for side-by-side sub-questions',
    sbs_question_sub_selector = 'Sub-selector for side-by-side sub-questions',
    sbs_choices = 'Available choices for side-by-side sub-questions',
    response_id = 'Unique identifier for each survey response submission',
    response = 'Human-readable response value or label',
    response_type = 'Human-readable response status label',
    response_value = 'Numeric or coded value of the response',
    response_type_status = 'Numeric status code indicating response type',
    sub_questions_recode = 'Numeric recode value for sub-questions',
    choice_recode = 'Recode value for choice options',
    sub_questions_key = 'Unique key combining question and sub-question identifiers'
  ),
  column_tags (
    survey_id = ('identifier', 'partition_key', 'fact'),
    response_id = ('identifier', 'fact', 'grain'),
    question_id = ('identifier', 'foreign_key'),
    questions_key = ('identifier', 'export_variable', 'join_key', 'enriched'),
    question_type = ('classification', 'metadata'),
    response = ('measurement', 'fact', 'display_value'),
    response_value = ('measurement', 'numeric', 'coded_value'),
    response_type = ('classification', 'status'),
    response_type_status = ('classification', 'status_code'),
    block_number = ('sequence', 'ordering'),
    question_number = ('sequence', 'ordering'),
    choice_key = ('numeric', 'reference'),
    choice_recode = ('numeric', 'recode'),
    sub_questions_recode = ('numeric', 'recode')
  ),
  column_terms (
    survey_id = ('qualtrics.survey_id', 'fact.survey'),
    response_id = ('qualtrics.response_id', 'fact.response'),
    question_id = ('qualtrics.question_id', 'fact.question'),
    questions_key = ('question.export_key', 'response.enriched_variable'),
    question_type = ('qualtrics.question_type', 'question.classification'),
    response = ('response.display_value', 'fact.measurement'),
    response_value = ('response.coded_value', 'fact.numeric_value'),
    response_type = ('qualtrics.status_label', 'response.status'),
    question_text = ('question.text', 'survey.content'),
    choices = ('question.choices', 'response.options')
  ),
  physical_properties (
    format = 'iceberg'
  )
);

WITH unnesting_properties AS (
  SELECT
    REGEXP_EXTRACT(INPUT_FILE_NAME(), '(?:.+\\/)(.+)[\\.]') AS survey_id,
    EXPLODE_OUTER(parsed_json.result.properties.values.properties) AS (questions_key, values1)
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
), response_table_repartitioned AS (
  SELECT
    survey_id,
    block_id,
    block_description,
    block_number::INT,
    question_id,
    questions_key,
    question_number::INT,
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
    data_export_tag,
    sbs_question_number::INT,
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
    choice_recode::DECIMAL(15, 2) AS choice_recode,
    sub_questions_key
  FROM filtering_repeated_choice_text_rows
  WHERE
    NOT questions_key LIKE 'SC%'
)
SELECT
  *
FROM response_table_repartitioned