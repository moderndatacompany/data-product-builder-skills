#!/usr/bin/env python3
"""
Create a demo schema with 9 joinable tables on Postgres — FAST version.

Connection details can be overridden by environment variables:
  PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE

Provided defaults in this file:
  host=localhost, port=5433, user=vulcan, password=vulcan, database=postgres
"""
import os
import sys
import time
import random
import string
import logging
from contextlib import contextmanager
from datetime import datetime, timedelta

import psycopg2

# ---------- Connection details (defaults can be overridden via env) ----------
PG_HOST =  "127.0.0.1"
PG_PORT =  "5433"
PG_USER =  "vulcan"
PG_PASSWORD =  "vulcan"
PG_DATABASE =  "warehouse"

# Target schema (you can change)
SCHEMA =  "vulcan_demo"

# Data sizes (tweak as needed)
N_CUSTOMERS = 100
N_SUPPLIERS = 30
N_WAREHOUSES = 10
N_ORDERS = 1000
DATE_DAYS = 365

# Insert batch size: number of rows per VALUES statement
VALUES_BATCH_ROWS = 5000

# ---------- Logging setup ----------
def _configure_logging() -> logging.Logger:
    logger = logging.getLogger("postgres_demo_loader_fast")
    logger.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())
    logger.propagate = False

    for h in list(logger.handlers):
        logger.removeHandler(h)

    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    ch = logging.StreamHandler(stream=sys.stdout)
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    log_file = os.getenv("LOG_FILE")
    if log_file:
        fh = logging.FileHandler(log_file, encoding="utf-8")
        fh.setFormatter(formatter)
        logger.addHandler(fh)

    return logger

LOGGER = _configure_logging()

@contextmanager
def log_step(step_name: str, extra: dict | None = None):
    extra = extra or {}
    LOGGER.info("▶️  START: %s | %s", step_name, extra if extra else "-")
    t0 = time.time()
    try:
        yield
        dur = time.time() - t0
        LOGGER.info("✅ DONE : %s (%.2fs)", step_name, dur)
    except Exception as e:
        dur = time.time() - t0
        LOGGER.exception("💥 FAIL : %s after %.2fs | error=%s", step_name, dur, e)
        raise

# ---------- Helpers for batched VALUES using psycopg2.mogrify ----------
def _insert_values(cur, table: str, cols: list[str], rows: list[tuple], label: str):
    """Insert many rows using batched multi-row VALUES safely via cursor.mogrify."""
    total = len(rows)
    if total == 0:
        LOGGER.info("No rows to insert for %s.", label)
        return
    col_list = ", ".join(cols)
    LOGGER.info("Inserting %d rows into %s in batches of %d", total, label, VALUES_BATCH_ROWS)

    tpl = "(" + ",".join(["%s"] * len(cols)) + ")"

    for i in range(0, total, VALUES_BATCH_ROWS):
        chunk = rows[i : i + VALUES_BATCH_ROWS]
        # Use mogrify to safely interpolate each row as SQL literal bytes
        values_bytes = b",".join(cur.mogrify(tpl, row) for row in chunk)
        values_sql = values_bytes.decode("utf-8")
        sql_text = f"INSERT INTO {table} ({col_list}) VALUES {values_sql}"
        cur.execute(sql_text)
        LOGGER.debug("Inserted %d/%d into %s", min(i + VALUES_BATCH_ROWS, total), total, label)

