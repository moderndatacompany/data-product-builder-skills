MODEL (
  name raw.raw_shipments,
  kind SEED (
    path '../../seeds/raw_shipments.csv'
  ),
  description 'Seed model loading raw shipment data from CSV file',
  columns (
    shipment_id VARCHAR,
    order_id VARCHAR,
    shipped_date DATE,
    delivered_date DATE,
    carrier VARCHAR,
    tracking_number VARCHAR,
    shipping_status VARCHAR,
    shipping_cost FLOAT
  ),
  grain shipment_id
);

