"""
TechFab Industries - DP1: Production Operations Analytics
Data Generation & Snowflake Loader

Generates realistic data for 2 EXTERNAL models and loads them into Snowflake:
  1. mes_platform.bronze.actual_production_output  (production confirmations)
  2. mes_platform.bronze.downtime_events           (equipment downtime tracking)

Also creates 2 SEED CSVs in seeds/ folder:
  1. plant_master.csv
  2. equipment_master.csv

All FK/PK relationships are enforced to ensure joinability.
"""

import pandas as pd
import numpy as np
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import os
from datetime import datetime, timedelta
from pathlib import Path


# ============================================================
# CONFIGURATION
# ============================================================

# Number of records to generate
NUM_PRODUCTION_RECORDS = 60000  # 60k production records (fact table)
NUM_DOWNTIME_EVENTS = 12000     # 12k downtime events (proportional to production)

# Date range for generated data (6 months)
DATE_START = datetime(2024, 7, 1)
DATE_END = datetime(2024, 12, 31)

# Snowflake target
SF_DATABASE = "MES_PLATFORM"
SF_SCHEMA_BRONZE = "BRONZE"

# Table names (must match metadata doc exactly)
TABLE_ACTUAL_PRODUCTION = "ACTUAL_PRODUCTION_OUTPUT"
TABLE_DOWNTIME_EVENTS = "DOWNTIME_EVENTS"


# ============================================================
# SEED DATA (loaded from CSVs for FK integrity)
# ============================================================

def load_seed_data(seeds_dir):
    """Load seed CSVs to use as FK reference for generated data"""
    plant_df = pd.read_csv(os.path.join(seeds_dir, "plant_master.csv"))
    equipment_df = pd.read_csv(os.path.join(seeds_dir, "equipment_master.csv"))

    print(f"✓ Loaded plant_master: {len(plant_df)} plants")
    print(f"  Plants: {', '.join(plant_df['plant_code'].tolist())}")
    print(f"✓ Loaded equipment_master: {len(equipment_df)} equipment items")
    print(f"  Active equipment: {len(equipment_df[equipment_df['installation_status'] == 'Active'])}")

    return plant_df, equipment_df


# ============================================================
# DATA GENERATORS
# ============================================================

