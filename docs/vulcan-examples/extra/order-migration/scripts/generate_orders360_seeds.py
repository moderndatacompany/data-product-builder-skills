#!/usr/bin/env python3
"""
Generate realistic Orders360 seed CSVs with referential integrity.

No external dependencies (standard library only).

Writes CSVs compatible with:
  - models/seeds/raw_customers.sql
  - models/seeds/raw_products.sql
  - models/seeds/raw_orders.sql
  - models/seeds/raw_order_items.sql
  - models/seeds/raw_payments.sql
  - models/seeds/raw_shipments.sql
  - models/seeds/raw_returns.sql
"""

from __future__ import annotations

import argparse
import csv
import os
import random
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


ORDER_STATUSES = ["Completed", "Shipped", "Processing", "Cancelled", "Returned"]
ORDER_CHANNELS = ["Web", "Mobile", "Store", "Marketplace"]
PAYMENT_METHODS = ["Card", "PayPal", "BankTransfer", "Wallet"]
PAYMENT_PROVIDERS = ["Stripe", "Adyen", "PayPal", "Braintree"]
RETURN_REASONS = ["Defective", "ChangedMind", "SizeIssue", "LateDelivery", "CancelledOrder"]
RETURN_STATUSES = ["Approved", "Rejected", "Pending"]
SHIPPING_STATUSES = ["Delivered", "InTransit"]


US_STATES: List[Tuple[str, str, str, str]] = [
    ("NY", "New York", "10001", "US"),
    ("CA", "Los Angeles", "90001", "US"),
    ("IL", "Chicago", "60601", "US"),
    ("TX", "Houston", "77001", "US"),
    ("AZ", "Phoenix", "85001", "US"),
    ("PA", "Philadelphia", "19101", "US"),
    ("MA", "Boston", "02108", "US"),
    ("FL", "Miami", "33101", "US"),
    ("WA", "Seattle", "98101", "US"),
    ("CO", "Denver", "80202", "US"),
    ("OR", "Portland", "97205", "US"),
    ("TN", "Nashville", "37201", "US"),
    ("NV", "Las Vegas", "89101", "US"),
    ("GA", "Atlanta", "30303", "US"),
    ("NJ", "Newark", "07102", "US"),
    ("NC", "Charlotte", "28202", "US"),
    ("MN", "Minneapolis", "55401", "US"),
    ("OH", "Cleveland", "44114", "US"),
    ("NM", "Albuquerque", "87102", "US"),
]


FIRST_NAMES = [
    "Ava", "Liam", "Mia", "Noah", "Emma", "Olivia", "Ethan", "Sophia", "Amir", "Riya",
    "Leo", "Ivy", "Zane", "Tara", "Quinn", "Ben", "Ana", "Omar", "Vera", "Will",
    "Xiu", "Yara", "Deepak", "Camila", "Sam", "Grace", "Henry", "Alice", "Bob", "Carol",
]
LAST_NAMES = [
    "Johnson", "Smith", "Williams", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Anderson",
    "Thomas", "Jackson", "White", "Harris", "Clark", "Lopez", "Young", "Patel", "Nguyen", "Kim",
    "Rossi", "Martin", "Silva", "Walker", "Gomez", "Santos", "Mehta", "Lee", "Garcia", "Cooper",
]


@dataclass(frozen=True)
class Product:
    product_id: str
    product_name: str
    category: str
    subcategory: str
    brand: str
    color: str
    size: str
    weight: float
    material: str
    model_number: str
    sku: str
    upc: str
    price: float
    cost: float
    supplier: str
    warranty_period: str
    release_date: date
    rating: float
    stock_quantity: int
    discontinued: bool


def _id(prefix: str, n: int, width: int) -> str:
    return f"{prefix}{n:0{width}d}"


def _rand_date(rng: random.Random, start: date, end: date) -> date:
    days = (end - start).days
    return start + timedelta(days=rng.randint(0, max(days, 0)))


