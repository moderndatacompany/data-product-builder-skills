"""
Direct Snowflake Insert Script for v_fact_sales
Connects to Snowflake and inserts 10,000 rows directly
Much faster than running SQL INSERT statements!
"""
"""
CREATE TABLE onesourceplus.v_fact_sales (
    sales_sk BIGINT,
    site INTEGER,
    customer_no INTEGER,
    item_no INTEGER,
    posting_dt_sk INTEGER,
    invoice_no INTEGER,
    invoice_dt_sk INTEGER,
    qty_dec_equ DECIMAL(18, 6),
    cases INTEGER,
    bottles INTEGER,
    ship_dt TIMESTAMP_NTZ,
    posting_prd INTEGER,
    entry_origin VARCHAR(10),
    sequence_no INTEGER,
    unit_price DECIMAL(18, 4),
    ext_net DECIMAL(18, 4),
    ext_cost DECIMAL(18, 4),
    ext_depl_allow DECIMAL(18, 4),
    ext_participation DECIMAL(18, 4),
    ext_guaranteed_adj DECIMAL(18, 4),
    cqd_amt DECIMAL(18, 4),
    current_salesperson_sk BIGINT,
    salesman_no INTEGER,
    salesperson_sk BIGINT,
    customer_sk BIGINT,
    order_no INTEGER,
    load_dt TIMESTAMP_NTZ,
    deal_id VARCHAR(50),
    modified_dt TIMESTAMP_NTZ,
    warehouse_no INTEGER
);

"""
import os
import sys
import random
import snowflake.connector
from datetime import datetime, timedelta

# Configuration
NUM_ROWS = 10000
BATCH_SIZE = 1000  # Insert 1000 rows at a time
random.seed(42)

# Snowflake credentials. Use same database as Vulcan (e.g. GENSLER) so RFM models find the tables.
try:
    from dotenv import load_dotenv
    _root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    load_dotenv(os.path.join(_root, '.env'))
except ImportError:
    pass

_scripts_dir = os.path.dirname(os.path.abspath(__file__))
_key_path = os.environ.get('SNOWFLAKE_PRIVATE_KEY_PATH') or os.path.normpath(os.path.join(_scripts_dir, '..', 'snowflake_key.p8'))
_key_pass = os.environ.get('SNOWFLAKE_PRIVATE_KEY_PASSPHRASE') or None
_use_key = os.path.exists(_key_path)

