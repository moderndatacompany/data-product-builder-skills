#!/usr/bin/env python3
"""
Sanitize ALL seed CSVs that feed silver CUSTOMER, SALES, PRODUCT.
Replace any non-numeric value in numeric columns with safe defaults (0 or 100000)
so Snowflake never sees alphanumeric in numeric columns.
Run from sgws-web-analytics: python3 scripts/sanitize_all_seeds_for_silver.py
"""
import csv
import re
from pathlib import Path

SEED_DIR = Path(__file__).parent.parent / "seeds"

# Columns that must be numeric; non-numeric -> replacement value
# Use 100000 for customer_no–style IDs so joins still work; 0 for others
NUMERIC_COLUMNS_BY_FILE = {
    "v_d_customer.csv": {
        "customer_sk": "0", "site": "1", "customer_no": "100000", "zip": "0", "county": "0",
        "liquor_rating": "0", "wine_rating": "0", "selling_div_sk": "0", "selling_div_no": "0",
        "state_chain_no": "0", "corp_chain_no": "0", "ar_group_acct_no": "0", "chain_supvsr_no": "0",
        "bill_to_cust_no": "0", "cust_level1_no": "0", "cust_level3_no": "0", "chain_store_no": "0",
        "primary_salesperson_no": "0", "state_sales_tax_no": "0", "po_no_required_ind": "0",
        "warehouse_permit_no": "0", "univ_customer_no": "0", "ar_group_custmast_acct_no": "0",
    },
    "v_fact_sales.csv": {
        "sales_sk": "0", "site": "1", "customer_no": "100000", "item_no": "0", "invoice_no": "0",
        "sequence_no": "0", "cases": "0", "bottles": "0", "posting_prd": "0",
        "current_salesperson_sk": "0", "salesman_no": "0", "salesperson_sk": "0", "customer_sk": "0",
        "order_no": "0", "warehouse_no": "0",
    },
    "v_d_curr_item.csv": {
        "item_sk": "0", "site": "1", "item_no": "0", "suppl_no": "0", "sap_suppl_no": "0",
        "bottles_case": "0", "reptg_case_ratio": "0", "case_conv_fact": "0", "unit_cube_volume": "0",
        "corp_item_sk": "0", "cases_per_pallet": "0", "alt_brand_no": "0", "alt_suppl_no": "0",
        "site_sk": "0", "brand_manager_no": "0", "price_group_1_no": "0", "price_group_2_no": "0",
        "item_sold_by_cases_ind": "0", "item_authorization_list_id": "0",
    },
    "v_d_curr_corp_item.csv": {
        "corp_item_no": "0", "corp_item_desc": "0",
    },
    "v_d_current_account_salesperson.csv": {
        "site_state": "0", "site": "1", "customer_no": "100000",
    },
}


def is_numeric(s):
    if s is None or str(s).strip() == "":
        return False
    return re.match(r"^-?\d+\.?\d*$", str(s).strip()) is not None


# Known bad values that cause "Numeric value ... is not recognized" - replace anywhere
BAD_VALUES_REPLACE = {
    "EA14248UB8OM": "0", "HH7II2VYMLIH5S0": "100000", "L5GPC3N": "0", "ZOWEI98KPPW": "0", "00HB8B9V5B065L": "100000",
    "SOMY7AZP9": "100000", "82ZF7A": "0", "EKG1": "100000",
    "1ST7MW": "1", "S3H3XLW4IUQPV": "100000", "UZSJFXOE0B6KL": "100000",
}


def sanitize_file(filename, numeric_cols):
    path = SEED_DIR / filename
    if not path.exists():
        print(f"  Skip {filename}: file not found")
        return 0
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        headers = next(reader)
        rows = list(reader)

    indices = {}
    for col, default in numeric_cols.items():
        try:
            indices[headers.index(col)] = default
        except ValueError:
            pass

    fixed = 0
    for row in rows:
        for idx, default in indices.items():
            if len(row) > idx and not is_numeric(row[idx]):
                row[idx] = default
                fixed += 1
        # Replace known bad values in any cell
        for i, cell in enumerate(row):
            if cell in BAD_VALUES_REPLACE:
                row[i] = BAD_VALUES_REPLACE[cell]
                fixed += 1

    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)
    return fixed


def main():
    print("Sanitizing all seed CSVs for silver CUSTOMER, SALES, PRODUCT...")
    total = 0
    for filename, cols in NUMERIC_COLUMNS_BY_FILE.items():
        n = sanitize_file(filename, cols)
        total += n
        print(f"  {filename}: {n} cells replaced")
    print(f"Done. Total: {total} cells replaced.")


if __name__ == "__main__":
    main()
