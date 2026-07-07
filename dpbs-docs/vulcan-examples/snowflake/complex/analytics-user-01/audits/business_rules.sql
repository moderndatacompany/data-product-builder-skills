AUDIT (
  name validate_customer_id
);


select * from 
@this_model where CUSTOMER_ID is null
