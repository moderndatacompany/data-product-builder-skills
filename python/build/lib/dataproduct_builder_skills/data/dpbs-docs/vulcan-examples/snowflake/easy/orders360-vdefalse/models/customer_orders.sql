MODEL (
  name DEMODB.VDEFALSE.CUSTOMER_ORDERS,
  kind FULL,
  cron '@daily',
  grain (CUSTOMER_ID, ORDER_ID),
  tags ('curated', 'join', 'customer', 'orders', 'sales', 'vde_disabled'),
  terms ('sales.customer_orders', 'analytics.customer_order_join'),
  description 'Curated customer x order join exposing customer identity and segment alongside each order row. Drives downstream SQL consumers that want a single dimensional table without writing joins themselves.',
  assertions (
    not_null(columns := (CUSTOMER_ID, ORDER_ID, ORDER_DATE))
  ),
  column_descriptions (
    CUSTOMER_ID      = 'Customer identifier (joined from customers)',
    FULL_NAME        = 'Customer full name (joined from customers)',
    EMAIL            = 'Customer email (joined from customers)',
    CUSTOMER_SEGMENT = 'Customer segment tier (joined from customers)',
    ACCOUNT_STATUS   = 'Customer account status (joined from customers)',
    LOYALTY_SCORE    = 'Customer loyalty score (joined from customers)',
    ORDER_ID         = 'Order identifier',
    ORDER_DATE       = 'Date the order was placed',
    PRODUCT_ID       = 'Product reference on the order',
    QUANTITY         = 'Quantity of items ordered',
    UNIT_PRICE       = 'Per-unit price on the order',
    DISCOUNT         = 'Order discount rate (0.0 to 1.0)',
    TOTAL_AMOUNT     = 'Total order amount including tax and shipping'
  ),
  column_tags (
    CUSTOMER_ID      = ('identifier', 'grain', 'foreign_key'),
    FULL_NAME        = ('dimension', 'label', 'pii'),
    EMAIL            = ('dimension', 'contact', 'pii'),
    CUSTOMER_SEGMENT = ('dimension', 'classification', 'label'),
    ACCOUNT_STATUS   = ('dimension', 'status', 'label'),
    LOYALTY_SCORE    = ('measure', 'metric', 'score'),
    ORDER_ID         = ('identifier', 'grain'),
    ORDER_DATE       = ('temporal', 'date'),
    PRODUCT_ID       = ('foreign_key', 'reference', 'dimension'),
    QUANTITY         = ('measure', 'metric', 'count'),
    UNIT_PRICE       = ('measure', 'financial', 'price'),
    DISCOUNT         = ('measure', 'financial', 'percentage'),
    TOTAL_AMOUNT     = ('measure', 'financial', 'revenue')
  ),
  column_terms (
    CUSTOMER_ID      = ('customer.identifier', 'entity.customer_id'),
    CUSTOMER_SEGMENT = ('customer.segment', 'classification.customer_tier'),
    ORDER_ID         = ('order.identifier', 'transaction.order_id'),
    ORDER_DATE       = ('order.date', 'transaction.date'),
    TOTAL_AMOUNT     = ('order.total', 'sales.revenue')
  )
);

SELECT
  c.CUSTOMER_ID::VARCHAR AS CUSTOMER_ID,
  c.FULL_NAME::VARCHAR AS FULL_NAME,
  c.EMAIL::VARCHAR AS EMAIL,
  c.CUSTOMER_SEGMENT::VARCHAR AS CUSTOMER_SEGMENT,
  c.ACCOUNT_STATUS::VARCHAR AS ACCOUNT_STATUS,
  c.LOYALTY_SCORE::INTEGER AS LOYALTY_SCORE,
  o.ORDER_ID::VARCHAR AS ORDER_ID,
  o.ORDER_DATE::DATE AS ORDER_DATE,
  o.PRODUCT_ID::VARCHAR AS PRODUCT_ID,
  o.QUANTITY::INTEGER AS QUANTITY,
  o.UNIT_PRICE::FLOAT AS UNIT_PRICE,
  o.DISCOUNT::FLOAT AS DISCOUNT,
  o.TOTAL_AMOUNT::FLOAT AS TOTAL_AMOUNT
FROM DEMODB.VDEFALSE.CUSTOMERS AS c
INNER JOIN DEMODB.VDEFALSE.ORDERS AS o
  ON c.CUSTOMER_ID = o.CUSTOMER_ID
