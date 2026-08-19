"""
FAST Single Script: Create and Insert v_d_customer
- Creates table with all 297 columns
- Inserts data matching v_fact_sales customers
- Optimized for speed (< 2 minutes)
"""

import os
import random
import csv
from datetime import datetime

# Load .env from cobs/ so SNOWFLAKE_* and SNOWFLAKE_PRIVATE_KEY_PASSPHRASE are set
try:
    from dotenv import load_dotenv
    _COBS_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    load_dotenv(os.path.join(_COBS_ROOT, '.env'))
except ImportError:
    pass  # optional: pip install python-dotenv

import snowflake.connector

# Directory of this script (for template CSV path)
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Default path to Snowflake private key (sibling project sgws-web-analytics)
_DEFAULT_KEY_PATH = os.path.normpath(
    os.path.join(_SCRIPT_DIR, '..', '..', 'sgws-web-analytics', 'snowflake_key.p8')
)

print("=" * 70)
print("🚀 FAST v_d_customer Setup - Create Table + Insert Data")
print("=" * 70)

# Snowflake config – key-pair auth (avoids MFA/TOTP)
# Use SNOWFLAKE_PRIVATE_KEY_PATH if set and file exists; else use repo path sgws-web-analytics/snowflake_key.p8
_env_key_path = os.environ.get('SNOWFLAKE_PRIVATE_KEY_PATH')
if _env_key_path and os.path.exists(_env_key_path):
    private_key_path = _env_key_path
else:
    private_key_path = _DEFAULT_KEY_PATH
private_key_passphrase = os.environ.get('SNOWFLAKE_PRIVATE_KEY_PASSPHRASE') or None

