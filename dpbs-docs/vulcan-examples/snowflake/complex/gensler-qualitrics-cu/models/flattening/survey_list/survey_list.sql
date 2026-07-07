-- Survey catalog dimension table
-- Comprehensive survey metadata including survey details, language settings, ownership, activity status, and aggregated response statistics
MODEL (
  name GENSLER.FINAL.QUALTRICS_SURVEY_LIST,
  kind FULL,
  grains [SURVEY_ID],
  owner 'shreyasikarwartmdcio',
  profiles (SURVEY_ID, SURVEY_NAME, CREATION_DATE, LAST_MODIFIED_DATE, IS_ACTIVE, TOTAL_RESPONSE_COUNT, LIVE_RESPONSE_COUNT, SURVEY_STATUS_CATEGORY),
  description 'Survey catalog dimension providing comprehensive survey metadata including ownership, language settings, activity status, aggregated response statistics, data quality metrics, and business health indicators for enterprise survey management and analytics',
  tags ('dimension', 'catalog', 'survey', 'metadata', 'aggregate_stats', 'data_quality', 'validated'),
  terms ('survey_catalog', 'metadata', 'survey_list'),
  column_descriptions (
    survey_id = 'Unique identifier for the Qualtrics survey. Format: SV_XXXXXXXXXXXX. Required field that serves as the primary key. Source: Extracted from definition file name.',
    survey_name = 'Descriptive name or title of the survey. User-defined string that provides human-readable identification. May contain special characters. Example: "Q1 2024 Employee Satisfaction Survey". Source: SurveyName field from definition.',
    survey_description = 'Detailed description or purpose of the survey. Optional text field that can be multi-line. Provides context about survey objectives and target audience. Source: SurveyDescription field from definition.',
    available_languages = 'Array of language codes available for the survey (e.g., [EN, ES, FR]). ISO 639-1 language codes. Indicates all languages in which the survey can be taken. Must include survey_language. Source: Keys from SurveyOptions.AvailableLanguages.',
    survey_language = 'Default or primary language code for the survey. ISO 639-1 format (e.g., EN, ES, FR). Required field. Must be present in available_languages array. Source: SurveyOptions.SurveyLanguage.',
    owner_id = 'Qualtrics user ID of the survey owner or creator. Format: UR_XXXXXXXXXXXX. Required field. Used for access control and audit purposes. References qualtrics_users dimension. Source: OwnerID field.',
    organization_id = 'Qualtrics brand or organization ID that owns the survey. Format: Brand/Org identifier. Required field. Used for multi-tenant segregation and reporting. References qualtrics_organizations dimension. Source: BrandID field.',
    creation_date = 'Timestamp when the survey was originally created in Qualtrics platform. Required field. Immutable. Always <= last_modified_date and last_accessed_date. Source: SurveyOptions.SurveyCreationDate.',
    last_modified_date = 'Timestamp of the most recent modification to survey structure or content. Includes changes to questions, flow, or settings. Always >= creation_date. Used for change tracking. Source: LastModified field.',
    last_accessed_date = 'Timestamp when the survey was last accessed or viewed in Qualtrics. Includes read-only access. Always >= creation_date. Used for usage analytics. Source: LastAccessed field.',
    is_active = 'Boolean flag indicating if survey is currently active and accepting responses. TRUE=Active (accepting responses), FALSE=Inactive (closed). Required field. Controlled by SurveyStatus. Source: Derived from SurveyStatus (Active/Inactive).',
    earliest_response_date = 'Timestamp of the earliest response received for this survey. NULL if no responses exist. Derived from MIN(startDate) across all response types. Must be <= latest_response_date. Source: Aggregated from response data.',
    latest_response_date = 'Timestamp of the most recent response received for this survey. NULL if no responses exist. Derived from MAX(endDate) across all response types. Must be >= earliest_response_date. Source: Aggregated from response data.',
    preview_response_count = 'Count of preview responses (status codes 1, 9, 17). Preview responses are typically internal testing or demo responses. Non-negative integer. Contributes to total_response_count. Source: Calculated from response status field.',
    imported_response_count = 'Count of imported responses from external sources (status codes 4, 12). Responses loaded from other systems or bulk imports. Non-negative integer. Contributes to total_response_count. Source: Calculated from response status field.',
    live_response_count = 'Count of live production responses (status codes 0, 8, 16). Real respondent submissions. Most important metric for analysis. Non-negative integer. Contributes to total_response_count. Source: Calculated from response status field.',
    test_response_count = 'Count of test responses (status code 2). Used for quality assurance and validation. Should be excluded from production analytics. Non-negative integer. Contributes to total_response_count. Source: Calculated from response status field.',
    total_response_count = 'Total count of all responses across all types (preview + imported + live + test). Non-negative integer. Required field. Must equal sum of individual counts. 0 indicates survey has no responses yet. Source: Derived aggregate.',
    ingestion_ts = 'Timestamp when this record was ingested into the data warehouse. Required audit field. Generated by CURRENT_TIMESTAMP() during ETL. Used for data lineage and freshness monitoring. Should be within 24 hours of current time. Source: System generated.',
    survey_age_days = 'Number of days since survey was created. Calculated as DATEDIFF(CURRENT_DATE, creation_date). Useful for lifecycle analysis and retention metrics.',
    days_since_last_modified = 'Number of days since survey was last modified. Indicates content freshness and maintenance activity. High values may suggest abandoned surveys.',
    days_since_last_accessed = 'Number of days since survey was last accessed. Indicates usage recency. Values > 180 days may indicate stale or abandoned surveys.',
    response_collection_duration_days = 'Number of days between earliest and latest response. Indicates survey active collection period. NULL if no responses exist.',
    language_count = 'Count of available languages for the survey. Derived from SIZE(available_languages). Value of 1 indicates monolingual, >1 indicates multilingual support.',
    response_volume_category = 'Categorical classification of response volume: No Responses (0), Low Response (1-10), Medium Response (11-100), High Response (101-1000), Very High Response (>1000).',
    survey_status_category = 'Combined status showing activity and response state: Active with Responses, Active No Responses, Closed with Responses, Closed No Responses.',
    live_response_percentage = 'Percentage of live responses out of total responses. Key quality metric. High values (>80%) indicate good data quality. 0 if no responses.',
    test_response_percentage = 'Percentage of test responses out of total responses. Quality check metric. High values (>20%) may indicate testing phase or data quality issues.',
    days_since_last_response = 'Number of days since the last response was received. NULL if no responses exist. Used to identify inactive surveys with stale response data.',
    survey_lifecycle_stage = 'Categorical classification based on survey age: New (0-7 days), Recent (8-30 days), Current (31-90 days), Active Period (91-365 days), Mature (1-2 years), Legacy (2+ years). Used for lifecycle analysis.',
    preview_response_percentage = 'Percentage of preview responses out of total responses. Preview responses are internal/demo responses. Should typically be low (<10%) for production surveys.',
    imported_response_percentage = 'Percentage of imported responses out of total responses. Imported responses are from external sources. High values may indicate data migration scenarios.',
    avg_responses_per_day = 'Average number of responses received per day during collection period. Calculated as total_response_count / response_collection_duration_days. NULL if <2 responses. Indicates survey engagement rate.',
    response_rate_since_creation = 'Average responses per day since survey creation. Calculated as total_response_count / survey_age_days. Measures overall survey performance.',
    missing_survey_name = 'Data quality flag. TRUE if survey_name is NULL or empty string. Indicates incomplete metadata that should be remediated. Critical for survey identification.',
    missing_survey_description = 'Data quality flag. TRUE if survey_description is NULL or empty string. Optional metadata but recommended for documentation purposes.',
    is_multilingual = 'Boolean flag. TRUE if survey supports multiple languages (language_count > 1). Used for internationalization reporting and localization requirements.',
    has_temporal_anomaly = 'Critical data quality flag. TRUE if temporal logic violations detected: creation > modification, creation > access, earliest_response > latest_response, or any future dates. Requires investigation.',
    has_invalid_survey_id_format = 'Format validation flag. TRUE if survey_id does not match expected pattern ^SV_[A-Za-z0-9]{11,}$. Indicates potential data corruption or non-standard IDs.',
    has_invalid_owner_id_format = 'Format validation flag. TRUE if owner_id does not match expected pattern ^UR_[A-Za-z0-9]{11,}$. May indicate system integration issues.',
    has_language_inconsistency = 'Language validation flag. TRUE if survey_language is not present in available_languages array, or if available_languages is empty/null. Indicates configuration error.',
    has_future_dates = 'Critical validation flag. TRUE if any timestamp field contains future dates. Indicates system clock issues, data entry errors, or timezone problems.',
    is_stale_active_survey = 'Business rule flag. TRUE if survey is marked active but not accessed in 180+ days. Indicates potential candidates for deactivation or archival.',
    is_inactive_potential = 'Business rule flag. TRUE if survey is active, created 30+ days ago, but has zero responses. Suggests survey may need promotion, review, or closure.',
    recently_closed_survey = 'Business event flag. TRUE if survey was closed (is_active=FALSE) within the last 7 days. Useful for tracking recent survey completions.',
    has_no_live_responses_anomaly = 'Data quality warning. TRUE if survey has 10+ responses but zero live responses. All responses are test/preview/imported. May indicate misconfiguration.',
    has_high_test_response_ratio = 'Quality concern flag. TRUE if test responses exceed 50% of total when total_response_count >= 20. Suggests survey is still in testing phase or data cleaning needed.',
    active_but_no_recent_responses = 'Business rule flag. TRUE if survey is active, has received responses before, but none in the last 90 days. May indicate declining engagement.',
    is_high_volume_survey = 'Classification flag. TRUE if total_response_count > 10,000. Identifies high-impact surveys requiring special attention for performance and analytics.',
    is_abandoned_survey = 'Critical business flag. TRUE if survey is 2+ years old, still marked active, but has zero responses. Strong candidate for closure or removal.',
    survey_health_status = 'Comprehensive health assessment: Healthy (active, good response quality, recently accessed), Good (active, has responses, moderately recent), At Risk (active but stale access), Closed - Completed (successful completion), Needs Attention (other cases requiring review).',
    data_quality_score = 'Comprehensive data quality score (0-100). Weighted scoring: Core Identifiers (40pts - survey_id format 20, owner_id format 10, organization_id 10), Metadata Quality (25pts - name 10, description 5, language 5, available_languages 5), Temporal Consistency (20pts - valid creation 5, modification 5, access 5, response dates 5), Response Integrity (10pts - count math 5, date consistency 5), Language Consistency (5pts). Scores: 90-100 Excellent, 80-89 Good, 70-79 Fair, <70 Poor.',
    completeness_score = 'Data completeness score (0-100). Each of 10 key fields contributes 10 points if populated: survey_id, survey_name, survey_description, owner_id, organization_id, creation_date, last_modified_date, last_accessed_date, survey_language, available_languages. Score of 100 indicates all metadata present.'
  ),
  column_tags (
    survey_id = ('identifier', 'primary_key', 'dimension', 'required'),
    survey_name = ('metadata', 'descriptive', 'display', 'recommended'),
    survey_description = ('metadata', 'descriptive', 'content', 'optional'),
    available_languages = ('classification', 'array', 'locale', 'required'),
    survey_language = ('classification', 'locale', 'default', 'required'),
    owner_id = ('identifier', 'reference', 'user', 'required', 'foreign_key'),
    organization_id = ('identifier', 'reference', 'organization', 'required', 'foreign_key'),
    creation_date = ('temporal', 'timestamp', 'lifecycle', 'required', 'immutable'),
    last_modified_date = ('temporal', 'timestamp', 'lifecycle', 'audit', 'mutable'),
    last_accessed_date = ('temporal', 'timestamp', 'usage', 'audit', 'mutable'),
    is_active = ('flag', 'boolean', 'status', 'required', 'business_critical'),
    earliest_response_date = ('temporal', 'timestamp', 'aggregate', 'derived', 'optional'),
    latest_response_date = ('temporal', 'timestamp', 'aggregate', 'derived', 'optional'),
    preview_response_count = ('measurement', 'count', 'aggregate', 'derived', 'non_negative'),
    imported_response_count = ('measurement', 'count', 'aggregate', 'derived', 'non_negative'),
    live_response_count = ('measurement', 'count', 'aggregate', 'derived', 'non_negative', 'kpi'),
    test_response_count = ('measurement', 'count', 'aggregate', 'derived', 'non_negative', 'quality_metric'),
    total_response_count = ('measurement', 'count', 'aggregate', 'derived', 'non_negative', 'kpi'),
    ingestion_ts = ('temporal', 'timestamp', 'audit', 'required', 'system_generated'),
    survey_age_days = ('measurement', 'duration', 'derived', 'lifecycle'),
    days_since_last_modified = ('measurement', 'duration', 'derived', 'audit'),
    days_since_last_accessed = ('measurement', 'duration', 'derived', 'usage'),
    response_collection_duration_days = ('measurement', 'duration', 'derived', 'aggregate'),
    language_count = ('measurement', 'count', 'derived', 'locale'),
    response_volume_category = ('classification', 'categorical', 'derived', 'business_segment'),
    survey_status_category = ('classification', 'categorical', 'derived', 'business_segment'),
    live_response_percentage = ('measurement', 'percentage', 'derived', 'quality_metric', 'kpi'),
    test_response_percentage = ('measurement', 'percentage', 'derived', 'quality_metric'),
    missing_survey_name = ('flag', 'boolean', 'quality_check', 'derived'),
    missing_survey_description = ('flag', 'boolean', 'quality_check', 'derived'),
    is_multilingual = ('flag', 'boolean', 'classification', 'derived'),
    has_temporal_anomaly = ('flag', 'boolean', 'quality_check', 'derived', 'critical'),
    has_invalid_survey_id_format = ('flag', 'boolean', 'quality_check', 'derived', 'validation'),
    has_invalid_owner_id_format = ('flag', 'boolean', 'quality_check', 'derived', 'validation'),
    has_language_inconsistency = ('flag', 'boolean', 'quality_check', 'derived', 'validation'),
    has_future_dates = ('flag', 'boolean', 'quality_check', 'derived', 'critical'),
    is_stale_active_survey = ('flag', 'boolean', 'business_rule', 'derived', 'action_required'),
    is_inactive_potential = ('flag', 'boolean', 'business_rule', 'derived', 'action_required'),
    recently_closed_survey = ('flag', 'boolean', 'business_event', 'derived', 'informational'),
    has_no_live_responses_anomaly = ('flag', 'boolean', 'quality_check', 'derived', 'warning'),
    has_high_test_response_ratio = ('flag', 'boolean', 'quality_check', 'derived', 'warning'),
    active_but_no_recent_responses = ('flag', 'boolean', 'business_rule', 'derived', 'warning'),
    is_high_volume_survey = ('flag', 'boolean', 'classification', 'derived'),
    is_abandoned_survey = ('flag', 'boolean', 'business_rule', 'derived', 'critical'),
    survey_lifecycle_stage = ('classification', 'categorical', 'derived', 'lifecycle'),
    preview_response_percentage = ('measurement', 'percentage', 'derived', 'quality_metric'),
    imported_response_percentage = ('measurement', 'percentage', 'derived', 'quality_metric'),
    avg_responses_per_day = ('measurement', 'rate', 'derived', 'kpi'),
    response_rate_since_creation = ('measurement', 'rate', 'derived', 'kpi'),
    days_since_last_response = ('measurement', 'duration', 'derived', 'recency'),
    survey_health_status = ('classification', 'categorical', 'derived', 'kpi', 'business_critical'),
    data_quality_score = ('measurement', 'score', 'derived', 'quality_metric', 'kpi'),
    completeness_score = ('measurement', 'score', 'derived', 'quality_metric', 'kpi')
  ),
  column_terms (
    survey_id = ('survey_id', 'survey_identifier'),
    survey_name = ('name', 'title'),
    survey_description = ('description', 'purpose'),
    available_languages = ('languages', 'available'),
    survey_language = ('default_language', 'primary'),
    owner_id = ('user_id', 'owner'),
    organization_id = ('brand_id', 'identifier'),
    creation_date = ('creation_timestamp', 'created'),
    last_modified_date = ('modified_timestamp', 'updated'),
    last_accessed_date = ('accessed_timestamp', 'last_view'),
    is_active = ('active_status', 'is_active'),
    earliest_response_date = ('first_date', 'min_date'),
    latest_response_date = ('last_date', 'max_date'),
    preview_response_count = ('preview_count', 'count'),
    imported_response_count = ('imported_count', 'count'),
    live_response_count = ('live_count', 'count'),
    test_response_count = ('test_count', 'count'),
    total_response_count = ('total_count', 'count'),
    ingestion_ts = ('timestamp', 'load_time'),
    survey_age_days = ('age', 'duration', 'days'),
    days_since_last_modified = ('staleness', 'recency', 'days'),
    days_since_last_accessed = ('dormancy', 'recency', 'days'),
    response_collection_duration_days = ('collection_period', 'duration', 'timespan'),
    days_since_last_response = ('recency', 'staleness', 'days'),
    language_count = ('language_count', 'coverage', 'count'),
    response_volume_category = ('volume_segment', 'category', 'tier'),
    survey_status_category = ('status_segment', 'state', 'composite'),
    survey_lifecycle_stage = ('lifecycle', 'maturity', 'age_segment'),
    live_response_percentage = ('live_ratio', 'metric', 'engagement'),
    test_response_percentage = ('test_ratio', 'metric', 'coverage'),
    preview_response_percentage = ('preview_ratio', 'metric', 'usage'),
    imported_response_percentage = ('imported_ratio', 'metric', 'integration'),
    avg_responses_per_day = ('velocity', 'rate', 'throughput'),
    response_rate_since_creation = ('lifetime_rate', 'performance', 'efficiency'),
    missing_survey_name = ('missing_name', 'check', 'metadata'),
    missing_survey_description = ('missing_description', 'check', 'metadata'),
    is_multilingual = ('multilingual', 'flag', 'language'),
    has_temporal_anomaly = ('temporal_violation', 'critical', 'check'),
    has_invalid_survey_id_format = ('invalid_id_format', 'format', 'check'),
    has_invalid_owner_id_format = ('invalid_owner_format', 'format', 'check'),
    has_language_inconsistency = ('language_mismatch', 'consistency', 'error'),
    has_future_dates = ('future_timestamp', 'critical', 'anomaly'),
    is_stale_active_survey = ('stale_survey', 'dormant', 'deactivation_candidate'),
    is_inactive_potential = ('inactive_candidate', 'unsuccessful', 'review_required'),
    recently_closed_survey = ('recent_closure', 'event', 'status'),
    has_no_live_responses_anomaly = ('no_live_responses', 'warning', 'concern'),
    has_high_test_response_ratio = ('high_test_ratio', 'warning', 'indicator'),
    active_but_no_recent_responses = ('declining_engagement', 'at_risk', 'investigation_needed'),
    is_high_volume_survey = ('high_volume', 'scale', 'tier'),
    is_abandoned_survey = ('abandoned', 'failed', 'cleanup_required'),
    survey_health_status = ('health', 'status', 'assessment'),
    data_quality_score = ('composite_score', 'quality', 'weighted_assessment'),
    completeness_score = ('completeness', 'metadata_coverage', 'simple_assessment')
  ),
  references (
    owner_id = 'nilus.vulcan.qualtrics_users.user_id',
    organization_id = 'nilus.vulcan.qualtrics_organizations.organization_id'
  ),
  
);

