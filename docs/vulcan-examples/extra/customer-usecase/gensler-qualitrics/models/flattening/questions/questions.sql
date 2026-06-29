-- Final dimension table for Qualtrics survey questions
-- Provides clean, deduplicated question metadata ready for analysis and joining with response data
MODEL (
  name GENSLER.FINAL.QUALTRICS_DEFINITION_FLATTENED,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(survey_id),
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, QUESTION_ID, QUESTIONS_KEY, QUESTION_TYPE, QUESTION_TEXT, CHOICE_LABEL),
  grains [SURVEY_ID, QUESTION_ID, QUESTIONS_KEY],
  tags ('dimension', 'question', 'clean', 'analytical', 'scd_type1'),
  terms ('question_dimension', 'question_catalog', 'dimension'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    block_id = 'Survey block identifier where the question appears',
    block_description = 'Descriptive name or label for the survey block',
    block_number = 'Sequential order number of the block in the survey flow',
    question_id = 'Unique Qualtrics question identifier (e.g., QID1, QID2)',
    question_number = 'Sequential order number of the question within its block',
    question_name = 'Data export tag or variable name for the question',
    question_type = 'Qualtrics question type (MC, TE, Matrix, Slider, etc.)',
    selector = 'Question selector defining interaction method',
    sub_selector = 'Additional selector refinement for question behavior',
    question_text = 'Full question text displayed to respondents',
    image_description = 'Description or alt text for images used in questions',
    sub_questions = 'Sub-questions or rows in matrix-type questions',
    choices = 'Answer choices or columns available for selection',
    items = 'Items or options in ranking/ordering questions',
    groups = 'Question grouping or categorization tags',
    regions = 'Geographic or clickable regions for heatmap questions',
    sbs_question_number = 'Sub-question number for side-by-side questions',
    sbs_question_text = 'Text of side-by-side sub-questions',
    sbs_question_type = 'Question type for side-by-side sub-questions',
    sbs_question_selector = 'Selector for side-by-side sub-questions',
    sbs_question_sub_selector = 'Sub-selector for side-by-side sub-questions',
    sbs_choices = 'Available choices for side-by-side sub-questions',
    choice_key = 'Numeric key for answer choices',
    choice_analyze = 'Boolean flag indicating if choice should be included in analysis',
    sub_questions_key = 'Unique key combining question and sub-question identifiers',
    sub_questions_recode = 'Numeric recode value for sub-questions',
    srq_id = 'Survey response question identifier for complex questions',
    row_id = 'Unique row identifier for each question-choice combination',
    questions_key = 'Complete export variable name used in response data',
    choice_label = 'Display label for answer choices',
    data_export_tag = 'Data export tag for the question field',
    variable_naming = 'Custom variable naming for export fields',
    choice_recode = 'Recode value for choice options',
    unique_identifier = 'Flag to identify unique question-choice combinations (0=unique, 1=duplicate)'
  ),
  column_tags (
    survey_id = ('identifier', 'partition_key', 'dimension'),
    block_id = ('identifier', 'survey_structure'),
    block_number = ('sequence', 'ordering'),
    question_id = ('identifier', 'dimension'),
    question_number = ('sequence', 'ordering'),
    question_name = ('metadata', 'export_tag'),
    question_type = ('classification', 'metadata'),
    question_text = ('content', 'display_text'),
    choices = ('content', 'options'),
    questions_key = ('identifier', 'export_variable', 'join_key'),
    choice_analyze = ('flag', 'boolean'),
    unique_identifier = ('flag', 'deduplication')
  ),
  column_terms (
    survey_id = ('survey_id', 'survey'),
    question_id = ('question_id', 'question'),
    question_type = ('question_type', 'type'),
    questions_key = ('export_key', 'join_key'),
    question_text = ('text', 'content'),
    choices = ('choices', 'options')
  )
);

WITH final_questions_table AS (
  SELECT
    survey_id,
    NULLIF(block_id, '') AS block_id,
    NULLIF(block_description, '') AS block_description,
    block_number::INT AS block_number,
    NULLIF(question_id, '') AS question_id,
    question_number::INT AS question_number,
    NULLIF(question_name, '') AS question_name,
    NULLIF(question_type, '') AS question_type,
    NULLIF(selector, '') AS selector,
    NULLIF(sub_selector, '') AS sub_selector,
    NULLIF(question_text, '') AS question_text,
    NULLIF(image_description, '') AS image_description,
    NULLIF(sub_questions, '') AS sub_questions,
    NULLIF(choices, '') AS choices,
    NULLIF(items, '') AS items,
    NULLIF(groups, '') AS groups,
    NULLIF(regions, '') AS regions,
    sbs_question_number::INT AS sbs_question_number,
    NULLIF(sbs_question_text, '') AS sbs_question_text,
    NULLIF(sbs_question_type, '') AS sbs_question_type,
    NULLIF(sbs_question_selector, '') AS sbs_question_selector,
    NULLIF(sbs_question_sub_selector, '') AS sbs_question_sub_selector,
    NULLIF(sbs_choices, '') AS sbs_choices,
    choice_recode::INT AS choice_key,
    analyze_choice::BOOLEAN AS choice_analyze,
    CASE
      WHEN LOWER(sub_questions_key) = 'null' OR sub_questions_key = ''
      THEN NULL
      ELSE sub_questions_key
    END AS sub_questions_key,
    sub_questions_recode::INT AS sub_questions_recode,
    srq_id::INT AS srq_id,
    row_id,
    NULLIF(questions_key, '') AS questions_key,
    CASE
      WHEN LOWER(choice_label) = 'null' OR choice_label = ''
      THEN NULL
      ELSE choice_label
    END AS choice_label,
    NULLIF(data_export_struct, '') AS data_export_tag,
    NULLIF(variable_naming, '') AS variable_naming,
    NULLIF(recode_values, '')::DECIMAL(15, 2) AS choice_recode,
    CASE
      WHEN ROW_NUMBER() OVER (PARTITION BY survey_id, question_id, sub_questions_key ORDER BY survey_id) = 1
      THEN 0
      ELSE 1
    END AS unique_identifier
  FROM GENSLER.RAW.QUALTRICS_QUESTIONS_FLATTENING_PART_001
  WHERE
    NOT questions_key LIKE 'SC%'
), question_table_with_embedded_fields AS (
  SELECT 
    *
  FROM final_questions_table
)
SELECT
  *
FROM question_table_with_embedded_fields