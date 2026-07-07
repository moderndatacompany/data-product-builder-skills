MODEL (
  name s3depot.qcommerce_delivery_bronze.raw_shipments,
  kind SEED (
    path '../../seeds/raw_shipments.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [shipment_id],
  description 'Raw shipment attempt events sourced from the bundled seed CSV. Acts as the single source of truth for the shipments_clean bronze model in this self-contained Spark example.',
  tags ('seed', 'bronze', 'shipments', 'raw'),
  terms ('raw_shipments', 'shipment_event', 'shipment_attempt'),
  columns (
    shipment_id STRING,
    order_id STRING,
    rider_id STRING,
    pickup_ts TIMESTAMP,
    delivered_ts TIMESTAMP,
    shipment_status STRING,
    scan_count INT
  ),
  assertions (
    not_null(columns := (shipment_id, order_id)),
    unique_values(columns := (shipment_id)),
    accepted_range(column := scan_count, min_v := 0, max_v := 1000)
  )
);