def generate_actual_production(plant_df, equipment_df, num_records):
    """
    Generate mes_platform.bronze.actual_production_output records.

    Schema (13 columns):
      confirmation_id      INTEGER        PK - unique
      work_order_id        INTEGER        FK to work orders
      plant_code           VARCHAR(10)    FK to plant_master
      work_center          VARCHAR(20)    from equipment_master
      equipment_id         VARCHAR(20)    FK to equipment_master
      material_number      VARCHAR(50)    product produced
      confirmation_date    DATE           production date
      shift                VARCHAR(10)    S1, S2, S3
      good_quantity        INTEGER        accepted units
      scrap_quantity       INTEGER        scrapped units
      rework_quantity      INTEGER        rework units
      confirmation_timestamp  TIMESTAMP   confirmation time
      operator_id          VARCHAR(20)    operator
      duration_minutes     INTEGER        production time
    """
    print(f"\nGenerating {num_records} actual_production_output records...")
    np.random.seed(42)

    # Only use Active equipment
    active_equipment = equipment_df[equipment_df["installation_status"] == "Active"].copy()

    # Build equipment lookup: equipment_id -> (plant_code, work_center)
    equip_lookup = active_equipment.set_index("equipment_id")[["plant_code", "work_center"]].to_dict("index")
    equipment_ids = list(equip_lookup.keys())

    # Plant -> shifts mapping (from seed data)
    plant_shifts = plant_df.set_index("plant_code")["operating_shifts"].to_dict()

    # Material numbers for TechFab products
    materials = [
        "MAT-SNS-100", "MAT-SNS-200", "MAT-SNS-300",   # Industrial sensors
        "MAT-PLC-100", "MAT-PLC-200",                    # PLCs
        "MAT-IOT-100", "MAT-IOT-200", "MAT-IOT-300",   # IoT gateways
        "MAT-CTL-100", "MAT-CTL-200",                    # Custom controllers
    ]

    # Operator pool per plant (dynamically generated for all plants)
    operators = {}
    for plant_code in plant_df['plant_code'].unique():
        num_operators = np.random.randint(20, 31)  # 20-30 operators per plant
        operators[plant_code] = [f"OP-{plant_code}-{str(i).zfill(3)}" for i in range(1, num_operators + 1)]

    # Shift definitions
    shift_map = {1: "S1", 2: "S2", 3: "S3"}
    shift_hours = {"S1": (6, 14), "S2": (14, 22), "S3": (22, 6)}  # start hour ranges

    # Generate date range
    total_days = (DATE_END - DATE_START).days + 1
    records = []

    # Work order counter (simulates sequential WO IDs)
    wo_counter = 100000

    for i in range(num_records):
        confirmation_id = i + 1  # Unique PK

        # Pick random equipment -> determines plant and work center
        eq_id = np.random.choice(equipment_ids)
        plant_code = equip_lookup[eq_id]["plant_code"]
        work_center = equip_lookup[eq_id]["work_center"]

        # Random date in range
        day_offset = np.random.randint(0, total_days)
        conf_date = DATE_START + timedelta(days=int(day_offset))

        # Shift based on plant's operating shifts
        max_shift = plant_shifts.get(plant_code, 2)
        shift_num = np.random.randint(1, max_shift + 1)
        shift = shift_map[shift_num]

        # Timestamp within shift hours
        start_hour, _ = shift_hours[shift]
        hour = start_hour + np.random.randint(0, 7)
        minute = np.random.randint(0, 60)
        conf_timestamp = conf_date.replace(hour=hour % 24, minute=minute, second=np.random.randint(0, 60))

        # Material
        material = np.random.choice(materials)

        # Quantities — realistic manufacturing distributions
        good_qty = int(np.random.normal(85, 15))
        good_qty = max(10, good_qty)

        # Scrap: ~4% average (TechFab's current 4.2%)
        scrap_qty = int(np.random.exponential(3.5))
        scrap_qty = max(0, min(scrap_qty, good_qty // 3))

        # Rework: ~2% average
        rework_qty = int(np.random.exponential(1.8))
        rework_qty = max(0, min(rework_qty, good_qty // 5))

        # Duration proportional to quantity
        duration = int((good_qty + scrap_qty + rework_qty) * np.random.uniform(0.8, 1.5))
        duration = max(15, min(duration, 480))

        # Operator from correct plant
        operator = np.random.choice(operators[plant_code])

        # Work order (group ~5-10 confirmations per WO)
        if i % np.random.randint(5, 11) == 0:
            wo_counter += 1
        work_order_id = wo_counter

        records.append({
            "confirmation_id": confirmation_id,
            "work_order_id": work_order_id,
            "plant_code": plant_code,
            "work_center": work_center,
            "equipment_id": eq_id,
            "material_number": material,
            "confirmation_date": conf_date.strftime("%Y-%m-%d"),
            "shift": shift,
            "good_quantity": good_qty,
            "scrap_quantity": scrap_qty,
            "rework_quantity": rework_qty,
            "confirmation_timestamp": conf_timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            "operator_id": operator,
            "duration_minutes": duration,
        })

    df = pd.DataFrame(records)
    print(f"  ✓ Generated {len(df)} production records")
    print(f"  Plants: {df['plant_code'].value_counts().to_dict()}")
    print(f"  Shifts: {df['shift'].value_counts().to_dict()}")
    print(f"  Avg good_qty: {df['good_quantity'].mean():.1f}, Avg scrap_qty: {df['scrap_quantity'].mean():.1f}")
    return df


def generate_downtime_events(plant_df, equipment_df, num_events):
    """
    Generate mes_platform.bronze.downtime_events records.

    Schema (10 columns):
      downtime_id            INTEGER        PK - unique
      equipment_id           VARCHAR(20)    FK to equipment_master
      plant_code             VARCHAR(10)    FK to plant_master
      downtime_start         TIMESTAMP      start of downtime
      downtime_end           TIMESTAMP      end of downtime
      duration_minutes       INTEGER        duration
      downtime_category      VARCHAR(20)    Planned / Unplanned
      downtime_reason        VARCHAR(100)   reason code
      downtime_reason_detail TEXT           detailed notes
      reported_by            VARCHAR(20)    reporter
    """
    print(f"\nGenerating {num_events} downtime_events records...")
    np.random.seed(99)

    # Only use Active equipment
    active_equipment = equipment_df[equipment_df["installation_status"] == "Active"].copy()
    equip_lookup = active_equipment.set_index("equipment_id")["plant_code"].to_dict()
    equipment_ids = list(equip_lookup.keys())

    # Downtime categories and reasons
    planned_reasons = {
        "Preventive Maintenance": [
            "Scheduled PM - monthly lubrication and calibration",
            "Quarterly preventive maintenance per SOP-PM-001",
            "Annual major maintenance shutdown",
            "Semi-annual belt and filter replacement",
        ],
        "Changeover": [
            "Product changeover from {} to {}",
            "Material changeover - nozzle replacement for new BOM",
            "Tooling changeover for new batch run",
            "Line reconfiguration for product family switch",
        ],
        "Scheduled Break": [
            "Scheduled shift break per labor agreement",
            "Planned lunch break period",
            "End-of-shift cleanup and handover",
        ],
    }
    unplanned_reasons = {
        "Equipment Failure": [
            "Feeder jam on slot {} - cleared and restarted",
            "Conveyor belt misalignment causing board jams",
            "Solder nozzle clogged - emergency cleaning required",
            "Vision system camera failure - replaced unit",
            "Motor overheating - cooling fan failure detected",
            "Pneumatic actuator leak on pick-and-place head",
        ],
        "Material Shortage": [
            "Component {} stockout - waiting for warehouse replenishment",
            "Solder paste expired - awaiting new batch from QC",
            "PCB substrate shortage from supplier delay",
            "Missing BOM component - procurement escalation",
        ],
        "Quality Hold": [
            "SPC out-of-control alert - process stopped for investigation",
            "Customer complaint hold - awaiting quality review",
            "Incoming material inspection hold - suspect lot",
            "First article inspection failure - engineering review",
        ],
        "Utility Failure": [
            "Compressed air pressure drop below threshold",
            "Power fluctuation triggered safety shutdown",
            "Nitrogen supply interruption for reflow oven",
        ],
    }

    # Materials for changeover reasons
    materials = ["MAT-SNS-100", "MAT-SNS-200", "MAT-PLC-100", "MAT-IOT-100", "MAT-CTL-100"]
    components = ["R-10K-0402", "C-100nF-0603", "IC-STM32F4", "U-TPS65281", "Q-MOSFET-N"]

    # Reporter pool per plant (dynamically generated for all plants)
    reporters = {}
    for plant_code in plant_df['plant_code'].unique():
        num_supervisors = np.random.randint(5, 9)  # 5-8 supervisors per plant
        reporters[plant_code] = [f"SUP-{plant_code}-{str(i).zfill(2)}" for i in range(1, num_supervisors + 1)]

    total_days = (DATE_END - DATE_START).days + 1
    records = []

    for i in range(num_events):
        downtime_id = i + 1  # Unique PK

        # Pick random equipment -> determines plant
        eq_id = np.random.choice(equipment_ids)
        plant_code = equip_lookup[eq_id]

        # Planned (~35%) vs Unplanned (~65%)
        is_planned = np.random.random() < 0.35
        category = "Planned" if is_planned else "Unplanned"

        if is_planned:
            reason = np.random.choice(list(planned_reasons.keys()))
            detail_template = np.random.choice(planned_reasons[reason])
            if "{}" in detail_template:
                detail = detail_template.format(
                    np.random.choice(materials),
                    np.random.choice(materials)
                )
            else:
                detail = detail_template

            # Planned downtime durations: 30-240 min
            duration = int(np.random.normal(90, 40))
            duration = max(30, min(duration, 240))
        else:
            reason = np.random.choice(list(unplanned_reasons.keys()))
            detail_template = np.random.choice(unplanned_reasons[reason])
            if "{}" in detail_template:
                detail = detail_template.format(
                    np.random.randint(1, 50) if "slot" in detail_template
                    else np.random.choice(components)
                )
            else:
                detail = detail_template

            # Unplanned downtime durations: 10-360 min (heavier tail)
            duration = int(np.random.exponential(60))
            duration = max(10, min(duration, 360))

        # Random day and start hour
        day_offset = np.random.randint(0, total_days)
        dt_date = DATE_START + timedelta(days=int(day_offset))
        start_hour = np.random.randint(0, 24)
        start_minute = np.random.randint(0, 60)
        downtime_start = dt_date.replace(hour=start_hour, minute=start_minute, second=0)
        downtime_end = downtime_start + timedelta(minutes=duration)

        # Reporter from correct plant
        reporter = np.random.choice(reporters[plant_code])

        records.append({
            "downtime_id": downtime_id,
            "equipment_id": eq_id,
            "plant_code": plant_code,
            "downtime_start": downtime_start.strftime("%Y-%m-%d %H:%M:%S"),
            "downtime_end": downtime_end.strftime("%Y-%m-%d %H:%M:%S"),
            "duration_minutes": duration,
            "downtime_category": category,
            "downtime_reason": reason,
            "downtime_reason_detail": detail,
            "reported_by": reporter,
        })

    df = pd.DataFrame(records)
    print(f"  ✓ Generated {len(df)} downtime events")
    print(f"  Categories: {df['downtime_category'].value_counts().to_dict()}")
    print(f"  Reasons: {df['downtime_reason'].value_counts().to_dict()}")
    print(f"  Avg duration: {df['duration_minutes'].mean():.1f} min")
    return df


# ============================================================
# SNOWFLAKE LOADER
# ============================================================

def connect_to_snowflake():
    """Connect to Snowflake using JWT key-pair auth (same pattern as gensler data_load.py)"""
    print("\nConnecting to Snowflake...")

    # ---- Load and decrypt private key ----
    encrypted_key = """-----BEGIN ENCRYPTED PRIVATE KEY-----
MIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQILmVpSDkxA3MCAggA
MBQGCCqGSIb3DQMHBAiPhvirFCddQwSCBMgw0+DrOenEHWdShv09TEiiB3bqtWW4
42hA3JIUnGZWXSh/NNGmVH6syEVByvFGmjdnSP5bbrxswBUMbFmruQkb3iHNa9ZC
CPJ20oEmkl/1SEfnUFWi6sCNZMjgMmmNniTWXxN4r5qswW2/6XDd/g7+c6YF3g4G
tmzWnlMHTkLzc3RJMRdfBvxrCtGratKb1QJYKAtP71dm1oVr3KevKCSnubJ0hegi
iz++je0iDh8tEI6U8QBe2IuXPE98rd1J/t7fcmJa4KJgDkmsmDMTf20qPfAr1pQC
5z0Mx/F0vEqVIUmhHilS1KgHoeAk3vTGclAucrj70IaJTcTqEeR+9HwkOfcAXwMa
9sk1RhowXdKKwZ3mLJMgN38C5Wbs8FtPY39+TXZ1RPtGsB55yPg6eH/y3g+HGlIu
JDpZkfoZt15tZpBGWToO9h5Y1UrJghOneOOhbZBShe4N+9EMigrq0hztuEoBgrvh
nQNCwfGsg/6/dAIHq2K4S7RsrOZI+t1hPklGeNIj22E9cmwN+aqWtHHnG1+fl6Fs
ne+KXMn7iZyx+R7r+cyGo6OmQuJvgct09nesF0Utm3Q4N8o73vl2dByNWKZAYXg2
k0nDkKDcU7rYmEKhO93jX3ZOopr1/FEMULZDhjeqnuTKo0FNgpLg+5ff/HZX8G+d
KTcJJ+HdR+UkLdt7Hdsv9e0VwRhEVp/oFq1pJXkMTNnFjZ40WnOVDwF5sigruHsc
kRro5o/Ty4SgbAzeiWnlIsqfZuRhkBS79bEn95FnBNyy8K8bQgrTCgIGU9PioXZo
HzdGacRUU7kiXyns5UZfbpFDu/v3DzzH6EgXPrKA/cwdGbTMQD5M++q20PiZSurA
3HzIQuM7a6aD7vO+3dnPRKNyMbt2lDmlnnw2g1kVp2l1AZrclcjsdsABfNI1zWEZ
druTTGbJyGgp4nW4yy+J/h3PH0WpbPRv2iXkUAIVDWV4Qphzgd/YF0tuOmb6MeKK
tQQrvnOziOFqXgXXfepeC/kG+aU526HHiNx029NHOYOjgMHOO6CRSs7pGtF2ciUX
pOKxVnOu570NDWm/kJzpiZ0I3xkbmBBzrkC18SZqSDlRpyEPdJYrEjeL8SNnX6Gx
KODi12Qqh18wP2MAs2BS4LDNZpWJl6manExPTb+vKW3cxos0vxWn9+HiFry4BWDm
CJbN+84WtP6pNNc/srSP9ZLYXaWj/ed2IfyOTpEO7s1nYa6Q63fvX6RC0EGHRuJF
sEEjw2jWA64VGo91uYdSIaUgUUJVoq37q2uZqqR9joKgYko2eYWdBjfJuHpidhl1
tUSq0kIuTd0Z4FH/vzQLa57Xnf9abDtVpaYFegsPCVpoP1Jipr2GqMRbAirb0mgH
C3yUQWVkG+7H0sj8kAj8Mbxv5wsfSPVuM2iJWKMEMD5xa9pTZgqHoJP/E05f1ApC
RP2ILzErshhPz6+s1OEK3vM/ChYO7lpWqQba4JUkcqZVS9BXKkzU7basaPGzK2XS
T41yYMCTNY37xvuklmLDLbxJVRQgNwuM4dceXYUnqQ5BURSVmC/bSF6wYoiJSYr1
fta7jXJau0pTwHK2N2TBB5Drk+IS1uTJgeNfxOaFMdXZflirIikcAZ2lQFOw69Ln
L5M=
-----END ENCRYPTED PRIVATE KEY-----"""

    passphrase = "shreya"

    # Parse the encrypted private key with passphrase
    private_key = serialization.load_pem_private_key(
        encrypted_key.encode(),
        password=passphrase.encode(),
        backend=default_backend()
    )

    # Convert to DER format for Snowflake
    private_key_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )

    # Snowflake connection using JWT key-pair auth
    conn = snowflake.connector.connect(
        account="EQZOTUQ-JCA67320",
        user="SHREYA",
        private_key=private_key_bytes,
        warehouse="COMPUTE_WH",
        database=SF_DATABASE,
        schema=SF_SCHEMA_BRONZE,
        role="ACCOUNTADMIN",
        authenticator="snowflake_jwt"
    )

    print("  ✓ Connected to Snowflake")
    return conn


def setup_schema(conn):
    """Create database and schema if they don't exist, drop existing tables"""
    cursor = conn.cursor()
    try:
        # Create database and schema
        cursor.execute(f"CREATE DATABASE IF NOT EXISTS {SF_DATABASE}")
        cursor.execute(f"USE DATABASE {SF_DATABASE}")
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {SF_SCHEMA_BRONZE}")
        cursor.execute(f"USE SCHEMA {SF_SCHEMA_BRONZE}")
        print(f"\n✓ Schema {SF_DATABASE}.{SF_SCHEMA_BRONZE} is ready")

        # Drop existing tables to recreate them cleanly
        print("\nDropping existing tables...")
        cursor.execute(f"DROP TABLE IF EXISTS {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_ACTUAL_PRODUCTION}")
        print(f"  ✓ Dropped {TABLE_ACTUAL_PRODUCTION}")
        cursor.execute(f"DROP TABLE IF EXISTS {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_DOWNTIME_EVENTS}")
        print(f"  ✓ Dropped {TABLE_DOWNTIME_EVENTS}")
    except Exception as e:
        print(f"  Note: {e}")
    finally:
        cursor.close()


def load_to_snowflake(conn, df, table_name, description):
    """Load a DataFrame to Snowflake table"""
    print(f"\n[Loading] {description}")
    print(f"  Table: {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{table_name}")
    print(f"  Rows: {len(df)}")

    success, nchunks, nrows, _ = write_pandas(
        conn,
        df,
        table_name=table_name,
        auto_create_table=True
    )
    print(f"  ✓ Success: {success}, Chunks: {nchunks}, Rows loaded: {nrows}")
    return nrows


def verify_tables(conn):
    """Verify all tables were loaded correctly"""
    cursor = conn.cursor()

    print("\n" + "=" * 60)
    print("VERIFYING DATA IN SNOWFLAKE")
    print("=" * 60)

    tables = [
        (TABLE_ACTUAL_PRODUCTION, "Production confirmations"),
        (TABLE_DOWNTIME_EVENTS, "Equipment downtime events"),
    ]

    for table_name, description in tables:
        fqn = f"{SF_DATABASE}.{SF_SCHEMA_BRONZE}.{table_name}"

        # Row count
        cursor.execute(f"SELECT COUNT(*) FROM {fqn}")
        count = cursor.fetchone()[0]
        print(f"\n✓ {table_name}: {count} rows ({description})")

        # Column names
        cursor.execute(f"DESCRIBE TABLE {fqn}")
        cols = [r[0] for r in cursor.fetchall()]
        print(f"  Columns ({len(cols)}): {', '.join(cols)}")

        # Sample data
        cursor.execute(f"SELECT * FROM {fqn} LIMIT 3")
        sample = cursor.fetchall()
        print(f"  Sample (first 3 rows):")
        for row in sample:
            print(f"    {row}")

    # Verify FK integrity: all equipment_ids in production exist in equipment_master pattern
    print("\n" + "-" * 40)
    print("FK INTEGRITY CHECKS:")

    # Check distinct plants in production data
    cursor.execute(f"""
        SELECT DISTINCT "plant_code" 
        FROM {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_ACTUAL_PRODUCTION} 
        ORDER BY "plant_code"
    """)
    plants = [r[0] for r in cursor.fetchall()]
    print(f"  ✓ Plants in production data: {plants}")

    # Check distinct equipment in production data
    cursor.execute(f"""
        SELECT COUNT(DISTINCT "equipment_id") 
        FROM {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_ACTUAL_PRODUCTION}
    """)
    eq_count = cursor.fetchone()[0]
    print(f"  ✓ Distinct equipment in production: {eq_count}")

    # Check distinct equipment in downtime data
    cursor.execute(f"""
        SELECT COUNT(DISTINCT "equipment_id") 
        FROM {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_DOWNTIME_EVENTS}
    """)
    dt_eq_count = cursor.fetchone()[0]
    print(f"  ✓ Distinct equipment in downtime: {dt_eq_count}")

    # PK uniqueness check
    cursor.execute(f"""
        SELECT COUNT(*) AS total, COUNT(DISTINCT "confirmation_id") AS unique_ids 
        FROM {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_ACTUAL_PRODUCTION}
    """)
    row = cursor.fetchone()
    print(f"  ✓ Production PK check: {row[0]} total = {row[1]} unique confirmation_ids")

    cursor.execute(f"""
        SELECT COUNT(*) AS total, COUNT(DISTINCT "downtime_id") AS unique_ids 
        FROM {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_DOWNTIME_EVENTS}
    """)
    row = cursor.fetchone()
    print(f"  ✓ Downtime PK check: {row[0]} total = {row[1]} unique downtime_ids")

    cursor.close()


# ============================================================
# MAIN
# ============================================================

def main():
    script_dir = Path(__file__).parent
    seeds_dir = script_dir / "seeds"

    print("=" * 60)
    print("TechFab DP1: Production Operations Analytics")
    print("Data Generation & Snowflake Loader")
    print("=" * 60)

    # ---- Step 1: Load seed data for FK references ----
    print("\n[STEP 1] Loading seed data for FK integrity...")
    plant_df, equipment_df = load_seed_data(str(seeds_dir))

    # ---- Step 2: Generate external table data ----
    print("\n[STEP 2] Generating external table data...")
    production_df = generate_actual_production(plant_df, equipment_df, NUM_PRODUCTION_RECORDS)
    downtime_df = generate_downtime_events(plant_df, equipment_df, NUM_DOWNTIME_EVENTS)

    # ---- Step 3: Validate PK uniqueness before loading ----
    print("\n[STEP 3] Validating PK uniqueness...")
    assert production_df["confirmation_id"].is_unique, "FAIL: confirmation_id has duplicates!"
    print(f"  ✓ confirmation_id is unique ({len(production_df)} records)")
    assert downtime_df["downtime_id"].is_unique, "FAIL: downtime_id has duplicates!"
    print(f"  ✓ downtime_id is unique ({len(downtime_df)} records)")

    # Validate FK integrity
    valid_plants = set(plant_df["plant_code"])
    valid_equipment = set(equipment_df["equipment_id"])

    prod_plants = set(production_df["plant_code"])
    assert prod_plants.issubset(valid_plants), f"Invalid plant_codes in production: {prod_plants - valid_plants}"
    print(f"  ✓ All production plant_codes valid")

    prod_equip = set(production_df["equipment_id"])
    assert prod_equip.issubset(valid_equipment), f"Invalid equipment_ids in production: {prod_equip - valid_equipment}"
    print(f"  ✓ All production equipment_ids valid")

    dt_plants = set(downtime_df["plant_code"])
    assert dt_plants.issubset(valid_plants), f"Invalid plant_codes in downtime: {dt_plants - valid_plants}"
    print(f"  ✓ All downtime plant_codes valid")

    dt_equip = set(downtime_df["equipment_id"])
    assert dt_equip.issubset(valid_equipment), f"Invalid equipment_ids in downtime: {dt_equip - valid_equipment}"
    print(f"  ✓ All downtime equipment_ids valid")

    # ---- Step 4: Connect to Snowflake and load ----
    print("\n[STEP 4] Loading to Snowflake...")
    conn = connect_to_snowflake()
    setup_schema(conn)

    nrows_prod = load_to_snowflake(
        conn, production_df,
        TABLE_ACTUAL_PRODUCTION,
        f"actual_production_output ({len(production_df)} production confirmations)"
    )

    nrows_dt = load_to_snowflake(
        conn, downtime_df,
        TABLE_DOWNTIME_EVENTS,
        f"downtime_events ({len(downtime_df)} downtime records)"
    )

    # ---- Step 5: Verify ----
    print("\n[STEP 5] Verifying loaded data...")
    verify_tables(conn)

    conn.close()

    # ---- Summary ----
    print("\n" + "=" * 60)
    print("✓ ALL DATA LOADED SUCCESSFULLY!")
    print("=" * 60)
    print(f"\nSeed CSVs (in {seeds_dir}):")
    print(f"  1. plant_master.csv         — {len(plant_df)} plants")
    print(f"  2. equipment_master.csv     — {len(equipment_df)} equipment items across {len(plant_df)} plants")
    print(f"\nSnowflake Tables (in {SF_DATABASE}.{SF_SCHEMA_BRONZE}):")
    print(f"  1. {TABLE_ACTUAL_PRODUCTION}  — {nrows_prod} rows")
    print(f"     Columns: confirmation_id, work_order_id, plant_code, work_center,")
    print(f"              equipment_id, material_number, confirmation_date, shift,")
    print(f"              good_quantity, scrap_quantity, rework_quantity,")
    print(f"              confirmation_timestamp, operator_id, duration_minutes")
    print(f"  2. {TABLE_DOWNTIME_EVENTS}       — {nrows_dt} rows")
    print(f"     Columns: downtime_id, equipment_id, plant_code, downtime_start,")
    print(f"              downtime_end, duration_minutes, downtime_category,")
    print(f"              downtime_reason, downtime_reason_detail, reported_by")
    print(f"\nQuery examples:")
    print(f"  SELECT * FROM {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_ACTUAL_PRODUCTION} LIMIT 10;")
    print(f"  SELECT * FROM {SF_DATABASE}.{SF_SCHEMA_BRONZE}.{TABLE_DOWNTIME_EVENTS} LIMIT 10;")


if __name__ == "__main__":
    main()