def _choice_weighted(rng: random.Random, choices: List[Tuple[str, float]]) -> str:
    total = sum(w for _, w in choices)
    r = rng.random() * total
    upto = 0.0
    for val, w in choices:
        upto += w
        if upto >= r:
            return val
    return choices[-1][0]


def _tax_rate_for_state(state: str) -> float:
    # Simple, deterministic mapping (not real tax tables).
    mapping = {
        "NY": 0.08875,
        "CA": 0.0825,
        "IL": 0.1025,
        "TX": 0.0825,
        "AZ": 0.08,
        "PA": 0.06,
        "MA": 0.0625,
        "FL": 0.07,
        "WA": 0.1025,
        "CO": 0.029,
        "OR": 0.0,
        "TN": 0.07,
        "NV": 0.0815,
        "GA": 0.089,
        "NJ": 0.06625,
        "NC": 0.07,
        "MN": 0.077,
        "OH": 0.0725,
        "NM": 0.05125,
    }
    return float(mapping.get(state, 0.08))


def _money(x: float) -> float:
    return round(float(x) + 1e-9, 2)


def generate_customers(rng: random.Random, n: int) -> List[Dict[str, object]]:
    segments = [("Platinum", 0.18), ("Gold", 0.32), ("Silver", 0.33), ("Bronze", 0.17)]
    statuses = [("Active", 0.9), ("Inactive", 0.07), ("Suspended", 0.03)]
    rows: List[Dict[str, object]] = []
    for i in range(1, n + 1):
        cid = _id("C", i, 4)
        fn = rng.choice(FIRST_NAMES)
        ln = rng.choice(LAST_NAMES)
        email = f"{fn.lower()}.{ln.lower()}{i:03d}@example.com"
        phone = f"555-{rng.randint(1000, 9999)}"
        state, city, postal, country = rng.choice(US_STATES)
        address1 = f"{rng.randint(10, 9999)} {rng.choice(['Main', 'Oak', 'Pine', 'Cedar', 'Maple', 'Market', 'River'])} {rng.choice(['St', 'Ave', 'Rd', 'Blvd', 'Dr'])}"
        address2 = rng.choice(["", f"Apt {rng.randint(1, 40)}", f"Unit {rng.randint(1, 30)}", f"Suite {rng.randint(100, 900)}"])
        segment = _choice_weighted(rng, segments)
        status = _choice_weighted(rng, statuses)
        signup = _rand_date(rng, date(2020, 1, 1), date(2024, 12, 31))

        base_loyalty = {"Platinum": 85, "Gold": 70, "Silver": 55, "Bronze": 40}[segment]
        if status != "Active":
            base_loyalty -= 15
        loyalty = max(0, min(100, int(rng.gauss(base_loyalty, 10))))

        rows.append(
            {
                "customer_id": cid,
                "first_name": fn,
                "last_name": ln,
                "email": email,
                "phone": phone,
                "address_line1": address1,
                "address_line2": address2,
                "city": city,
                "state": state,
                "postal_code": postal,
                "customer_segment": segment,
                "account_status": status,
                "signup_date": signup.isoformat(),
                "loyalty_score": loyalty,
            }
        )
    return rows


