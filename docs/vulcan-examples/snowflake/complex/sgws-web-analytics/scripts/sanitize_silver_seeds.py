#!/usr/bin/env python3
"""
Sanitize seed CSVs so silver models (CUSTOMER, SALES) don't fail on numeric columns.
- v_d_customer: ensure customer_no and univ_customer_no are numeric-only (silver casts to BIGINT).
- v_fact_sales: ensure customer_no and salesman_no are numeric-only.
Replaces non-numeric values with safe numeric placeholders in place.
"""
import csv
import re
from pathlib import Path

SEED_DIR = Path(__file__).parent.parent / "seeds"

def is_numeric(s):
    if s is None or str(s).strip() == "":
        return False
    return re.match(r"^-?\d+\.?\d*$", str(s).strip()) is not None

def sanitize_v_d_customer():
    path = SEED_DIR / "v_d_customer.csv"
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)

    try:
        idx_customer_no = headers.index("customer_no")
        idx_univ_customer_no = headers.index("univ_customer_no")
    except ValueError as e:
        print(f"  Skip v_d_customer: column not found ({e})")
        return 0

    fixed = 0
    for row in rows:
        if len(row) <= max(idx_customer_no, idx_univ_customer_no):
            continue
        if not is_numeric(row[idx_customer_no]):
            row[idx_customer_no] = "100000"
            fixed += 1
        if not is_numeric(row[idx_univ_customer_no]):
            row[idx_univ_customer_no] = "0"
            fixed += 1

    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)
    return fixed

def sanitize_v_fact_sales():
    path = SEED_DIR / "v_fact_sales.csv"
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)

    try:
        idx_customer_no = headers.index("customer_no")
        idx_salesman_no = headers.index("salesman_no")
    except ValueError as e:
        print(f"  Skip v_fact_sales: column not found ({e})")
        return 0

    fixed = 0
    for row in rows:
        if len(row) <= max(idx_customer_no, idx_salesman_no):
            continue
        if not is_numeric(row[idx_customer_no]):
            row[idx_customer_no] = "100000"
            fixed += 1
        if not is_numeric(row[idx_salesman_no]):
            row[idx_salesman_no] = "0"
            fixed += 1

    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)
    return fixed

def main():
    print("Sanitizing seed CSVs for silver CUSTOMER and SALES...")
    n1 = sanitize_v_d_customer()
    print(f"  v_d_customer.csv: {n1} cells replaced")
    n2 = sanitize_v_fact_sales()
    print(f"  v_fact_sales.csv: {n2} cells replaced")
    print("Done.")

if __name__ == "__main__":
    main()
