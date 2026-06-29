MODEL (
  name DEMODB.VDEFALSE.ORDERS,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column ORDER_DATE
  ),
  start '2025-01-01',
  cron '@daily',
  grain ORDER_ID,
  tags ('fact', 'orders', 'sales', 'transactions', 'incremental', 'vde_disabled'),
  terms ('sales.orders', 'transactions.order_fact'),
  description 'Orders fact table loaded incrementally by ORDER_DATE. Captures per-order transactional grain (quantity, unit price, discount, tax, shipping, total) and is the source for the customer_orders join and the daily_sales_summary aggregate.',
  assertions (
    not_null(columns := (ORDER_ID, ORDER_DATE, CUSTOMER_ID))
  ),
  column_descriptions (
    ORDER_ID      = 'Unique identifier for each order',
    ORDER_DATE    = 'Date the order was placed (incremental time column)',
    CUSTOMER_ID   = 'Foreign key to DEMODB.VDEFALSE.CUSTOMERS',
    PRODUCT_ID    = 'Foreign key to DEMODB.VDEFALSE.PRODUCTS',
    QUANTITY      = 'Quantity of items ordered',
    UNIT_PRICE    = 'Price per unit at time of order',
    DISCOUNT      = 'Discount rate applied (0.0 to 1.0)',
    TAX           = 'Tax amount charged',
    SHIPPING_COST = 'Shipping cost for the order',
    TOTAL_AMOUNT  = 'Total order amount including tax and shipping'
  ),
  column_tags (
    ORDER_ID      = ('identifier', 'primary_key', 'grain'),
    ORDER_DATE    = ('temporal', 'date', 'time_column'),
    CUSTOMER_ID   = ('foreign_key', 'reference', 'dimension'),
    PRODUCT_ID    = ('foreign_key', 'reference', 'dimension'),
    QUANTITY      = ('measure', 'metric', 'count'),
    UNIT_PRICE    = ('measure', 'financial', 'price'),
    DISCOUNT      = ('measure', 'financial', 'percentage'),
    TAX           = ('measure', 'financial', 'amount'),
    SHIPPING_COST = ('measure', 'financial', 'amount'),
    TOTAL_AMOUNT  = ('measure', 'financial', 'revenue')
  ),
  column_terms (
    ORDER_ID      = ('order.identifier', 'transaction.order_id'),
    ORDER_DATE    = ('order.date', 'transaction.date'),
    CUSTOMER_ID   = ('order.customer', 'customer.identifier'),
    PRODUCT_ID    = ('order.product', 'product.identifier'),
    QUANTITY      = ('order.quantity', 'sales.items_sold'),
    UNIT_PRICE    = ('order.unit_price', 'product.price'),
    DISCOUNT      = ('order.discount', 'pricing.discount_rate'),
    TAX           = ('order.tax', 'financial.tax_amount'),
    SHIPPING_COST = ('order.shipping', 'financial.shipping_cost'),
    TOTAL_AMOUNT  = ('order.total', 'sales.revenue')
  )
);

SELECT
  ORDER_ID::VARCHAR AS ORDER_ID,
  ORDER_DATE::DATE AS ORDER_DATE,
  CUSTOMER_ID::VARCHAR AS CUSTOMER_ID,
  PRODUCT_ID::VARCHAR AS PRODUCT_ID,
  QUANTITY::INTEGER AS QUANTITY,
  UNIT_PRICE::FLOAT AS UNIT_PRICE,
  DISCOUNT::FLOAT AS DISCOUNT,
  TAX::FLOAT AS TAX,
  SHIPPING_COST::FLOAT AS SHIPPING_COST,
  TOTAL_AMOUNT::FLOAT AS TOTAL_AMOUNT
FROM VULCAN.RAW.ORDERS
WHERE ORDER_DATE::DATE BETWEEN @start_date AND @end_date