def generate_products(rng: random.Random, n: int) -> Tuple[List[Product], List[Dict[str, object]]]:
    categories = [
        ("Electronics", ["Accessories", "Audio", "Power", "Wearables"]),
        ("Home", ["Lighting", "Kitchen", "Decor", "Cleaning"]),
        ("Clothing", ["Tops", "Bottoms", "Outerwear", "Footwear"]),
        ("Sports", ["Fitness", "Accessories", "Footwear", "Outdoor"]),
        ("Food", ["Beverages", "Snacks", "Pantry"]),
        ("Toys", ["Educational", "Outdoor", "Plush"]),
    ]
    brands = ["TechPro", "SoundMax", "VoltEdge", "BrightHome", "ChefMate", "ComfortWear", "UrbanThread", "FitLife", "HydroPeak", "JavaPure", "ZenLeaf", "KidsBuild", "ZoomToys", "BrainyKids", "CuddleTime"]
    colors = ["Black", "White", "Blue", "Red", "Green", "Gray", "Silver", "Clear", "Multi", "Purple", "Brown", "Indigo"]
    sizes = ["XS", "S", "M", "L", "XL", "OneSize"]
    materials = ["Metal", "Plastic", "Wood", "Fabric", "Glass", "Food"]
    suppliers = ["Tech Supplies Inc", "Home Essentials", "Kitchen Warehouse", "Fashion Direct", "Sports Wholesale", "Organic Foods Co", "Toy Factory Ltd"]
    warranty = ["30 days", "90 days", "6 months", "1 year", "2 years", "N/A"]

    products: List[Product] = []
    rows: List[Dict[str, object]] = []

    for i in range(1, n + 1):
        pid = _id("P", i, 4)
        cat, subs = rng.choice(categories)
        sub = rng.choice(subs)
        brand = rng.choice(brands)
        color = rng.choice(colors)
        size = rng.choice(sizes)
        material = rng.choice(materials)
        supplier = rng.choice(suppliers)
        warr = rng.choice(warranty)

        base_price = {
            "Electronics": rng.uniform(15, 250),
            "Home": rng.uniform(8, 150),
            "Clothing": rng.uniform(10, 120),
            "Sports": rng.uniform(12, 180),
            "Food": rng.uniform(3, 35),
            "Toys": rng.uniform(8, 80),
        }[cat]
        price = _money(base_price)
        cost = _money(price * rng.uniform(0.35, 0.75))

        pname = f"{brand} {sub} {rng.choice(['Pro', 'Plus', 'Classic', 'Mini', 'Max', ''])}".strip()
        model_number = f"{brand[:2].upper()}-{sub[:2].upper()}-{rng.randint(1, 999):03d}"
        sku = f"SKU-{i:04d}"
        upc = f"{rng.randint(100000000000, 999999999999)}"
        weight = round(rng.uniform(0.05, 2.5), 2)
        release = _rand_date(rng, date(2021, 1, 1), date(2024, 12, 31))
        rating = round(min(5.0, max(1.0, rng.gauss(4.2, 0.4))), 1)
        stock = rng.randint(0, 1000)
        discontinued = rng.random() < 0.06

        p = Product(
            product_id=pid,
            product_name=pname,
            category=cat,
            subcategory=sub,
            brand=brand,
            color=color,
            size=size,
            weight=float(weight),
            material=material,
            model_number=model_number,
            sku=sku,
            upc=upc,
            price=float(price),
            cost=float(cost),
            supplier=supplier,
            warranty_period=warr,
            release_date=release,
            rating=float(rating),
            stock_quantity=int(stock),
            discontinued=bool(discontinued),
        )
        products.append(p)
        rows.append(
            {
                "product_id": p.product_id,
                "product_name": p.product_name,
                "category": p.category,
                "subcategory": p.subcategory,
                "brand": p.brand,
                "color": p.color,
                "size": p.size,
                "weight": p.weight,
                "material": p.material,
                "model_number": p.model_number,
                "sku": p.sku,
                "upc": p.upc,
                "price": p.price,
                "cost": p.cost,
                "supplier": p.supplier,
                "warranty_period": p.warranty_period,
                "release_date": p.release_date.isoformat(),
                "rating": p.rating,
                "stock_quantity": p.stock_quantity,
                "discontinued": str(p.discontinued).lower(),
            }
        )

    return products, rows


def _compute_line_amounts(quantity: int, unit_price: float, discount_rate: float, tax_rate: float) -> Tuple[float, float, float, float]:
    subtotal = quantity * unit_price
    discount = subtotal * discount_rate
    taxable = max(0.0, subtotal - discount)
    tax = taxable * tax_rate
    total = taxable + tax
    return _money(subtotal), _money(discount), _money(tax), _money(total)


