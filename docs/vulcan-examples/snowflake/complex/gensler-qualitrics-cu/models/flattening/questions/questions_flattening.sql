-- Transformation layer for comprehensive question flattening
-- Processes complex nested survey structure into flattened question metadata including choices, sub-questions, dynamic references, scoring, and flow logic
MODEL (
  name GENSLER.RAW.QUALTRICS_QUESTIONS_FLATTENING_PART_001,
  kind INCREMENTAL_BY_PARTITION,
  partitioned_by ARRAY(survey_id),
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, QUESTION_ID, QUESTIONS_KEY, QUESTION_TYPE, SELECTOR, QUESTION_TEXT, CHOICES),
  grains [SURVEY_ID, QUESTION_ID, QUESTIONS_KEY],
  description 'Comprehensive question transformation processing complex nested survey structures into flattened question metadata including choices, sub-questions, dynamic references, scoring logic, flow control, and validation rules for complete question catalog',
  tags ('flattening', 'transformation', 'question', 'dimension', 'complex_logic'),
  terms ('question_metadata', 'question_structure', 'flattening'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    block_id = 'Survey block identifier where the question appears',
    block_description = 'Descriptive name or label for the survey block',
    block_number = 'Sequential order number of the block in the survey flow',
    question_id = 'Unique Qualtrics question identifier (e.g., QID1, QID2)',
    question_number = 'Sequential order number of the question within its block',
    question_name = 'Data export tag or variable name for the question',
    question_type = 'Qualtrics question type (MC, TE, Matrix, Slider, etc.)',
    selector = 'Question selector defining interaction method (SAVR, FORM, etc.)',
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
    choice_recode = 'Numeric recode value assigned to answer choices',
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
    unique_identifier = 'Flag to identify unique question-choice combinations'
  ),
  column_tags (
    survey_id = ('identifier', 'partition_key', 'survey'),
    block_id = ('identifier', 'survey_structure'),
    block_description = ('metadata', 'descriptive'),
    block_number = ('sequence', 'ordering'),
    question_id = ('identifier', 'question'),
    question_number = ('sequence', 'ordering'),
    question_name = ('metadata', 'export_tag'),
    question_type = ('classification', 'metadata'),
    selector = ('metadata', 'interaction'),
    sub_selector = ('metadata', 'interaction'),
    question_text = ('content', 'display_text'),
    image_description = ('metadata', 'accessibility'),
    sub_questions = ('content', 'matrix'),
    choices = ('content', 'options'),
    items = ('content', 'ranking'),
    groups = ('classification', 'categorization'),
    regions = ('geographic', 'interaction'),
    sbs_question_number = ('sequence', 'sub_question'),
    sbs_question_text = ('content', 'sub_question'),
    sbs_question_type = ('classification', 'sub_question'),
    sbs_question_selector = ('metadata', 'sub_question'),
    sbs_question_sub_selector = ('metadata', 'sub_question'),
    sbs_choices = ('content', 'sub_question'),
    choice_recode = ('numeric', 'recode'),
    choice_analyze = ('flag', 'analysis'),
    sub_questions_key = ('identifier', 'composite_key'),
    sub_questions_recode = ('numeric', 'recode'),
    srq_id = ('identifier', 'complex_question'),
    row_id = ('identifier', 'unique_key'),
    questions_key = ('identifier', 'export_variable'),
    choice_label = ('content', 'display_text'),
    data_export_tag = ('metadata', 'export_tag'),
    variable_naming = ('metadata', 'export_variable')
  ),
  column_terms (
    survey_id = ('survey_id', 'identifier'),
    block_id = ('block_id', 'block'),
    block_description = ('block_description', 'description'),
    block_number = ('block_order', 'number'),
    question_id = ('question_id', 'identifier'),
    question_number = ('order', 'number'),
    question_name = ('export_name', 'name'),
    question_type = ('question_type', 'classification'),
    selector = ('selector', 'interaction_type'),
    sub_selector = ('sub_selector', 'interaction_subtype'),
    question_text = ('text', 'question_content'),
    choices = ('choices', 'options'),
    questions_key = ('export_key', 'variable_name')
  )
);
WITH unnest_result AS (
    SELECT
        survey_id,
        PARSED_JSON:result:Questions AS questions,
        PARSED_JSON:result:Blocks AS blocks,
        PARSED_JSON:result:SurveyFlow AS flow,
        PARSED_JSON:result:Scoring AS score,
        PARSED_JSON:result:ReferenceLists AS reference_lists
    FROM
        GENSLER.RAW.QUALTRICS_DEFINITION
),
explode_reference_list AS (
    SELECT
        survey_id,
        f.key AS ref_key,
        f.value AS ref_value
    FROM
        unnest_result,
        LATERAL FLATTEN(
            INPUT => reference_lists,
            OUTER => TRUE
        ) f
),
unnest_ref_value AS (
    SELECT
        survey_id,
        ref_key,
        ref_value:Type AS type,
        ref_value:Selections AS selections
    FROM
        explode_reference_list
),
explode_selections AS (
    SELECT
        survey_id,
        ref_key,
        type,
        s.key AS ref_choice_id,
        s.value AS ref_choices
    FROM
        unnest_ref_value,
        LATERAL FLATTEN(
            INPUT => selections,
            OUTER => TRUE
        ) s
),
final_ref_list AS (
    SELECT
        survey_id,
        ref_key,
        type::STRING AS type,
        ref_choice_id::STRING AS ref_choice_id,
        ref_choices:Display::STRING AS reference_choices
    FROM
        explode_selections
),
explode_questions AS (
    SELECT
        survey_id,
        q.key AS question_id,
        q.value AS question_struct
    FROM
        unnest_result,
        LATERAL FLATTEN(
            INPUT => questions,
            OUTER => TRUE
        ) q
),
unnest_question_struct AS (
    SELECT
        survey_id,
        question_id,
        question_struct:QuestionText AS question_text,
        question_struct:DataExportTag AS question_name,
        question_struct:QuestionType AS question_type,
        question_struct:Selector AS selector,
        question_struct:SubSelector AS sub_selector,
        question_struct:Choices AS choices,
        question_struct:Answers AS answers,
        question_struct:Groups AS groups,
        question_struct:AdditionalQuestions AS add_questions,
        question_struct:Regions AS regions,
        question_struct:ColumnLabels AS column_labels,
        question_struct:Labels AS labels,
        question_struct:AnalyzeChoices AS analyze_choice,
        question_struct:ChoiceDataExportTags AS choice_data_export_tags,
        question_struct:DynamicChoices AS dynamic_choices,
        question_struct:DynamicAnswers AS dynamic_answers,
        question_struct:VariableNaming AS variable_naming,
        question_struct:RecodeValues AS recode_values
    FROM
        explode_questions
),
explode_variable_naming AS (
    SELECT
        survey_id,
        question_id,
        vn.key AS variable_naming_key,
        vn.value AS variable_naming
    FROM
        unnest_question_struct,
        LATERAL FLATTEN(
            INPUT => variable_naming,
            OUTER => TRUE
        ) vn
),
explode_recode_values AS (
    SELECT
        survey_id,
        question_id,
        rv.key::STRING AS recode_values_key,
        rv.value AS recode_values
    FROM
        unnest_question_struct,
        LATERAL FLATTEN(
            INPUT => recode_values,
            OUTER => TRUE
        ) rv
),
explode_questions_choices AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        c.key AS choice_id,
        c.value AS choice_struct,
        answers,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dynamic_choices,
        dynamic_answers
    FROM
        unnest_question_struct,
        LATERAL FLATTEN(
            INPUT => choices,
            OUTER => TRUE
        ) c
),
adding_row_num_question_type_DD AS (
    SELECT
        *,
        CASE
            WHEN question_type = 'DD' THEN ROW_NUMBER() OVER (
                PARTITION BY survey_id,
                question_id
                ORDER BY
                    survey_id
            )
            ELSE 0
        END AS dd_row_num
    FROM
        explode_questions_choices
),
unnest_question_choices AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_struct:Display AS choice_display,
        choice_struct:Image:Display AS choice_image_display,
        choice_struct:TextEntry AS text_entry,
        answers,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num,
        dynamic_choices,
        dynamic_answers
    FROM
        adding_row_num_question_type_DD
),
unnest_dynamic_choices AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answers,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num,
        dynamic_choices:Locator AS choices_locator,
        dynamic_choices:DynamicType AS choices_dynamic_type,
        dynamic_answers:Locator AS answers_locator,
        dynamic_answers:DynamicType AS answers_dynamic_type
    FROM
        unnest_question_choices
),
dynamic_type_conditions AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        answers,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        choices_dynamic_type,
        answers_dynamic_type,
        CASE
            WHEN choices_dynamic_type = 'ChoiceGroup' THEN REGEXP_SUBSTR(choices_locator, 'QID[0-9]+')
            WHEN choices_dynamic_type = 'ReferenceList' THEN REGEXP_SUBSTR(choices_locator, 'REFL_[a-zA-Z0-9]+')
        END AS choices_extracted_qid,
        CASE
            WHEN answers_dynamic_type = 'ChoiceGroup' THEN REGEXP_SUBSTR(answers_locator, 'QID[0-9]+')
            WHEN answers_dynamic_type = 'ReferenceList' THEN REGEXP_SUBSTR(answers_locator, 'REFL_[a-zA-Z0-9]+')
        END AS answers_extracted_qid,
        choice_image_display,
        text_entry,
        choice_id,
        choice_display,
        dd_row_num
    FROM
        unnest_dynamic_choices
),
dynamic_choices_ref_list AS (
    SELECT
        d.survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        answers,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        choices_dynamic_type,
        choices_extracted_qid,
        answers_extracted_qid,
        choice_image_display,
        text_entry,
        choice_id,
        choice_display,
        dd_row_num,
        ref_key,
        type AS dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        dynamic_type_conditions AS d
        LEFT JOIN final_ref_list AS rl ON d.survey_id = rl.survey_id
        AND d.choices_extracted_qid = rl.ref_key
),
dynamic_choices_join AS (
    SELECT
        *,
        CASE
            WHEN row_number_b_id = 1 THEN b_choice_id
            ELSE NULL
        END AS final_b_choice_id,
        CASE
            WHEN row_number_a_id = 1 THEN a_choice_id
            ELSE NULL
        END AS final_a_choice_id,
        CASE
            WHEN row_number_c_id = 1 THEN c_choice_id
            ELSE NULL
        END AS final_c_choice_id,
        CASE
            WHEN row_number_ref_choice_id = 1 THEN ref_choice_id
            ELSE NULL
        END AS final_ref_choice_id,
        CASE
            WHEN row_number_b_id = 1 THEN b_choice_image_display
            ELSE NULL
        END AS final_b_choice_image_display,
        CASE
            WHEN row_number_a_id = 1 THEN a_choice_image_display
            ELSE NULL
        END AS final_a_choice_image_display,
        CASE
            WHEN row_number_c_id = 1 THEN c_choice_image_display
            ELSE NULL
        END AS final_c_choice_image_display,
        CASE
            WHEN row_number_b_id = 1 THEN b_text_entry
            ELSE NULL
        END AS final_b_text_entry,
        CASE
            WHEN row_number_a_id = 1 THEN a_text_entry
            ELSE NULL
        END AS final_a_text_entry,
        CASE
            WHEN row_number_c_id = 1 THEN c_text_entry
            ELSE NULL
        END AS final_c_text_entry,
        CASE
            WHEN row_number_b_id = 1 THEN b_choice_display
            ELSE NULL
        END AS final_b_choice_display,
        CASE
            WHEN row_number_a_id = 1 THEN a_choice_display
            ELSE NULL
        END AS final_a_choice_display,
        CASE
            WHEN row_number_c_id = 1 THEN c_choice_display
            ELSE NULL
        END AS final_c_choice_display,
        CASE
            WHEN row_number_ref_choice_id = 1 THEN reference_choices
            ELSE NULL
        END AS final_reference_choices
    FROM
        (
            SELECT
                a.survey_id,
                a.question_id,
                a.question_text,
                a.question_name,
                a.question_type,
                a.selector,
                a.sub_selector,
                a.choice_id AS a_choice_id,
                b.choice_id AS b_choice_id,
                c.choice_id AS c_choice_id,
                a.choices_extracted_qid AS a_qid,
                b.choices_extracted_qid AS b_qid,
                c.choices_extracted_qid AS c_qid,
                a.answers,
                a.answers_extracted_qid,
                a.groups,
                a.add_questions,
                a.regions,
                a.column_labels,
                a.labels,
                a.analyze_choice,
                a.choice_data_export_tags,
                a.dd_row_num,
                a.choice_image_display AS a_choice_image_display,
                b.choice_image_display AS b_choice_image_display,
                c.choice_image_display AS c_choice_image_display,
                a.text_entry AS a_text_entry,
                b.text_entry AS b_text_entry,
                c.text_entry AS c_text_entry,
                a.choice_display AS a_choice_display,
                b.choice_display AS b_choice_display,
                c.choice_display AS c_choice_display,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    b.choice_id
                    ORDER BY
                        b.choice_id
                ) AS row_number_b_id,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    a.choice_id
                    ORDER BY
                        a.choice_id
                ) AS row_number_a_id,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    c.choice_id
                    ORDER BY
                        c.choice_id
                ) AS row_number_c_id,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    a.ref_choice_id
                    ORDER BY
                        a.ref_choice_id
                ) AS row_number_ref_choice_id,
                a.ref_key,
                a.dynamic_choices_type,
                a.ref_choice_id,
                a.reference_choices
            FROM
                dynamic_choices_ref_list AS a
                LEFT JOIN dynamic_choices_ref_list AS b ON a.survey_id = b.survey_id
                AND a.choices_extracted_qid = b.question_id
                LEFT JOIN dynamic_choices_ref_list AS c ON b.survey_id = c.survey_id
                AND b.choices_extracted_qid = c.question_id
        )
),
testing AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        answers,
        answers_extracted_qid,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num,
        NULLIF(
            RTRIM(
                CONCAT(
                    COALESCE(final_a_choice_id || '!@#%', ''),
                    COALESCE('x' || final_b_choice_id || '!@#%', ''),
                    COALESCE('xx' || final_c_choice_id || '!@#%', ''),
                    COALESCE('x' || final_ref_choice_id || '!@#%', '')
                ),
                '!@#%'
            ),
            ''
        ) AS choice_id,
        NULLIF(
            RTRIM(
                CONCAT(
                    COALESCE(final_a_choice_display || '!@#%', ''),
                    COALESCE(final_b_choice_display || '!@#%', ''),
                    COALESCE(final_c_choice_display || '!@#%', ''),
                    COALESCE(final_reference_choices, '')
                )
            ),
            ''
        ) AS choice_display,
        NULLIF(
            RTRIM(
                CONCAT(
                    COALESCE(final_a_choice_image_display || '!@#%', ''),
                    COALESCE(final_b_choice_image_display || '!@#%', ''),
                    COALESCE(final_c_choice_image_display || '!@#%', '')
                )
            ),
            ''
        ) AS choice_image_display,
        NULLIF(
            RTRIM(
                CONCAT(
                    COALESCE(final_a_text_entry || '!@#%', ''),
                    COALESCE(final_b_text_entry || '!@#%', ''),
                    COALESCE(final_c_text_entry || '!@#%', '')
                )
            ),
            ''
        ) AS text_entry,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        dynamic_choices_join
),
zip_columns AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        answers,
        answers_extracted_qid,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num,
        z.index AS zip_index,
        SPLIT(COALESCE(choice_id, 'null'), '!@#%') AS choice_id_arr,
        SPLIT(COALESCE(choice_display, 'null'), '!@#%') AS choice_display_arr,
        SPLIT(COALESCE(choice_image_display, 'null'), '!@#%') AS choice_image_display_arr,
        SPLIT(COALESCE(text_entry, 'null'), '!@#%') AS text_entry_arr,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        testing,
        LATERAL FLATTEN(
            INPUT => SPLIT(COALESCE(choice_id, 'null'), '!@#%')
        ) z
),
explode_multiple_rows AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        answers,
        answers_extracted_qid,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num,
        choice_id_arr [zip_index]::STRING AS choice_id,
        choice_display_arr [zip_index]::STRING AS choice_display,
        choice_image_display_arr [zip_index]::STRING AS choice_image_display,
        text_entry_arr [zip_index]::STRING AS text_entry,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        zip_columns
),
remove_null_rows AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        answers,
        answers_extracted_qid,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        COUNT(
            CASE
                WHEN (
                    choice_id = NULL
                    OR choice_id = 'null'
                ) THEN 1
            END
        ) OVER (PARTITION BY survey_id, question_id) AS null_count,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        explode_multiple_rows
),
final_choices AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answers,
        answers_extracted_qid,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        remove_null_rows
    WHERE
        (
            NOT choice_id = NULL
            AND choice_id <> 'null'
            AND choice_id <> ''
        )
        OR (
            (
                choice_id = NULL
                OR choice_id = 'null'
                OR choice_id = ''
            )
            AND null_count = 1
        )
),
dynamic_answers_ref_list AS (
    SELECT
        d.survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        answers,
        groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        choices_dynamic_type,
        choices_extracted_qid,
        answers_extracted_qid,
        choice_image_display,
        text_entry,
        choice_id,
        choice_display,
        dd_row_num,
        ref_key,
        type AS dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        dynamic_type_conditions AS d
        LEFT JOIN final_ref_list AS rl ON d.survey_id = rl.survey_id
        AND d.answers_extracted_qid = rl.ref_key
),
answers_outer_key AS (
    SELECT
        survey_id,
        question_id,
        a.key AS outer_key,
        a.value AS outer_value,
        answers_extracted_qid,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        dynamic_answers_ref_list,
        LATERAL FLATTEN(
            INPUT => PARSE_JSON(answers),
            OUTER => TRUE
        ) a
),
answers_inner_key AS (
    SELECT
        survey_id,
        question_id,
        outer_key,
        ov.key AS outer_value_key,
        ov.value AS outer_value,
        outer_value ['Display'] AS display,
        answers_extracted_qid,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        answers_outer_key,
        LATERAL FLATTEN(
            INPUT => outer_value,
            OUTER => TRUE
        ) ov
),
answers AS (
    SELECT
        survey_id,
        question_id,
        outer_value:Display::STRING AS outer_display,
        CASE
            WHEN outer_value:Display::STRING = NULL THEN outer_key
            ELSE outer_value_key
        END AS answer_id,
        CASE
            WHEN outer_value:Display::STRING = NULL THEN NULL
            ELSE outer_key
        END AS answer_key,
        CASE
            WHEN outer_value:Display::STRING = NULL THEN display
            ELSE outer_value:Display::STRING
        END AS answers,
        answers_extracted_qid,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        answers_inner_key
    WHERE
        outer_value_key = 'Display'
        OR outer_value_key = NULL
        OR outer_value_key RLIKE '^[0-9]+$'
),
dynamic_answers_join AS (
    SELECT
        *,
        CASE
            WHEN row_number_b_id = 1 THEN b_answer_id
            ELSE NULL
        END AS final_b_answer_id,
        CASE
            WHEN row_number_a_id = 1 THEN a_answer_id
            ELSE NULL
        END AS final_a_answer_id,
        CASE
            WHEN row_number_c_id = 1 THEN c_answer_id
            ELSE NULL
        END AS final_c_answer_id,
        CASE
            WHEN row_number_ref_choice_id = 1 THEN ref_choice_id
            ELSE NULL
        END AS final_ref_choice_id,
        CASE
            WHEN row_number_b_id = 1 THEN b_answer_key
            ELSE NULL
        END AS final_b_answer_key,
        CASE
            WHEN row_number_a_id = 1 THEN a_answer_key
            ELSE NULL
        END AS final_a_answer_key,
        CASE
            WHEN row_number_c_id = 1 THEN c_answer_key
            ELSE NULL
        END AS final_c_answer_key,
        CASE
            WHEN row_number_b_id = 1 THEN b_answers
            ELSE NULL
        END AS final_b_answers,
        CASE
            WHEN row_number_a_id = 1 THEN a_answers
            ELSE NULL
        END AS final_a_answers,
        CASE
            WHEN row_number_c_id = 1 THEN c_answers
            ELSE NULL
        END AS final_c_answers,
        CASE
            WHEN row_number_ref_choice_id = 1 THEN reference_choices
            ELSE NULL
        END AS final_reference_choices
    FROM
        (
            SELECT
                a.survey_id,
                a.question_id,
                a.answer_id AS a_answer_id,
                b.answer_id AS b_answer_id,
                c.answer_id AS c_answer_id,
                a.answers_extracted_qid AS a_qid,
                b.answers_extracted_qid AS b_qid,
                c.answers_extracted_qid AS c_qid,
                a.answers,
                a.answer_key AS a_answer_key,
                b.answer_key AS b_answer_key,
                c.answer_key AS c_answer_key,
                a.answers AS a_answers,
                b.answers AS b_answers,
                c.answers AS c_answers,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    b.answer_id
                    ORDER BY
                        b.answer_id
                ) AS row_number_b_id,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    a.answer_id
                    ORDER BY
                        a.answer_id
                ) AS row_number_a_id,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    c.answer_id
                    ORDER BY
                        c.answer_id
                ) AS row_number_c_id,
                ROW_NUMBER() OVER (
                    PARTITION BY a.survey_id,
                    a.question_id,
                    a.ref_choice_id
                    ORDER BY
                        a.ref_choice_id
                ) AS row_number_ref_choice_id,
                a.ref_key,
                a.dynamic_choices_type,
                a.ref_choice_id,
                a.reference_choices
            FROM
                answers AS a
                LEFT JOIN answers AS b ON a.survey_id = b.survey_id
                AND a.answers_extracted_qid = b.question_id
                LEFT JOIN answers AS c ON b.survey_id = c.survey_id
                AND b.answers_extracted_qid = c.question_id
        )
),
dynamic_answers_cases AS (
    SELECT
        survey_id,
        question_id,
        NULLIF(
            RTRIM(
                CONCAT(
                    COALESCE(final_a_answer_id || '!@#%', ''),
                    COALESCE(CONCAT('x', final_b_answer_id) || '!@#%', ''),
                    COALESCE(CONCAT('xx', final_c_answer_id) || '!@#%', ''),
                    COALESCE(CONCAT('x', final_ref_choice_id), '')
                )
            ),
            ''
        ) AS answer_id,
        NULLIF(
            RTRIM(
                CONCAT(
                    COALESCE(final_a_answers || '!@#%', ''),
                    COALESCE(final_b_answers || '!@#%', ''),
                    COALESCE(final_c_answers || '!@#%', ''),
                    COALESCE(final_reference_choices, '')
                )
            ),
            ''
        ) AS answers,
        NULLIF(
            RTRIM(
                CONCAT(
                    COALESCE(final_a_answer_key || '!@#%', ''),
                    COALESCE(final_b_answer_key || '!@#%', ''),
                    COALESCE(final_c_answer_key || '!@#%', '')
                )
            ),
            ''
        ) AS answer_key,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        dynamic_answers_join
),
zip_answers_columns AS (
    SELECT
        survey_id,
        question_id,
        za.index AS zip_index,
        SPLIT(COALESCE(answer_id, 'null'), '!@#%') AS answer_id_arr,
        SPLIT(COALESCE(answer_key, 'null'), '!@#%') AS answer_key_arr,
        SPLIT(COALESCE(answers, 'null'), '!@#%') AS answers_arr,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        dynamic_answers_cases,
        LATERAL FLATTEN(
            INPUT => SPLIT(COALESCE(answer_id, 'null'), '!@#%')
        ) za
),
explode_multiple_rows_answers AS (
    SELECT
        survey_id,
        question_id,
        answer_id_arr [zip_index]::STRING AS answer_id,
        answer_key_arr [zip_index]::STRING AS answer_key,
        answers_arr [zip_index]::STRING AS answers,
        ref_key,
        dynamic_choices_type,
        ref_choice_id,
        reference_choices
    FROM
        zip_answers_columns
),
remove_null_rows_answers AS (
    SELECT
        survey_id,
        question_id,
        answer_id,
        answer_key,
        answers,
        COUNT(
            CASE
                WHEN (
                    answer_id = NULL
                    OR answer_id = 'null'
                ) THEN 1
            END
        ) OVER (PARTITION BY survey_id, question_id) AS null_answer_count
    FROM
        explode_multiple_rows_answers
),
final_answers AS (
    SELECT
        survey_id,
        question_id,
        answer_id,
        answer_key,
        answers
    FROM
        remove_null_rows_answers
    WHERE
        (
            NOT answer_id = NULL
            AND answer_id <> 'null'
            AND answer_id <> ''
        )
        OR (
            (
                answer_id = NULL
                OR answer_id = 'null'
                OR answer_id = ''
            )
            AND null_answer_count = 1
        )
),
choices_and_answers_together AS (
    SELECT
        c.survey_id,
        c.question_id,
        c.question_text,
        c.question_name,
        c.question_type,
        c.selector,
        c.sub_selector,
        c.choice_id,
        c.choice_display,
        c.choice_image_display,
        c.text_entry,
        c.answers_extracted_qid,
        c.groups,
        c.add_questions,
        c.regions,
        c.column_labels,
        c.labels,
        c.analyze_choice,
        c.choice_data_export_tags,
        c.dd_row_num,
        a.answer_id,
        a.answer_key,
        a.answers
    FROM
        final_choices AS c
        LEFT JOIN final_answers AS a ON c.survey_id = a.survey_id
        AND c.question_id = a.question_id
),
explode_question_groups AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answers,
        answer_key,
        g.value AS groups,
        add_questions,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        choices_and_answers_together,
        LATERAL FLATTEN(
            INPUT => groups,
            OUTER => TRUE
        ) g
),
explode_additional_questions AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        aq.key AS add_ques_key,
        aq.value AS add_ques_struct,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        explode_question_groups,
        LATERAL FLATTEN(
            INPUT => add_questions,
            OUTER => TRUE
        ) aq
),
unnest_additional_questions AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        add_ques_struct:QuestionText AS sbs_question_text,
        add_ques_struct:QuestionType AS sbs_question_type,
        add_ques_struct:Selector AS sbs_question_selector,
        add_ques_struct:SubSelector AS sbs_question_sub_selector,
        add_ques_struct:Answers AS sbs_answer,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        explode_additional_questions
),
explode_sbs_answer AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sa.key AS sbs_answer_key,
        sa.value AS sbs_answer_struct,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        unnest_additional_questions,
        LATERAL FLATTEN(
            INPUT => sbs_answer,
            OUTER => TRUE
        ) sa
),
unnest_sbs_answer AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        SBS_ANSWER_STRUCT:Display AS sbs_answer,
        regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        explode_sbs_answer
),
explode_questions_regions AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        r.value AS col,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        unnest_sbs_answer,
        LATERAL FLATTEN(
            INPUT => regions,
            OUTER => TRUE
        ) r
),
unnest_questions_regions AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        COL:Description AS regions,
        column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        explode_questions_regions
),
explode_column_labels AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        cl.value AS column_labels,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        unnest_questions_regions,
        LATERAL FLATTEN(
            INPUT => column_labels,
            OUTER => TRUE
        ) cl
),
unnest_column_labels AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        COLUMN_LABELS:Display AS column_labels_display,
        labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        explode_column_labels
),
explode_questions_labels AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        l.key AS labels_key,
        l.value AS labels,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        unnest_column_labels,
        LATERAL FLATTEN(
            INPUT => labels,
            OUTER => TRUE
        ) l
),
unnest_question_labels AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choice_display,
        choice_image_display,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_key,
        LABELS:Display AS labels_display,
        analyze_choice,
        choice_data_export_tags,
        dd_row_num
    FROM
        explode_questions_labels
),
explode_analyze_choice AS (
    SELECT
        survey_id,
        question_id,
        ac.key AS analyze_choice_key,
        ac.value AS analyze_choice_struct
    FROM
        unnest_question_labels,
        LATERAL FLATTEN(
            INPUT => analyze_choice,
            OUTER => TRUE
        ) ac
),
unnest_choice_analyze AS (
    SELECT
        DISTINCT survey_id,
        question_id,
        analyze_choice_key,
        analyze_choice_struct
    FROM
        explode_analyze_choice
),
explode_data_export_tag AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        NULLIF(choice_id, 'null') AS choice_id,
        NULLIF(choice_display, 'null') AS choice_display,
        NULLIF(choice_image_display, 'null') AS choice_image_display,
        NULLIF(text_entry, 'null') AS text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_key,
        labels_display,
        cdet.key AS data_export_key,
        cdet.value AS data_export_struct,
        dd_row_num,
        CASE
            WHEN question_type IN ('Draw', 'FileUpload') THEN ARRAY_CONSTRUCT('FILE_SIZE', 'FILE_ID', 'FILE_TYPE', 'FILE_NAME')
            ELSE NULL
        END AS array_value
    FROM
        unnest_question_labels,
        LATERAL FLATTEN(
            INPUT => choice_data_export_tags,
            OUTER => TRUE
        ) cdet
),
adding_image_description AS (
    SELECT
        DISTINCT survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        CASE
            WHEN choice_image_display = NULL THEN choice_display
            ELSE choice_image_display
        END AS choices,
        CASE
            WHEN choice_image_display = NULL THEN NULL
            ELSE choice_display
        END AS image_description,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_key,
        labels_display,
        data_export_key,
        CASE
            WHEN choice_id = data_export_key THEN data_export_struct
            ELSE NULL
        END AS data_export_struct,
        dd_row_num,
        av.value AS array_value
    FROM
        explode_data_export_tag,
        LATERAL FLATTEN(
            INPUT => array_value,
            OUTER => TRUE
        ) av
    WHERE
        (
            choice_id = data_export_key
            OR data_export_key = NULL
        )
),
data_export_key_v AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choices,
        image_description,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_key,
        labels_display,
        CASE
            WHEN data_export_struct = NULL
            AND question_type IN ('Draw', 'FileUpload') THEN COALESCE(CONCAT(question_name, '_', array_value), NULL)
            WHEN data_export_struct = NULL
            AND question_type = 'SBS' THEN COALESCE(
                CONCAT(question_name, '#', add_ques_key, '_', choice_id),
                NULL
            )
            WHEN (
                data_export_struct = NULL
                OR data_export_struct = FALSE
            )
            AND NOT choices = NULL
            AND NOT question_type IN (
                'SBS',
                'Draw',
                'FileUpload',
                'Timing',
                'Meta',
                'SS',
                'TE',
                'MC',
                'RO',
                'PGR',
                'DB'
            ) THEN CONCAT(question_name, '_', choice_id)
            WHEN (
                data_export_struct = NULL
                OR data_export_struct = FALSE
            )
            AND question_type IN (
                'Timing',
                'Meta',
                'SS',
                'TE',
                'MC',
                'RO',
                'PGR',
                'DB'
            )
            AND (
                answers = NULL
                OR answers = 'null'
            ) THEN question_name
            WHEN (
                data_export_struct = NULL
                OR data_export_struct = FALSE
            )
            AND question_type IN (
                'HL',
                'DD',
                'HotSpot',
                'Slider',
                'CS',
                'Matrix',
                'SBS'
            )
            AND choices = NULL THEN question_name
            ELSE data_export_struct
        END AS data_export_struct,
        dd_row_num,
        array_value
    FROM
        adding_image_description
),
choices_and_answers_condition AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        choice_id,
        choices,
        image_description,
        text_entry,
        answer_id,
        answer_key,
        answers,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_key,
        labels_display,
        CASE
            WHEN question_type IN (
                'HL',
                'DD',
                'HotSpot',
                'Slider',
                'Matrix',
                'CS',
                'SBS'
            ) THEN answers
            WHEN question_type IN (
                'Timing',
                'Meta',
                'SS',
                'TE',
                'MC',
                'RO',
                'PGR',
                'DB'
            ) THEN choices
            ELSE NULL
        END AS question_choices,
        CASE
            WHEN question_type IN (
                'Timing',
                'Meta',
                'SS',
                'TE',
                'MC',
                'RO',
                'PGR',
                'DB'
            ) THEN choice_id
            WHEN question_type IN ('HL', 'DD', 'HotSpot', 'Slider', 'Matrix') THEN answer_id
            ELSE NULL
        END AS question_choice_id,
        CASE
            WHEN question_type IN (
                'HL',
                'DD',
                'HotSpot',
                'Slider',
                'CS',
                'Matrix',
                'SBS'
            ) THEN choices
            ELSE answers
        END AS question_answers,
        CASE
            WHEN question_type IN (
                'HL',
                'DD',
                'HotSpot',
                'Slider',
                'CS',
                'Matrix',
                'SBS'
            ) THEN choice_id
            ELSE answer_id
        END AS question_answer_id,
        data_export_struct,
        dd_row_num,
        array_value
    FROM
        data_export_key_v
),
intermediate AS (
    SELECT
        survey_id,
        question_id,
        ARRAY_TO_STRING(
            ARRAY_SORT(
                ARRAY_AGG(
                    DISTINCT CASE
                        WHEN NOT column_labels_display = NULL
                        AND column_labels_display <> '&nbsp;' THEN column_labels_display
                        ELSE NULL
                    END
                ),
                TRUE
            ),
            '|'
        ) AS column_labels_display,
        ARRAY_TO_STRING(
            ARRAY_SORT(
                ARRAY_AGG(
                    DISTINCT CASE
                        WHEN NOT labels_display = NULL
                        AND labels_display <> '&nbsp;' THEN labels_display
                        ELSE NULL
                    END
                ),
                TRUE
            ),
            '|'
        ) AS labels_display
    FROM
        choices_and_answers_condition
    GROUP BY
        survey_id,
        question_id
),
labels_column_labels_logic AS (
    SELECT
        choices_and_answers_condition.survey_id,
        choices_and_answers_condition.question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        question_choice_id,
        question_choices,
        image_description,
        text_entry,
        question_answer_id,
        question_answers,
        answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        intermediate.column_labels_display,
        intermediate.labels_display,
        data_export_struct,
        dd_row_num,
        array_value
    FROM
        choices_and_answers_condition
        LEFT JOIN intermediate ON intermediate.survey_id = choices_and_answers_condition.survey_id
        AND intermediate.question_id = choices_and_answers_condition.question_id
),
questions_choice_analyze AS (
    SELECT
        q.survey_id,
        q.question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        question_choice_id,
        question_choices,
        image_description,
        text_entry,
        question_answer_id,
        question_answers,
        answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_display,
        data_export_struct,
        dd_row_num,
        array_value,
        ca.analyze_choice_struct AS analyze_choice
    FROM
        labels_column_labels_logic AS q
        LEFT JOIN unnest_choice_analyze AS ca ON q.survey_id = ca.survey_id
        AND q.question_id = ca.question_id
        AND question_choice_id = analyze_choice_key
),
adding_items AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        question_choice_id,
        question_choices,
        image_description,
        text_entry,
        question_answer_id,
        question_answers,
        CASE
            WHEN answer_key = NULL
            OR answer_key = 'null' THEN question_answer_id
            ELSE answer_key
        END AS answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_display,
        CASE
            WHEN question_type = 'PGR' THEN question_choices
            ELSE NULL
        END AS items,
        CASE
            WHEN question_type = 'PGR' THEN NULL
            ELSE question_choices
        END AS choices_final,
        analyze_choice,
        data_export_struct,
        dd_row_num,
        array_value
    FROM
        questions_choice_analyze
),
explode_array_value AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        question_choice_id,
        question_choices,
        image_description,
        text_entry,
        question_answer_id,
        question_answers,
        answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_display,
        items,
        choices_final,
        CASE
            WHEN analyze_choice = 'No' THEN FALSE
            ELSE TRUE
        END AS analyze_choice,
        data_export_struct,
        dd_row_num,
        array_value
    FROM
        adding_items
),
choices_variable_naming_together AS (
    SELECT
        ques.survey_id,
        ques.question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        question_choice_id,
        question_choices,
        image_description,
        text_entry,
        question_answer_id,
        question_answers,
        answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_display,
        items,
        choices_final,
        analyze_choice,
        data_export_struct,
        dd_row_num,
        array_value,
        variable_naming
    FROM
        explode_array_value AS ques
        LEFT JOIN explode_variable_naming AS var ON ques.survey_id = var.survey_id
        AND ques.question_id = var.question_id
        AND ques.question_choice_id = var.variable_naming_key
),
choices_with_recode_values AS (
    SELECT
        DISTINCT que.survey_id,
        que.question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        question_choice_id,
        question_choices,
        image_description,
        text_entry,
        question_answer_id,
        question_answers,
        answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_display,
        items,
        choices_final,
        analyze_choice,
        data_export_struct,
        dd_row_num,
        array_value,
        variable_naming,
        rec.recode_values,
        rec.recode_values_key
    FROM
        choices_variable_naming_together AS que
        LEFT JOIN explode_recode_values AS rec ON que.survey_id = rec.survey_id
        AND que.question_id = rec.question_id
        AND que.question_choice_id = rec.recode_values_key
),
question_key_logic1 AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        CASE
            WHEN text_entry = 'true'
            AND question_type IN (
                'HL',
                'DD',
                'HotSpot',
                'Slider',
                'CS',
                'Matrix',
                'SBS'
            ) THEN CONCAT(
                question_id,
                '_',
                question_answer_id,
                '_',
                'TEXT'
            )
            WHEN text_entry = 'true'
            AND question_type IN ('Timing', 'Meta', 'SS', 'TE', 'MC', 'RO', 'PGR') THEN CONCAT(
                question_id,
                '_',
                question_choice_id,
                '_',
                'TEXT'
            )
        END AS questions_key,
        question_choice_id,
        choices_final AS question_choices,
        text_entry,
        image_description,
        question_answer_id,
        question_answers,
        answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_display,
        items,
        analyze_choice,
        data_export_struct,
        dd_row_num,
        variable_naming,
        recode_values
    FROM
        choices_with_recode_values
),
question_key_logic2 AS (
    SELECT
        survey_id,
        question_id,
        question_text,
        question_name,
        question_type,
        selector,
        sub_selector,
        CASE
            WHEN question_type = 'Timing' THEN COALESCE(
                CASE
                    WHEN question_choices LIKE '%FirstClick%' THEN CONCAT(question_id, '_FIRST_CLICK')
                    WHEN question_choices LIKE '%LastClick%' THEN CONCAT(question_id, '_LAST_CLICK')
                    WHEN question_choices LIKE '%PageSubmit%' THEN CONCAT(question_id, '_PAGE_SUBMIT')
                    WHEN question_choices LIKE '%ClickCount%' THEN CONCAT(question_id, '_CLICK_COUNT')
                    ELSE UPPER(
                        REPLACE(
                            CONCAT(question_id, '_', question_choices),
                            ' ',
                            '_'
                        )
                    )
                END,
                question_id
            )
            WHEN question_type = 'HL' THEN COALESCE(
                REPLACE(
                    CONCAT(question_id, '_', question_choice_id),
                    ' ',
                    '_'
                ),
                question_id
            )
            WHEN question_type = 'Meta' THEN COALESCE(
                CASE
                    WHEN question_choices = 'Operating System' THEN CONCAT(question_id, '_OS')
                    WHEN question_choices = 'Screen Resolution' THEN CONCAT(question_id, '_RESOLUTION')
                    ELSE UPPER(
                        REPLACE(
                            CONCAT(question_id, '_', question_choices),
                            ' ',
                            '_'
                        )
                    )
                END,
                question_id
            )
            WHEN question_type = 'DD' THEN COALESCE(
                CONCAT(question_id, '_', question_answer_id),
                question_id
            )
            WHEN question_type = 'TE' THEN COALESCE(
                CASE
                    WHEN selector = 'AUTO' THEN CONCAT(question_id, '_', 1)
                    WHEN selector = 'FORM' THEN CONCAT(question_id, '_', question_choice_id)
                    ELSE CONCAT(question_id, '_', 'TEXT')
                END,
                question_id
            )
            WHEN question_type = 'HeatMap' THEN COALESCE(CONCAT(question_id, '_', 'REGIONS'), question_id)
            WHEN question_type = 'HotSpot' THEN COALESCE(
                CONCAT(question_id, '_', question_answer_id),
                question_id
            )
            WHEN question_type = 'PGR' THEN COALESCE(
                CONCAT(
                    question_id,
                    '_',
                    'G0',
                    '_',
                    question_choice_id,
                    '_',
                    'RANK'
                ),
                question_id
            )
            WHEN question_type = 'RO' THEN COALESCE(
                CONCAT(question_id, '_', question_choice_id),
                question_id
            )
            WHEN question_type = 'Slider' THEN COALESCE(
                CONCAT(question_id, '_', question_answer_id),
                question_id
            )
            WHEN question_type = 'CS' THEN COALESCE(
                CONCAT(question_id, '_', question_answer_id),
                question_id
            )
            WHEN question_type = 'Matrix'
            AND (
                selector <> 'CS'
                AND NOT (
                    selector = 'TE'
                    AND sub_selector = 'Short'
                )
            ) THEN COALESCE(
                CONCAT(question_id, '_', answer_key),
                question_id
            )
            WHEN question_type = 'Matrix'
            AND (
                selector = 'CS'
                OR (
                    selector = 'TE'
                    AND sub_selector = 'Short'
                )
            ) THEN COALESCE(
                CONCAT(
                    question_id,
                    '_',
                    question_answer_id,
                    '_',
                    question_choice_id
                ),
                question_id
            )
            WHEN question_type = 'SBS' THEN COALESCE(
                CONCAT(
                    question_id,
                    '#',
                    add_ques_key,
                    '_',
                    question_answer_id
                ),
                question_id
            )
            WHEN question_type IN ('Draw', 'FileUpload') THEN COALESCE(
                CONCAT(question_id, '_', array_value),
                question_id
            )
            ELSE question_id
        END AS questions_key,
        question_choice_id,
        choices_final AS question_choices,
        text_entry,
        image_description,
        question_answer_id,
        question_answers,
        answer_key,
        groups,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        regions,
        column_labels_display,
        labels_display,
        items,
        analyze_choice,
        data_export_struct,
        dd_row_num,
        variable_naming,
        recode_values
    FROM
        choices_with_recode_values
),
adding_questions_key AS (
    SELECT
        *
    FROM
        question_key_logic1
    UNION
    SELECT
        *
    FROM
        question_key_logic2
),
max_dd AS (
    SELECT
        *,
        MAX(dd_row_num) OVER (
            PARTITION BY survey_id,
            question_id
            ORDER BY
                survey_id
        ) AS max_dd
    FROM
        adding_questions_key
),
question_type_DD_row_num AS (
    SELECT
        *,
        CASE
            WHEN question_type = NULL THEN 0
            WHEN question_type <> 'DD' THEN 0
            WHEN question_type = 'DD'
            AND question_choices = NULL
            AND NOT question_answers = NULL THEN 1
            WHEN question_type = 'DD'
            AND dd_row_num = ARRAY_SIZE(SPLIT(question_choices, ' ~ ')) THEN 1
            WHEN question_type = 'DD'
            AND (
                ARRAY_SIZE(SPLIT(question_choices, ' ~ ')) > max_dd
                AND dd_row_num = max_dd
            ) THEN 1
            ELSE 2
        END AS filter_row_num
    FROM
        max_dd
),
question_type_DD_filter AS (
    SELECT
        *
    FROM
        question_type_DD_row_num
    WHERE
        filter_row_num <= 1
),
drop_dd_filter_columns AS (
    SELECT
        *,
        NULL AS score_id,
        NULL AS scoring_id
    FROM
        question_type_DD_filter
    WHERE
        NOT questions_key = NULL
),
unnest_outer_flow_and_explode_inner_flow AS (
    SELECT
        survey_id,
        FLOW:Type AS flow_type,
        FLOW:FlowID AS flow_id,
        FLOW:ID AS outer_flow_block_id,
        if_.value AS inner_flow
    FROM
        unnest_result,
        LATERAL FLATTEN(
            INPUT => flow:Flow,
            OUTER => TRUE
        ) if_
),
unnest_inner_flow_explode_nested_flow AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow:Type AS inner_flow_type,
        inner_flow:FlowID AS inner_flow_id,
        inner_flow:ID AS inner_flow_block_id,
        inner_flow:EmbeddedData AS inner_embedded_data,
        nf.value AS nested_flow
    FROM
        unnest_outer_flow_and_explode_inner_flow,
        LATERAL FLATTEN(
            INPUT => inner_flow:Flow,
            OUTER => TRUE
        ) nf
),
explode_inner_embedded_data AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        ied.value AS inner_embedded_data,
        (NESTED_FLOW:Type) AS nested_flow_type,
        (NESTED_FLOW:FlowID) AS nested_flow_id,
        (NESTED_FLOW:ID) AS nested_flow_block_id,
        NESTED_FLOW:EmbeddedData AS nested_embedded_data,
        NESTED_FLOW:Flow AS double_nested_flow
    FROM
        unnest_inner_flow_explode_nested_flow,
        LATERAL FLATTEN(
            INPUT => INNER_EMBEDDED_DATA:Field,
            OUTER => TRUE
        ) ied
),
explode_double_nested_flow_unnest_nested_flow AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        inner_embedded_data,
        nested_flow_type,
        nested_flow_id,
        nested_flow_block_id,
        ned.value AS nested_embedded_data,
        double_nested_flow
    FROM
        explode_inner_embedded_data,
        LATERAL FLATTEN(
            INPUT => NESTED_EMBEDDED_DATA:Field,
            OUTER => TRUE
        ) ned
),
unnest_double_nested_flow_explode_triple_nested_flow AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        inner_embedded_data,
        nested_flow_type,
        nested_flow_id,
        nested_flow_block_id,
        nested_embedded_data,
        dnf.value AS double_nested_flow
    FROM
        explode_double_nested_flow_unnest_nested_flow,
        LATERAL FLATTEN(
            INPUT => double_nested_flow,
            OUTER => TRUE
        ) dnf
),
explode_double_nested_embedded_data AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        inner_embedded_data,
        nested_flow_type,
        nested_flow_id,
        nested_flow_block_id,
        nested_embedded_data,
        double_NESTED_FLOW:Type AS double_nested_flow_type,
        (double_NESTED_FLOW:FlowID) AS double_nested_flow_id,
        double_NESTED_FLOW:ID AS double_nested_flow_block_id,
        dned.value AS double_nested_embedded_data,
        double_NESTED_FLOW:Flow AS triple_nested_flow
    FROM
        unnest_double_nested_flow_explode_triple_nested_flow,
        LATERAL FLATTEN(
            INPUT => double_NESTED_FLOW:EmbeddedData,
            OUTER => TRUE
        ) dned
),
unnest_double_nested_embedded_data AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        inner_embedded_data,
        nested_flow_type,
        nested_flow_id,
        nested_flow_block_id,
        nested_embedded_data,
        double_nested_flow_type,
        double_nested_flow_id,
        double_nested_flow_block_id,
        double_NESTED_EMBEDDED_DATA:Field AS double_nested_embedded_data,
        tnf.value AS triple_nested_flow
    FROM
        explode_double_nested_embedded_data,
        LATERAL FLATTEN(
            INPUT => triple_nested_flow,
            OUTER => TRUE
        ) tnf
),
unnest_triple_nested_flow_explode_embedded_data AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        inner_embedded_data,
        nested_flow_type,
        nested_flow_id,
        nested_flow_block_id,
        nested_embedded_data,
        double_nested_flow_type,
        double_nested_flow_id,
        double_nested_flow_block_id,
        double_nested_embedded_data,
        triple_NESTED_FLOW:Type AS triple_nested_flow_type,
        triple_NESTED_FLOW:FlowID AS triple_nested_flow_id,
        triple_NESTED_FLOW:ID AS triple_nested_flow_block_id,
        tned.value AS triple_nested_embedded_data
    FROM
        unnest_double_nested_embedded_data,
        LATERAL FLATTEN(
            INPUT => triple_NESTED_FLOW:EmbeddedData,
            OUTER => TRUE
        ) tned
),
unnest_triple_nested_embedded_data AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        inner_embedded_data,
        nested_flow_type,
        nested_flow_id,
        nested_flow_block_id,
        nested_embedded_data,
        double_nested_flow_type,
        double_nested_flow_id,
        double_nested_flow_block_id,
        double_nested_embedded_data,
        triple_nested_flow_type,
        triple_nested_flow_id,
        triple_nested_flow_block_id,
        triple_NESTED_EMBEDDED_DATA:Field AS triple_nested_embedded_data
    FROM
        unnest_triple_nested_flow_explode_embedded_data
),
embedded_data_logic AS (
    SELECT
        survey_id,
        flow_type,
        flow_id,
        outer_flow_block_id,
        inner_flow_type,
        inner_flow_id,
        inner_flow_block_id,
        inner_embedded_data,
        nested_flow_type,
        nested_flow_id,
        nested_flow_block_id,
        nested_embedded_data,
        double_nested_flow_type,
        double_nested_flow_id,
        double_nested_flow_block_id,
        double_nested_embedded_data,
        triple_nested_flow_type,
        triple_nested_flow_id,
        triple_nested_flow_block_id,
        triple_nested_embedded_data,
        CASE
            WHEN NOT inner_embedded_data = NULL
            AND nested_embedded_data = NULL
            AND double_nested_embedded_data = NULL
            AND triple_nested_embedded_data = NULL THEN inner_embedded_data
            WHEN inner_embedded_data = NULL
            AND NOT nested_embedded_data = NULL
            AND double_nested_embedded_data = NULL
            AND triple_nested_embedded_data = NULL THEN nested_embedded_data
            WHEN inner_embedded_data = NULL
            AND nested_embedded_data = NULL
            AND NOT double_nested_embedded_data = NULL
            AND triple_nested_embedded_data = NULL THEN double_nested_embedded_data
            WHEN inner_embedded_data = NULL
            AND nested_embedded_data = NULL
            AND double_nested_embedded_data = NULL
            AND NOT triple_nested_embedded_data = NULL THEN triple_nested_embedded_data
        END AS embedded_data
    FROM
        unnest_triple_nested_embedded_data
),
creating_block_id AS (
    SELECT
        survey_id,
        CASE
            WHEN NOT outer_flow_block_id = NULL
            AND inner_flow_block_id = NULL
            AND nested_flow_block_id = NULL
            AND double_nested_flow_block_id = NULL
            AND triple_nested_flow_block_id = NULL THEN outer_flow_block_id
            WHEN NOT inner_flow_block_id = NULL
            AND outer_flow_block_id = NULL
            AND nested_flow_block_id = NULL
            AND double_nested_flow_block_id = NULL
            AND triple_nested_flow_block_id = NULL THEN inner_flow_block_id
            WHEN NOT nested_flow_block_id = NULL
            AND outer_flow_block_id = NULL
            AND inner_flow_block_id = NULL
            AND double_nested_flow_block_id = NULL
            AND triple_nested_flow_block_id = NULL THEN nested_flow_block_id
            WHEN NOT double_nested_flow_block_id = NULL
            AND inner_flow_block_id = NULL
            AND nested_flow_block_id = NULL
            AND outer_flow_block_id = NULL
            AND triple_nested_flow_block_id = NULL THEN double_nested_flow_block_id
            WHEN NOT triple_nested_flow_block_id = NULL
            AND outer_flow_block_id = NULL
            AND inner_flow_block_id = NULL
            AND nested_flow_block_id = NULL
            AND double_nested_flow_block_id = NULL THEN triple_nested_flow_block_id
            WHEN NOT nested_flow_block_id = NULL
            AND NOT inner_flow_block_id = NULL
            AND outer_flow_block_id = NULL THEN nested_flow_block_id
        END AS block_id
    FROM
        embedded_data_logic
),
final_flow AS (
    SELECT
        survey_id,
        block_id,
        ROW_NUMBER() OVER (
            PARTITION BY survey_id
            ORDER BY
                survey_id
        ) AS block_number
    FROM
        creating_block_id
    WHERE
        NOT block_id = NULL
),
explode_blocks AS (
    SELECT
        survey_id,
        b.key AS block_id,
        b.value AS block_value
    FROM
        unnest_result,
        LATERAL FLATTEN(
            INPUT => blocks,
            OUTER => TRUE
        ) b
),
unnest_blocks_explode_block_element AS (
    SELECT
        survey_id,
        block_id,
        BLOCK_VALUE:Description AS block_description,
        BLOCK_VALUE:ID AS block_key,
        be.value AS block_element
    FROM
        explode_blocks,
        LATERAL FLATTEN(
            INPUT => BLOCK_VALUE:BlockElements,
            OUTER => TRUE
        ) be
),
unnest_block_element AS (
    SELECT
        survey_id,
        block_id,
        block_description,
        block_element:Type AS block_element_type,
        CASE
            WHEN block_element:Type = NULL THEN 'QID_null'
            ELSE block_element:QuestionID
        END AS question_id,
        ROW_NUMBER() OVER (
            PARTITION BY survey_id,
            block_id
            ORDER BY
                survey_id,
                block_id
        ) AS question_number
    FROM
        unnest_blocks_explode_block_element
),
final_block AS (
    SELECT
        survey_id,
        block_id,
        block_description,
        question_id,
        block_element_type,
        question_number
    FROM
        unnest_block_element
    WHERE
        NOT question_id = NULL
),
flow_blocks_filtered AS (
    SELECT
        bt.survey_id,
        bt.block_id,
        ft.block_number,
        bt.question_id,
        bt.question_number,
        bt.block_description
    FROM
        final_block AS bt
        INNER JOIN final_flow AS ft ON ft.survey_id = bt.survey_id
        AND ft.block_id = bt.block_id
    ORDER BY
        bt.survey_id,
        ft.block_number
),
questions_table_flow_filtered AS (
    SELECT
        qt.survey_id,
        ff.block_id,
        ff.block_description,
        ff.block_number,
        qt.question_id,
        qt.scoring_id,
        qt.questions_key,
        CASE
            WHEN qt.question_type = 'TE'
            AND qt.selector <> 'FORM' THEN NULL
            ELSE qt.question_choice_id
        END AS question_choice_id,
        qt.question_answer_id,
        qt.answer_key,
        ff.question_number,
        qt.question_name,
        qt.question_type,
        qt.selector,
        qt.sub_selector,
        qt.question_text,
        qt.image_description,
        CASE
            WHEN qt.question_type = 'TE'
            AND qt.selector <> 'FORM' THEN NULL
            ELSE qt.question_choices
        END AS question_choices,
        qt.question_answers,
        qt.groups,
        qt.regions,
        qt.add_ques_key,
        qt.sbs_question_text,
        qt.sbs_question_type,
        qt.sbs_question_selector,
        qt.sbs_question_sub_selector,
        qt.sbs_answer_key,
        qt.sbs_answer,
        qt.column_labels_display,
        qt.labels_display,
        qt.score_id,
        qt.items,
        NULL::INT AS srq_id,
        qt.analyze_choice,
        qt.data_export_struct,
        ROW_NUMBER() OVER (
            PARTITION BY qt.survey_id,
            qt.question_id
            ORDER BY
                CASE
                    WHEN qt.question_type = 'TE'
                    AND qt.selector <> 'FORM' THEN 0
                    ELSE 1
                END
        ) AS row_num_te,
        qt.variable_naming,
        qt.recode_values
    FROM
        drop_dd_filter_columns AS qt
        INNER JOIN flow_blocks_filtered AS ff ON ff.survey_id = qt.survey_id
        AND ff.question_id = qt.question_id
),
te_filter AS (
    SELECT
        survey_id,
        block_id,
        block_description,
        block_number,
        question_id,
        scoring_id::STRING AS scoring_id,
        questions_key,
        question_choice_id,
        question_answer_id,
        answer_key,
        question_number,
        question_name,
        question_type,
        selector,
        sub_selector,
        question_text,
        image_description,
        question_choices,
        question_answers,
        groups,
        regions,
        add_ques_key,
        sbs_question_text,
        sbs_question_type,
        sbs_question_selector,
        sbs_question_sub_selector,
        sbs_answer_key,
        sbs_answer,
        column_labels_display,
        labels_display,
        score_id,
        items,
        srq_id,
        analyze_choice,
        data_export_struct,
        variable_naming,
        recode_values
    FROM
        questions_table_flow_filtered
    WHERE
        (
            question_type = 'TE'
            AND selector <> 'FORM'
            AND row_num_te = 1
        )
        OR NOT (
            question_type = 'TE'
            AND selector <> 'FORM'
        )
),
embedded_fields AS (
    SELECT
        survey_id,
        'NULL' AS block_id,
        'NULL' AS block_description,
        0 AS block_number,
        'EF' AS question_id,
        'NULL' AS scoring_id,
        embedded_data AS questions_key,
        'NULL' AS question_choice_id,
        'NULL' AS question_answer_id,
        'NULL' AS answer_key,
        0 AS question_number,
        'NULL' AS question_name,
        'NULL' AS question_type,
        'NULL' AS selector,
        'NULL' AS sub_selector,
        'NULL' AS question_text,
        'NULL' AS image_description,
        'NULL' AS question_choices,
        'NULL' AS question_answers,
        'NULL' AS groups,
        'NULL' AS regions,
        'NULL' AS add_ques_key,
        'NULL' AS sbs_question_text,
        'NULL' AS sbs_question_type,
        'NULL' AS sbs_question_selector,
        'NULL' AS sbs_question_sub_selector,
        'NULL' AS sbs_answer_key,
        'NULL' AS sbs_answer,
        'NULL' AS column_labels_display,
        'NULL' AS labels_display,
        'NULL' AS score_id,
        'NULL' AS items,
        'NULL' AS srq_id,
        NULL AS analyze_choice,
        'NULL' AS data_export_struct,
        'NULL' AS variable_naming,
        'NULL' AS recode_values
    FROM
        embedded_data_logic
),
explode_score AS (
    SELECT
        survey_id,
        'SC' AS question_id,
        sc.value AS score
    FROM
        unnest_result,
        LATERAL FLATTEN(
            INPUT => SCORE:ScoringCategories,
            OUTER => TRUE
        ) sc
),
unnest_score AS (
    SELECT
        survey_id,
        'NULL' AS block_id,
        'NULL' AS block_description,
        0 AS block_number,
        'SC' AS question_id,
        SCORE:Name AS scoring_id,
        SCORE:ID AS questions_key,
        'NULL' AS question_choice_id,
        'NULL' AS question_answer_id,
        'NULL' AS answer_key,
        0 AS question_number,
        'NULL' AS question_name,
        'NULL' AS question_type,
        'NULL' AS selector,
        'NULL' AS sub_selector,
        'NULL' AS question_text,
        'NULL' AS image_description,
        'NULL' AS question_choices,
        'NULL' AS question_answers,
        'NULL' AS groups,
        'NULL' AS regions,
        'NULL' AS add_ques_key,
        'NULL' AS sbs_question_text,
        'NULL' AS sbs_question_type,
        'NULL' AS sbs_question_selector,
        'NULL' AS sbs_question_sub_selector,
        'NULL' AS sbs_answer_key,
        'NULL' AS sbs_answer,
        'NULL' AS column_labels_display,
        'NULL' AS labels_display,
        'NULL' AS score_id,
        'NULL' AS items,
        'NULL' AS srq_id,
        NULL AS analyze_choice,
        'NULL' AS data_export_struct,
        'NULL' AS variable_naming,
        'NULL' AS recode_values
    FROM
        explode_score
),
unnesting_properties
/* --------------------- */
AS (
    SELECT
        survey_id,
        p.key AS questions_key,
        p.value AS values1
    FROM
        GENSLER.RAW.QUALTRICS_RESPONSE_SCHEMA,
        LATERAL FLATTEN(
            INPUT => parsed_json:result:properties:"values":properties,
            OUTER => TRUE
        ) p
),
extracting_variable_names AS (
    SELECT
        survey_id,
        questions_key,
        VALUES1:description AS variable_names
    FROM
        unnesting_properties
    WHERE
        VALUES1:dataType = 'embeddedData'
)
,
filtering_sc
/* Temporary placeholder CTE to maintain query structure */
/* extracting_variable_names AS ( */
/*   SELECT */
/*     'temp_survey_id' as survey_id, */
/*     'temp_questions_key' as questions_key, */
/*     'temp_variable_name' as variable_names */
/*   WHERE 1=0  -- Returns no rows, just maintains structure */
/* ), */
AS (
    SELECT
        a.survey_id,
        'NULL' AS block_id,
        'NULL' AS block_description,
        'NULL' AS block_number,
        a.question_id,
        a.questions_key AS scoring_id,
        variable_names AS questions_key,
        'NULL' AS question_choice_id,
        'NULL' AS question_answer_id,
        'NULL' AS answer_key,
        'NULL' AS question_number,
        'NULL' AS question_name,
        'NULL' AS question_type,
        'NULL' AS selector,
        'NULL' AS sub_selector,
        'NULL' AS question_text,
        'NULL' AS image_description,
        'NULL' AS question_choices,
        'NULL' AS question_answers,
        'NULL' AS groups,
        'NULL' AS regions,
        'NULL' AS add_ques_key,
        'NULL' AS sbs_question_text,
        'NULL' AS sbs_question_type,
        'NULL' AS sbs_question_selector,
        'NULL' AS sbs_question_sub_selector,
        'NULL' AS sbs_answer_key,
        'NULL' AS sbs_answer,
        'NULL' AS column_labels_display,
        'NULL' AS labels_display,
        'NULL' AS score_id,
        'NULL' AS items,
        'NULL' AS srq_id,
        NULL AS analyze_choice,
        'NULL' AS data_export_struct,
        'NULL' AS variable_naming,
        'NULL' AS recode_values
    FROM
        unnest_score AS a
        INNER JOIN extracting_variable_names AS b ON a.survey_id = b.survey_id
        AND a.questions_key = b.questions_key
) ,
filtering_rm_var AS (
    SELECT
        survey_id,
        'NULL' AS block_id,
        'NULL' AS block_description,
        'NULL' AS block_number,
        'RM/VAR' AS question_id,
        questions_key AS scoring_id,
        variable_names AS questions_key,
        'NULL' AS question_choice_id,
        'NULL' AS question_answer_id,
        'NULL' AS answer_key,
        'NULL' AS question_number,
        'NULL' AS question_name,
        'NULL' AS question_type,
        'NULL' AS selector,
        'NULL' AS sub_selector,
        'NULL' AS question_text,
        'NULL' AS image_description,
        'NULL' AS question_choices,
        'NULL' AS question_answers,
        'NULL' AS groups,
        'NULL' AS regions,
        'NULL' AS add_ques_key,
        'NULL' AS sbs_question_text,
        'NULL' AS sbs_question_type,
        'NULL' AS sbs_question_selector,
        'NULL' AS sbs_question_sub_selector,
        'NULL' AS sbs_answer_key,
        'NULL' AS sbs_answer,
        'NULL' AS column_labels_display,
        'NULL' AS labels_display,
        'NULL' AS score_id,
        'NULL' AS items,
        'NULL' AS srq_id,
        NULL AS analyze_choice,
        'NULL' AS data_export_struct,
        'NULL' AS variable_naming,
        'NULL' AS recode_values
    FROM
        extracting_variable_names
    WHERE
        NOT questions_key IN (
            SELECT
                DISTINCT questions_key
            FROM
                filtering_sc
        )
) ,
union_all_question_id AS (

    /* =========================
       te_filter
       ========================= */
    SELECT
        CAST(survey_id AS STRING)                                   AS survey_id,
        CAST(block_id AS STRING)                                    AS block_id,
        CAST(block_description AS STRING)                           AS block_description,
        CAST(block_number AS INT)                    AS block_number,
        CAST(question_id AS STRING)                                 AS question_id,
        CAST(scoring_id AS STRING)                                  AS scoring_id,
        CAST(questions_key AS STRING)                               AS questions_key,
        CAST(question_choice_id AS STRING)                          AS question_choice_id,
        CAST(question_answer_id AS STRING)                          AS question_answer_id,
        CAST(answer_key AS STRING)                                  AS answer_key,
        CAST(question_number AS INT)                 AS question_number,
        CAST(question_name AS STRING)                               AS question_name,
        CAST(question_type AS STRING)                               AS question_type,
        CAST(selector AS STRING)                                    AS selector,
        CAST(sub_selector AS STRING)                                AS sub_selector,
        CAST(question_text AS STRING)                               AS question_text,
        CAST(image_description AS STRING)                           AS image_description,
        CAST(question_choices AS STRING)                            AS question_choices,
        CAST(question_answers AS STRING)                            AS question_answers,
        CAST(groups AS VARIANT)                                     AS groups,
        CAST(regions AS VARIANT)                                    AS regions,
        CAST(add_ques_key AS STRING)                                AS add_ques_key,
        CAST(sbs_question_text AS STRING)                           AS sbs_question_text,
        CAST(sbs_question_type AS STRING)                           AS sbs_question_type,
        CAST(sbs_question_selector AS STRING)                       AS sbs_question_selector,
        CAST(sbs_question_sub_selector AS STRING)                   AS sbs_question_sub_selector,
        CAST(sbs_answer_key AS STRING)                              AS sbs_answer_key,
        CAST(sbs_answer AS STRING)                                  AS sbs_answer,
        CAST(column_labels_display AS STRING)                       AS column_labels_display,
        CAST(labels_display AS STRING)                              AS labels_display,
        CAST(score_id AS STRING)                                    AS score_id,
        CAST(items AS STRING)                                       AS items,
        TRY_TO_NUMBER(NULLIF(srq_id, 'NULL'))                           AS srq_id,
        CAST(NULLIF(analyze_choice,'NULL') AS BOOLEAN)              AS analyze_choice,
        CAST(data_export_struct AS VARIANT)                         AS data_export_struct,
        CAST(variable_naming AS VARIANT)                            AS variable_naming,
        CAST(recode_values AS VARIANT)                              AS recode_values
    FROM te_filter

    UNION ALL

    SELECT
        CAST(survey_id AS STRING),
        CAST(block_id AS STRING),
        CAST(block_description AS STRING),
        CAST(block_number AS INT)   ,
        CAST(question_id AS STRING),
        CAST(scoring_id AS STRING),
        CAST(questions_key AS STRING),
        CAST(question_choice_id AS STRING),
        CAST(question_answer_id AS STRING),
        CAST(answer_key AS STRING),
        CAST(question_number AS INT)  ,
        CAST(question_name AS STRING),
        CAST(question_type AS STRING),
        CAST(selector AS STRING),
        CAST(sub_selector AS STRING),
        CAST(question_text AS STRING),
        CAST(image_description AS STRING),
        CAST(question_choices AS STRING),
        CAST(question_answers AS STRING),
        CAST(groups AS VARIANT),
        CAST(regions AS VARIANT),
        CAST(add_ques_key AS STRING),
        CAST(sbs_question_text AS STRING),
        CAST(sbs_question_type AS STRING),
        CAST(sbs_question_selector AS STRING),
        CAST(sbs_question_sub_selector AS STRING),
        CAST(sbs_answer_key AS STRING),
        CAST(sbs_answer AS STRING),
        CAST(column_labels_display AS STRING),
        CAST(labels_display AS STRING),
        CAST(score_id AS STRING),
        CAST(items AS STRING),
        TRY_TO_NUMBER(NULLIF(srq_id, 'NULL')) ,
        CAST(NULLIF(analyze_choice,'NULL') AS BOOLEAN),
        CAST(data_export_struct AS VARIANT),
        CAST(variable_naming AS VARIANT),
        CAST(recode_values AS VARIANT)
    FROM embedded_fields

    UNION ALL

    SELECT
        CAST(survey_id AS STRING),
        CAST(block_id AS STRING),
        CAST(block_description AS STRING),
        CAST(block_number AS INT)   ,
        CAST(question_id AS STRING),
        CAST(scoring_id AS STRING),
        CAST(questions_key AS STRING),
        CAST(question_choice_id AS STRING),
        CAST(question_answer_id AS STRING),
        CAST(answer_key AS STRING),
       CAST(question_number AS INT)  ,
        CAST(question_name AS STRING),
        CAST(question_type AS STRING),
        CAST(selector AS STRING),
        CAST(sub_selector AS STRING),
        CAST(question_text AS STRING),
        CAST(image_description AS STRING),
        CAST(question_choices AS STRING),
        CAST(question_answers AS STRING),
        CAST(groups AS VARIANT),
        CAST(regions AS VARIANT),
        CAST(add_ques_key AS STRING),
        CAST(sbs_question_text AS STRING),
        CAST(sbs_question_type AS STRING),
        CAST(sbs_question_selector AS STRING),
        CAST(sbs_question_sub_selector AS STRING),
        CAST(sbs_answer_key AS STRING),
        CAST(sbs_answer AS STRING),
        CAST(column_labels_display AS STRING),
        CAST(labels_display AS STRING),
        CAST(score_id AS STRING),
        CAST(items AS STRING),
        TRY_TO_NUMBER(NULLIF(srq_id, 'NULL')) ,
        CAST(NULLIF(analyze_choice,'NULL') AS BOOLEAN),
        CAST(data_export_struct AS VARIANT),
        CAST(variable_naming AS VARIANT),
        CAST(recode_values AS VARIANT)
    FROM filtering_sc

    UNION ALL

    SELECT
        CAST(survey_id AS STRING),
        CAST(block_id AS STRING),
        CAST(block_description AS STRING),
        CAST(block_number AS INT)   ,
        CAST(question_id AS STRING),
        CAST(scoring_id AS STRING),
        CAST(questions_key AS STRING),
        CAST(question_choice_id AS STRING),
        CAST(question_answer_id AS STRING),
        CAST(answer_key AS STRING),
        CAST(question_number AS INT)  ,
        CAST(question_name AS STRING),
        CAST(question_type AS STRING),
        CAST(selector AS STRING),
        CAST(sub_selector AS STRING),
        CAST(question_text AS STRING),
        CAST(image_description AS STRING),
        CAST(question_choices AS STRING),
        CAST(question_answers AS STRING),
        CAST(groups AS VARIANT),
        CAST(regions AS VARIANT),
        CAST(add_ques_key AS STRING),
        CAST(sbs_question_text AS STRING),
        CAST(sbs_question_type AS STRING),
        CAST(sbs_question_selector AS STRING),
        CAST(sbs_question_sub_selector AS STRING),
        CAST(sbs_answer_key AS STRING),
        CAST(sbs_answer AS STRING),
        CAST(column_labels_display AS STRING),
        CAST(labels_display AS STRING),
        CAST(score_id AS STRING),
        CAST(items AS STRING),
        TRY_TO_NUMBER(NULLIF(srq_id, 'NULL'))  ,
        CAST(NULLIF(analyze_choice,'NULL') AS BOOLEAN),
        CAST(data_export_struct AS VARIANT),
        CAST(variable_naming AS VARIANT),
        CAST(recode_values AS VARIANT)
    FROM filtering_rm_var
)



