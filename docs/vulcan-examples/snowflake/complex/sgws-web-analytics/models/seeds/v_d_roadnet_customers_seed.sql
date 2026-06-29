MODEL (
  name web_analytics_seeds.V_D_ROADNET_CUSTOMERS,
  kind SEED (
    path '../../seeds/v_d_roadnet_customers.csv'
  ),
  owner 'rohitrajtmdcio',
  description 'Static customer reference data from source system',
  tags ('seed', 'reference_data', 'dimension', 'master_data'),
  terms ('v_d_roadnet_customers'),
  columns (
        customer_id BIGINT,
        site_id VARCHAR,
        location_type VARCHAR,
        customer_name VARCHAR,
        delivery_days VARCHAR,
        address_line1 VARCHAR,
        address_line2 VARCHAR,
        postal_code VARCHAR,
        region1 VARCHAR,
        region2 VARCHAR,
        region3 VARCHAR,
        phone_number VARCHAR,
        customer_number VARCHAR,
        otc_customer_id VARCHAR,
        otc_site_id VARCHAR,
        load_date VARCHAR,
        longitude DECIMAL(18, 4),
        latitude DECIMAL(18, 4),
        locquality_desc VARCHAR,
        is_deleted VARCHAR,
        modified_date VARCHAR,
        modified_user VARCHAR,
        source_system VARCHAR,
        otc_warehouse_no VARCHAR
  )
);

-- ============================================================================
-- SEED DATA: V_D_ROADNET_CUSTOMERS
-- ============================================================================

SELECT
  customer_id,
  site_id,
  location_type,
  customer_name,
  delivery_days,
  address_line1,
  address_line2,
  postal_code,
  region1,
  region2,
  region3,
  phone_number,
  customer_number,
  otc_customer_id,
  otc_site_id,
  load_date,
  longitude,
  latitude,
  locquality_desc,
  is_deleted,
  modified_date,
  modified_user,
  source_system,
  otc_warehouse_no
FROM SEED();
