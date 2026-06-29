-- Raw layer model for Qualtrics response schema definitions
-- Captures metadata about response data structure including field names, data types, and embedded data configurations
MODEL (
  name GENSLER.RAW.QUALTRICS_RESPONSE_SCHEMA,
  kind incremental_by_partition,
  partitioned_by ARRAY(SURVEY_ID),
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, PARSED_JSON),
  grains [SURVEY_ID],
  description 'Raw layer model capturing Qualtrics response schema metadata with parsed JSON structures defining field names, data types, descriptions, and embedded data configurations for response data validation and transformation',
  tags ('raw', 'schema', 'response', 'metadata', 'source:qualtrics'),
  terms ('response_schema', 'metadata', 'raw'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    parsed_json = 'Structured JSON object containing response field definitions, descriptions, and data types'
  ),
  column_tags (
    survey_id = ('identifier', 'primary_key', 'survey'),
    parsed_json = ('json', 'structured', 'schema')
  ),
  column_terms (
    survey_id = ('survey_id', 'identifier'),
    parsed_json = ('definition', 'structure')
  )
);

SELECT
  "survey_id" AS SURVEY_ID,
  PARSE_JSON("payload") AS PARSED_JSON
FROM VULCAN.QUALTRICS.QUALTRICS_RESPONSE_SCHEMA;