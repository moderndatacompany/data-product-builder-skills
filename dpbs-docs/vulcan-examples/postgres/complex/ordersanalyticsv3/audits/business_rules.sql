AUDIT (
  name assert_positive_order_ids,
);

SELECT *
FROM @this_model
WHERE
  item_id < 0

AUDIT (
  name validate_customer_id
);


select * from 
@this_model where customer_id is null
