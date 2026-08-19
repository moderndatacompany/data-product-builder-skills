MODEL (
  name sales.returns,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column return_date
  ),
  start '2024-01-01',
  cron '@daily',
  grain return_id,
  description 'Returns fact table with incremental loading by return date',
  assertions (
    not_null(columns := (return_id, order_id, order_item_id, return_date)),
    unique_values(columns := (return_id)),
    forall(criteria := (refund_amount >= 0))
  ),
  column_descriptions (
    return_id = 'Unique identifier for the return record',
    order_id = 'Order identifier associated with the return',
    order_item_id = 'Order item identifier associated with the return',
    return_date = 'Date the return was recorded',
    return_reason = 'High-level return reason',
    return_status = 'Return status',
    refund_amount = 'Refund amount issued for the return'
  )
);

SELECT
  r.return_id::VARCHAR AS return_id,
  r.order_id::VARCHAR AS order_id,
  r.order_item_id::VARCHAR AS order_item_id,
  r.return_date::DATE AS return_date,
  r.return_reason::VARCHAR AS return_reason,
  r.return_status::VARCHAR AS return_status,
  r.refund_amount::FLOAT AS refund_amount
FROM raw.raw_returns AS r
WHERE r.return_date::DATE BETWEEN @start_date AND @end_date

