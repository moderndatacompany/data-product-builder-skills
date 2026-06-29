#!/usr/bin/env python3
"""
Generate realistic site and store data for SGWS
"""

import csv
import random
from datetime import datetime
from pathlib import Path

SEED_DIR = Path(__file__).parent / "seeds"

# US cities for distribution centers and stores
US_CITIES = [
    ('New York', 'NY', '10001'), ('Los Angeles', 'CA', '90001'), ('Chicago', 'IL', '60601'),
    ('Houston', 'TX', '77001'), ('Phoenix', 'AZ', '85001'), ('Philadelphia', 'PA', '19101'),
    ('San Antonio', 'TX', '78201'), ('San Diego', 'CA', '92101'), ('Dallas', 'TX', '75201'),
    ('San Jose', 'CA', '95101'), ('Austin', 'TX', '78701'), ('Jacksonville', 'FL', '32201'),
    ('Fort Worth', 'TX', '76101'), ('Columbus', 'OH', '43201'), ('Charlotte', 'NC', '28201'),
    ('San Francisco', 'CA', '94101'), ('Indianapolis', 'IN', '46201'), ('Seattle', 'WA', '98101'),
    ('Denver', 'CO', '80201'), ('Boston', 'MA', '02101'), ('Nashville', 'TN', '37201'),
    ('Oklahoma City', 'OK', '73101'), ('Las Vegas', 'NV', '89101'), ('Portland', 'OR', '97201'),
    ('Memphis', 'TN', '38101'), ('Louisville', 'KY', '40201'), ('Milwaukee', 'WI', '53201'),
    ('Albuquerque', 'NM', '87101'), ('Tucson', 'AZ', '85701'), ('Atlanta', 'GA', '30301'),
    ('Miami', 'FL', '33101'), ('Tampa', 'FL', '33601'), ('New Orleans', 'LA', '70112'),
]

REGIONS = {
    'Northeast': ['NY', 'PA', 'MA', 'NJ', 'CT', 'RI', 'VT', 'NH', 'ME'],
    'Southeast': ['FL', 'GA', 'NC', 'SC', 'VA', 'TN', 'KY', 'LA', 'MS', 'AL'],
    'Midwest': ['IL', 'OH', 'IN', 'MI', 'WI', 'MN', 'IA', 'MO', 'KS', 'NE'],
    'Southwest': ['TX', 'OK', 'AR', 'NM'],
    'West': ['CA', 'WA', 'OR', 'AZ', 'NV', 'CO', 'UT', 'ID', 'MT', 'WY']
}

def get_region(state):
    for region, states in REGIONS.items():
        if state in states:
            return region
    return 'Other'

