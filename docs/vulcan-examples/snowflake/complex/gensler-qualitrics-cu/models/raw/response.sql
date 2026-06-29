-- Raw layer model for Qualtrics survey response data
-- Ingests survey responses with both raw values and human-readable labels for each answer
MODEL (
  name GENSLER.RAW.QUALTRICS_RESPONSE,
  kind incremental_by_partition,
  partitioned_by ARRAY(survey_id),
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, RESPONSE_ID, VALUES_PARSED, LABELS_PARSED),
  grains [SURVEY_ID, RESPONSE_ID],
  description 'Raw layer model ingesting Qualtrics survey response data with both coded values and human-readable labels, including displayed field metadata for complete response capture and downstream transformation',
  tags ('raw', 'response', 'fact', 'transactional', 'source:qualtrics'),
  terms ('survey_response', 'fact', 'raw'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    response_id = 'Unique identifier for each survey response submission',
    values_parsed = 'Parsed JSON map of question IDs to response values (coded values)',
    labels_parsed = 'Parsed JSON map of question IDs to response labels (human-readable text)',
    displayed_fields = 'Raw string of displayed field names from Qualtrics export',
    displayed_values = 'Raw string of displayed values from Qualtrics export'
  ),
  column_tags (
    survey_id = ('identifier', 'foreign_key', 'survey'),
    response_id = ('identifier', 'primary_key', 'response'),
    values_parsed = ('json', 'map', 'response_data'),
    labels_parsed = ('json', 'map', 'response_data'),
    displayed_fields = ('raw', 'metadata'),
    displayed_values = ('raw', 'metadata')
  ),
  column_terms (
    survey_id = ('survey_id', 'identifier'),
    response_id = ('response_id', 'identifier'),
    values_parsed = ('values', 'coded_values'),
    labels_parsed = ('labels', 'display_values'),
    displayed_fields = ('field_names', 'fields'),
    displayed_values = ('field_values', 'values')
  )
);

SELECT
  "surveyId" AS SURVEY_ID,
  "responseId" AS RESPONSE_ID,
  PARSE_JSON("values") AS VALUES_PARSED, 
  PARSE_JSON("labels") AS LABELS_PARSED, 
  "displayedFields" AS DISPLAYED_FIELDS,
  "displayedValues" AS DISPLAYED_VALUES
FROM VULCAN.QUALTRICS.QUALTRICS_RESPONSES_RAW;