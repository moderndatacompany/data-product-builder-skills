AUDIT (
  name validate_customer_id
);


select * from 
@this_model where customer_id is null