def generate_orders_bundle(
    rng: random.Random,
    customers: List[Dict[str, object]],
    products: List[Product],
    n_orders: int,
    max_items_per_order: int,
    start_date: date,
    end_date: date,
) -> Tuple[
    List[Dict[str, object]],  # orders
    List[Dict[str, object]],  # order_items
    List[Dict[str, object]],  # payments
    List[Dict[str, object]],  # shipments
    List[Dict[str, object]],  # returns
]:
    orders: List[Dict[str, object]] = []
    order_items: List[Dict[str, object]] = []
    payments: List[Dict[str, object]] = []
    shipments: List[Dict[str, object]] = []
    returns: List[Dict[str, object]] = []

    status_weights = [
        ("Completed", 0.62),
        ("Shipped", 0.22),
        ("Processing", 0.06),
        ("Cancelled", 0.05),
        ("Returned", 0.05),
    ]
    channel_weights = [("Web", 0.45), ("Mobile", 0.35), ("Store", 0.08), ("Marketplace", 0.12)]
    discount_choices = [0.0, 0.0, 0.05, 0.1, 0.15, 0.2]

    payment_id = 0
    shipment_id = 0
    return_id = 0
    order_item_id = 0

    customer_ids = [c["customer_id"] for c in customers]

    # Build an index for product lookup by id
    product_by_id: Dict[str, Product] = {p.product_id: p for p in products}
    product_ids = list(product_by_id.keys())

    for i in range(1, n_orders + 1):
        oid = _id("O", i, 6)
        cid = rng.choice(customer_ids)
        order_date = _rand_date(rng, start_date, end_date)

        state, city, postal, country = rng.choice(US_STATES)
        tax_rate = _tax_rate_for_state(state)

        status = _choice_weighted(rng, status_weights)
        channel = _choice_weighted(rng, channel_weights)
        currency = "USD"

        # Items
        n_items = rng.randint(1, max_items_per_order)
        selected_products = rng.sample(product_ids, k=min(n_items, len(product_ids)))

        order_subtotal = 0.0
        order_discount = 0.0
        order_tax = 0.0
        order_total_lines = 0.0

        returned_item_ids: List[str] = []
        for pid in selected_products:
            p = product_by_id[pid]
            qty = rng.randint(1, 5)
            # Light noise around list price to simulate promos/price changes
            unit = max(0.5, float(_money(p.price * rng.uniform(0.92, 1.08))))
            disc = float(rng.choice(discount_choices))

            order_item_id += 1
            oi_id = _id("OI", order_item_id, 6)

            line_sub, line_disc, line_tax, line_total = _compute_line_amounts(qty, unit, disc, tax_rate)
            order_subtotal += line_sub
            order_discount += line_disc
            order_tax += line_tax
            order_total_lines += line_total

            order_items.append(
                {
                    "order_item_id": oi_id,
                    "order_id": oid,
                    "product_id": pid,
                    "quantity": qty,
                    "unit_price": unit,
                    "discount_rate": disc,
                    "tax_rate": tax_rate,
                }
            )

            if status == "Returned" and rng.random() < 0.7:
                returned_item_ids.append(oi_id)
            if status == "Cancelled" and rng.random() < 0.4:
                returned_item_ids.append(oi_id)

        # Shipping cost
        base_ship = {"Web": 5.99, "Mobile": 5.49, "Store": 2.99, "Marketplace": 7.99}[channel]
        ship_cost = _money(base_ship + (0.5 * max(0, n_items - 1)) + rng.uniform(-0.75, 0.75))
        if status == "Cancelled":
            ship_cost = 0.0

        # Payment status aligned to order status
        if status in ("Processing",):
            payment_status = "Pending"
        elif status in ("Cancelled", "Returned"):
            payment_status = "Refunded"
        else:
            payment_status = "Paid"

        orders.append(
            {
                "order_id": oid,
                "order_date": order_date.isoformat(),
                "customer_id": cid,
                "order_status": status,
                "order_channel": channel,
                "currency": currency,
                "shipping_cost": ship_cost,
                "shipping_country": country,
                "shipping_state": state,
                "shipping_city": city,
                "shipping_postal_code": postal,
                "payment_status": payment_status,
            }
        )

        # Payments (amount is "what was charged/refunded" at a high level)
        payment_id += 1
        pm_id = _id("PMT", payment_id, 6)
        method = rng.choice(PAYMENT_METHODS)
        provider = rng.choice(PAYMENT_PROVIDERS)
        txn = f"TXN-{payment_id:06d}"

        order_total = _money(order_total_lines + ship_cost)
        if payment_status == "Pending":
            amount = 0.0
            pay_status = "Pending"
        elif payment_status == "Refunded":
            # Refund amount is approximate and based on returned items (or full order for cancellations)
            if returned_item_ids:
                refund_amt = 0.0
                # estimate refund from selected items (use line totals already computed in loop, but not stored)
                # simple heuristic: refund 65-100% of order_total depending on count of returned items
                ratio = min(1.0, max(0.2, len(returned_item_ids) / max(1, len(selected_products))))
                refund_amt = _money(order_total * rng.uniform(0.65, 1.0) * ratio)
                amount = refund_amt
            else:
                amount = order_total
            pay_status = "Refunded"
        else:
            amount = order_total
            pay_status = "Paid"

        payments.append(
            {
                "payment_id": pm_id,
                "order_id": oid,
                "payment_date": (order_date + timedelta(days=rng.randint(0, 2))).isoformat(),
                "payment_method": method,
                "provider": provider,
                "transaction_id": txn,
                "amount": float(amount),
                "status": pay_status,
            }
        )

        # Shipments for non-cancelled orders most of the time
        if status in ("Completed", "Shipped", "Returned") and rng.random() < 0.95:
            shipment_id += 1
            sh_id = _id("SHP", shipment_id, 6)
            shipped = order_date + timedelta(days=rng.randint(0, 3))
            delivered = shipped + timedelta(days=rng.randint(2, 6))
            carrier = rng.choice(["UPS", "FedEx", "USPS", "DHL"])
            tracking = f"{carrier[:3].upper()}{shipment_id:08d}"
            ship_status = "Delivered" if delivered <= end_date else "InTransit"

            shipments.append(
                {
                    "shipment_id": sh_id,
                    "order_id": oid,
                    "shipped_date": shipped.isoformat(),
                    "delivered_date": delivered.isoformat() if ship_status == "Delivered" else "",
                    "carrier": carrier,
                    "tracking_number": tracking,
                    "shipping_status": ship_status,
                    "shipping_cost": ship_cost,
                }
            )

        # Returns records for returned/cancelled orders (subset of items)
        if status in ("Returned", "Cancelled") and returned_item_ids:
            for oi_id in returned_item_ids[: rng.randint(1, min(len(returned_item_ids), 2))]:
                return_id += 1
                rt_id = _id("RTN", return_id, 6)
                reason = "CancelledOrder" if status == "Cancelled" else rng.choice(RETURN_REASONS[:-1])
                r_status = "Approved"
                refund_amount = _money(float(amount) * rng.uniform(0.2, 0.8))
                returns.append(
                    {
                        "return_id": rt_id,
                        "order_id": oid,
                        "order_item_id": oi_id,
                        "return_date": (order_date + timedelta(days=rng.randint(3, 20))).isoformat(),
                        "return_reason": reason,
                        "return_status": r_status,
                        "refund_amount": float(refund_amount),
                    }
                )

    return orders, order_items, payments, shipments, returns


