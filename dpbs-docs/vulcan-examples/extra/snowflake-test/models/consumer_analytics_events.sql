MODEL (
  name LENOVO.USDK.CONSUMER_ANALYTICS_EVENTS,
  kind FULL,
  grain REPORTING_TIME,
  owner 'shreyasikarwartmdcio',
  profiles (CONTEXT, EVENT, REPORTING_TIME),
  tags ('bronze', 'consumer-analytics', 'events', 'lenovo', 'usdk', 'json-parsing', 'raw-data'),
  terms ('consumer_analytics', 'event_tracking', 'device_telemetry'),
  description 'Bronze layer table parsing raw consumer analytics events from JSON format into structured VARIANT objects for downstream processing. Contains device context, user context, environment details, and event metadata.',
  column_descriptions (
    CONTEXT = 'Nested JSON object containing user, device, environment, and product context information including device type, manufacturer, model, OS, product versions, and geographic location',
    EVENT = 'Nested JSON object containing event details including timestamp, action type, event name, group, custom data payload, and aggregation metadata (method, count, first/last time)',
    REPORTING_TIME = 'Timestamp when the event was reported to the analytics system (grain column)'
  ),
  column_tags (
    CONTEXT = ('pii-sensitive', 'device-info', 'variant', 'nested-json', 'context-data'),
    EVENT = ('event-data', 'analytics', 'variant', 'nested-json', 'event-payload'),
    REPORTING_TIME = ('timestamp', 'audit', 'grain', 'temporal')
  ),
  column_terms (
    CONTEXT = ('context', 'context_data', 'context'),
    EVENT = ('event', 'event_payload', 'event'),
    REPORTING_TIME = ('report_time', 'timestamp', 'report_timestamp')
  )
);

/* Parse JSON data from seed/staged data */
WITH parsed_raw AS (
  SELECT
    TRY_PARSE_JSON("context") AS context_json,
    TRY_PARSE_JSON("event") AS event_json,
    "report_time" AS reporting_time
  FROM VULCAN.TEST.CONSUMER_ANALYTICS_EVENTS_RAW
)
SELECT
  OBJECT_CONSTRUCT(
    'user',
    OBJECT_CONSTRUCT(
      'generated_anonymous_user_id',
      context_json[0][0]::VARCHAR,
      'anonymous_user_account_id',
      context_json[0][1]::VARCHAR
    ),
    'device',
    OBJECT_CONSTRUCT(
      'device_type',
      context_json[1][0]::VARCHAR,
      'anonymous_device_idv1',
      context_json[1][1]::VARCHAR,
      'manufacturer',
      context_json[1][2]::VARCHAR,
      'product_name',
      context_json[1][3]::VARCHAR,
      'model',
      context_json[1][4]::VARCHAR
    ),
    'environment',
    OBJECT_CONSTRUCT(
      'os',
      context_json[2][0]::VARCHAR,
      'os_version',
      context_json[2][1]::VARCHAR,
      'first_run_date',
      TRY_CAST(context_json[2][2]::VARCHAR AS TIMESTAMP),
      'locale',
      context_json[2][3]::VARCHAR,
      'geo',
      context_json[2][4]::VARCHAR,
      'session_id',
      context_json[2][5]::VARCHAR
    ),
    'product',
    OBJECT_CONSTRUCT(
      'product_id',
      context_json[3][0]::VARCHAR,
      'product_version',
      context_json[3][1]::VARCHAR,
      'component_id',
      context_json[3][2]::VARCHAR,
      'component_version',
      context_json[3][3]::VARCHAR,
      'collect_sdk_version',
      context_json[3][4]::VARCHAR,
      'sync_sdk_version',
      context_json[3][5]::VARCHAR
    )
  ) AS context,
  OBJECT_CONSTRUCT(
    'timestamp',
    TRY_CAST(event_json[0]::VARCHAR AS TIMESTAMP),
    'action',
    event_json[1]::VARCHAR,
    'name',
    event_json[2]::VARCHAR,
    'group',
    event_json[3]::VARCHAR,
    'data',
    TRY_PARSE_JSON(event_json[4]::VARCHAR),
    'aggregation',
    OBJECT_CONSTRUCT(
      'method',
      CAST(GET_PATH(TRY_PARSE_JSON(event_json[5]::VARCHAR), 'method') AS VARCHAR),
      'count',
      CAST(GET_PATH(TRY_PARSE_JSON(event_json[5]::VARCHAR), 'count') AS INT),
      'first_time',
      TRY_CAST(CAST(GET_PATH(TRY_PARSE_JSON(event_json[5]::VARCHAR), 'first_time') AS VARCHAR) AS TIMESTAMP),
      'last_time',
      TRY_CAST(CAST(GET_PATH(TRY_PARSE_JSON(event_json[5]::VARCHAR), 'last_time') AS VARCHAR) AS TIMESTAMP)
    )
  ) AS event,
  reporting_time
  FROM parsed_raw