def main():
    LOGGER.info("Connecting to Postgres (host=%s port=%d db=%s user=%s)", PG_HOST, PG_PORT, PG_DATABASE, PG_USER)
    # Connect to the target database (PG_DATABASE)
    conn = psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        user=PG_USER,
        password=PG_PASSWORD,
        dbname=PG_DATABASE,
    )
    # Ensure we run in a single transaction
    conn.autocommit = False

    # Table names
    t_regions     = "regions"
    t_customers   = "customers"
    t_suppliers   = "suppliers"
    t_products    = "products"
    t_warehouses  = "warehouses"
    t_orders      = "orders"
    t_order_items = "order_items"
    t_shipments   = "shipments"
    t_dim_dates   = "dim_dates"

    try:
        with conn, conn.cursor() as cur:
            # Ensure schema exists and set search_path
            with log_step("ensure & select schema", {"schema": SCHEMA}):
                cur.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")
                cur.execute(f"SET search_path TO {SCHEMA}")

            # ---------- Create tables ----------
            with log_step("create tables"):
                # Postgres types: SERIAL can be used but we keep explicit INTs to match Snowflake script
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_regions} (
                      region_id INTEGER,
                      region_name TEXT
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_customers} (
                      customer_id INTEGER,
                      region_id INTEGER,
                      name TEXT,
                      email TEXT
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_suppliers} (
                      supplier_id INTEGER,
                      region_id INTEGER,
                      name TEXT
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_products} (
                      product_id INTEGER,
                      supplier_id INTEGER,
                      name TEXT,
                      category TEXT,
                      price NUMERIC(10,2)
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_warehouses} (
                      warehouse_id INTEGER,
                      region_id INTEGER,
                      name TEXT
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_orders} (
                      order_id INTEGER,
                      customer_id INTEGER,
                      order_date TIMESTAMP,
                      warehouse_id INTEGER
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_order_items} (
                      order_id INTEGER,
                      item_id INTEGER,
                      product_id INTEGER,
                      quantity INTEGER,
                      unit_price NUMERIC(10,2)
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_shipments} (
                      shipment_id INTEGER,
                      order_id INTEGER,
                      shipped_date DATE,
                      carrier TEXT
                    )
                """)
                cur.execute(f"""
                    CREATE TABLE IF NOT EXISTS {t_dim_dates} (
                      dt DATE,
                      year INTEGER,
                      month INTEGER,
                      day_of_week TEXT
                    )
                """)

            # ---------- Generate data (same logic as original) ----------
            with log_step("generate data"):
                random.seed(42)

                regions = [
                    (1, "North"),
                    (2, "South"),
                    (3, "East"),
                    (4, "West"),
                    (5, "Central"),
                ]

                def rand_name():
                    return "".join(random.choices(string.ascii_letters, k=8)).capitalize()

                def rand_email(n):
                    return f"{n.lower()}@example.com"

                customers = []
                for cid in range(1, N_CUSTOMERS + 1):
                    r = random.choice(regions)[0]
                    nm = rand_name()
                    customers.append((cid, r, nm, rand_email(nm)))

                suppliers = []
                for sid in range(1, N_SUPPLIERS + 1):
                    r = random.choice(regions)[0]
                    suppliers.append((sid, r, f"Supplier_{sid}"))

                categories = ["Widgets", "Gadgets", "Doohickeys", "Thingamajigs"]
                products = []
                pid = 1
                for sid, _, _ in suppliers:
                    for _ in range(random.randint(3, 8)):  # 3-8 products per supplier
                        products.append((
                            pid,
                            sid,
                            f"Product_{pid}",
                            random.choice(categories),
                            round(random.uniform(1.0, 500.0), 2),
                        ))
                        pid += 1

                warehouses = []
                for wid in range(1, N_WAREHOUSES + 1):
                    r = random.choice(regions)[0]
                    warehouses.append((wid, r, f"Warehouse_{wid}"))

                start = datetime(2025, 11, 13)
                dim_dates = []
                for i in range(DATE_DAYS):
                    d = start + timedelta(days=i)
                    dim_dates.append((d.date(), d.year, d.month, d.strftime("%A")))

                orders = []
                order_id = 1
                end = datetime.now()  # up to current timestamp
                total_seconds = (end - start).total_seconds()
                for _ in range(N_ORDERS):
                    cust = random.choice(customers)[0]
                    rand_seconds = random.uniform(0, total_seconds)
                    d = start + timedelta(seconds=rand_seconds)
                    wid = random.choice(warehouses)[0]
                    orders.append((order_id, cust, d, wid))
                    order_id += 1

                order_items = []
                for (oid, _, _, _) in orders:
                    for item_id in range(1, random.randint(1, 5) + 1):
                        p = random.choice(products)
                        qty = random.randint(1, 10)
                        order_items.append((oid, item_id, p[0], qty, p[4]))

                carriers = ["DHL", "UPS", "FedEx", "USPS", "BlueDart"]
                shipments = []
                ship_id = 1
                for (oid, _, d, _) in orders:
                    if random.random() < 0.9:
                        shipped_date = d + timedelta(days=random.randint(0, 5))
                        shipments.append((ship_id, oid, shipped_date, random.choice(carriers)))
                        ship_id += 1

                LOGGER.info(
                    "Generated rows | regions=%d customers=%d suppliers=%d products=%d warehouses=%d orders=%d order_items=%d shipments=%d dim_dates=%d",
                    len(regions), len(customers), len(suppliers), len(products), len(warehouses),
                    len(orders), len(order_items), len(shipments), len(dim_dates)
                )

            # ---------- TRUNCATE existing tables ----------
            with log_step("truncate existing tables"):
                for tbl in [t_regions, t_customers, t_suppliers, t_products, t_warehouses,
                            t_orders, t_order_items, t_shipments, t_dim_dates]:
                    cur.execute(f"TRUNCATE TABLE {tbl}")

            # ---------- Load data (batched VALUES) ----------
            with log_step("insert data (batched VALUES)"):
                _insert_values(cur, t_regions,     ["region_id","region_name"], regions,     "regions")
                _insert_values(cur, t_customers,   ["customer_id","region_id","name","email"], customers,   "customers")
                _insert_values(cur, t_suppliers,   ["supplier_id","region_id","name"], suppliers,   "suppliers")
                _insert_values(cur, t_products,    ["product_id","supplier_id","name","category","price"], products, "products")
                _insert_values(cur, t_warehouses,  ["warehouse_id","region_id","name"], warehouses, "warehouses")
                _insert_values(cur, t_orders,      ["order_id","customer_id","order_date","warehouse_id"], orders, "orders")
                _insert_values(cur, t_order_items, ["order_id","item_id","product_id","quantity","unit_price"], order_items, "order_items")
                _insert_values(cur, t_shipments,   ["shipment_id","order_id","shipped_date","carrier"], shipments, "shipments")
                _insert_values(cur, t_dim_dates,   ["dt","year","month","day_of_week"], dim_dates, "dim_dates")

            # Commit once
            with log_step("commit"):
                conn.commit()

            # ---------- Verification ----------
            with log_step("verification query"):
                cur.execute(f"""
                    SELECT c.name AS customer_name,
                           r.region_name,
                           COUNT(DISTINCT o.order_id) AS orders,
                           SUM(oi.quantity * oi.unit_price) AS revenue
                    FROM {t_customers} c
                    JOIN {t_regions} r       ON c.region_id = r.region_id
                    JOIN {t_orders} o        ON o.customer_id = c.customer_id
                    JOIN {t_order_items} oi  ON oi.order_id   = o.order_id
                    GROUP BY c.name, r.region_name
                    ORDER BY revenue DESC
                    LIMIT 10
                """)
                rows = cur.fetchall()
                for idx, row in enumerate(rows, 1):
                    LOGGER.info("Top %d: %s", idx, row)

            LOGGER.info("All done ✅")

    finally:
        try:
            conn.close()
        except Exception:
            pass

if __name__ == "__main__":
    main()