SNOWFLAKE_CONFIG = {
    'user': os.environ.get('SNOWFLAKE_USER', 'SHREYA'),
    'account': os.environ.get('SNOWFLAKE_ACCOUNT', 'EQZOTUQ-JCA67320'),
    'warehouse': os.environ.get('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
    'database': os.environ.get('SNOWFLAKE_DATABASE', 'GENSLER'),
    'schema': 'ONESOURCEPLUS'
}
if _use_key:
    SNOWFLAKE_CONFIG['authenticator'] = 'SNOWFLAKE_JWT'
    SNOWFLAKE_CONFIG['private_key_path'] = _key_path
    SNOWFLAKE_CONFIG['private_key_passphrase'] = _key_pass
else:
    SNOWFLAKE_CONFIG['password'] = os.environ.get('SNOWFLAKE_PASSWORD', '')

# Calculate date ranges
today = datetime.now().date()
start_date = today - timedelta(days=365)

# Helper functions
def random_date_within_months(months_back):
    """Generate date within specified months back from today"""
    days_back = (months_back * 30) + random.randint(0, 29)
    return today - timedelta(days=days_back)

def format_date_yyyymmdd(date):
    """Convert date to yyyyMMdd integer"""
    return int(date.strftime('%Y%m%d'))

def format_timestamp(date, hour=None, minute=None, second=None):
    """Generate timestamp from date"""
    if hour is None:
        hour = random.randint(0, 23)
    if minute is None:
        minute = random.randint(0, 59)
    if second is None:
        second = random.randint(0, 59)
    microsecond = random.randint(0, 999999)
    
    dt = datetime.combine(date, datetime.min.time())
    dt = dt.replace(hour=hour, minute=minute, second=second, microsecond=microsecond)
    return dt

# Data pools
sites = [1, 20, 60, 170]
warehouses = [14, 201, 360, 702]
entry_origins_all = ['B', 'U', 'J', 'F', 'Z', 'K', 'Y', '1T', 'B3', 'WA', 'PP', '5N', 'GI', 'R6', 'Q', '8P', 'MK']
entry_origins_proof = ['H', 'G']
customer_pool = random.sample(range(10000, 999999), 2000)

def generate_row():
    """Generate a single row of data"""
    # Generate posting date (weighted toward recent months)
    months_back = random.choices(
        range(12),
        weights=[15, 12, 10, 9, 8, 7, 7, 6, 6, 5, 5, 5]
    )[0]
    posting_date = random_date_within_months(months_back)
    posting_dt_sk = format_date_yyyymmdd(posting_date)
    posting_prd = int(posting_date.strftime('%Y%m'))
    
    # Invoice date
    invoice_date = posting_date + timedelta(days=random.randint(0, 5))
    invoice_dt_sk = format_date_yyyymmdd(invoice_date)
    
    # Ship date
    ship_date = posting_date + timedelta(days=random.randint(-30, 60))
    ship_dt = format_timestamp(ship_date)
    
    # Load date
    load_date = posting_date + timedelta(days=random.randint(0, max(1, (today - posting_date).days)))
    load_dt = format_timestamp(load_date)
    
    # Modified date
    modified_date = today - timedelta(days=random.randint(0, 365))
    modified_dt = format_timestamp(modified_date)
    
    # Entry origin (30% proof)
    if random.random() < 0.30:
        entry_origin = random.choice(entry_origins_proof)
    else:
        entry_origin = random.choice(entry_origins_all)
    
    customer_no = random.choice(customer_pool)
    site = random.choice(sites)
    
    return (
        random.randint(1000000000, 9999999999),  # sales_sk
        site,
        customer_no,
        random.randint(10000, 999999),  # item_no
        posting_dt_sk,
        random.randint(1000000, 9999999),  # invoice_no
        invoice_dt_sk,
        round(random.uniform(-1000, 1000), 6),  # qty_dec_equ
        random.randint(10, 10000000),  # cases
        random.randint(100, 10000000),  # bottles
        ship_dt,
        posting_prd,
        entry_origin,
        random.randint(100000, 9999999),  # sequence_no
        round(random.uniform(1000, 500000), 4),  # unit_price
        round(random.uniform(1000, 500000), 4),  # ext_net (always > 0)
        round(random.uniform(-500000, 500000), 4),  # ext_cost
        round(random.uniform(-10000, 10000), 4),  # ext_depl_allow
        round(random.uniform(-10000, 10000), 4),  # ext_participation
        round(random.uniform(-10000, 10000), 4),  # ext_guaranteed_adj
        round(random.uniform(-500000, 500000), 4),  # cqd_amt
        random.randint(1000000000, 9999999999),  # current_salesperson_sk
        random.randint(1000, 9999999),  # salesman_no
        random.randint(1000000000, 9999999999),  # salesperson_sk
        random.randint(1000000000, 9999999999),  # customer_sk
        random.randint(100000, 9999999),  # order_no
        load_dt,
        ''.join(random.choices('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', k=random.randint(4, 20))),  # deal_id
        modified_dt,
        random.choice(warehouses)
    )

def main():
    print("=" * 70)
    print("🚀 Direct Snowflake Insert for v_fact_sales")
    print("=" * 70)
    print(f"Target: {SNOWFLAKE_CONFIG['database']}.{SNOWFLAKE_CONFIG['schema']}.v_fact_sales")
    print(f"Rows to insert: {NUM_ROWS:,}")
    print(f"Batch size: {BATCH_SIZE:,}")
    print()
    
    # Connect to Snowflake
    print("🔌 Connecting to Snowflake...")
    try:
        conn = snowflake.connector.connect(**SNOWFLAKE_CONFIG)
        cursor = conn.cursor()
        print("✅ Connected successfully!")
        print()
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        sys.exit(1)
    
    try:
        # Set context
        cursor.execute(f"USE DATABASE {SNOWFLAKE_CONFIG['database']}")
        cursor.execute(f"USE SCHEMA {SNOWFLAKE_CONFIG['schema']}")
        
        # Check if table exists
        cursor.execute("SHOW TABLES LIKE 'V_FACT_SALES'")
        if cursor.rowcount == 0:
            print("⚠️  Table V_FACT_SALES does not exist!")
            print("Creating table...")
            
            create_table_sql = """
            CREATE TABLE v_fact_sales (
                sales_sk BIGINT,
                site INTEGER,
                customer_no INTEGER,
                item_no INTEGER,
                posting_dt_sk INTEGER,
                invoice_no INTEGER,
                invoice_dt_sk INTEGER,
                qty_dec_equ DECIMAL(18, 6),
                cases INTEGER,
                bottles INTEGER,
                ship_dt TIMESTAMP_NTZ,
                posting_prd INTEGER,
                entry_origin VARCHAR(10),
                sequence_no INTEGER,
                unit_price DECIMAL(18, 4),
                ext_net DECIMAL(18, 4),
                ext_cost DECIMAL(18, 4),
                ext_depl_allow DECIMAL(18, 4),
                ext_participation DECIMAL(18, 4),
                ext_guaranteed_adj DECIMAL(18, 4),
                cqd_amt DECIMAL(18, 4),
                current_salesperson_sk BIGINT,
                salesman_no INTEGER,
                salesperson_sk BIGINT,
                customer_sk BIGINT,
                order_no INTEGER,
                load_dt TIMESTAMP_NTZ,
                deal_id VARCHAR(50),
                modified_dt TIMESTAMP_NTZ,
                warehouse_no INTEGER
            )
            """
            cursor.execute(create_table_sql)
            print("✅ Table created successfully!")
            print()
        
        # Prepare insert statement
        insert_sql = """
        INSERT INTO v_fact_sales
        (sales_sk, site, customer_no, item_no, posting_dt_sk, invoice_no, invoice_dt_sk,
         qty_dec_equ, cases, bottles, ship_dt, posting_prd, entry_origin, sequence_no,
         unit_price, ext_net, ext_cost, ext_depl_allow, ext_participation, ext_guaranteed_adj,
         cqd_amt, current_salesperson_sk, salesman_no, salesperson_sk, customer_sk, order_no,
         load_dt, deal_id, modified_dt, warehouse_no)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        # Generate and insert data in batches
        print(f"📊 Generating and inserting {NUM_ROWS:,} rows...")
        print()
        
        rows_inserted = 0
        batch_data = []
        
        for i in range(NUM_ROWS):
            row = generate_row()
            batch_data.append(row)
            
            # Insert batch when full
            if len(batch_data) >= BATCH_SIZE:
                cursor.executemany(insert_sql, batch_data)
                rows_inserted += len(batch_data)
                print(f"  ✓ Inserted {rows_inserted:,}/{NUM_ROWS:,} rows ({rows_inserted/NUM_ROWS*100:.1f}%)")
                batch_data = []
        
        # Insert remaining rows
        if batch_data:
            cursor.executemany(insert_sql, batch_data)
            rows_inserted += len(batch_data)
            print(f"  ✓ Inserted {rows_inserted:,}/{NUM_ROWS:,} rows (100.0%)")
        
        # Commit transaction
        conn.commit()
        
        print()
        print("=" * 70)
        print("✅ SUCCESS! Data inserted successfully!")
        print("=" * 70)
        print()
        
        # Verify data
        print("🔍 Verifying data...")
        cursor.execute("SELECT COUNT(*) FROM v_fact_sales")
        count = cursor.fetchone()[0]
        print(f"  Total rows in table: {count:,}")
        
        cursor.execute("""
            SELECT 
                entry_origin,
                COUNT(*) as count
            FROM v_fact_sales
            WHERE entry_origin IN ('H', 'G')
            GROUP BY entry_origin
            ORDER BY entry_origin
        """)
        proof_counts = cursor.fetchall()
        total_proof = sum(row[1] for row in proof_counts)
        print(f"  Proof transactions (H/G): {total_proof:,} ({total_proof/count*100:.1f}%)")
        
        cursor.execute("""
            SELECT 
                MIN(posting_dt_sk) as min_date,
                MAX(posting_dt_sk) as max_date,
                COUNT(DISTINCT customer_no) as unique_customers
            FROM v_fact_sales
        """)
        date_info = cursor.fetchone()
        print(f"  Date range: {date_info[0]} to {date_info[1]}")
        print(f"  Unique customers: {date_info[2]:,}")
        
        cursor.execute("SELECT COUNT(*) FROM v_fact_sales WHERE ext_net <= 0")
        invalid_count = cursor.fetchone()[0]
        print(f"  Invalid ext_net (<=0): {invalid_count} ✅")
        
        print()
        print("🎉 All done! Your data is ready for the RFM analysis workflow!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        conn.rollback()
        sys.exit(1)
    
    finally:
        cursor.close()
        conn.close()
        print()
        print("🔌 Connection closed.")

if __name__ == "__main__":
    main()

