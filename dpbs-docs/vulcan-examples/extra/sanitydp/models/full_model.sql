MODEL (
  name lenovo.vulcan_example.full_model,
  kind FULL,
  cron '@daily',
  grain item_id,
  assertions (
    not_null(columns := (item_id)),
    forall(criteria := (item_id > 0))
  ),
);

SELECT
  item_id,
  COUNT(DISTINCT id) AS num_orders,
FROM
  lenovo.vulcan_example.incremental_model
GROUP BY item_id
  