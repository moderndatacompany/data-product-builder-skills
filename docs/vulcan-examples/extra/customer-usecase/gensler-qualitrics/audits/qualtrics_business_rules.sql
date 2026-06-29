AUDIT (
  name survey_definition_completeness,
  standalone true,
  blocking false
);

-- Validate that surveys with responses have complete question definitions
WITH surveys_with_responses AS (
  SELECT DISTINCT SURVEY_ID
  FROM GENSLER.FINAL.QUALTRICS_RESPONSE_FINAL_RESPONSE
),
incomplete_surveys AS (
  SELECT 
    d.SURVEY_ID,
    d.PARSED_JSON:result.SurveyName::STRING AS SURVEY_NAME,
    COUNT(DISTINCT qf.QUESTION_ID) AS QUESTIONS_COUNT,
    COUNT(DISTINCT r.QUESTION_ID) AS RESPONSE_QUESTIONS_COUNT
  FROM GENSLER.RAW.QUALTRICS_DEFINITION d
  JOIN surveys_with_responses sr ON d.SURVEY_ID = sr.SURVEY_ID
  LEFT JOIN GENSLER.RAW.QUALTRICS_QUESTIONS_FLATTENING_PART_001 qf ON d.SURVEY_ID = qf.SURVEY_ID
  LEFT JOIN GENSLER.FINAL.QUALTRICS_RESPONSE_FINAL_RESPONSE r ON d.SURVEY_ID = r.SURVEY_ID
  GROUP BY d.SURVEY_ID, d.PARSED_JSON:result.SurveyName::STRING
  HAVING COUNT(DISTINCT qf.QUESTION_ID) = 0
)
SELECT 
  SURVEY_ID,
  SURVEY_NAME,
  QUESTIONS_COUNT,
  RESPONSE_QUESTIONS_COUNT,
  'Survey has responses but no question definitions' AS ISSUE_TYPE
FROM incomplete_surveys;

AUDIT (
  name response_question_referential_integrity,
  standalone true,
  blocking false
);

-- Validate that all responses reference valid questions from the definition
WITH response_question_refs AS (
  SELECT DISTINCT
    r.SURVEY_ID,
    r.RESPONSE_ID,
    r.QUESTION_ID,
    r.QUESTIONS_KEY,
    qf.QUESTION_ID AS DEF_QUESTION_ID
  FROM GENSLER.FINAL.QUALTRICS_RESPONSE_FINAL_RESPONSE r
  LEFT JOIN GENSLER.RAW.QUALTRICS_QUESTIONS_FLATTENING_PART_001 qf 
    ON r.SURVEY_ID = qf.SURVEY_ID 
    AND r.QUESTION_ID = qf.QUESTION_ID
  WHERE qf.QUESTION_ID IS NULL
)
SELECT 
  SURVEY_ID,
  RESPONSE_ID,
  QUESTION_ID,
  QUESTIONS_KEY,
  'Response references question not found in survey definition' AS ISSUE_TYPE
FROM response_question_refs
LIMIT 100;

AUDIT (
  name duplicate_questions_in_definition,
  standalone true,
  blocking false
);

-- Detect duplicate question IDs within the same survey
WITH question_counts AS (
  SELECT 
    SURVEY_ID,
    QUESTION_ID,
    QUESTION_TEXT,
    COUNT(*) AS OCCURRENCE_COUNT
  FROM GENSLER.RAW.QUALTRICS_QUESTIONS_FLATTENING_PART_001
  GROUP BY SURVEY_ID, QUESTION_ID, QUESTION_TEXT
  HAVING COUNT(*) > 1
)
SELECT 
  SURVEY_ID,
  QUESTION_ID,
  QUESTION_TEXT,
  OCCURRENCE_COUNT,
  'Duplicate question ID found in survey definition' AS ISSUE_TYPE
FROM question_counts;

AUDIT (
  name survey_id_consistency_across_raw_models,
  standalone true,
  blocking false
);

SELECT SURVEY_ID
FROM (
    SELECT SURVEY_ID, 'A' AS SRC FROM GENSLER.RAW.QUALTRICS_DEFINITION
    UNION ALL
    SELECT SURVEY_ID, 'B' FROM GENSLER.RAW.QUALTRICS_RESPONSE_SCHEMA
    UNION ALL
    SELECT SURVEY_ID, 'C' FROM GENSLER.RAW.QUALTRICS_RESPONSE
) s
GROUP BY SURVEY_ID
HAVING COUNT(DISTINCT SRC) < 3;