def _write_csv(path: Path, fieldnames: List[str], rows: Iterable[Dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)


def _maybe_backup(out_dir: Path, filenames: List[str], backup: bool) -> Optional[Path]:
    if not backup:
        return None
    existing = [out_dir / fn for fn in filenames if (out_dir / fn).exists()]
    if not existing:
        return None
    backup_dir = out_dir / "_backup"
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = f"{date.today().isoformat()}_{os.getpid()}"
    dest = backup_dir / stamp
    dest.mkdir(parents=True, exist_ok=True)
    for p in existing:
        p.rename(dest / p.name)
    return dest


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Orders360 seed CSVs.")
    parser.add_argument("--output-dir", default=str(Path(__file__).resolve().parents[1] / "seeds"), help="Output directory for CSVs (default: vulcan-example/seeds).")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for deterministic generation.")
    parser.add_argument("--customers", type=int, default=500, help="Number of customers to generate.")
    parser.add_argument("--products", type=int, default=200, help="Number of products to generate.")
    parser.add_argument("--orders", type=int, default=1500, help="Number of orders to generate.")
    parser.add_argument("--max-items-per-order", type=int, default=4, help="Max line items per order.")
    parser.add_argument("--start-date", default="2024-01-01", help="Start date for order generation (YYYY-MM-DD).")
    parser.add_argument("--end-date", default="2024-06-30", help="End date for order generation (YYYY-MM-DD).")
    parser.add_argument("--backup", action="store_true", help="Backup existing CSVs into seeds/_backup/<date_pid>/ before overwriting.")
    args = parser.parse_args()

    out_dir = Path(args.output_dir).resolve()
    rng = random.Random(args.seed)

    sd = date.fromisoformat(args.start_date)
    ed = date.fromisoformat(args.end_date)
    if ed < sd:
        raise SystemExit("end-date must be >= start-date")

    files = [
        "raw_customers.csv",
        "raw_products.csv",
        "raw_orders.csv",
        "raw_order_items.csv",
        "raw_payments.csv",
        "raw_shipments.csv",
        "raw_returns.csv",
    ]
    backup_dir = _maybe_backup(out_dir, files, backup=bool(args.backup))
    if backup_dir:
        print(f"Backed up existing seed CSVs to: {backup_dir}")

    customers = generate_customers(rng, args.customers)
    products, product_rows = generate_products(rng, args.products)
    orders, order_items, payments, shipments, returns = generate_orders_bundle(
        rng=rng,
        customers=customers,
        products=products,
        n_orders=args.orders,
        max_items_per_order=args.max_items_per_order,
        start_date=sd,
        end_date=ed,
    )

    _write_csv(
        out_dir / "raw_customers.csv",
        [
            "customer_id",
            "first_name",
            "last_name",
            "email",
            "phone",
            "address_line1",
            "address_line2",
            "city",
            "state",
            "postal_code",
            "customer_segment",
            "account_status",
            "signup_date",
            "loyalty_score",
        ],
        customers,
    )
    _write_csv(
        out_dir / "raw_products.csv",
        [
            "product_id",
            "product_name",
            "category",
            "subcategory",
            "brand",
            "color",
            "size",
            "weight",
            "material",
            "model_number",
            "sku",
            "upc",
            "price",
            "cost",
            "supplier",
            "warranty_period",
            "release_date",
            "rating",
            "stock_quantity",
            "discontinued",
        ],
        product_rows,
    )
    _write_csv(
        out_dir / "raw_orders.csv",
        [
            "order_id",
            "order_date",
            "customer_id",
            "order_status",
            "order_channel",
            "currency",
            "shipping_cost",
            "shipping_country",
            "shipping_state",
            "shipping_city",
            "shipping_postal_code",
            "payment_status",
        ],
        orders,
    )
    _write_csv(
        out_dir / "raw_order_items.csv",
        ["order_item_id", "order_id", "product_id", "quantity", "unit_price", "discount_rate", "tax_rate"],
        order_items,
    )
    _write_csv(
        out_dir / "raw_payments.csv",
        ["payment_id", "order_id", "payment_date", "payment_method", "provider", "transaction_id", "amount", "status"],
        payments,
    )
    _write_csv(
        out_dir / "raw_shipments.csv",
        ["shipment_id", "order_id", "shipped_date", "delivered_date", "carrier", "tracking_number", "shipping_status", "shipping_cost"],
        shipments,
    )
    _write_csv(
        out_dir / "raw_returns.csv",
        ["return_id", "order_id", "order_item_id", "return_date", "return_reason", "return_status", "refund_amount"],
        returns,
    )

    print("Generated Orders360 seed CSVs:")
    print(f"- customers:    {len(customers)}")
    print(f"- products:     {len(product_rows)}")
    print(f"- orders:       {len(orders)}")
    print(f"- order_items:  {len(order_items)}")
    print(f"- payments:     {len(payments)}")
    print(f"- shipments:    {len(shipments)}")
    print(f"- returns:      {len(returns)}")
    print(f"Output dir: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

