-- Respondent dimension table
-- Provides unique respondent records with survey context, response status classification, and metadata enrichment
MODEL (
  name GENSLER.ANALYTICS.QUALTRICS_RESPONDENTS_DIMENSION,
  kind VIEW,
  grains [SURVEY_ID, RESPONSE_ID],
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, RESPONSE_ID, RESPONSE_TYPE_STATUS, RESPONSE_STATUS, SURVEY_NAME, SURVEY_TYPE),
  description 'Respondent dimension table providing unique respondent records enriched with survey context, simplified response status classification, and comprehensive metadata for analytical segmentation and respondent-level reporting',
  tags ('dimension', 'respondent', 'analytical', 'clean', 'production'),
  terms ('respondent_dimension', 'respondent_catalog', 'respondent'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey',
    response_id = 'Unique identifier for each survey response submission',
    response_type = 'Human-readable response status label (e.g., IP Address, Survey Preview)',
    response_type_status = 'Numeric status code indicating response type (0=IP Address, 1=Preview, etc.)',
    survey_name = 'Descriptive name or title of the survey',
    survey_description = 'Detailed description or purpose of the survey',
    owner_id = 'Qualtrics user ID of the survey owner or creator',
    organization_id = 'Qualtrics brand or organization ID that owns the survey',
    response_status = 'Simplified response status classification: Complete, Preview, or Other',
    survey_type = 'Survey type from SharePoint metadata (e.g., Experience, Pulse, etc.)',
    survey_status = 'Survey status from SharePoint metadata (e.g., Active, Closed, Cancelled)'
  ),
  column_tags (
    survey_id = ('identifier', 'partition_key', 'dimension', 'foreign_key'),
    response_id = ('identifier', 'primary_key', 'grain'),
    response_type = ('classification', 'status', 'display_value'),
    response_type_status = ('classification', 'status_code', 'numeric'),
    survey_name = ('metadata', 'descriptive', 'display'),
    survey_description = ('metadata', 'descriptive', 'content'),
    owner_id = ('identifier', 'reference', 'foreign_key'),
    organization_id = ('identifier', 'reference', 'foreign_key'),
    response_status = ('classification', 'derived', 'simplified'),
    survey_type = ('classification', 'business_category'),
    survey_status = ('classification', 'business_state')
  ),
  column_terms (
    survey_id = ('survey_id', 'survey'),
    response_id = ('response_id', 'respondent'),
    response_type = ('status_label', 'type'),
    response_type_status = ('status_code', 'status'),
    survey_name = ('name', 'title'),
    response_status = ('simplified_status', 'classification')
  )
);

SELECT DISTINCT
    rt.survey_id,
    rt.response_id,
    rt.response_type,
    rt.response_type_status,
    s.survey_name,
    s.survey_description,
    s.owner_id,
    s.organization_id,
    CASE 
        WHEN rt.response_type_status IN (0, 4, 8, 12, 16) THEN 'Complete'
        WHEN rt.response_type_status IN (1, 9, 17) THEN 'Preview'
        ELSE 'Other'
    END AS response_status,
    ss.surveytype AS survey_type,
    ss.status AS survey_status
FROM GENSLER.RAW.QUALTRICS_RESPONSE_INTERMEDIATE_TABLE rt
FULL OUTER JOIN GENSLER.RAW.SHAREPOINT_METADATA_SEED ss
    ON rt.survey_id = ss.surveyid
FULL OUTER JOIN GENSLER.FINAL.QUALTRICS_SURVEY_LIST s
    ON rt.survey_id = s.survey_id
