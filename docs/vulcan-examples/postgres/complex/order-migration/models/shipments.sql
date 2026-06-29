MODEL (
  name sales.shipments,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column shipped_date
  ),
  start '2024-01-01',
  cron '@daily',
  grain shipment_id,
  description 'Shipments fact table with incremental loading by shipped date',
  assertions (
    not_null(columns := (shipment_id, order_id)),
    unique_values(columns := (shipment_id)),
    forall(criteria := (shipping_cost >= 0))
  ),
  column_descriptions (
    shipment_id = 'Unique shipment identifier',
    order_id = 'Order identifier for the shipment',
    shipped_date = 'Date the shipment was shipped',
    delivered_date = 'Date the shipment was delivered (nullable)',
    carrier = 'Shipping carrier',
    tracking_number = 'Tracking number for the shipment',
    shipping_status = 'Shipment status (Delivered, InTransit, etc.)',
    shipping_cost = 'Shipment shipping cost'
  )
);

SELECT
  s.shipment_id::VARCHAR AS shipment_id,
  s.order_id::VARCHAR AS order_id,
  s.shipped_date::DATE AS shipped_date,
  s.delivered_date::DATE AS delivered_date,
  s.carrier::VARCHAR AS carrier,
  s.tracking_number::VARCHAR AS tracking_number,
  s.shipping_status::VARCHAR AS shipping_status,
  s.shipping_cost::FLOAT AS shipping_cost
FROM raw.raw_shipments AS s
WHERE s.shipped_date::DATE BETWEEN @start_date AND @end_date