def generate_sites(num_sites=50):
    """Generate distribution center sites"""
    print(f"Generating {num_sites} distribution center sites...")
    
    sites = []
    site_counter = 1
    
    # Read existing headers
    existing_file = SEED_DIR / 'v_d_site.csv'
    with open(existing_file, 'r') as f:
        headers = next(csv.reader(f))
    
    for i in range(num_sites):
        city, state, base_zip = random.choice(US_CITIES)
        region = get_region(state)
        site_id = (i % 4) * 100 + i + 1  # Spread across 1, 20, 60, 170 bases
        
        street_num = random.randint(100, 9999)
        streets = ['Distribution Way', 'Warehouse Blvd', 'Commerce Dr', 'Industrial Pkwy', 'Logistics Ave']
        
        site = [
            100000000 + i,  # site_sk
            site_id,  # site
            f"{city} Distribution Center",  # site_name
            f"SGWS {city[:3].upper()}",  # appl_display_name
            f"SGWS_{city[:3].upper()}",  # site_short_name
            f"{region} Region",  # region_name
            694100 + i,  # bdn_site_no
            f"{street_num} {random.choice(streets)}",  # site_address_1
            '',  # site_address_2
            city,  # site_city
            state,  # site_state
            base_zip,  # site_zip_cd
            str(random.randint(1000, 9999)),  # site_zip_cd_ext
            city,  # site_county
            2026,  # site_fiscal_year_ccyy
            202601,  # site_fiscal_period
            '2026-01-29 12:00:00.000000',  # lastrundate
            202601,  # postingperiod
            202601,  # posting_prd_sk
            20260129,  # postingday
            city[0],  # tdlinx_storecode_prefix
            'SYSTEM_USER',  # modified_user
            '2020-01-01 00:00:00.000000',  # effective_from_dt
            '2099-12-31 23:59:59.999999',  # effective_thru_dt
            '2026-01-29 12:00:00.000000',  # load_dt
            '2026-01-29 12:00:00.000000',  # modified_dt
            'Y',  # current_ind
            'SGWS',  # src_desc
            'Y',  # active_ind
            '20260129',  # last_inv_date
            1000 + i,  # sap_company_code
            '2026-01-29 12:00:00.000000',  # lrd_lastrundate
            202601,  # lrd_postingperiod
            20260129,  # lrd_postingday
            '2026-01-29 00:00:00.000000',  # postingday_cal_dt
            202601,  # depletion_postingperiod
            202601,  # depletion_posting_prd_sk
            20260129,  # inventory_postingday
            'SGWS',  # source_system
            202512,  # last_closed_posting_period
            '20260101',  # last_posting_period_closed_date
            'Y',  # national_reporting_ind
            'Y',  # sop_ind
            round(random.uniform(2000000, 5000000), 2),  # site_end_of_day_total_net
            round(random.uniform(30000, 80000), 2),  # site_end_of_day_total_cases
            random.randint(150000, 300000),  # site_end_of_day_total_records_processed
            'Y',  # tdlinx_distribution_ind
            region,  # site_geo_region
            state,  # site_geo_sub_region
            region[:2],  # site_geo_region_short_name
            f"CHKSUM{i:03d}",  # check_sum
            202601,  # rt_posting_prd
            20260129,  # rt_posting_dt
            202601,  # rt_posting_prd_sk
            202601,  # rt_inventory_posting_prd
            20260129,  # rt_inventory_posting_dt
            202601,  # inventory_posting_prd_sk
            202601,  # rt_inventory_posting_prd_sk
            '2026-01-29 12:00:00.000000',  # rt_last_refresh_time
            'Y',  # processed_ind
            'Y',  # depletion_ind
            city[:3].upper()  # site_abbrev
        ]
        
        sites.append(site)
    
    # Write to file
    with open(SEED_DIR / 'v_d_site.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(sites)
    
    print(f"✅ Wrote {num_sites} sites to v_d_site.csv")

def generate_stores(num_stores=500):
    """Generate retail store locations"""
    print(f"Generating {num_stores} retail store locations...")
    
    stores = []
    
    # Read existing headers
    existing_file = SEED_DIR / 'v_td_store.csv'
    with open(existing_file, 'r') as f:
        headers = next(csv.reader(f))
    
    # Store chains and types
    off_premise_chains = [
        'Total Wine & More', 'BevMo!', "Spec's Wine Spirit & Finer Foods", 'ABC Fine Wine & Spirits',
        'Binny\'s Beverage Depot', 'K&L Wine Merchants', 'Hi-Time Wine Cellars', 'Liquor Barn',
        'Wine World', 'Bottles', 'Keg N Bottle', 'Riverside Liquor', 'Gary\'s Wine & Marketplace'
    ]
    
    on_premise_chains = [
        'The Capital Grille', 'Ruth\'s Chris Steak House', 'Morton\'s The Steakhouse',
        'Fleming\'s Prime Steakhouse', 'Eddie V\'s', 'Ocean Prime', 'Seasons 52',
        'Yardhouse', 'Bonefish Grill', 'Carrabba\'s Italian Grill', 'The Cheesecake Factory'
    ]
    
    for i in range(num_stores):
        city, state, zip_code = random.choice(US_CITIES)
        
        # Decide on/off premise
        is_on_premise = random.random() < 0.3  # 30% on-premise, 70% off-premise
        
        if is_on_premise:
            store_name = random.choice(on_premise_chains)
            premise_type = 'ON'
            trade_channel = 'Restaurant - On Premise'
            format_type = random.choice(['Fine Dining', 'Casual Dining', 'Bar & Grill'])
            liquor = 'Y'
            wine = 'Y'
            beer = 'Y'
            onprem = 'Y'
            food_type = random.choice(['STEAK', 'SEAFOOD', 'ITALIAN', 'CASUAL', 'MIXED'])
        else:
            store_name = random.choice(off_premise_chains)
            premise_type = 'OFF'
            trade_channel = 'Retail - Off Premise'
            format_type = random.choice(['Superstore', 'Specialty Store', 'Convenience Store'])
            liquor = 'Y'
            wine = 'Y'
            beer = 'Y'
            onprem = 'N'
            food_type = random.choice(['CONV', 'RETAIL', 'SPEC'])
        
        # Volume classification
        volume_desc = random.choice(['High Volume,$10M+', 'Medium Volume,$5-10M', 'Medium Volume,$2-5M', 'Low Volume,<$2M'])
        
        # Chain indicator
        chain_ind = random.choice(['C', 'C', 'C', 'I'])  # 75% chain, 25% independent
        chain_desc = 'Chain' if chain_ind == 'C' else 'Independent'
        
        # Ecommerce
        has_ecommerce = random.random() < 0.4 if not is_on_premise else random.random() < 0.6
        ecommerce_provider = random.choice(['Instacart', 'DoorDash', 'Uber Eats', 'None']) if has_ecommerce else 'None'
        
        street_num = random.randint(100, 9999)
        streets = ['Main St', 'Broadway', 'Market St', 'Oak Ave', 'Elm St', 'Pine St', '1st Ave']
        
        # Generate latitude/longitude (rough US bounds)
        lat = round(random.uniform(25.0, 49.0), 4)
        lon = round(random.uniform(-125.0, -66.0), 4)
        
        store = [
            f"TDLX{i:05d}",  # stdlinxscd
            1000000000 + i,  # tdlinx_store_sk
            'N',  # stranscd
            'ADD',  # smodchgind
            '20260129',  # sfiledt
            'A',  # sstatusind
            store_name,  # sname
            str(1000 + i),  # sno
            f"{street_num} {random.choice(streets)}",  # sstreetadd
            city,  # scity
            state,  # sst
            zip_code,  # szip
            city,  # splacenm
            state,  # sstcd
            'USA',  # scntcd
            'United States',  # scntrynm
            premise_type,  # stradeclcd (ON/OFF)
            format_type[:2],  # sformatcd
            f"{i%100:02d}",  # snostrcd
            chain_ind,  # schainind
            'FILLER',  # sfiller1
            lat,  # slat
            lon,  # slong
            'Y',  # slatlongcd
            f"BLK{i:05d}",  # sblockid
            'FILLER',  # sfiller2
            state[:3],  # sareacd
            f"{random.randint(200,999)}-555-{random.randint(1000,9999)}",  # sphoneno
            'FILLER',  # sfiller3
            random.choice(['H', 'M', 'L']),  # sannvolcd
            random.randint(1000, 10000),  # swklyvol
            random.randint(5000, 30000),  # ssqft
            random.randint(20, 100),  # sftemploy
            random.randint(3, 12),  # snmchkout
            'FILLER',  # sfiller4
            f"OWN{i:05d}",  # stdlinxocd
            f"FAM{i:03d}",  # sownfamcd
            f"{store_name} Inc",  # sownnm
            city,  # sowncity
            state,  # sownst
            state,  # sownstcd
            'USA',  # sowncntcd
            'FILLER',  # sfiller5
            f"PROV{i:05d}",  # stdlinxpcd
            'SUP001',  # ssupfamcd
            "Southern Glazer's",  # ssupnm
            random.choice(['Miami', 'Dallas', 'Los Angeles', 'New York']),  # ssupcity
            random.choice(['FL', 'TX', 'CA', 'NY']),  # ssupst
            random.choice(['FL', 'TX', 'CA', 'NY']),  # ssupstcd
            'USA',  # ssupcntcd
            'FILLER',  # sfiller6
            f"GRP{i:03d}",  # stdlinxgcd
            f"{store_name} Group",  # sgrpnm
            'Y' if chain_ind == 'C' else 'N',  # sfranind
            'FILLER',  # sfiller7
            'N',  # sgas
            'Y' if not is_on_premise else 'N',  # shivolcig
            'Y' if not is_on_premise else 'N',  # spharm
            liquor,  # sliquor
            wine,  # swine
            beer,  # sbeer
            onprem,  # sonprem
            food_type,  # sfoodtype
            'FUTURE1',  # sfuture1
            'FUTURE2',  # sfuture2
            'FUTURE3',  # sfuture3
            'FILLER',  # sfiller8
            'SGWS',  # src_desc
            f"TDLX{i:05d}",  # cstdlinxscd
            'Y',  # current_ind
            trade_channel,  # trade_channel_desc
            premise_type,  # premise_type
            f"{premise_type}-Premise",  # tdlinx_premise
            volume_desc,  # store_volume_desc
            chain_desc,  # chain_indicator_desc
            format_type,  # food_type_desc
            format_type,  # format_type_desc
            'Valid Coordinates',  # lat_long_geo_desc
            'Multi-Unit' if chain_ind == 'C' else 'Single Store',  # no_of_stores_desc
            'Active',  # store_status_desc
            'New Account',  # transaction_code_desc
            f"ULOC{i:05d}",  # htdlinxucd
            f"{store_name[:20].upper()} {city[:10].upper()}",  # hulname
            1000000000 + i,  # td_store_osk
            'SGWS',  # source_system
            ecommerce_provider,  # ecommerce_provider
            'Y' if ecommerce_provider != 'None' else 'N',  # ecommerce_delivery_ind
            'Y' if ecommerce_provider in ['Instacart', 'DoorDash'] else 'N',  # ecommerce_in_store_pickup_ind
            'Y' if ecommerce_provider in ['DoorDash', 'Uber Eats'] else 'N',  # ecommerce_curbside_pickup_ind
            '2026-01-29 12:00:00.000000',  # load_dt
            '2026-01-29 12:00:00.000000',  # modified_dt
        ]
        
        stores.append(store)
        
        if (i + 1) % 100 == 0:
            print(f"  Generated {i + 1} stores...")
    
    # Write to file
    with open(SEED_DIR / 'v_td_store.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(stores)
    
    print(f"✅ Wrote {num_stores} stores to v_td_store.csv")

if __name__ == "__main__":
    print("=" * 80)
    print("SGWS Site and Store Data Generator")
    print("=" * 80)
    print()
    
    generate_sites(50)  # 50 distribution centers
    print()
    generate_stores(500)  # 500 retail locations
    print()
    
    print("=" * 80)
    print("✅ Site and Store Data Generation Complete!")
    print("=" * 80)
    print("Summary:")
    print("  - Distribution Centers: 50")
    print("  - Retail Locations: 500")
    print()
