-- Order line items fact table containing order details at product level
-- Enables product-level revenue analysis and inventory tracking
-- Connected to orders table via order_id foreign key
MODEL (
  name bronze_v2alpha.order_items,
  kind FULL,
  grains (order_id, item_id),
  cron '*/15 * * * *',
  tags ('fact', 'transaction', 'sales', 'line_item'),
  terms ('sales.order_item', 'transaction.line_item'),
  description 'Order line items fact table containing detailed product-level information for each order including quantities, pricing, and product attribution for revenue and inventory analytics',
  column_descriptions (
    order_id = 'Foreign key to orders table - identifies which order this line item belongs to',
    item_id = 'Line item sequence number within the order (1, 2, 3, etc.)',
    product_id = 'Foreign key to products table - identifies which product was ordered',
    quantity = 'Number of units of the product ordered',
    unit_price = 'Price per unit of the product at time of order in USD'
  ),
  column_tags (
    order_id = ('foreign_key', 'reference', 'composite_key'),
    item_id = ('identifier', 'composite_key', 'sequence'),
    product_id = ('foreign_key', 'reference', 'product'),
    quantity = ('measure', 'metric', 'inventory'),
    unit_price = ('measure', 'financial', 'pricing')
  ),
  column_terms (
    order_id = ('sales.order_id', 'transaction.order_id'),
    item_id = ('sales.line_item_id', 'transaction.item_sequence'),
    product_id = ('product.product_id', 'reference.product_id'),
    quantity = ('sales.quantity', 'inventory.quantity_ordered'),
    unit_price = ('sales.unit_price', 'finance.price_per_unit')
  ),
  assertions (
    unique_combination_of_columns(columns := (order_id, item_id)),
    not_null(columns := (order_id, item_id, product_id, quantity, unit_price)),
    forall(criteria := (
      order_id > 0,
      item_id > 0,
      product_id > 0
    )),
    accepted_range(column := quantity, min_v := 1, max_v := 1000),
    accepted_range(column := unit_price, min_v := 0, max_v := 10000)
  ),
  profiles (product_id, quantity, unit_price)
);

-- Join with orders to get line items for recent orders
-- This approach ensures we capture all line items even as orders are updated
SELECT
  oi.order_id,
  oi.item_id,
  oi.product_id,
  oi.quantity,
  oi.unit_price
FROM vulcan_demo.order_items AS oi