,
html_tag_replace AS (
    SELECT
        survey_id,
        CASE
            WHEN LOWER(block_id) = 'null' THEN NULL
            ELSE block_id
        END AS block_id,
        CASE
            WHEN LOWER(block_description) = 'null' THEN NULL
            ELSE block_description
        END AS block_description,
        block_number,
        CASE
            WHEN question_id = NULL THEN 'QID_null'
            ELSE question_id
        END AS question_id,
        question_number,
        CASE
            WHEN LOWER(question_name) = 'null' THEN NULL
            ELSE question_name
        END AS question_name,
        CASE
            WHEN LOWER(question_type) = 'null' THEN NULL
            ELSE question_type
        END AS question_type,
        CASE
            WHEN LOWER(selector) = 'null' THEN NULL
            ELSE selector
        END AS selector,
        CASE
            WHEN LOWER(sub_selector) = 'null' THEN NULL
            ELSE sub_selector
        END AS sub_selector,
        CASE
            WHEN LOWER(question_text) = 'null' THEN NULL
            ELSE question_text
        END AS question_text,
        CASE
            WHEN LOWER(image_description) = 'null' THEN NULL
            ELSE image_description
        END AS image_description,
        CASE
            WHEN LOWER(question_choices) = 'null' THEN NULL
            ELSE question_choices
        END AS choices,
        CASE
            WHEN LOWER(question_answers) = 'null' THEN NULL
            ELSE question_answers
        END AS sub_questions,
        CASE
            WHEN LOWER(groups) = 'null' THEN NULL
            ELSE groups
        END AS groups,
        CASE
            WHEN LOWER(regions) = 'null' THEN NULL
            ELSE regions
        END AS regions,
        add_ques_key AS sbs_question_number,
        CASE
            WHEN LOWER(sbs_question_text) = 'null' THEN NULL
            ELSE sbs_question_text
        END AS sbs_question_text,
        CASE
            WHEN LOWER(sbs_question_type) = 'null' THEN NULL
            ELSE sbs_question_type
        END AS sbs_question_type,
        CASE
            WHEN LOWER(sbs_question_selector) = 'null' THEN NULL
            ELSE sbs_question_selector
        END AS sbs_question_selector,
        CASE
            WHEN LOWER(sbs_question_sub_selector) = 'null' THEN NULL
            ELSE sbs_question_sub_selector
        END AS sbs_question_sub_selector,
        CASE
            WHEN LOWER(sbs_answer_key) = 'null' THEN NULL
            ELSE sbs_answer_key
        END AS sbs_choice_key,
        CASE
            WHEN LOWER(sbs_answer) = 'null' THEN NULL
            ELSE sbs_answer
        END AS sbs_choices,
        CASE
            WHEN questions_key = NULL THEN question_id
            ELSE questions_key
        END AS questions_key,
        CASE
            WHEN question_answer_id <> answer_key THEN question_answer_id
            ELSE answer_key
        END AS sub_questions_key,
        REPLACE(question_answer_id, 'x', '') AS sub_questions_recode,
        REPLACE(question_choice_id, 'x', '') AS choice_recode,
        ROW_NUMBER() OVER (
            ORDER BY
                survey_id
        ) AS row_id,
        NULLIF(srq_id, 'NULL') AS srq_id,
        CASE
            WHEN NOT column_labels_display = NULL
            AND labels_display = '' THEN column_labels_display
            WHEN NOT labels_display = NULL
            AND column_labels_display = '' THEN labels_display
        END AS choice_label,
        NULLIF(score_id, 'NULL') AS score_id,
        NULLIF(scoring_id, 'NULL') AS scoring_id,
        CASE
            WHEN LOWER(items) = 'null' THEN NULL
            ELSE items
        END AS items,
        CASE
            WHEN LOWER(analyze_choice) = 'null' THEN NULL
            ELSE analyze_choice
        END AS analyze_choice,
        CASE
            WHEN LOWER(data_export_struct) = 'null' THEN NULL
            ELSE data_export_struct
        END AS data_export_struct,
        CASE
            WHEN LOWER(variable_naming) = 'null' THEN NULL
            ELSE variable_naming
        END AS variable_naming,
        CASE
            WHEN LOWER(recode_values) = 'null' THEN NULL
            ELSE REPLACE(recode_values, 'x', '')
        END AS recode_values
    FROM
        union_all_question_id
    ORDER BY
        survey_id,
        block_number,
        question_number,
        choice_recode,
        sbs_question_number
)
SELECT
    *
FROM
    html_tag_replace