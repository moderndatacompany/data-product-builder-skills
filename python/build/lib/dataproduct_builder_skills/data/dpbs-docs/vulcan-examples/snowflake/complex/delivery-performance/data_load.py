"""
Quick-commerce delivery performance demo data generator and Snowflake loader.

This script creates demo source data for:
  1. QCOMMERCE_PLATFORM.EXT_RAW.ORDERS
  2. QCOMMERCE_PLATFORM.EXT_RAW.SHIPMENTS
  3. QCOMMERCE_PLATFORM.EXT_RAW.CUSTOMERS

It also validates the local seed file:
  - seeds/city_sla_rules.csv

Required environment variables:
  SNOWFLAKE_ACCOUNT
  SNOWFLAKE_USER
  SNOWFLAKE_PASSWORD

Optional environment variables:
  SNOWFLAKE_WAREHOUSE
  SNOWFLAKE_ROLE
"""

from __future__ import annotations

import argparse
import os
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas


NUM_CUSTOMERS = 3500
NUM_ORDERS = 15000
DATE_START = datetime(2026, 4, 1)
DATE_END = datetime(2026, 4, 15, 23, 59, 59)

SF_DATABASE = "QCOMMERCE_PLATFORM"
SF_SCHEMA_EXT_RAW = "EXT_RAW"
TABLE_ORDERS = "ORDERS"
TABLE_SHIPMENTS = "SHIPMENTS"
TABLE_CUSTOMERS = "CUSTOMERS"

CITIES = ["Bengaluru", "Mumbai", "Delhi", "Hyderabad", "Chennai", "Pune"]
CITY_WEIGHTS = np.array([0.25, 0.20, 0.18, 0.15, 0.12, 0.10])
DELIVERY_MODES = ["standard", "express"]
DELIVERY_MODE_WEIGHTS = np.array([0.72, 0.28])
CUSTOMER_TIERS = ["STANDARD", "PREMIUM", "VIP"]
CUSTOMER_TIER_WEIGHTS = np.array([0.68, 0.22, 0.10])

CITY_ISSUE_PROFILES = {
    "Bengaluru": {"late": 0.16, "missing_scan": 0.04, "failed": 0.03, "address_issue": 0.02},
    "Mumbai": {"late": 0.06, "missing_scan": 0.03, "failed": 0.02, "address_issue": 0.01},
    "Delhi": {"late": 0.11, "missing_scan": 0.12, "failed": 0.03, "address_issue": 0.03},
    "Hyderabad": {"late": 0.07, "missing_scan": 0.03, "failed": 0.02, "address_issue": 0.02},
    "Chennai": {"late": 0.05, "missing_scan": 0.02, "failed": 0.02, "address_issue": 0.01},
    "Pune": {"late": 0.04, "missing_scan": 0.02, "failed": 0.02, "address_issue": 0.01},
}

RIDER_POOLS = {
    "Bengaluru": ["R101", "R102", "R103", "R105", "R106", "R107"],
    "Mumbai": ["R108", "R109", "R110", "R111", "R112", "R113"],
    "Delhi": ["R114", "R115", "R116", "R117", "R118", "R119"],
    "Hyderabad": ["R104", "R120", "R121", "R122", "R123", "R124"],
    "Chennai": ["R125", "R126", "R127", "R128", "R129"],
    "Pune": ["R130", "R131", "R132", "R133", "R134"],
}

FIRST_NAMES = [
    "Aarav", "Vivaan", "Aditya", "Vihaan", "Arjun", "Sai", "Reyansh", "Krish",
    "Ananya", "Diya", "Aadhya", "Myra", "Ira", "Sara", "Meera", "Kiara",
]
LAST_NAMES = [
    "Sharma", "Verma", "Patel", "Reddy", "Nair", "Rao", "Kapoor", "Mehta",
    "Yadav", "Gupta", "Singh", "Iyer", "Das", "Kulkarni", "Jain", "Mishra",
]

