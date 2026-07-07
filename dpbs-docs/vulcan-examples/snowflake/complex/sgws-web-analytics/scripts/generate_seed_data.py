#!/usr/bin/env python3
"""
Generate realistic seed data for SGWS Web Analytics
Generates data for a US alcohol distributor with realistic customer names, 
addresses, and product catalog.
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

# Configuration
NUM_CUSTOMERS = 10000
NUM_PRODUCTS = 5000
NUM_SALES_PER_CUSTOMER = 20
NUM_ORDERS_PER_CUSTOMER = 5
NUM_SALESPERSONS = 500

# Seed directory
SEED_DIR = Path(__file__).parent / "seeds"

# ============================================================================
# REALISTIC US DATA
# ============================================================================

# Real US cities with states and zip codes
US_CITIES = [
    ('New York', 'NY', '10001-10299'),
    ('Los Angeles', 'CA', '90001-90899'),
    ('Chicago', 'IL', '60601-60699'),
    ('Houston', 'TX', '77001-77299'),
    ('Phoenix', 'AZ', '85001-85099'),
    ('Philadelphia', 'PA', '19101-19199'),
    ('San Antonio', 'TX', '78201-78299'),
    ('San Diego', 'CA', '92101-92199'),
    ('Dallas', 'TX', '75201-75399'),
    ('San Jose', 'CA', '95101-95199'),
    ('Austin', 'TX', '78701-78799'),
    ('Jacksonville', 'FL', '32201-32299'),
    ('Fort Worth', 'TX', '76101-76199'),
    ('Columbus', 'OH', '43201-43299'),
    ('Charlotte', 'NC', '28201-28299'),
    ('San Francisco', 'CA', '94101-94199'),
    ('Indianapolis', 'IN', '46201-46299'),
    ('Seattle', 'WA', '98101-98199'),
    ('Denver', 'CO', '80201-80299'),
    ('Boston', 'MA', '02101-02299'),
    ('Nashville', 'TN', '37201-37299'),
    ('Oklahoma City', 'OK', '73101-73199'),
    ('Las Vegas', 'NV', '89101-89199'),
    ('Portland', 'OR', '97201-97299'),
    ('Memphis', 'TN', '38101-38199'),
    ('Louisville', 'KY', '40201-40299'),
    ('Milwaukee', 'WI', '53201-53299'),
    ('Albuquerque', 'NM', '87101-87199'),
    ('Tucson', 'AZ', '85701-85799'),
    ('Atlanta', 'GA', '30301-30399'),
    ('Miami', 'FL', '33101-33199'),
    ('Tampa', 'FL', '33601-33699'),
    ('New Orleans', 'LA', '70112-70199'),
]

# Realistic customer business types for alcohol industry
CUSTOMER_PREFIXES = [
    "The", "O'Malley's", "Joe's", "Maria's", "Tony's", "Pat's", "Mike's", 
    "Sam's", "Jimmy's", "Blue", "Red", "Green", "Golden", "Silver", "Black",
    "White", "Royal", "Crown", "King's", "Queen's", "The Old", "The New"
]

CUSTOMER_TYPES = [
    "Bar & Grill", "Tavern", "Pub", "Bistro", "Steakhouse", "Restaurant",
    "Liquor Store", "Wine Shop", "Sports Bar", "Brewery", "Craft House",
    "Italian Restaurant", "Mexican Cantina", "Sushi Bar", "Gastropub",
    "Wine Bar", "Cocktail Lounge", "Hotel", "Country Club", "Golf Club",
    "Casino", "Event Center", "Taproom", "Beer Garden", "Pizzeria",
    "Seafood Restaurant", "Grill", "Diner", "Café", "Nightclub"
]

STREET_NAMES = [
    "Main St", "Oak Ave", "Maple Dr", "Pine St", "Broadway", "Park Ave",
    "Washington St", "Jefferson Ave", "Lincoln Blvd", "Madison St",
    "1st Ave", "2nd Street", "Market St", "State St", "Church St"
]

# Realistic alcohol products
WINE_BRANDS = [
    "Kendall-Jackson", "Robert Mondavi", "Beringer", "Columbia Crest", "Chateau Ste Michelle",
    "Woodbridge", "Barefoot", "Yellow Tail", "Apothic", "19 Crimes",
    "La Crema", "Meiomi", "Caymus", "Silver Oak", "Duckhorn", "Stag's Leap"
]

SPIRIT_BRANDS = [
    "Jack Daniel's", "Jim Beam", "Maker's Mark", "Crown Royal", "Johnnie Walker",
    "Grey Goose", "Tito's", "Ketel One", "Absolut", "Smirnoff",
    "Patron", "Jose Cuervo", "Bacardi", "Captain Morgan", "Hennessy",
    "Bombay Sapphire", "Tanqueray", "Jameson", "Glenlivet", "Macallan"
]

BEER_BRANDS = [
    "Budweiser", "Coors", "Miller", "Corona", "Heineken", "Stella Artois",
    "Sam Adams", "Sierra Nevada", "Blue Moon", "Modelo", "Dos Equis"
]

PRODUCT_TYPES = [
    "Chardonnay", "Cabernet Sauvignon", "Pinot Noir", "Merlot", "Sauvignon Blanc",
    "Vodka", "Whiskey", "Bourbon", "Scotch", "Tequila", "Rum", "Gin",
    "Lager", "IPA", "Pale Ale", "Stout", "Pilsner"
]

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def random_string(length=10):
    import string
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))

def random_email(business_name, domain_suffix=''):
    clean_name = business_name.lower().replace(' ', '').replace("'", '').replace('&', 'and')[:15]
    domains = ['gmail.com', 'yahoo.com', 'outlook.com', 'business.com']
    return f"{clean_name}{domain_suffix}@{random.choice(domains)}"

def random_phone():
    area_code = random.randint(200, 999)
    exchange = random.randint(200, 999)
    number = random.randint(1000, 9999)
    return f"{area_code}-{exchange}-{number}"

def get_random_location():
    city, state, zip_range = random.choice(US_CITIES)
    zip_parts = zip_range.split('-')
    zip_code = random.randint(int(zip_parts[0]), int(zip_parts[1]))
    return city, state, str(zip_code)

def random_street_address():
    number = random.randint(100, 9999)
    street = random.choice(STREET_NAMES)
    suite = f"Suite {random.randint(100, 999)}" if random.random() > 0.7 else ""
    return f"{number} {street}", suite

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

# Read existing data to get column headers
def read_csv_headers(filename):
    filepath = SEED_DIR / filename
    with open(filepath, 'r') as f:
        reader = csv.reader(f)
        return next(reader)

# Generate customer data
def generate_customers(num_customers=10000):
    print(f"Generating {num_customers} realistic customer records...")
    
    headers = read_csv_headers('v_d_customer.csv')
    
    customers = []
    sites = [1, 20, 60, 170]
    premise_codes = {
        'ON': ['Bar & Grill', 'Tavern', 'Pub', 'Restaurant', 'Hotel', 'Casino'],
        'OFF': ['Liquor Store', 'Wine Shop', 'Convenience Store', 'Grocery Store'],
    }
    
    for i in range(num_customers):
        customer_no = 100000 + i
        site = random.choice(sites)
        
        # Generate realistic business name
        premise_type = random.choice(['ON', 'OFF'])
        business_type = random.choice(premise_codes[premise_type])
        prefix = random.choice(CUSTOMER_PREFIXES)
        business_name = f"{prefix} {business_type}" if random.random() > 0.5 else f"{business_type}"
        if random.random() > 0.7:
            business_name = f"{random.choice(['The ', ''])}{random.choice(['Corner', 'Downtown', 'Uptown', 'Main Street', 'Harbor', 'Lakeside'])} {business_type}"
        
        # Get realistic location
        city, state, zip_code = get_random_location()
        address1, address2 = random_street_address()
        
        customer = [
            random.randint(100000000, 999999999),  # customer_sk
            site,  # site
            customer_no,  # customer_no
            business_name,  # customer_name
            address1,  # address_1
            address2,  # address_2
            city,  # city
            state,  # state
            zip_code,  # zip
            f"{random.randint(1, 150):03d}",  # county
            f"{premise_type} ",  # premise_code (ON/OFF premise)
            f"{random.randint(1, 100):03d}",  # liquor_rating
            f"{random.randint(1, 100):03d}",  # wine_rating
            random.choice(['A', 'I']),  # status (A=Active, I=Inactive)
        ]
        
        # Fill remaining columns with appropriate random data
        for j in range(len(headers) - len(customer)):
            col_name = headers[len(customer)].lower()
            
            if 'email' in col_name:
                customer.append(random_email(business_name, str(i)))
            elif 'phone' in col_name or 'fax' in col_name:
                customer.append(random_phone())
            elif 'date' in col_name or '_dt' in col_name:
                customer.append(random_datetime())
            elif 'amt' in col_name or 'bal' in col_name or 'vol' in col_name or 'revenue' in col_name:
                customer.append(random_float(5000, 500000))
            elif 'limit' in col_name:
                customer.append(random_float(10000, 250000))
            elif 'latitude' in col_name:
                customer.append(random_float(25.0, 49.0, 6))  # US latitude range
            elif 'longitude' in col_name:
                customer.append(random_float(-125.0, -66.0, 6))  # US longitude range
            elif '_no' in col_name and 'customer' not in col_name:
                customer.append(random.randint(1000, 999999))
            elif '_sk' in col_name:
                customer.append(random.randint(100000000, 9999999999))
            elif 'flg' in col_name or '_ind' in col_name:
                customer.append(random.choice(['Y', 'N']))
            elif '_cd' in col_name or 'code' in col_name:
                customer.append(random.choice(['A', 'B', 'C', 'D', 'E']))
            elif 'desc' in col_name or 'name' in col_name:
                customer.append(f"{random.choice(['Premium', 'Standard', 'Value', 'VIP', 'Corporate'])} Tier")
            elif 'premise' in col_name and col_name != 'premise_code':
                customer.append(random.choice(['On Premise', 'Off Premise']))
            elif 'chain' in col_name:
                customer.append(random.choice(['Independent', 'Chain', 'Franchise']))
            elif col_name == 'univ_customer_no':
                # Silver CUSTOMER expects numeric; avoid alphanumeric
                customer.append(str(random.randint(100000, 999999999)))
            else:
                customer.append(random_string(random.randint(3, 20)))
        
        customers.append(customer)
        
        if (i + 1) % 1000 == 0:
            print(f"  Generated {i + 1} customers...")
    
    # Write to file
    output_file = SEED_DIR / 'v_d_customer.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(customers)
    
    print(f"✅ Wrote {num_customers} customers to {output_file}")
    return [c[2] for c in customers]  # Return customer_no list

# Generate sales data
def generate_sales(customer_numbers, records_per_customer=20):
    print(f"Generating ~{len(customer_numbers) * records_per_customer} sales records...")
    
    headers = read_csv_headers('v_fact_sales.csv')
    
    sales = []
    sites = [1, 20, 60, 170]
    entry_origins = ['UB', 'J', '1T', 'B3', 'WA', 'U', 'F', 'Z', '6']
    warehouses = [14, 201, 360, 702]
    
    for idx, customer_no in enumerate(customer_numbers):
        num_records = random.randint(records_per_customer - 10, records_per_customer + 10)
        
        for r in range(num_records):
            sales.append([
                random.randint(1000000000, 9999999999),  # sales_sk
                random.choice(sites),  # site
                customer_no,  # customer_no
                random.randint(10000, 999999),  # item_no
                random_date('2024-01-01', '2025-12-31'),  # posting_dt_sk
                random.randint(1000000, 9999999),  # invoice_no
                random_date('2024-01-01', '2025-12-31'),  # invoice_dt_sk
                random_float(100, 1000, 2),  # qty_dec_equ
                random.randint(1000, 9999999),  # cases
                random.randint(1000, 9999999),  # bottles
                random_datetime('2024-01-01', '2026-01-01'),  # ship_dt
                f"{random.randint(202401, 202512)}",  # posting_prd
                random.choice(entry_origins),  # entry_origin
                random.randint(100000, 9999999),  # sequence_no
                random_float(10, 500000, 4),  # unit_price
                random_float(10000, 500000, 4),  # ext_net
                random_float(5000, 300000, 4),  # ext_cost
                random_float(1000, 10000, 4),  # ext_depl_allow
                random_float(1000, 10000, 4),  # ext_participation
                random_float(1000, 10000, 4),  # ext_guaranteed_adj
                random_float(10000, 500000, 4),  # cqd_amt
                random.randint(1000000000, 9999999999),  # current_salesperson_sk
                random.randint(100000, 9999999),  # salesman_no
                random.randint(1000000000, 9999999999),  # salesperson_sk
                random.randint(100000000, 999999999),  # customer_sk
                random.randint(1000000, 9999999),  # order_no
                random_datetime('2024-01-01', '2026-01-01'),  # load_dt
                random_string(random.randint(3, 20)),  # deal_id
                random_datetime('2024-01-01', '2026-01-01'),  # modified_dt
                random.choice(warehouses),  # warehouse_no
            ])
        
        if (idx + 1) % 500 == 0:
            print(f"  Generated sales for {idx + 1} customers...")
    
    # Write to file
    output_file = SEED_DIR / 'v_fact_sales.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(sales)
    
    print(f"✅ Wrote {len(sales)} sales records to {output_file}")

# Generate orders data
def generate_orders(customer_numbers, records_per_customer=5):
    print(f"Generating ~{len(customer_numbers) * records_per_customer} order records...")
    
    headers = read_csv_headers('v_f_order.csv')
    
    orders = []
    sites = [1, 20, 60, 170]
    entry_codes = ['N', 'F', 'C', '1', 'I', 'E', 'Y']
    status_codes = ['C', 'J', 'H', '0', '1', 'I']
    warehouses = [14, 201, 360, 702]
    
    for idx, customer_no in enumerate(customer_numbers):
        num_records = random.randint(records_per_customer - 2, records_per_customer + 3)
        
        for r in range(num_records):
            orders.append([
                random.randint(100000000, 9999999999),  # order_sk
                random.choice(sites),  # site_id
                random.randint(10000, 999999),  # item_no
                customer_no,  # customer_no
                random.randint(1000000, 9999999),  # order_no
                random.randint(100000, 9999999),  # order_line_no
                random.choice(entry_codes),  # order_entry_cd
                random.randint(100000, 9999999),  # order_cases_qty
                random.randint(100000, 9999999),  # order_bottle_qty
                random_float(-1000, 1000, 4),  # cases_dec_equivalent
                random_float(-300000, 500000, 4),  # order_net_amt
                random_float(10000, 500000, 4),  # order_price_per_case
                random_float(100, 10000, 4),  # order_dsct_per_case
                random.randint(1000000, 9999999),  # invoice_no
                random.randint(100000, 9999999),  # invoice_line_no
                random_date('2024-01-01', '2025-12-31'),  # invoice_dt
                random.choice(warehouses),  # warehouse_no
                f"{random.randint(202401, 202512)}",  # posting_period
                random.choice(status_codes),  # order_status_cd
                random_date('2024-01-01', '2025-12-31'),  # order_entry_dt
                random.choice(['0', 'Y', 'S', 'J', 'E', 'H']),  # order_reject_cd
                random_date('2024-01-01', '2026-01-01'),  # order_reject_dt
                random.randint(10000, 999999),  # order_reject_time
                random_string(random.randint(3, 40)),  # order_reject_by
                random_string(random.randint(10, 50)),  # order_external_id
                'N',  # is_deleted
                random_datetime('2024-01-01', '2026-01-01'),  # load_dt
                random_datetime('2024-01-01', '2026-01-01'),  # modified_dt
            ])
        
        if (idx + 1) % 500 == 0:
            print(f"  Generated orders for {idx + 1} customers...")
    
    # Write to file
    output_file = SEED_DIR / 'v_f_order.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(orders)
    
    print(f"✅ Wrote {len(orders)} order records to {output_file}")

# Generate product items (v_d_curr_item)
def generate_products(num_products=5000):
    print(f"Generating {num_products} realistic alcohol product records...")
    
    headers = read_csv_headers('v_d_curr_item.csv')
    
    products = []
    sites = [1, 20, 60, 170]
    statuses = ['A', 'I', 'D']
    
    for i in range(num_products):
        item_no = 10000 + i
        
        # Generate realistic alcohol product
        product_category = random.choice(['WINE', 'SPIRITS', 'BEER'])
        if product_category == 'WINE':
            brand = random.choice(WINE_BRANDS)
            variety = random.choice(['Chardonnay', 'Cabernet Sauvignon', 'Pinot Noir', 'Merlot', 'Sauvignon Blanc', 'Pinot Grigio', 'Riesling'])
            size = random.choice(['750ml', '1.5L', '375ml'])
            product_name = f"{brand} {variety} {size}"
        elif product_category == 'SPIRITS':
            brand = random.choice(SPIRIT_BRANDS)
            spirit_type = random.choice(['Vodka', 'Whiskey', 'Bourbon', 'Scotch', 'Tequila', 'Rum', 'Gin'])
            size = random.choice(['750ml', '1L', '375ml', '1.75L'])
            product_name = f"{brand} {spirit_type} {size}"
        else:  # BEER
            brand = random.choice(BEER_BRANDS)
            package = random.choice(['12pk Bottles', '24pk Cans', '6pk Bottles', 'Case'])
            product_name = f"{brand} {package}"
        
        product = [
            random.randint(100000000, 999999999),  # item_sk
            random.choice(sites),  # site
            item_no,  # item_no
            product_name,  # item_name
            brand if product_category != 'BEER' else brand.split()[0],  # brand_name
            random.choice(statuses),  # status
        ]
        
        # Fill remaining columns
        for j in range(len(headers) - len(product)):
            col_name = headers[len(product)].lower()
            
            if 'date' in col_name or '_dt' in col_name:
                product.append(random_datetime())
            elif 'price' in col_name or 'cost' in col_name:
                if product_category == 'WINE':
                    product.append(random_float(50, 500))
                elif product_category == 'SPIRITS':
                    product.append(random_float(100, 800))
                else:  # BEER
                    product.append(random_float(15, 45))
            elif 'qty' in col_name or 'vol' in col_name or 'case' in col_name:
                product.append(random.randint(0, 10000))
            elif '_no' in col_name and 'item' not in col_name:
                product.append(random.randint(100, 999999))
            elif '_sk' in col_name:
                product.append(random.randint(100000000, 9999999999))
            elif 'flg' in col_name or '_ind' in col_name:
                product.append(random.choice(['Y', 'N']))
            elif '_cd' in col_name or 'code' in col_name:
                product.append(random.choice(['A', 'B', 'C', 'D']))
            elif 'class' in col_name or 'category' in col_name:
                product.append(product_category)
            elif 'desc' in col_name or 'name' in col_name:
                product.append(f"{product_category} - {random.choice(['Premium', 'Standard', 'Value'])}")
            else:
                product.append(random_string(random.randint(3, 15)))
        
        products.append(product)
        
        if (i + 1) % 500 == 0:
            print(f"  Generated {i + 1} products...")
    
    output_file = SEED_DIR / 'v_d_curr_item.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(products)
    
    print(f"✅ Wrote {num_products} products to {output_file}")
    return [p[2] for p in products]  # Return item_no list

# Generate corporate product items (v_d_curr_corp_item)
def generate_corp_products(num_products=5000):
    print(f"Generating {num_products} corporate product records...")
    
    headers = read_csv_headers('v_d_curr_corp_item.csv')
    
    products = []
    
    suppliers = [
        "Constellation Brands", "Diageo", "Pernod Ricard", "Brown-Forman", 
        "Beam Suntory", "LVMH", "Treasury Wine Estates", "E&J Gallo",
        "Heineken", "Anheuser-Busch", "MillerCoors", "Bacardi"
    ]
    
    for i in range(num_products):
        corp_item_no = 10000 + i
        
        # Generate realistic corporate product info
        product_category = random.choice(['WINE', 'SPIRITS', 'BEER'])
        supplier = random.choice(suppliers)
        
        if product_category == 'WINE':
            varietal = random.choice(['Chardonnay', 'Cabernet Sauvignon', 'Pinot Noir', 'Merlot'])
            product_name = f"{varietal} - {random.choice(['California', 'Washington', 'Oregon', 'Napa Valley'])}"
        elif product_category == 'SPIRITS':
            spirit_type = random.choice(['Premium Vodka', 'Aged Bourbon', 'Single Malt Scotch', 'Silver Tequila'])
            product_name = spirit_type
        else:
            beer_style = random.choice(['Craft IPA', 'Premium Lager', 'Imported Pilsner'])
            product_name = beer_style
        
        product = [
            random.randint(100000000, 999999999),  # corp_item_sk
            corp_item_no,  # corp_item_no
            product_name,  # corp_item_name
            supplier,  # supplier/producer
        ]
        
        # Fill remaining columns
        for j in range(len(headers) - len(product)):
            col_name = headers[len(product)].lower()
            
            if 'date' in col_name or '_dt' in col_name:
                product.append(random_datetime())
            elif 'price' in col_name or 'cost' in col_name:
                if product_category == 'WINE':
                    product.append(random_float(40, 400))
                elif product_category == 'SPIRITS':
                    product.append(random_float(80, 600))
                else:
                    product.append(random_float(12, 35))
            elif '_no' in col_name:
                product.append(random.randint(100, 999999))
            elif '_sk' in col_name:
                product.append(random.randint(100000000, 9999999999))
            elif 'category' in col_name or 'class' in col_name:
                product.append(product_category)
            elif 'desc' in col_name or 'name' in col_name:
                product.append(f"{product_category} - {supplier}")
            else:
                product.append(random_string(random.randint(3, 15)))
        
        products.append(product)
        
        if (i + 1) % 500 == 0:
            print(f"  Generated {i + 1} corporate products...")
    
    output_file = SEED_DIR / 'v_d_curr_corp_item.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(products)
    
    print(f"✅ Wrote {num_products} corporate products to {output_file}")

# Generate customer attributes (v_d_customer_na_attributes)
def generate_customer_attributes(customer_numbers):
    print(f"Generating {len(customer_numbers)} customer attribute records...")
    
    headers = read_csv_headers('v_d_customer_na_attributes.csv')
    
    attributes = []
    
    for idx, customer_no in enumerate(customer_numbers):
        attr = [
            random.randint(100000000, 999999999),  # customer_sk
            customer_no,  # customer_no
        ]
        
        # Fill remaining columns
        for j in range(len(headers) - len(attr)):
            col_name = headers[len(attr)]
            
            if 'date' in col_name.lower() or 'dt' in col_name.lower():
                attr.append(random_datetime())
            elif 'amt' in col_name.lower() or 'bal' in col_name.lower():
                attr.append(random_float(0, 100000))
            elif 'flg' in col_name.lower() or 'ind' in col_name.lower():
                attr.append(random.choice(['Y', 'N']))
            elif 'desc' in col_name.lower() or 'name' in col_name.lower():
                attr.append(f"DESC_{idx % 100}")
            else:
                attr.append(random_string(random.randint(3, 15)))
        
        attributes.append(attr)
        
        if (idx + 1) % 1000 == 0:
            print(f"  Generated {idx + 1} customer attributes...")
    
    output_file = SEED_DIR / 'v_d_customer_na_attributes.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(attributes)
    
    print(f"✅ Wrote {len(attributes)} customer attributes to {output_file}")

# Generate roadnet customers (v_d_roadnet_customers)
def generate_roadnet_customers(customer_numbers):
    print(f"Generating {len(customer_numbers)} roadnet customer records...")
    
    headers = read_csv_headers('v_d_roadnet_customers.csv')
    
    roadnet = []
    
    for idx, customer_no in enumerate(customer_numbers):
        record = [
            customer_no,  # customer_no
            f"ROUTE_{idx % 100}",  # route
        ]
        
        # Fill remaining columns
        for j in range(len(headers) - len(record)):
            col_name = headers[len(record)]
            
            if 'date' in col_name.lower() or 'dt' in col_name.lower():
                record.append(random_datetime())
            elif 'lat' in col_name.lower() or 'lon' in col_name.lower():
                record.append(random_float(-180, 180, 6))
            elif 'desc' in col_name.lower() or 'name' in col_name.lower():
                record.append(f"DESC_{idx % 100}")
            else:
                record.append(random_string(random.randint(3, 15)))
        
        roadnet.append(record)
        
        if (idx + 1) % 1000 == 0:
            print(f"  Generated {idx + 1} roadnet customers...")
    
    output_file = SEED_DIR / 'v_d_roadnet_customers.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(roadnet)
    
    print(f"✅ Wrote {len(roadnet)} roadnet customers to {output_file}")

# Generate salesperson data (v_d_current_account_salesperson)
def generate_salespersons(num_salespersons=500):
    print(f"Generating {num_salespersons} salesperson records...")
    
    headers = read_csv_headers('v_d_current_account_salesperson.csv')
    
    first_names = [
        'James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph',
        'Mary', 'Jennifer', 'Linda', 'Patricia', 'Barbara', 'Elizabeth', 'Susan', 'Jessica',
        'Christopher', 'Daniel', 'Matthew', 'Anthony', 'Mark', 'Donald', 'Steven', 'Paul'
    ]
    
    last_names = [
        'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
        'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson',
        'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Thompson', 'White'
    ]
    
    salespersons = []
    
    for i in range(num_salespersons):
        first_name = random.choice(first_names)
        last_name = random.choice(last_names)
        full_name = f"{first_name} {last_name}"
        
        salesperson = [
            random.randint(100000000, 9999999999),  # salesperson_sk
            100000 + i,  # salesperson_no
            full_name,  # salesperson_name
        ]
        
        # Fill remaining columns
        for j in range(len(headers) - len(salesperson)):
            col_name = headers[len(salesperson)].lower()
            
            if 'email' in col_name:
                email_name = f"{first_name.lower()}.{last_name.lower()}"
                salesperson.append(f"{email_name}@sgws.com")
            elif 'phone' in col_name:
                salesperson.append(random_phone())
            elif 'date' in col_name or '_dt' in col_name:
                salesperson.append(random_datetime())
            elif 'territory' in col_name or 'region' in col_name:
                salesperson.append(random.choice(['Northeast', 'Southeast', 'Midwest', 'Southwest', 'West']))
            elif 'title' in col_name or 'position' in col_name:
                salesperson.append(random.choice(['Account Executive', 'Sales Representative', 'Territory Manager', 'Sr. Account Manager']))
            elif 'desc' in col_name or 'name' in col_name:
                salesperson.append(f"Sales {random.choice(['Division A', 'Division B', 'Division C'])}")
            else:
                salesperson.append(random_string(random.randint(3, 15)))
        
        salespersons.append(salesperson)
    
    output_file = SEED_DIR / 'v_d_current_account_salesperson.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(salespersons)
    
    print(f"✅ Wrote {num_salespersons} salespersons to {output_file}")

# Generate pricing data (v_f_npw_pricing)
def generate_pricing(product_numbers):
    print(f"Generating pricing for {len(product_numbers)} products...")
    
    headers = read_csv_headers('v_f_npw_pricing.csv')
    
    pricing = []
    sites = [1, 20, 60, 170]
    
    for idx, item_no in enumerate(product_numbers):
        # Generate pricing for each site
        for site in sites:
            price = [
                random.randint(100000000, 999999999),  # pricing_sk
                site,  # site
                item_no,  # item_no
                random_float(10, 500, 2),  # price
            ]
            
            # Fill remaining columns
            for j in range(len(headers) - len(price)):
                col_name = headers[len(price)]
                
                if 'date' in col_name.lower() or 'dt' in col_name.lower():
                    price.append(random_datetime())
                elif 'price' in col_name.lower() or 'cost' in col_name.lower() or 'amt' in col_name.lower():
                    price.append(random_float(5, 500))
                elif 'desc' in col_name.lower():
                    price.append(f"DESC_{idx % 100}")
                else:
                    price.append(random_string(random.randint(3, 10)))
            
            pricing.append(price)
        
        if (idx + 1) % 500 == 0:
            print(f"  Generated pricing for {idx + 1} products...")
    
    output_file = SEED_DIR / 'v_f_npw_pricing.csv'
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(pricing)
    
    print(f"✅ Wrote {len(pricing)} pricing records to {output_file}")

def main():
    print("=" * 80)
    print("SGWS Web Analytics - Seed Data Generator (ENHANCED)")
    print("=" * 80)
    print()
    
    # Generate products first (needed for sales)
    print("STEP 1: Generating Product Data")
    print("-" * 80)
    product_numbers = generate_products(NUM_PRODUCTS)
    print()
    generate_corp_products(NUM_PRODUCTS)
    print()
    generate_pricing(product_numbers)
    print()
    
    # Generate customers
    print("STEP 2: Generating Customer Data")
    print("-" * 80)
    customer_numbers = generate_customers(NUM_CUSTOMERS)
    print()
    generate_customer_attributes(customer_numbers)
    print()
    generate_roadnet_customers(customer_numbers)
    print()
    
    # Generate salespersons
    print("STEP 3: Generating Sales Team Data")
    print("-" * 80)
    generate_salespersons(NUM_SALESPERSONS)
    print()
    
    # Generate transactions
    print("STEP 4: Generating Transaction Data")
    print("-" * 80)
    generate_sales(customer_numbers, NUM_SALES_PER_CUSTOMER)
    print()
    generate_orders(customer_numbers, NUM_ORDERS_PER_CUSTOMER)
    print()
    
    print("=" * 80)
    print("✅ DATA GENERATION COMPLETE!")
    print("=" * 80)
    print(f"Summary:")
    print(f"  Products:")
    print(f"    - Items:              {NUM_PRODUCTS:,}")
    print(f"    - Corporate Items:    {NUM_PRODUCTS:,}")
    print(f"    - Pricing Records:    {NUM_PRODUCTS * 4:,} (4 sites)")
    print()
    print(f"  Customers:")
    print(f"    - Customers:          {NUM_CUSTOMERS:,}")
    print(f"    - Attributes:         {NUM_CUSTOMERS:,}")
    print(f"    - Roadnet Records:    {NUM_CUSTOMERS:,}")
    print()
    print(f"  Sales Team:")
    print(f"    - Salespersons:       {NUM_SALESPERSONS:,}")
    print()
    print(f"  Transactions:")
    print(f"    - Sales:              ~{NUM_CUSTOMERS * NUM_SALES_PER_CUSTOMER:,}")
    print(f"    - Orders:             ~{NUM_CUSTOMERS * NUM_ORDERS_PER_CUSTOMER:,}")
    print()
    print(f"  TOTAL RECORDS:          ~{NUM_PRODUCTS*3 + NUM_CUSTOMERS*3 + NUM_SALESPERSONS + NUM_CUSTOMERS*(NUM_SALES_PER_CUSTOMER + NUM_ORDERS_PER_CUSTOMER):,}")
    print()
    print("Next steps:")
    print("  1. Review the generated CSV files in the seeds/ folder")
    print("  2. Run: vulcan plan --auto-apply")
    print("  3. Run: vulcan run")
    print()

if __name__ == "__main__":
    main()