config = {
    'user': os.environ.get('SNOWFLAKE_USER', 'SHREYA'),
    'account': os.environ.get('SNOWFLAKE_ACCOUNT', 'EQZOTUQ-JCA67320'),
    'warehouse': os.environ.get('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
    'database': os.environ.get('SNOWFLAKE_DATABASE', 'GENSLER'),
    'schema': 'ONESOURCEPLUS',
    'private_key_path': private_key_path,
    'private_key_passphrase': private_key_passphrase,
}
# Key-pair auth (avoids MFA); connector needs authenticator or it may try password and fail
config['authenticator'] = 'SNOWFLAKE_JWT'
if not os.path.exists(private_key_path):
    raise FileNotFoundError(
        f"Snowflake private key not found: {private_key_path}\n"
        "Set SNOWFLAKE_PRIVATE_KEY_PATH to a valid path or place snowflake_key.p8 in sgws-web-analytics/"
    )

# Same customer pool used in v_fact_sales
random.seed(42)
CUSTOMER_POOL = random.sample(range(10000, 999999), 2000)
SITES = [1, 20, 60, 170]

print(f"\n✅ Using {len(CUSTOMER_POOL)} customers from v_fact_sales")
print(f"✅ Sites: {SITES}")
print(f"✅ Total rows to insert: {len(CUSTOMER_POOL) * len(SITES):,}\n")

# Connect
print("🔌 Connecting to Snowflake...")
conn = snowflake.connector.connect(**config)
cursor = conn.cursor()
print("✅ Connected!\n")

try:
    # Step 1: DROP existing table
    print("📋 Step 1: Dropping existing table...")
    cursor.execute("DROP TABLE IF EXISTS onesourceplus.v_d_customer")
    print("✅ Done\n")
    
    # Step 2: CREATE TABLE with all 297 columns
    print("📋 Step 2: Creating table...")
    
    create_sql = """
    CREATE TABLE onesourceplus.v_d_customer (
        customer_sk BIGINT,
        site VARCHAR(50),
        customer_no INTEGER,
        customer_name VARCHAR(255),
        address_1 VARCHAR(255),
        address_2 VARCHAR(255),
        city VARCHAR(100),
        state VARCHAR(50),
        zip VARCHAR(50),
        county VARCHAR(50),
        premise_code VARCHAR(50),
        liquor_rating VARCHAR(50),
        wine_rating VARCHAR(50),
        status VARCHAR(50),
        selling_div_sk BIGINT,
        selling_div_no INTEGER,
        bdn_license_type VARCHAR(50),
        rating VARCHAR(50),
        family_code VARCHAR(50),
        family_name VARCHAR(255),
        location VARCHAR(255),
        location_name VARCHAR(255),
        merchandiser1 VARCHAR(50),
        merchandiser2 VARCHAR(50),
        merchandiser3 VARCHAR(50),
        ethnic_type VARCHAR(50),
        ethnic_type_desc VARCHAR(255),
        license_type VARCHAR(100),
        license_class VARCHAR(255),
        license_name VARCHAR(255),
        class_name VARCHAR(255),
        store_type VARCHAR(50),
        store_type_desc VARCHAR(255),
        liquor_case_vol VARCHAR(50),
        wine_case_vol VARCHAR(50),
        total_case_vol VARCHAR(50),
        liquor_dlr_vol VARCHAR(50),
        wine_dollar_vol VARCHAR(50),
        tot_dollar_vol VARCHAR(50),
        phone_no VARCHAR(100),
        contact VARCHAR(255),
        new_customer_no VARCHAR(50),
        old_customer_no VARCHAR(50),
        chain_id INTEGER,
        chain_name VARCHAR(255),
        chain_type VARCHAR(100),
        chain_class VARCHAR(100),
        chain_class_desc VARCHAR(255),
        chain_type_desc VARCHAR(255),
        chain_active_cd VARCHAR(50),
        state_chain_no INTEGER,
        state_chain_name VARCHAR(255),
        corp_chain_no VARCHAR(50),
        corp_chain_name VARCHAR(255),
        corp_chain_class VARCHAR(100),
        corp_chain_class_desc VARCHAR(255),
        corp_chain_type VARCHAR(100),
        corp_chain_type_desc VARCHAR(255),
        corp_sp_prem_cd VARCHAR(50),
        corp_sp_premise VARCHAR(255),
        corp_prty_cd VARCHAR(50),
        corp_rpt_type VARCHAR(50),
        ar_group_acct_no VARCHAR(50),
        chain_supvsr_no VARCHAR(50),
        lockbox VARCHAR(50),
        deactivate_dt TIMESTAMP_NTZ,
        sfa_include VARCHAR(50),
        fax_no VARCHAR(100),
        license_classification VARCHAR(100),
        zip_ext VARCHAR(50),
        bill_to_cust_no INTEGER,
        check_avrg DECIMAL(18,4),
        wine_list_size INTEGER,
        by_the_glass VARCHAR(50),
        well_pct INTEGER,
        wine_list_pct INTEGER,
        floor_mrch_lvl VARCHAR(50),
        bck_room_strg_lvl VARCHAR(50),
        wine_prservsys_flg VARCHAR(50),
        vis_back_bar_flg VARCHAR(50),
        table_tent_flg VARCHAR(50),
        cord_drnklst_flg VARCHAR(50),
        cndct_promo_flg VARCHAR(50),
        hgh_prof_chef_flg VARCHAR(50),
        mini_bar_flg VARCHAR(50),
        cold_box_flg VARCHAR(50),
        chalet_flg VARCHAR(50),
        cntrl_whs_flg VARCHAR(50),
        gen_hse_wine_flg VARCHAR(50),
        variet_hse_wine_flg VARCHAR(50),
        imprt_hse_wine_flg VARCHAR(50),
        dmstic_hse_wine_flg VARCHAR(50),
        dmstic_imprt_flg VARCHAR(50),
        newspapr_adv_flg VARCHAR(50),
        newsletr_adv_flg VARCHAR(50),
        stre_adv_flg VARCHAR(50),
        window_adv_flg VARCHAR(50),
        tv_adv_flg VARCHAR(50),
        radio_adv_flg VARCHAR(50),
        magazine_adv_flg VARCHAR(50),
        flyr_adv_flg VARCHAR(50),
        commissionable_acct_flg VARCHAR(50),
        last_ord_dt TIMESTAMP_NTZ,
        acct_type_cd VARCHAR(50),
        stdlinxscd VARCHAR(50),
        county_name VARCHAR(255),
        commission_acct VARCHAR(50),
        credit_cd VARCHAR(50),
        credit_limit INTEGER,
        dist_cluster VARCHAR(50),
        on_sales_ind VARCHAR(50),
        past_due_flg VARCHAR(50),
        priority_cd VARCHAR(50),
        prog_cluster VARCHAR(50),
        terms_cd VARCHAR(50),
        user_name VARCHAR(255),
        modified_user VARCHAR(255),
        effective_from_dt TIMESTAMP_NTZ,
        effective_thru_dt TIMESTAMP_NTZ,
        load_dt TIMESTAMP_NTZ,
        modified_dt TIMESTAMP_NTZ,
        current_ind VARCHAR(50),
        src_desc VARCHAR(100),
        active_ind VARCHAR(50),
        license VARCHAR(100),
        univ_customer_no INTEGER,
        corp_vip_chain_cd VARCHAR(50),
        customer_create_date VARCHAR(50),
        rpt_sales_org_code INTEGER,
        rpt_sales_org_desc VARCHAR(255),
        rpt_sales_org_short_desc VARCHAR(255),
        rpt_channel_code INTEGER,
        rpt_channel_desc VARCHAR(255),
        rpt_channel_short_desc VARCHAR(255),
        rpt_sub_channel_code INTEGER,
        rpt_sub_channel_desc VARCHAR(255),
        rpt_sub_channel_short_desc VARCHAR(255),
        rpt_ship_type_code VARCHAR(50),
        rpt_ship_type_desc VARCHAR(255),
        rpt_ship_type_short_desc VARCHAR(255),
        alt_license_number VARCHAR(100),
        billto_customer_name VARCHAR(255),
        billto_address_1 VARCHAR(500),
        billto_address_2 VARCHAR(500),
        billto_city VARCHAR(255),
        billto_state VARCHAR(50),
        billto_zip VARCHAR(50),
        billto_county VARCHAR(50),
        billto_county_name VARCHAR(255),
        primary_email_address VARCHAR(255),
        deliquent_flg VARCHAR(50),
        delv_day_ind VARCHAR(50),
        sun_delv VARCHAR(50),
        mon_delv VARCHAR(50),
        tue_delv VARCHAR(50),
        wed_delv VARCHAR(50),
        thu_delv VARCHAR(50),
        fri_delv VARCHAR(50),
        sat_delv VARCHAR(50),
        delv_wind1_start INTEGER,
        delv_wind1_end INTEGER,
        delv_wind2_start INTEGER,
        delv_wind2_end INTEGER,
        billing_zone INTEGER,
        license_exp_date TIMESTAMP_NTZ,
        alcohol_license_status VARCHAR(50),
        current_ar_bal DECIMAL(18,4),
        ar_aging_p1_bal DECIMAL(18,4),
        ar_aging_p2_bal DECIMAL(18,4),
        ar_aging_p3_bal DECIMAL(18,4),
        ar_aging_p4_bal DECIMAL(18,4),
        ar_aging_p1_desc VARCHAR(255),
        ar_aging_p2_desc VARCHAR(255),
        ar_aging_p3_desc VARCHAR(255),
        ar_aging_p4_desc VARCHAR(255),
        total_ar_bal DECIMAL(18,4),
        ar_past_due_amt DECIMAL(18,4),
        rtm_national_chain_code INTEGER,
        rtm_national_chain_desc VARCHAR(255),
        rtm_national_channel_code INTEGER,
        rtm_national_channel_desc VARCHAR(255),
        rtm_national_sub_channel_code INTEGER,
        rtm_national_sub_channel_desc VARCHAR(255),
        rtm_emerging_ind VARCHAR(50),
        rtm_national_acct_vp VARCHAR(255),
        rtm_national_acct_director VARCHAR(255),
        rtm_national_acct_ops_analyst VARCHAR(255),
        source_system VARCHAR(100),
        check_sum VARCHAR(500),
        bdn_license_type_desc VARCHAR(255),
        credit_cd_desc VARCHAR(255),
        terms_cd_desc VARCHAR(255),
        selling_div_name VARCHAR(255),
        is_deleted VARCHAR(50),
        selling_div_group_name VARCHAR(255),
        cust_level1_no INTEGER,
        cust_level1_name VARCHAR(255),
        cust_level3_no INTEGER,
        cust_level3_name VARCHAR(255),
        customer_route_no VARCHAR(255),
        customer_promo_cd VARCHAR(50),
        customer_price_list_cd VARCHAR(50),
        beer_traffic_cd VARCHAR(50),
        spirit_traffic_cd VARCHAR(50),
        wine_traffic_cd VARCHAR(50),
        item_authorization_list_id INTEGER,
        primary_warehouse INTEGER,
        cod_terms_code_flg VARCHAR(50),
        ar_terms_code VARCHAR(50),
        ar_terms_code_desc VARCHAR(255),
        cod_reason_code VARCHAR(50),
        cod_reason_code_desc VARCHAR(255),
        cust_updated_flg VARCHAR(50),
        cust_special_price_flg VARCHAR(50),
        cust_street_deals_flg VARCHAR(50),
        cust_lock_profile_flg VARCHAR(50),
        customer_latitude VARCHAR(50),
        customer_longitude VARCHAR(50),
        customer_service_level VARCHAR(255),
        delivery_priority VARCHAR(50),
        customer_acct_type_desc VARCHAR(255),
        ar_group_custmast_acct_no VARCHAR(50),
        ar_group_custmast_business_name VARCHAR(255),
        ar_group_business_name VARCHAR(255),
        chain_store_no INTEGER,
        chain_embed_delivery_charge_ind VARCHAR(50),
        chain_delivery_charge_override_amt DECIMAL(18,4),
        chain_discount_profile_on_premise INTEGER,
        chain_discount_profile_off_premise INTEGER,
        activated_acct VARCHAR(255),
        registered_acct VARCHAR(255),
        proof_of_eligible_acct VARCHAR(50),
        multi_account_flg VARCHAR(50),
        average_days_pay_count INTEGER,
        ar_account_type VARCHAR(50),
        credit_clerk_cd INTEGER,
        commits_overdue_flg VARCHAR(50),
        ar_credit_condition_cd_2 VARCHAR(50),
        ar_credit_condition_cd_3 VARCHAR(50),
        nsf_flg VARCHAR(50),
        ar_write_off_amt DECIMAL(18,4),
        last_write_off_dt VARCHAR(50),
        write_off_charge_service_bad_debt_ind VARCHAR(50),
        items_authorized_ind VARCHAR(50),
        bill_to_phone_no VARCHAR(100),
        outlet_type_short_desc VARCHAR(255),
        dms_flg VARCHAR(50),
        accepts_cases_only_ind VARCHAR(50),
        customer_route_desc VARCHAR(255),
        chain_broad_mkt_allocation VARCHAR(255),
        primary_salesperson_no INTEGER,
        last_pay_date VARCHAR(50),
        billto_zip_ext INTEGER,
        delivery_freq_code VARCHAR(50),
        delivery_freq_desc VARCHAR(255),
        owner_name VARCHAR(255),
        owner_address1 VARCHAR(500),
        owner_address2 VARCHAR(500),
        owner_city VARCHAR(255),
        owner_state VARCHAR(50),
        owner_zip_cd INTEGER,
        owner_zip_cd_plus INTEGER,
        license_effective_dt VARCHAR(50),
        state_excise_tax_exempt_cd VARCHAR(50),
        license_status_short_desc VARCHAR(255),
        license_status_long_desc VARCHAR(255),
        dual_license_ind VARCHAR(50),
        credit_clerk_name VARCHAR(255),
        ar_credit_condition_long_desc_1 VARCHAR(255),
        ar_credit_condition_short_desc_1 VARCHAR(255),
        ar_credit_condition_long_desc_2 VARCHAR(255),
        ar_credit_condition_short_desc_2 VARCHAR(255),
        ar_credit_condition_long_desc_3 VARCHAR(255),
        ar_credit_condition_short_desc_3 VARCHAR(255),
        discount_profile INTEGER,
        state_sales_tax_no INTEGER,
        cust_split_by_product_type_ind VARCHAR(50),
        bypass_state_reporting_ind VARCHAR(50),
        chain_cust_split_by_product_type_ind VARCHAR(50),
        chain_bypass_state_reporting_ind VARCHAR(50),
        credit_comments VARCHAR(500),
        next_delivery_date VARCHAR(50),
        price_code VARCHAR(50),
        delivery_route_stops_cnt INTEGER,
        time_open_for_business INTEGER,
        time_closed_for_business INTEGER,
        delivery_instruction_1 VARCHAR(500),
        delivery_instruction_2 VARCHAR(500),
        bill_to_email_address VARCHAR(255),
        bill_to_email_address_2 VARCHAR(255),
        po_no_required_ind VARCHAR(50),
        actual_credit_limit DECIMAL(18,4),
        seasonal_credit_limit DECIMAL(18,4),
        seasonal_credit_limit_start_dt TIMESTAMP_NTZ,
        seasonal_credit_limit_end_dt TIMESTAMP_NTZ,
        added_by_user_name VARCHAR(255),
        warehouse_permit_no VARCHAR(100)
    )
    """
    
    cursor.execute(create_sql)
    print("✅ Table created with 297 columns\n")
    
    # Step 3: Load sample data from CSV (cobs/artifacts/redshift/v_d_customer.csv)
    print("📋 Step 3: Loading sample data...")
    csv_file = os.path.join(_SCRIPT_DIR, '..', 'artifacts', 'redshift', 'v_d_customer.csv')
    csv_file = os.path.normpath(csv_file)
    if not os.path.exists(csv_file):
        raise FileNotFoundError(
            f"Template CSV not found: {csv_file}\n"
            "Ensure customer-usecase/cobs/artifacts/redshift/v_d_customer.csv exists."
        )
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames
        samples = [row for row in reader]
    if not samples:
        raise RuntimeError(f"No rows in {csv_file}; need at least one template row.")
    print(f"✅ Loaded {len(samples)} sample rows from artifacts/redshift/v_d_customer.csv\n")
    
    # Step 4: Insert data - FAST batch insert
    print("📋 Step 4: Inserting data (FAST mode)...")
    
    columns_str = ', '.join(headers)
    placeholders = ', '.join(['%s'] * len(headers))
    insert_sql = f"INSERT INTO onesourceplus.v_d_customer ({columns_str}) VALUES ({placeholders})"
    
    batch = []
    inserted = 0
    total = len(CUSTOMER_POOL) * len(SITES)
    
    for site in SITES:
        for cust_no in CUSTOMER_POOL:
            template = random.choice(samples)
            row = []
            
            for col in headers:
                if col == 'customer_no':
                    row.append(cust_no)
                elif col == 'site':
                    row.append(site)
                elif col == 'customer_sk':
                    row.append(int(f"{site}{cust_no}"))
                elif col == 'status':
                    row.append('A')
                elif col == 'activated_acct':
                    row.append(random.choice(['Re-Ordered', 'Ordered']))
                elif col == 'rtm_national_channel_desc':
                    row.append(random.choice(['LOCAL CHANNEL', 'REGIONAL CHANNEL']))
                elif col == 'proof_of_eligible_acct':
                    row.append('Y')
                else:
                    val = template.get(col, '')
                    row.append(val if val else None)
            
            batch.append(tuple(row))
            
            if len(batch) >= 1000:
                cursor.executemany(insert_sql, batch)
                inserted += len(batch)
                print(f"  ✓ {inserted:,}/{total:,} ({inserted/total*100:.1f}%)")
                batch = []
    
    if batch:
        cursor.executemany(insert_sql, batch)
        inserted += len(batch)
        print(f"  ✓ {inserted:,}/{total:,} (100.0%)")
    
    conn.commit()
    
    print("\n" + "=" * 70)
    print("✅ SUCCESS! All done in record time!")
    print("=" * 70)
    
    # Verify
    cursor.execute("SELECT COUNT(*), COUNT(DISTINCT customer_no), COUNT(DISTINCT site) FROM onesourceplus.v_d_customer")
    total, uniq_cust, uniq_site = cursor.fetchone()
    print(f"\n📊 Verification:")
    print(f"  Total rows: {total:,}")
    print(f"  Unique customers: {uniq_cust:,}")
    print(f"  Unique sites: {uniq_site}")
    print(f"\n🎉 Ready for RFM workflow!")

except Exception as e:
    print(f"\n❌ Error: {e}")
    conn.rollback()
    import traceback
    traceback.print_exc()

finally:
    cursor.close()
    conn.close()
    print("\n🔌 Disconnected")