SCENARIO_PROFILES = {
    "pass_all_checks": {
        "late_multiplier": 0.92,
        "missing_scan_multiplier": 0.90,
        "failed_multiplier": 0.90,
        "address_issue_multiplier": 0.95,
        "express_late_boost": 0.02,
        "mumbai_vip_late_boost": 0.04,
        "mumbai_premium_late_boost": 0.01,
        "r104_late_boost": 0.14,
        "r104_failed_boost": 0.03,
        "city_boosts": {},
    },
    "fail_checks": {
        "late_multiplier": 1.55,
        "missing_scan_multiplier": 1.45,
        "failed_multiplier": 1.35,
        "address_issue_multiplier": 1.20,
        "express_late_boost": 0.05,
        "mumbai_vip_late_boost": 0.08,
        "mumbai_premium_late_boost": 0.03,
        "r104_late_boost": 0.30,
        "r104_failed_boost": 0.08,
        "city_boosts": {
            "Bengaluru": {"late": 0.08},
            "Hyderabad": {"late": 0.10, "failed": 0.03},
            "Delhi": {"missing_scan": 0.10},
        },
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and load delivery-performance demo data.")
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--fail-checks",
        action="store_true",
        help="Generate data that fails a few business checks without violating model assertions.",
    )
    mode_group.add_argument(
        "--pass-all-checks",
        action="store_true",
        help="Generate data intended to pass the business checks.",
    )
    return parser.parse_args()


def load_sla_rules(seeds_dir: Path) -> pd.DataFrame:
    path = seeds_dir / "city_sla_rules.csv"
    if not path.exists():
        raise FileNotFoundError(f"Missing seed file: {path}")
    df = pd.read_csv(path)
    print(f"Loaded SLA seed with {len(df)} rows from {path}")
    return df


def random_timestamp(rng: np.random.Generator) -> datetime:
    total_seconds = int((DATE_END - DATE_START).total_seconds())
    return DATE_START + timedelta(seconds=int(rng.integers(0, total_seconds + 1)))


def build_customers(rng: np.random.Generator) -> pd.DataFrame:
    signup_city = rng.choice(CITIES, size=NUM_CUSTOMERS, p=CITY_WEIGHTS)
    tiers = rng.choice(CUSTOMER_TIERS, size=NUM_CUSTOMERS, p=CUSTOMER_TIER_WEIGHTS)
    is_active = rng.choice([True, False], size=NUM_CUSTOMERS, p=[0.96, 0.04])

    records = []
    for idx in range(NUM_CUSTOMERS):
        first = FIRST_NAMES[idx % len(FIRST_NAMES)]
        last = LAST_NAMES[(idx * 3) % len(LAST_NAMES)]
        records.append(
            {
                "CUSTOMER_ID": f"C{idx + 1:05d}",
                "CUSTOMER_NAME": f"{first} {last}",
                "CUSTOMER_TIER": tiers[idx],
                "SIGNUP_CITY": signup_city[idx],
                "IS_ACTIVE": bool(is_active[idx]),
            }
        )

    df = pd.DataFrame(records)
    print(f"Generated {len(df):,} customers")
    return df


def build_orders(customers_df: pd.DataFrame, sla_rules_df: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    customer_lookup = customers_df.set_index("CUSTOMER_ID").to_dict("index")
    customer_ids = customers_df["CUSTOMER_ID"].tolist()

    tier_amount_ranges = {
        "STANDARD": (120, 650),
        "PREMIUM": (250, 1200),
        "VIP": (500, 2200),
    }
    payment_statuses = ["paid", "captured", "settled", "pending", "refunded", "failed"]
    payment_weights = np.array([0.48, 0.20, 0.16, 0.07, 0.05, 0.04])

    sla_lookup = {
        (row.CITY, row.DELIVERY_MODE): int(row.SLA_MINUTES)
        for row in sla_rules_df.itertuples(index=False)
    }

    records = []
    for idx in range(NUM_ORDERS):
        customer_id = customer_ids[int(rng.integers(0, len(customer_ids)))]
        customer = customer_lookup[customer_id]
        city = rng.choice(CITIES, p=CITY_WEIGHTS)
        tier = customer["CUSTOMER_TIER"]
        delivery_mode = rng.choice(DELIVERY_MODES, p=DELIVERY_MODE_WEIGHTS)
        order_ts = random_timestamp(rng)
        min_amount, max_amount = tier_amount_ranges[tier]
        amount = round(float(rng.uniform(min_amount, max_amount)), 2)
        payment_status = str(rng.choice(payment_statuses, p=payment_weights))

        # Force a slight premium/express bias into Mumbai VIP traffic.
        if city == "Mumbai" and tier == "VIP" and rng.random() < 0.25:
            delivery_mode = "express"

        records.append(
            {
                "ORDER_ID": f"O{idx + 1:06d}",
                "CUSTOMER_ID": customer_id,
                "CITY": city,
                "ORDER_TS": order_ts.strftime("%Y-%m-%d %H:%M:%S"),
                "ORDER_AMOUNT": amount,
                "PAYMENT_STATUS": payment_status,
                "DELIVERY_MODE": delivery_mode,
                "META_CUSTOMER_TIER": tier,
                "META_SLA_MINUTES": sla_lookup[(city, delivery_mode)],
            }
        )

    df = pd.DataFrame(records)
    print(f"Generated {len(df):,} orders")
    return df


def _choose_rider(city: str, rng: np.random.Generator) -> str:
    riders = RIDER_POOLS[city]
    if city == "Hyderabad" and rng.random() < 0.30:
        return "R104"
    return str(rng.choice(riders))


def _city_issue_probabilities(
    city: str,
    tier: str,
    delivery_mode: str,
    rider_id: str,
    scenario: str,
) -> dict[str, float]:
    profile = SCENARIO_PROFILES[scenario]
    probs = {
        "late": CITY_ISSUE_PROFILES[city]["late"] * profile["late_multiplier"],
        "missing_scan": CITY_ISSUE_PROFILES[city]["missing_scan"] * profile["missing_scan_multiplier"],
        "failed": CITY_ISSUE_PROFILES[city]["failed"] * profile["failed_multiplier"],
        "address_issue": CITY_ISSUE_PROFILES[city]["address_issue"] * profile["address_issue_multiplier"],
    }

    if delivery_mode == "express":
        probs["late"] += profile["express_late_boost"]
    if city == "Mumbai" and tier == "VIP":
        probs["late"] += profile["mumbai_vip_late_boost"]
    if city == "Mumbai" and tier == "PREMIUM":
        probs["late"] += profile["mumbai_premium_late_boost"]
    if rider_id == "R104":
        probs["late"] += profile["r104_late_boost"]
        probs["failed"] += profile["r104_failed_boost"]

    for issue_name, boost in profile["city_boosts"].get(city, {}).items():
        probs[issue_name] += boost

    capped = {}
    for key, value in probs.items():
        capped[key] = min(max(value, 0.0), 0.45)
    return capped


def build_shipments(
    orders_df: pd.DataFrame,
    rng: np.random.Generator,
    scenario: str,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    shipment_records = []
    outcome_records = []
    shipment_counter = 1

    for row in orders_df.itertuples(index=False):
        order_ts = datetime.strptime(row.ORDER_TS, "%Y-%m-%d %H:%M:%S")
        rider_id = _choose_rider(row.CITY, rng)
        probs = _city_issue_probabilities(
            row.CITY,
            row.META_CUSTOMER_TIER,
            row.DELIVERY_MODE,
            rider_id,
            scenario,
        )

        pickup_delay = int(rng.integers(4, 16))
        pickup_ts = order_ts + timedelta(minutes=pickup_delay)
        status = "delivered"
        delivered_ts = None
        scan_count = int(rng.integers(2, 7))
        simulated_issue_type = "on_time"

        roll = rng.random()
        fail_cutoff = probs["failed"]
        address_cutoff = fail_cutoff + probs["address_issue"]

        if roll < fail_cutoff:
            status = str(rng.choice(["failed", "delivery_failed"]))
            simulated_issue_type = "failed_delivery"
            if rng.random() < 0.35:
                scan_count = 0
        elif roll < address_cutoff:
            status = "address_issue"
            simulated_issue_type = "address_issue"
            if rng.random() < 0.20:
                scan_count = 0
        else:
            missing_scan = rng.random() < probs["missing_scan"]
            late = rng.random() < probs["late"]
            if missing_scan:
                simulated_issue_type = "missing_scan"
                scan_count = 0
            if late and simulated_issue_type == "on_time":
                simulated_issue_type = "late_delivery"

            if late:
                total_minutes_from_order = int(row.META_SLA_MINUTES + rng.integers(5, 45))
            else:
                early_buffer = int(rng.integers(3, 12))
                total_minutes_from_order = max(10, row.META_SLA_MINUTES - early_buffer)
            delivered_ts = order_ts + timedelta(minutes=total_minutes_from_order)

        shipment_records.append(
            {
                "SHIPMENT_ID": f"S{shipment_counter:06d}",
                "ORDER_ID": row.ORDER_ID,
                "RIDER_ID": rider_id,
                "PICKUP_TS": pickup_ts.strftime("%Y-%m-%d %H:%M:%S"),
                "DELIVERED_TS": delivered_ts.strftime("%Y-%m-%d %H:%M:%S") if delivered_ts else None,
                "SHIPMENT_STATUS": status,
                "SCAN_COUNT": scan_count,
            }
        )
        shipment_counter += 1

        # Add a small fraction of prior failed attempts to mimic shipment retries.
        if status == "delivered" and rng.random() < 0.04:
            failed_pickup = pickup_ts - timedelta(minutes=int(rng.integers(45, 180)))
            shipment_records.append(
                {
                    "SHIPMENT_ID": f"S{shipment_counter:06d}",
                    "ORDER_ID": row.ORDER_ID,
                    "RIDER_ID": rider_id,
                    "PICKUP_TS": failed_pickup.strftime("%Y-%m-%d %H:%M:%S"),
                    "DELIVERED_TS": None,
                    "SHIPMENT_STATUS": "failed",
                    "SCAN_COUNT": int(rng.integers(0, 3)),
                }
            )
            shipment_counter += 1

        outcome_records.append(
            {
                "ORDER_ID": row.ORDER_ID,
                "CITY": row.CITY,
                "CUSTOMER_TIER": row.META_CUSTOMER_TIER,
                "DELIVERY_MODE": row.DELIVERY_MODE,
                "RIDER_ID": rider_id,
                "SLA_MINUTES": row.META_SLA_MINUTES,
                "SHIPMENT_STATUS": status,
                "DELIVERED_TS": delivered_ts,
                "ORDER_TS": order_ts,
                "SCAN_COUNT": scan_count,
                "SIMULATED_ISSUE_TYPE": simulated_issue_type,
            }
        )

    shipment_df = pd.DataFrame(shipment_records)
    outcome_df = pd.DataFrame(outcome_records)
    print(f"Generated {len(shipment_df):,} shipment attempts for {len(outcome_df):,} orders")
    return shipment_df, outcome_df


def connect_to_snowflake():
    required = ["SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD"]
    missing = [key for key in required if not os.getenv(key)]
    if missing:
        raise RuntimeError(f"Missing environment variables: {', '.join(missing)}")

    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        role=os.getenv("SNOWFLAKE_ROLE"),
    )
    print("Connected to Snowflake")
    return conn


def setup_schemas(conn) -> None:
    cursor = conn.cursor()
    try:
        cursor.execute(f"CREATE DATABASE IF NOT EXISTS {SF_DATABASE}")
        cursor.execute(f"USE DATABASE {SF_DATABASE}")
        for schema_name in ["EXT_RAW", "BRONZE", "SILVER", "GOLD", "SEMANTIC"]:
            cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema_name}")
        cursor.execute(f"USE SCHEMA {SF_SCHEMA_EXT_RAW}")
        cursor.execute(f"DROP TABLE IF EXISTS {TABLE_ORDERS}")
        cursor.execute(f"DROP TABLE IF EXISTS {TABLE_SHIPMENTS}")
        cursor.execute(f"DROP TABLE IF EXISTS {TABLE_CUSTOMERS}")
    finally:
        cursor.close()
    print(f"Prepared {SF_DATABASE}.{SF_SCHEMA_EXT_RAW}")


def load_dataframe(conn, df: pd.DataFrame, table_name: str) -> None:
    df = df.copy()
    df.columns = [column.upper() for column in df.columns]
    success, _, rows_loaded, _ = write_pandas(
        conn,
        df,
        table_name=table_name,
        database=SF_DATABASE,
        schema=SF_SCHEMA_EXT_RAW,
        auto_create_table=True,
        quote_identifiers=False,
    )
    if not success:
        raise RuntimeError(f"Failed to load table {table_name}")
    print(f"Loaded {rows_loaded:,} rows into {SF_DATABASE}.{SF_SCHEMA_EXT_RAW}.{table_name}")


def print_business_preview(outcomes_df: pd.DataFrame) -> None:
    preview_df = outcomes_df.copy()
    preview_df["IS_FAILED_DELIVERY"] = preview_df["SHIPMENT_STATUS"].isin(["failed", "delivery_failed"])
    preview_df["IS_LATE"] = (
        (preview_df["DELIVERED_TS"].notna())
        & ((preview_df["DELIVERED_TS"] - preview_df["ORDER_TS"]).dt.total_seconds() / 60 > preview_df["SLA_MINUTES"])
    )

    city_kpis = (
        preview_df.groupby("CITY")
        .agg(
            TOTAL_ORDERS=("ORDER_ID", "count"),
            LATE_ORDERS=("IS_LATE", "sum"),
            FAILED_ORDERS=("IS_FAILED_DELIVERY", "sum"),
        )
        .reset_index()
    )
    city_kpis["SLA_BREACH_RATE"] = ((city_kpis["LATE_ORDERS"] + city_kpis["FAILED_ORDERS"]) / city_kpis["TOTAL_ORDERS"]).round(4)
    print("\nCity breach preview:")
    print(city_kpis.sort_values("SLA_BREACH_RATE", ascending=False).head(6).to_string(index=False))

    mumbai_tiers = (
        preview_df[preview_df["CITY"] == "Mumbai"]
        .groupby("CUSTOMER_TIER")
        .agg(TOTAL_ORDERS=("ORDER_ID", "count"), LATE_DELIVERY_RATE=("IS_LATE", "mean"))
        .reset_index()
    )
    print("\nMumbai customer tier preview:")
    print(mumbai_tiers.to_string(index=False))

    hyderabad_riders = (
        preview_df[preview_df["CITY"] == "Hyderabad"]
        .groupby("RIDER_ID")
        .agg(
            ORDERS_HANDLED=("ORDER_ID", "count"),
            ON_TIME_RATE=("IS_LATE", lambda s: round(1 - float(s.mean()), 4)),
        )
        .reset_index()
        .sort_values(["ORDERS_HANDLED", "ON_TIME_RATE"], ascending=[False, True])
    )
    print("\nHyderabad rider preview:")
    print(hyderabad_riders.head(5).to_string(index=False))

    delhi_issues = (
        preview_df[preview_df["CITY"] == "Delhi"]
        .groupby("SIMULATED_ISSUE_TYPE")
        .agg(ISSUE_COUNT=("ORDER_ID", "count"))
        .reset_index()
        .sort_values("ISSUE_COUNT", ascending=False)
    )
    print("\nDelhi issue preview:")
    print(delhi_issues.to_string(index=False))


def main() -> None:
    args = parse_args()
    scenario = "fail_checks" if args.fail_checks else "pass_all_checks"
    script_dir = Path(__file__).parent
    seeds_dir = script_dir / "seeds"

    print("=" * 72)
    print("Delivery Performance Analytics")
    print("Quick-commerce demo data generation and Snowflake loading")
    print(f"Scenario: {scenario}")
    print("=" * 72)

    rng = np.random.default_rng(42)
    sla_rules_df = load_sla_rules(seeds_dir)
    customers_df = build_customers(rng)
    orders_df = build_orders(customers_df, sla_rules_df, rng)
    shipments_df, outcomes_df = build_shipments(orders_df, rng, scenario)

    print_business_preview(outcomes_df)

    ext_orders_df = orders_df.drop(columns=["META_CUSTOMER_TIER", "META_SLA_MINUTES"])

    conn = connect_to_snowflake()
    try:
        setup_schemas(conn)
        load_dataframe(conn, ext_orders_df, TABLE_ORDERS)
        load_dataframe(conn, shipments_df, TABLE_SHIPMENTS)
        load_dataframe(conn, customers_df, TABLE_CUSTOMERS)
    finally:
        conn.close()

    print("\nSeed file available for Vulcan seed model:")
    print(f"  {seeds_dir / 'city_sla_rules.csv'}")
    print("\nLoaded external source tables:")
    print(f"  - {SF_DATABASE}.{SF_SCHEMA_EXT_RAW}.{TABLE_ORDERS}")
    print(f"  - {SF_DATABASE}.{SF_SCHEMA_EXT_RAW}.{TABLE_SHIPMENTS}")
    print(f"  - {SF_DATABASE}.{SF_SCHEMA_EXT_RAW}.{TABLE_CUSTOMERS}")


if __name__ == "__main__":
    main()
