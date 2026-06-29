MODEL (
  name CUSTOMER_PLATFORM.BRONZE.SALES_ORDER_HISTORY,
  kind SEED (
    path '../../seeds/sales_order_history.csv'
  ),
  columns (
    order_id TEXT,
    order_number TEXT,
    customer_id TEXT,
    order_date TEXT,
    order_status TEXT,
    order_type TEXT,
    sales_rep_id TEXT,
    order_value_usd NUMERIC(15, 2),
    discount_percentage NUMERIC(5, 2),
    net_order_value_usd NUMERIC(15, 2),
    order_line_count BIGINT,
    delivery_date TEXT,
    invoice_date TEXT,
    payment_terms TEXT,
    created_at TEXT
  ),
  grain order_id,
  owner 'shreyasikarwartmdcio',
  tags ('seed-data', 'bronze', 'sales-orders'),
  description 'Sales order history containing all B2B customer orders with pricing, status, and delivery information.'
);