WITH unnest_definition_result AS (
  SELECT
    t.survey_id,
    t.parsed_json:"result" AS result
  FROM GENSLER.RAW.QUALTRICS_DEFINITION AS t
), extracting_definition_metadata AS (
  SELECT
    survey_id,
    result:"SurveyName"::STRING AS survey_name,
    result:"SurveyDescription"::STRING AS survey_description,
    result:"OwnerID"::STRING AS owner_id,
    result:"BrandID"::STRING AS organization_id,
    result:"SurveyOptions":"SurveyCreationDate"::TIMESTAMP AS creation_date,
    result:"SurveyOptions":"SurveyLanguage"::STRING AS survey_language,
    OBJECT_KEYS(result:"SurveyOptions":"AvailableLanguages") AS available_languages,
    result:"LastModified"::TIMESTAMP AS last_modified_date,
    CASE
      WHEN result:"SurveyStatus"::STRING = 'Inactive'
      THEN FALSE
      WHEN result:"SurveyStatus"::STRING = 'Active'
      THEN TRUE
    END AS is_active,
    result:"LastAccessed"::TIMESTAMP AS last_accessed_date
  FROM unnest_definition_result
), explode_response AS (
  SELECT
     survey_id,
    f.value AS response_struct
  FROM GENSLER.RAW.QUALTRICS_RESPONSE,
       LATERAL FLATTEN(
           INPUT => PARSE_JSON(values_parsed),
           OUTER => TRUE
       ) f

), calculate_response_count AS (
  SELECT
    survey_id,
    COUNT(response_struct:"responseId"::STRING) AS total_response_count,
    MIN(response_struct:"values":"startDate"::TIMESTAMP) AS earliest_response_date,
    MAX(response_struct:"values":"endDate"::TIMESTAMP) AS latest_response_date,
    SUM(CASE WHEN response_struct:"values":"status"::INT IN (1, 9, 17) THEN 1 ELSE 0 END) AS preview_response_count,
    SUM(CASE WHEN response_struct:"values":"status"::INT IN (4, 12) THEN 1 ELSE 0 END) AS imported_response_count,
    SUM(CASE WHEN response_struct:"values":"status"::INT IN (0, 8, 16) THEN 1 ELSE 0 END) AS live_response_count,
    SUM(CASE WHEN response_struct:"values":"status"::INT = 2 THEN 1 ELSE 0 END) AS test_response_count
  FROM explode_response
  GROUP BY
    1
), qualtrics_survey_list_table AS (
  SELECT
    l.survey_id,
    l.survey_name,
    l.survey_description,
    l.available_languages,
    l.survey_language,
    l.owner_id,
    l.organization_id,
    l.creation_date,
    l.last_modified_date,
    l.last_accessed_date,
    l.is_active,
    COALESCE(r.earliest_response_date, NULL) AS earliest_response_date,
    COALESCE(r.latest_response_date, NULL) AS latest_response_date,
    COALESCE(r.preview_response_count, 0) AS preview_response_count,
    COALESCE(r.imported_response_count, 0) AS imported_response_count,
    COALESCE(r.live_response_count, 0) AS live_response_count,
    COALESCE(r.test_response_count, 0) AS test_response_count,
    COALESCE(r.total_response_count, 0) AS total_response_count,
    CURRENT_TIMESTAMP() AS ingestion_ts
  FROM extracting_definition_metadata AS l
  LEFT JOIN calculate_response_count AS r
    ON r.survey_id = l.survey_id
), enriched_survey_list AS (
  SELECT
    *,
    -- ========================================
    -- TEMPORAL DERIVED METRICS
    -- ========================================
    DATEDIFF(DAY, creation_date, CURRENT_DATE()) AS survey_age_days,
    DATEDIFF(DAY, last_modified_date, CURRENT_DATE()) AS days_since_last_modified,
    DATEDIFF(DAY, last_accessed_date, CURRENT_DATE()) AS days_since_last_accessed,
    DATEDIFF(DAY, earliest_response_date, latest_response_date) AS response_collection_duration_days,
    DATEDIFF(DAY, latest_response_date, CURRENT_DATE()) AS days_since_last_response,
    
    -- ========================================
    -- LANGUAGE & LOCALIZATION METRICS
    -- ========================================
    ARRAY_SIZE(available_languages) AS language_count,
    CASE 
      WHEN ARRAY_SIZE(available_languages) > 1 THEN TRUE 
      ELSE FALSE 
    END AS is_multilingual,
    
    -- ========================================
    -- BUSINESS CATEGORIZATION
    -- ========================================
    CASE 
      WHEN total_response_count = 0 THEN 'No Responses'
      WHEN total_response_count BETWEEN 1 AND 10 THEN 'Low Response'
      WHEN total_response_count BETWEEN 11 AND 100 THEN 'Medium Response'
      WHEN total_response_count BETWEEN 101 AND 1000 THEN 'High Response'
      WHEN total_response_count BETWEEN 1001 AND 10000 THEN 'Very High Response'
      ELSE 'Extremely High Response'
    END AS response_volume_category,
    
    CASE
      WHEN is_active = TRUE AND total_response_count > 0 THEN 'Active with Responses'
      WHEN is_active = TRUE AND total_response_count = 0 THEN 'Active No Responses'
      WHEN is_active = FALSE AND total_response_count > 0 THEN 'Closed with Responses'
      ELSE 'Closed No Responses'
    END AS survey_status_category,
    
    CASE
      WHEN DATEDIFF(DAY, creation_date, CURRENT_DATE()) <= 7 THEN 'New (0-7 days)'
      WHEN DATEDIFF(DAY, creation_date, CURRENT_DATE()) <= 30 THEN 'Recent (8-30 days)'
      WHEN DATEDIFF(DAY, creation_date, CURRENT_DATE()) <= 90 THEN 'Current (31-90 days)'
      WHEN DATEDIFF(DAY, creation_date, CURRENT_DATE()) <= 365 THEN 'Active Period (91-365 days)'
      WHEN DATEDIFF(DAY, creation_date, CURRENT_DATE()) <= 730 THEN 'Mature (1-2 years)'
      ELSE 'Legacy (2+ years)'
    END AS survey_lifecycle_stage,
    
    -- ========================================
    -- RESPONSE DISTRIBUTION METRICS
    -- ========================================
    CASE 
      WHEN total_response_count > 0 
      THEN ROUND(live_response_count * 100.0 / total_response_count, 2)
      ELSE 0 
    END AS live_response_percentage,
    
    CASE 
      WHEN total_response_count > 0 
      THEN ROUND(test_response_count * 100.0 / total_response_count, 2)
      ELSE 0 
    END AS test_response_percentage,
    
    CASE 
      WHEN total_response_count > 0 
      THEN ROUND(preview_response_count * 100.0 / total_response_count, 2)
      ELSE 0 
    END AS preview_response_percentage,
    
    CASE 
      WHEN total_response_count > 0 
      THEN ROUND(imported_response_count * 100.0 / total_response_count, 2)
      ELSE 0 
    END AS imported_response_percentage,
    
    -- ========================================
    -- RESPONSE VELOCITY METRICS
    -- ========================================
    CASE 
      WHEN DATEDIFF(DAY, earliest_response_date, latest_response_date) > 0 
        AND total_response_count > 1
      THEN ROUND(total_response_count / DATEDIFF(DAY, earliest_response_date, latest_response_date), 2)
      ELSE NULL
    END AS avg_responses_per_day,
    
    CASE
      WHEN total_response_count > 0 AND DATEDIFF(DAY, creation_date, CURRENT_DATE()) > 0
      THEN ROUND(total_response_count / DATEDIFF(DAY, creation_date, CURRENT_DATE()), 2)
      ELSE 0
    END AS response_rate_since_creation,
    
    -- ========================================
    -- DATA QUALITY FLAGS
    -- ========================================
    CASE 
      WHEN survey_name IS NULL OR TRIM(survey_name) = '' THEN TRUE 
      ELSE FALSE 
    END AS missing_survey_name,
    
    CASE 
      WHEN survey_description IS NULL OR TRIM(survey_description) = '' THEN TRUE 
      ELSE FALSE 
    END AS missing_survey_description,
    
    CASE 
      WHEN creation_date > last_modified_date THEN TRUE
      WHEN creation_date > last_accessed_date THEN TRUE
      WHEN earliest_response_date IS NOT NULL 
        AND latest_response_date IS NOT NULL
        AND earliest_response_date > latest_response_date THEN TRUE
      ELSE FALSE
    END AS has_temporal_anomaly,
    
    CASE
      WHEN survey_id IS NULL THEN TRUE
      WHEN NOT REGEXP_LIKE(survey_id, '^SV_[A-Za-z0-9]{11,}$') THEN TRUE
      ELSE FALSE
    END AS has_invalid_survey_id_format,
    
    CASE
      WHEN owner_id IS NULL THEN TRUE
      WHEN NOT REGEXP_LIKE(owner_id, '^UR_[A-Za-z0-9]{11,}$') THEN TRUE
      ELSE FALSE
    END AS has_invalid_owner_id_format,
    
    CASE
      WHEN available_languages IS NULL OR ARRAY_SIZE(available_languages) = 0 THEN TRUE
      WHEN NOT ARRAYS_OVERLAP(available_languages, ARRAY_CONSTRUCT(survey_language)) THEN TRUE
      ELSE FALSE
    END AS has_language_inconsistency,
    
    CASE
      WHEN creation_date > CURRENT_TIMESTAMP() THEN TRUE
      WHEN last_modified_date > CURRENT_TIMESTAMP() THEN TRUE
      WHEN last_accessed_date > CURRENT_TIMESTAMP() THEN TRUE
      WHEN latest_response_date > CURRENT_TIMESTAMP() THEN TRUE
      ELSE FALSE
    END AS has_future_dates,
    
    -- ========================================
    -- BUSINESS RULE FLAGS
    -- ========================================
    CASE
      WHEN is_active = TRUE AND DATEDIFF(DAY, last_accessed_date, CURRENT_DATE()) > 180 THEN TRUE
      ELSE FALSE
    END AS is_stale_active_survey,
    
    CASE
      WHEN is_active = TRUE 
        AND total_response_count = 0 
        AND DATEDIFF(DAY, creation_date, CURRENT_DATE()) > 30 THEN TRUE
      ELSE FALSE
    END AS is_inactive_potential,
    
    CASE
      WHEN is_active = FALSE 
        AND DATEDIFF(DAY, last_modified_date, CURRENT_DATE()) < 7 THEN TRUE
      ELSE FALSE
    END AS recently_closed_survey,
    
    CASE
      WHEN total_response_count >= 10 
        AND live_response_count = 0 THEN TRUE
      ELSE FALSE
    END AS has_no_live_responses_anomaly,
    
    CASE
      WHEN total_response_count >= 20 
        AND test_response_count > (total_response_count * 0.5) THEN TRUE
      ELSE FALSE
    END AS has_high_test_response_ratio,
    
    CASE
      WHEN is_active = TRUE 
        AND earliest_response_date IS NOT NULL
        AND DATEDIFF(DAY, latest_response_date, CURRENT_DATE()) > 90 THEN TRUE
      ELSE FALSE
    END AS active_but_no_recent_responses,
    
    CASE
      WHEN total_response_count > 10000 THEN TRUE
      ELSE FALSE
    END AS is_high_volume_survey,
    
    CASE
      WHEN DATEDIFF(DAY, creation_date, CURRENT_DATE()) > 730
        AND is_active = TRUE
        AND total_response_count = 0 THEN TRUE
      ELSE FALSE
    END AS is_abandoned_survey,
    
    -- ========================================
    -- SURVEY HEALTH SCORE
    -- ========================================
    CASE
      WHEN is_active = TRUE 
        AND total_response_count > 10 
        AND live_response_count > (total_response_count * 0.7)
        AND DATEDIFF(DAY, last_accessed_date, CURRENT_DATE()) <= 30 THEN 'Healthy'
      WHEN is_active = TRUE 
        AND total_response_count > 0 
        AND DATEDIFF(DAY, last_accessed_date, CURRENT_DATE()) <= 90 THEN 'Good'
      WHEN is_active = TRUE 
        AND DATEDIFF(DAY, last_accessed_date, CURRENT_DATE()) > 90 THEN 'At Risk'
      WHEN is_active = FALSE 
        AND total_response_count > 0 THEN 'Closed - Completed'
      ELSE 'Needs Attention'
    END AS survey_health_status,
    
    -- ========================================
    -- DATA QUALITY SCORE (0-100)
    -- ========================================
    (
      -- Core Identifiers (40 points)
      CASE WHEN survey_id IS NOT NULL AND REGEXP_LIKE(survey_id, '^SV_[A-Za-z0-9]{11,}$') THEN 20 ELSE 0 END +
      CASE WHEN owner_id IS NOT NULL AND REGEXP_LIKE(owner_id, '^UR_[A-Za-z0-9]{11,}$') THEN 10 ELSE 0 END +
      CASE WHEN organization_id IS NOT NULL THEN 10 ELSE 0 END +
      
      -- Metadata Quality (25 points)
      CASE WHEN survey_name IS NOT NULL AND TRIM(survey_name) != '' THEN 10 ELSE 0 END +
      CASE WHEN survey_description IS NOT NULL AND TRIM(survey_description) != '' THEN 5 ELSE 0 END +
      CASE WHEN survey_language IS NOT NULL AND LENGTH(survey_language) IN (2, 5) THEN 5 ELSE 0 END +
      CASE WHEN available_languages IS NOT NULL AND ARRAY_SIZE(available_languages) > 0 THEN 5 ELSE 0 END +
      
      -- Temporal Consistency (20 points)
      CASE WHEN creation_date IS NOT NULL AND creation_date <= CURRENT_TIMESTAMP() THEN 5 ELSE 0 END +
      CASE WHEN last_modified_date IS NOT NULL AND last_modified_date >= creation_date THEN 5 ELSE 0 END +
      CASE WHEN last_accessed_date IS NOT NULL AND last_accessed_date >= creation_date THEN 5 ELSE 0 END +
      CASE WHEN (earliest_response_date IS NULL AND latest_response_date IS NULL) 
            OR (earliest_response_date <= latest_response_date) THEN 5 ELSE 0 END +
      
      -- Response Data Integrity (10 points)
      CASE WHEN total_response_count = COALESCE(preview_response_count, 0) 
                                     + COALESCE(imported_response_count, 0)
                                     + COALESCE(live_response_count, 0)
                                     + COALESCE(test_response_count, 0) THEN 5 ELSE 0 END +
      CASE WHEN (total_response_count = 0 AND earliest_response_date IS NULL AND latest_response_date IS NULL)
            OR (total_response_count > 0 AND earliest_response_date IS NOT NULL AND latest_response_date IS NOT NULL) 
            THEN 5 ELSE 0 END +
      
      -- Language Consistency (5 points)
      CASE WHEN available_languages IS NOT NULL 
            AND survey_language IS NOT NULL
            AND ARRAYS_OVERLAP(available_languages, ARRAY_CONSTRUCT(survey_language)) THEN 5 ELSE 0 END
    ) AS data_quality_score,
    
    -- ========================================
    -- COMPLETENESS SCORE (0-100)
    -- ========================================
    (
      CASE WHEN survey_id IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN survey_name IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN survey_description IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN owner_id IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN organization_id IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN creation_date IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN last_modified_date IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN last_accessed_date IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN survey_language IS NOT NULL THEN 10 ELSE 0 END +
      CASE WHEN available_languages IS NOT NULL THEN 10 ELSE 0 END
    ) AS completeness_score
    
  FROM qualtrics_survey_list_table
)
SELECT
  *
FROM enriched_survey_list