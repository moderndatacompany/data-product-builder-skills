-- Raw layer model for Qualtrics survey definitions
-- Ingests and parses complete survey structure including questions, blocks, flow logic, and scoring configurations
MODEL (
  name GENSLER.RAW.QUALTRICS_DEFINITION,
  kind incremental_by_partition,
  partitioned_by ARRAY(SURVEY_ID),
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, PARSED_JSON),
  grains [SURVEY_ID],
  description 'Raw layer model ingesting complete Qualtrics survey definitions with parsed JSON structures containing questions, blocks, flow logic, scoring configurations, and reference lists for survey metadata enrichment',
  tags ('raw', 'survey', 'definition', 'ingestion', 'source:qualtrics'),
  terms ('survey_definition', 'metadata', 'raw'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    parsed_json = 'Structured JSON object containing survey questions, blocks, flow, scoring, and reference lists'
  ),
  column_tags (
    survey_id = ('identifier', 'primary_key', 'survey'),
    parsed_json = ('json', 'structured', 'parsed')
  ),
  column_terms (
    survey_id = ('survey_id', 'identifier'),
    parsed_json = ('parsed_json', 'structure')
  )
);


SELECT
  "survey_id" AS SURVEY_ID,
  PARSE_JSON("payload") AS PARSED_JSON
FROM VULCAN.QUALTRICS.QUALTRICS_DEFINITION;
