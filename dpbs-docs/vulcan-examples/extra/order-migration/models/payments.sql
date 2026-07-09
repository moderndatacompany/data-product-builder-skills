MODEL (
  name sales.payments,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column payment_date
  ),
  start '2024-01-01',
  cron '@daily',
  grain payment_id,
  description 'Payments fact table (1+ payments per order) with incremental loading by payment date',
  assertions (
    not_null(columns := (payment_id, order_id, payment_date)),
    unique_values(columns := (payment_id)),
    forall(criteria := (amount >= 0))
  ),
  column_descriptions (
    payment_id = 'Unique identifier for the payment',
    order_id = 'Order identifier the payment belongs to',
    payment_date = 'Date the payment was recorded',
    payment_method = 'Payment method (Card, PayPal, etc.)',
    provider = 'Payment provider (Stripe, Adyen, PayPal, etc.)',
    transaction_id = 'External processor transaction id',
    amount = 'Payment amount',
    status = 'Payment status (Paid, Pending, Refunded)'
  )
);

SELECT
  p.payment_id::VARCHAR AS payment_id,
  p.order_id::VARCHAR AS order_id,
  p.payment_date::DATE AS payment_date,
  p.payment_method::VARCHAR AS payment_method,
  p.provider::VARCHAR AS provider,
  p.transaction_id::VARCHAR AS transaction_id,
  p.amount::FLOAT AS amount,
  p.status::VARCHAR AS status
FROM raw.raw_payments AS p
WHERE p.payment_date::DATE BETWEEN @start_date AND @end_date

