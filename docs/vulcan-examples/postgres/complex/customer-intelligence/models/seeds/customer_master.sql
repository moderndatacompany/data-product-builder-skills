MODEL (
  name CUSTOMER_PLATFORM.BRONZE.CUSTOMER_MASTER,
  kind SEED (
    path '../../seeds/customer_master.csv'
  ),
  columns (
    customer_id TEXT,
    customer_name TEXT,
    customer_type TEXT,
    industry TEXT,
    company_size TEXT,
    account_tier TEXT,
    primary_contact_name TEXT,
    primary_contact_email TEXT,
    billing_address_city TEXT,
    billing_address_state TEXT,
    billing_address_country TEXT,
    account_manager_id TEXT,
    account_status TEXT,
    created_date TEXT,
    last_modified_date TEXT
  ),
  grain customer_id,
  owner 'shreyasikarwartmdcio',
  tags ('seed-data', 'bronze', 'customer-master'),
  description 'Customer master data containing account details, contact information, and classification for all B2B customers.'
);
