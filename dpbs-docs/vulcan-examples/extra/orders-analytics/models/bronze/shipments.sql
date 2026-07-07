-- Shipments fact table containing order fulfillment and delivery tracking
-- Used for logistics analytics and delivery performance monitoring
-- Incremental processing based on shipped_date for efficient updates
MODEL (
  name bronze_v2alpha.shipments,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column shipped_date
  ),
  start '2025-01-01',
  cron '*/15 * * * *',
  grains (shipment_id),
  tags ('fact', 'logistics', 'fulfillment', 'shipping'),
  terms ('logistics.shipment', 'fulfillment.delivery'),
  description 'Shipment tracking fact table containing order fulfillment records with shipping dates, carrier information, and order attribution for logistics and delivery performance analytics',
  column_descriptions (
    shipment_id = 'Unique identifier for each shipment',
    order_id = 'Foreign key to orders table - identifies which order this shipment fulfills',
    shipped_date = 'Date when the shipment was dispatched from warehouse',
    carrier = 'Shipping carrier or courier company handling the delivery (DHL, UPS, FedEx, USPS, BlueDart)'
  ),
  column_tags (
    shipment_id = ('primary_key', 'identifier', 'transaction'),
    order_id = ('foreign_key', 'reference', 'order'),
    shipped_date = ('temporal', 'date', 'partition_key'),
    carrier = ('dimension', 'logistics', 'carrier')
  ),
  column_terms (
    shipment_id = ('logistics.shipment_id', 'fulfillment.shipment_id'),
    order_id = ('sales.order_id', 'reference.order_id'),
    shipped_date = ('time.ship_date', 'event.shipped_date'),
    carrier = ('logistics.carrier', 'shipping.carrier_name')
  ),
  assertions (
    unique_values(columns := shipment_id),
    not_null(columns := (shipment_id, order_id, shipped_date, carrier)),
    not_empty_string(column := carrier),
    accepted_values(column := carrier, is_in := ('DHL', 'UPS', 'FedEx', 'USPS', 'BlueDart')),
    forall(criteria := (
      shipment_id > 0,
      order_id > 0
    )),
    accepted_range(column := shipped_date, min_v := '2025-01-01'::DATE, max_v := CURRENT_DATE + INTERVAL '1 day')
  ),
  profiles (carrier, shipped_date, order_id)
);

SELECT
  shipment_id,
  order_id,
  shipped_date,
  carrier
FROM vulcan_demo.shipments
WHERE shipped_date BETWEEN @start_date AND @end_date

