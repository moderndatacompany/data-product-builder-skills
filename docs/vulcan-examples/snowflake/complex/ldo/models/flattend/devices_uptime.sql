MODEL (
  name lenovo.ldo.devices_uptime,
  kind FULL,
  grains (ID),
  tags ('device_monitoring', 'uptime', 'network', 'cdc', 'availability'),
  terms ('device.uptime', 'network.connectivity', 'availability.tracking'),
  description 'Device uptime and network connectivity tracking with CDC event processing. Monitors online/offline state transitions, calculates total uptime/downtime minutes for device availability analysis and network reliability metrics',
  column_descriptions (
    id = 'Unique uptime record identifier',
    class = 'Record class/type classification',
    device_id = 'Unique device identifier',
    network = 'Network connection type/identifier',
    last_change_to_online = 'Timestamp when device last came online',
    last_change_to_offline = 'Timestamp when device last went offline',
    total_minutes_online = 'Cumulative minutes device has been online',
    total_minutes_offline = 'Cumulative minutes device has been offline',
    __op = 'CDC operation type (insert, update, delete)',
    __source_ts_ms = 'Source system timestamp in milliseconds',
    __deleted = 'CDC deletion flag'
  ),
  column_tags (
    id = ('identifier', 'primary_key'),
    class = ('dimension', 'classification'),
    device_id = ('identifier', 'device', 'foreign_key'),
    network = ('dimension', 'network'),
    last_change_to_online = ('temporal', 'timestamp', 'event'),
    last_change_to_offline = ('temporal', 'timestamp', 'event'),
    total_minutes_online = ('measure', 'duration', 'uptime'),
    total_minutes_offline = ('measure', 'duration', 'downtime'),
    __op = ('metadata', 'cdc'),
    __source_ts_ms = ('metadata', 'cdc', 'temporal'),
    __deleted = ('metadata', 'cdc', 'flag')
  ),
  column_terms (
    id = ('entity.identifier', 'uptime.record_id'),
    device_id = ('device.identifier', 'entity.reference'),
    network = ('network.type', 'connectivity.network'),
    last_change_to_online = ('device.online', 'state.transition'),
    last_change_to_offline = ('device.offline', 'state.transition'),
    total_minutes_online = ('uptime.metric', 'availability.online'),
    total_minutes_offline = ('downtime.metric', 'availability.offline'),
    __op = ('cdc.operation', 'event.type'),
    __deleted = ('cdc.deletion', 'event.flag')
  )
);

WITH cleaned_cdc_data AS (
  SELECT 
    id,
    class,
    device_id,
    network,
    last_change_to_online,
    last_change_to_offline,
    total_minutes_online,
    total_minutes_offline,
    __op,
    __source_ts_ms,
    __deleted
  FROM (
    SELECT
      _id AS id,
      _class AS class,
      device_id,
      network,
      TO_TIMESTAMP_NTZ(last_change_to_online / 1000) AS last_change_to_online,
      TO_TIMESTAMP_NTZ(last_change_to_offline / 1000) AS last_change_to_offline,
      total_minutes_online,
      total_minutes_offline,
      _op AS __op,
      TO_TIMESTAMP_NTZ(_source_ts_ms / 1000) AS __source_ts_ms,
      deleted AS __deleted,
      ROW_NUMBER() OVER (
        PARTITION BY _id
        ORDER BY
          CASE WHEN _op IS NOT NULL THEN 0 ELSE 1 END,
          CAST(_source_ts_ms AS BIGINT) DESC
      ) AS rn
    FROM lenovo.ldo.device_network_seed_model
  )
  WHERE rn = 1
),

deleted_records AS (
  SELECT
    id,
    __op,
    __source_ts_ms,
    __deleted
  FROM
    cleaned_cdc_data
  WHERE
    __deleted = 'True'
),

cleaned_source_data AS (
  SELECT
    _id AS id,
    _class AS class,
    device_id,
    network,
    TO_TIMESTAMP_NTZ(last_change_to_online / 1000) AS last_change_to_online,
    TO_TIMESTAMP_NTZ(last_change_to_offline / 1000) AS last_change_to_offline,
    total_minutes_online,
    total_minutes_offline
  FROM
    lenovo.ldo.device_uptime_seed_model
  WHERE _id IN (
    SELECT
      id
    FROM
      deleted_records
    WHERE
      __deleted = 'True'
  )
),

reconstruct_deleted_records AS (
  SELECT
    source.*,
    d.__op,
    d.__source_ts_ms,
    d.__deleted
  FROM cleaned_source_data source
  INNER JOIN deleted_records d
  ON d.id = source.id
),

result AS (
  SELECT * FROM reconstruct_deleted_records
  UNION
  SELECT * FROM cleaned_cdc_data WHERE __deleted = 'False'
)

SELECT * FROM result;
