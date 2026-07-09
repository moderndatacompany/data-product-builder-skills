#!/usr/bin/env python3
"""
Generate realistic transaction data (f_sales_all and f_order_all) for SGWS
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

SEED_DIR = Path(__file__).parent / "seeds"

def random_string(length=10):
    import string
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))

def random_date(start='2024-01-01', end='2025-12-31'):
    start_date = datetime.strptime(start, '%Y-%m-%d')
    end_date = datetime.strptime(end, '%Y-%m-%d')
    delta = end_date - start_date
    random_days = random.randint(0, delta.days)
    return (start_date + timedelta(days=random_days)).strftime('%Y%m%d')

def random_datetime(start='2024-01-01', end='2025-12-31'):
    start_date = datetime.strptime(start, '%Y-%m-%d')
    end_date = datetime.strptime(end, '%Y-%m-%d')
    delta = end_date - start_date
    random_seconds = random.randint(0, int(delta.total_seconds()))
    return (start_date + timedelta(seconds=random_seconds)).strftime('%Y-%m-%d %H:%M:%S.%f')

def random_float(min_val, max_val, decimals=2):
    return round(random.uniform(min_val, max_val), decimals)

def generate_sales_all(num_records=50000):
    """Generate realistic sales transaction data"""
    print(f"Generating {num_records} sales transaction records...")
    
    # Read existing headers
    existing_file = SEED_DIR / 'f_sales_all.csv'
    with open(existing_file, 'r') as f:
        headers = next(csv.reader(f))
    
    sales = []
    sites = [1, 20, 60, 170]
    warehouses = [14, 201, 360, 702]
    entry_origins = ['UB', 'J', '1T', 'B3', 'WA', 'U', 'F', 'Z', '6']
    
    for i in range(num_records):
        posting_date = random_date('2024-01-01', '2025-12-31')
        posting_period = int(posting_date[:6])
        
        # Realistic quantities and prices
        cases = random.randint(10, 500)
        bottles = cases * random.randint(6, 24)
        qty_dec_equ = round(cases + (bottles / 12), 3)
        unit_price = random_float(20, 300, 4)
        ext_net = random_float(cases * unit_price * 0.9, cases * unit_price * 1.1, 2)
        ext_cost = ext_net * random_float(0.65, 0.85, 2)
        
        sale = [
            random.randint(1000000000, 9999999999),  # sales_sk
            posting_period,  # posting_prd_sk
            int(posting_date),  # posting_dt_sk
            random.randint(1000000000, 9999999999),  # item_sk
            random.randint(100000000, 999999999),  # customer_sk
            random.randint(1000000000, 9999999999),  # warehouse_sk
            random.randint(1000000000, 9999999999),  # current_salesperson_sk
            random.randint(1000000000, 9999999999),  # salesperson_sk
            int(random_date('2024-01-01', '2025-12-31')),  # invoice_dt_sk
            random.randint(1000000, 9999999),  # invoice_no
            random.randint(1000000, 9999999),  # sequence_no
            random.randint(100000, 9999999),  # ref_inv_no
            qty_dec_equ,  # qty_dec_equ
            ext_net,  # ext_net
            ext_cost,  # ext_cost
            random_float(100, 5000, 2),  # ext_dsct
            random_float(50, 3000, 2),  # ext_participation
            random_float(100, 5000, 2),  # ext_depl_allow
            cases,  # cases
            bottles,  # bottles
            random_string(8),  # combo_no
            random_string(12),  # purcahse_order_no
            random.randint(100000, 9999999),  # dsct_qualifier
            cases + random.randint(-10, 10),  # orig_case_qty
            random_float(5, 50, 2),  # dsct_per_case
            random_float(-1000, 1000, 2),  # unit_breakage_amt
            random_float(-20000, 30000, 2),  # recovery_amt
            random_float(1000, 10000, 2),  # ext_guaranteed_adj
            random_date('2024-01-01', '2025-12-31'),  # reference_dt
            bottles + random.randint(-50, 50),  # orig_bottle_qty
            qty_dec_equ + random_float(-5, 5, 3),  # converted_cases
            unit_price,  # unit_price
            random.choice(['Y', 'N', '0', '1', 'A']),  # master_bill
            random.randint(1000000, 9999999),  # orig_inv_line_item_no
            random.randint(202401, 202512),  # orig_inv_pst_per
            random.randint(1000000, 9999999),  # orig_inv_warehouse
            random_datetime('2024-01-01', '2026-01-01'),  # ship_dt
            random_float(100, 50000, 2),  # state_tax
            random_float(1000, 50000, 2),  # sws_cqd_amt
            random_float(-100000, 500000, 2),  # cqd_amt
            random_string(20),  # chksum
            random_string(8),  # modified_user
            random_datetime('2024-01-01', '2026-01-01'),  # load_dt
            random_datetime('2024-01-01', '2026-01-01'),  # modified_dt
            'SGWS',  # src_desc
            random.choice([1, 20, 60, 170]),  # site_sk
            random_string(4),  # route_no
            random_string(4),  # stop_no
            random_string(8),  # driver_no
            random_string(8),  # whs_ship_loc
            random.randint(1000000, 9999999),  # depot_no
            random.choice(sites),  # site
            random.choice(warehouses),  # warehouse_no
            random.randint(100000, 999999),  # customer_no
            random.randint(10000, 999999),  # item_no
            random.randint(1000000, 9999999),  # tpz_combo
            random.randint(100000, 9999999),  # salesman_no
            random.choice(['SGWS', 'GLAZERS', 'HANA', 'ODOM']),  # source_system
            random.choice(['Y', 'N', '0', '1']),  # document_type
            random.choice(['E ', 'A ', '0 ', '1 ']),  # reason_cd
            random.choice(['A', 'N', '0']),  # combo_option
            random.choice(['SC', 'TX', 'FL', 'CA', 'NY']),  # discount_origin
            random.choice(['J', 'N', 'A', 'S']),  # adjustment_cd
            random.choice(['CA', 'TX', 'SC', 'NY', 'FL']),  # dsct_category
            random.choice(entry_origins),  # entry_origin
            random.choice(['J', 'N', 'C', 'S', 'Y']),  # day_bill_cd
            random.choice(['C', '0', '1', 'A']),  # void_cd
            random.choice(['N', 'Y', '0', '1']),  # manifest_flg
            random.choice(['N', 'Y', 'A', '0']),  # reg_nght_shp_flg
            random.choice(['Y', 'N', '0', 'A']),  # ship_line_type
            random.choice(['S', 'I', 'E', 'H', 'Y', '0']),  # inv_subtype_cd
            random.choice(['N', 'A', 'S', 'Y']),  # delivery_pickup_flg
            random.choice(['S', 'A', 'N', 'H']),  # billing_type_cd
            random.choice(['N', 'Y', 'A', '0', '1']),  # slstax_chrgbk_flg
            posting_period,  # posting_prd
            random.randint(100000000, 9999999999),  # item_hist_sk
            random.randint(100000000, 9999999999),  # customer_hist_sk
            random.randint(1000000000, 9999999999),  # warehouse_hist_sk
            random.randint(1000000000, 9999999999),  # salesperson_hist_sk
            random.randint(1000000000, 9999999999),  # current_salesperson_hist_sk
            random.randint(100000000, 9999999999),  # profit_center_sk
            random.choice(['A', 'N', '0', 'H']),  # profit_center_cd
            random.randint(1000000, 9999999),  # order_no
            random.randint(1000000, 9999999),  # order_line_no
            random.choice(['J', 'N', 'F', '1', 'S']),  # invoice_sales_unit_cd
            random_float(10000, 500000, 2),  # state_tax_exempt_amt
            random_float(50, 10000, 2),  # cost_goods_sold_amt
            random_float(10000, 500000, 2),  # da_amt
            random_float(10000, 500000, 2),  # nda_amt
            random_float(-500000, 500000, 2),  # tax_chargeback_amt
            random_float(100, 500000, 2),  # total_breakage_amt
            random.randint(1000000, 9999999),  # call_in_sales_rep_no
            random.choice(['F', 'S', 'I', '1', 'C']),  # ship_via_cd
            random_string(15),  # front_line_price_id
            random_string(20),  # discount_id
            random_string(15),  # deal_id
            random.choice(['E', 'N', 'S', 'C', 'Y']),  # qnm_eligible_ind
            random.randint(1000000, 9999999),  # marketing_group_buying_chain
            random_string(30),  # marketing_group_type
            random_string(20),  # chain_period
            random_string(20),  # price_category
            random_string(40),  # invoice_discount_level
            random.choice(['C', '1', 'E', 'N']),  # accumulate_by_chain_ind
            random_float(-500000, 500000, 4),  # front_line_price_per_case
            random.choice(['Y', 'N', 'H']),  # qnm_process_ind
            random_string(20),  # parent_discount_id
            random.choice(['F', 'N', 'J']),  # item_accumulation_group_cd
            random_string(20),  # deal_level_id
            random.randint(1000000, 9999999),  # recovery_program_id
            random.randint(1000000, 9999999),  # recovery_group_id
            random_string(20),  # order_master_reference
            random_float(1000, 10000, 4),  # sales_deal_id
            random_string(20),  # discount_per_unit
            random_string(20),  # special_instructions_1
            random.choice(['N', 'A', '0', 'E']),  # special_instructions_2
            random_float(10000, 500000, 4),  # state_excise_tax_exemption_cd
            random_date('2024-01-01', '2025-12-31'),  # other_tax_cost_amt
            random.choice(['Y', '0', '1', 'S']),  # actual_ship_dt
            random_string(20),  # water_invoice_ind
            random_string(10),  # credit_status_approved_by_user_id
            random_string(20),  # entered_by_user_id
            random_string(20),  # billing_batch_id
            random.randint(1000000, 9999999),  # combo_id
            random.randint(1000000, 9999999),  # core_combo_id
            random.randint(100, 10000),  # adj_order_bottle_qty
            random.randint(10, 500),  # adj_order_case_qty
            random_float(10, 500, 4),  # adj_order_qty_dec_equ
            random_float(10, 500, 4),  # orig_order_qty_dec_equ
            random_date('2024-01-01', '2025-12-31'),  # discount_start_dt
            random_date('2024-01-01', '2025-12-31'),  # discount_end_dt
        ]
        
        sales.append(sale)
        
        if (i + 1) % 5000 == 0:
            print(f"  Generated {i + 1} sales records...")
    
    # Write to file
    with open(SEED_DIR / 'f_sales_all.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(sales)
    
    print(f"✅ Wrote {num_records} sales records to f_sales_all.csv")

def generate_orders_all(num_records=25000):
    """Generate realistic order data"""
    print(f"Generating {num_records} order records...")
    
    # Read existing headers
    existing_file = SEED_DIR / 'f_order_all.csv'
    with open(existing_file, 'r') as f:
        headers = next(csv.reader(f))
    
    orders = []
    sites = [1, 20, 60, 170]
    warehouses = [14, 201, 360, 702]
    status_codes = ['A', '1', 'C', 'H', 'J', '0', 'I']
    entry_codes = ['A', 'E', 'H', 'N', 'C']
    
    for i in range(num_records):
        posting_period = random.randint(202401, 202512)
        order_date = random_date('2024-01-01', '2025-12-31')
        
        # Realistic quantities
        cases = random.randint(10, 1000)
        bottles = cases * random.randint(6, 24)
        qty_dec_equ = round(cases + (bottles / 12), 4)
        price_per_case = random_float(100, 1000, 4)
        dsct_per_case = random_float(5, 100, 4)
        net_amt = round(cases * (price_per_case - dsct_per_case), 4)
        
        order = [
            random.randint(1000000000, 9999999999),  # order_sk
            random.choice([1, 20, 60, 170]),  # site_sk
            posting_period,  # posting_prd_sk
            random.randint(1000000000, 9999999999),  # item_sk
            random.randint(100000000, 999999999),  # customer_sk
            random.randint(1000000000, 9999999999),  # warehouse_sk
            random.randint(100000000, 9999999999),  # order_reject_sk
            random.randint(100000000, 9999999999),  # order_status_sk
            random.choice(sites),  # site_id
            random.randint(10000, 999999),  # item_no
            posting_period,  # posting_period
            random.randint(10000, 999999),  # customer_no
            random.randint(1000000, 9999999),  # order_no
            random.randint(100000, 9999999),  # order_line_no
            random.choice(status_codes),  # order_status_cd
            order_date,  # order_entry_dt
            random.randint(60000, 200000),  # order_entry_time
            random.choice(entry_codes),  # order_entry_cd
            random_string(20),  # order_entered_by
            cases,  # order_cases_qty
            bottles,  # order_bottle_qty
            qty_dec_equ,  # cases_dec_equivalent
            price_per_case,  # order_price_per_case
            dsct_per_case,  # order_dsct_per_case
            net_amt,  # order_net_amt
            random.choice(['0', '1', 'N', 'A', 'F', 'Y', 'J']),  # order_reject_cd
            random_date('2024-01-01', '2025-12-31'),  # order_reject_dt
            random.randint(10000, 200000),  # order_reject_time
            random_string(20),  # order_reject_by
            random.randint(1000000, 9999999),  # invoice_no
            random.randint(1000000, 9999999),  # invoice_line_no
            random_date('2024-01-01', '2025-12-31'),  # invoice_dt
            random.choice(warehouses),  # warehouse_no
            random_datetime('2024-01-01', '2026-01-01'),  # load_dt
            random.randint(1000000, 9999999),  # load_id
            random_datetime('2024-01-01', '2026-01-01'),  # modified_dt
            random_string(20),  # modified_user
            'SGWS',  # src_desc
            random.randint(1000000000, 9999999999),  # sales_sk
            random.choice(['SGWS', 'GLAZERS', 'HANA', 'ODOM']),  # source_system
            int(random_date('2024-01-01', '2025-12-31')),  # request_delivery_dt_sk
            random.randint(1000000000, 9999999999),  # order_type_sk
            random.choice(['N', 'S', 'C', 'Y', 'A']),  # order_type_cd
            random.choice(['N', 'Y', 'A']),  # order_category
            random_string(4),  # order_line_category
            random.choice(['I', 'J', 'Y', 'A']),  # order_doc_object_cd
            random.choice(['A', 'S', 'I']),  # order_unit_cd
            random.randint(1000000000, 9999999999),  # order_reject_reason_sk
            random.choice(['Y', 'H', 'N']),  # order_reject_reason_cd
            random.randint(1000000000, 9999999999),  # order_salesperson_sk
            random_string(20),  # order_salesperson
            random.randint(1000000, 9999999),  # order_ref_doc_no
            random.randint(1000000, 9999999),  # order_ref_line_no
            'N',  # is_deleted
            random.choice(['Y', 'N', '0', 'A']),  # credit_chk_status
            random.choice(['A', 'N', 'Y', 'S']),  # overall_delivery_status
            random.choice(['J', 'N', 'Y']),  # order_delivery_block_cd
            random_string(40),  # order_external_id
            random_string(50),  # order_cancel_error_msg
            random.choice(['GC', 'S', '8B', 'O']),  # order_billing_type
            random.choice(['N', 'A', 'Y', '0', 'C']),  # order_invoice_type
            random.choice(['C', 'J', 'I', 'Y', 'A']),  # order_bill_hold_flag
            random_string(20),  # purcahse_order_no
            random_string(40),  # order_special_instructions_1
            random_string(40),  # order_special_instructions_2
            random_float(1000, 100000, 2),  # order_line_cost_amt
            random.choice(['C', '1', 'I', 'S']),  # combo_promo_buy_get_flag
            random.randint(100000, 9999999),  # order_route_no
            random.randint(1000000, 9999999),  # order_depot_no
            random.randint(1000000000, 9999999999),  # order_route_sk
            random.randint(1000000000, 9999999999),  # order_depot_sk
            random.choice(['I', 'H', 'S', 'N']),  # order_billing_status_cd
            random.randint(1000000, 9999999),  # order_entered_by_salesperson_no
            random.randint(1000000, 9999999),  # order_promo_no
            random.choice(['0', '1', 'Y']),  # order_reserve_stock_status
            random.randint(100, 10000),  # backorder_bottles_qty
            random.randint(10, 1000),  # backorder_cases_qty
            random.randint(1000000, 9999999),  # credit_reason_cd
            random.choice(['H', '1', '0', 'C', 'I']),  # inv_subtype_cd
            random.choice(['C', 'F', 'N']),  # ship_via_cd
            random.randint(100000, 9999999),  # call_in_sales_rep_no
            random.randint(1000000, 9999999),  # customer_delivery_priority
            random.randint(1000000, 9999999),  # ref_promo_sequence_no
            random.randint(100000, 9999999),  # ref_promo_no
            random.choice(['F', '0', 'H', 'E']),  # ref_promo_discount_cd
            random.choice(['C', 'N', '1', 'Y', 'F']),  # ref_promo_buy_get_ind
            random.choice(['Y', 'N', '0', 'F']),  # order_approval_status
            random.randint(100000, 999999),  # original_item_number
            random_string(10),  # approved_by_user
            random.choice(['Y', '0', 'N']),  # water_invoice_yes_or_no
            random_string(10),  # entered_by_user
            cases + random.randint(-10, 10),  # orig_order_case_qty
            bottles + random.randint(-50, 50),  # orig_order_bottle_qty
            cases + random.randint(-10, 10),  # adj_order_case_qty
            bottles + random.randint(-50, 50),  # adj_order_bottle_qty
            qty_dec_equ + random_float(-5, 5, 4),  # adj_order_qty_dec_equ
            qty_dec_equ + random_float(-5, 5, 4),  # orig_order_qty_dec_equ
        ]
        
        orders.append(order)
        
        if (i + 1) % 2500 == 0:
            print(f"  Generated {i + 1} order records...")
    
    # Write to file
    with open(SEED_DIR / 'f_order_all.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(orders)
    
    print(f"✅ Wrote {num_records} order records to f_order_all.csv")

if __name__ == "__main__":
    print("=" * 80)
    print("SGWS Transaction Data Generator")
    print("=" * 80)
    print()
    
    generate_sales_all(50000)  # 50K sales transactions
    print()
    generate_orders_all(25000)  # 25K orders
    print()
    
    print("=" * 80)
    print("✅ Transaction Data Generation Complete!")
    print("=" * 80)
    print("Summary:")
    print("  - Sales Transactions: 50,000")
    print("  - Order Records: 25,000")
    print("  - Total: 75,000 transaction records")
    print()
