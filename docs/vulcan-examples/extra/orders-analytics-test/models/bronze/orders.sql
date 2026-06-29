-- Core orders fact table containing order transactions
-- Central fact table for sales analytics and customer behavior tracking
-- Incremental processing based on order_date for efficient updates
MODEL (
  name bronze_v1.orders,
  kind SEED (
    path '../../seeds/seed_orders.csv'
  ),
  columns (
    order_id INTEGER,
    customer_id INTEGER,
    order_date TIMESTAMP,
    warehouse_id INTEGER
  ),
  grains (order_id),
  tags ('fact', 'transaction', 'sales', 'order'),
  terms ('sales.order', 'transaction.order'),
  description 'Order transactions fact table containing all customer orders with timestamps, customer attribution, and warehouse fulfillment information for sales and operational analytics',
  column_descriptions (
    order_id = 'Unique identifier for each order transaction',
    customer_id = 'Foreign key to customers table - identifies which customer placed the order',
    order_date = 'Timestamp when the order was placed',
    warehouse_id = 'Foreign key to warehouses table - identifies which warehouse will fulfill the order'
  ),
  column_tags (
    order_id = ('primary_key', 'identifier', 'transaction'),
    customer_id = ('foreign_key', 'reference', 'customer'),
    order_date = ('temporal', 'timestamp', 'partition_key'),
    warehouse_id = ('foreign_key', 'reference', 'warehouse')
  ),
  column_terms (
    order_id = ('sales.order_id', 'transaction.order_id'),
    customer_id = ('customer.customer_id', 'reference.customer_id'),
    order_date = ('time.order_timestamp', 'event.order_date'),
    warehouse_id = ('warehouse.warehouse_id', 'reference.warehouse_id')
  ),
  -- assertions (
  --   unique_values(columns := order_id),
  --   not_null(columns := (order_id, customer_id, order_date, warehouse_id)),
  --   forall(criteria := (
  --     order_id > 0,
  --     customer_id > 0,
  --     warehouse_id > 0
  --   )),
  --   accepted_range(column := order_date, min_v := '2025-01-01'::TIMESTAMP, max_v := CURRENT_TIMESTAMP + INTERVAL '1 day')
  -- ),
  profiles (customer_id, warehouse_id, order_date)
);

