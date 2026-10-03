"""
Generates 6 CSVs for an automotive supply chain demo:
  suppliers (50), parts (200), plants (10), shipments (5000), orders (8000),
  inventory_snapshots (~24000, monthly per part/plant)

OTD (on-time delivery) is deliberately varied by supplier so the downstream
Semantic View / Cortex Analyst demo has a real signal to query:
  Supplier A -> ~92% on-time, Supplier B -> ~71%, Supplier C -> ~85%
"on-time" means actual_delivery_dt is within 1 calendar day of confirmed_delivery_dt.

shipments also carries freight_cost_per_unit / duty_cost_per_unit (landed cost
inputs), and inventory_snapshots carries qty_on_hand / avg_daily_demand_qty
(days-of-inventory inputs) so those two downstream metrics are computed from
real generated data rather than an invented proxy formula.
"""

import os
import random
from datetime import timedelta

import pandas as pd
from faker import Faker

SEED = 42
random.seed(SEED)
fake = Faker()
Faker.seed(SEED)

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")

N_SUPPLIERS = 50
N_PARTS = 200
N_PLANTS = 10
N_SHIPMENTS = 5000
N_ORDERS = 8000
INVENTORY_SNAPSHOT_MONTHS = 12

PART_CATEGORIES = [
    "Engine", "Transmission", "Brakes", "Suspension", "Electrical",
    "Interior Trim", "Exterior Body", "Exhaust", "Steering", "Cooling System",
]
CARRIERS = [
    "FedEx Freight", "UPS Supply Chain", "DHL Supply Chain", "Schneider National",
    "XPO Logistics", "J.B. Hunt", "Old Dominion", "C.H. Robinson",
]
REGIONS = ["North America", "EMEA", "APAC", "LATAM"]
SHIPMENT_STATUSES = ["Delivered", "Delivered", "Delivered", "In Transit", "Delayed"]
ORDER_STATUSES = ["Fulfilled", "Fulfilled", "Fulfilled", "Partially Fulfilled", "Backordered"]


def gen_suppliers():
    rows = []
    # Named demo suppliers with fixed OTD targets, used throughout the Semantic
    # View / Cortex Analyst / Streamlit layers to prove the canonical definition.
    fixed = [
        ("Supplier A", 92),
        ("Supplier B", 71),
        ("Supplier C", 85),
    ]
    for i, (name, otd_target) in enumerate(fixed, start=1):
        rows.append({
            "supplier_id": f"SUP{i:04d}",
            "supplier_name": name,
            "supplier_region": random.choice(REGIONS),
            "country": fake.country(),
            "reliability_tier": "Gold" if otd_target >= 90 else ("Silver" if otd_target >= 80 else "Bronze"),
            "otd_target_pct": otd_target,
            "lead_time_days_avg": random.randint(5, 15),
            "created_dt": fake.date_between(start_date="-5y", end_date="-2y"),
        })

    for i in range(len(fixed) + 1, N_SUPPLIERS + 1):
        otd_target = random.randint(65, 97)
        rows.append({
            "supplier_id": f"SUP{i:04d}",
            "supplier_name": fake.company(),
            "supplier_region": random.choice(REGIONS),
            "country": fake.country(),
            "reliability_tier": "Gold" if otd_target >= 90 else ("Silver" if otd_target >= 80 else "Bronze"),
            "otd_target_pct": otd_target,
            "lead_time_days_avg": random.randint(5, 15),
            "created_dt": fake.date_between(start_date="-5y", end_date="-2y"),
        })
    return pd.DataFrame(rows)


def gen_parts(suppliers_df):
    supplier_ids = suppliers_df["supplier_id"].tolist()
    # Supplier A/B/C are the named OTD demo suppliers (see gen_suppliers). Guarantee
    # each enough parts -> enough shipments that its measured OTD converges tightly
    # on its target rate, instead of being left to the luck of a uniform random draw.
    demo_supplier_ids = supplier_ids[:3]
    demo_quota = 16
    assigned_supplier_ids = []
    for sid in demo_supplier_ids:
        assigned_supplier_ids.extend([sid] * demo_quota)
    remaining = N_PARTS - len(assigned_supplier_ids)
    assigned_supplier_ids.extend(random.choice(supplier_ids) for _ in range(remaining))
    random.shuffle(assigned_supplier_ids)

    rows = []
    for i in range(1, N_PARTS + 1):
        category = random.choice(PART_CATEGORIES)
        rows.append({
            "part_id": f"PRT{i:05d}",
            "part_name": f"{category} - {fake.word().capitalize()} {random.randint(100, 999)}",
            "part_category": category,
            "supplier_id": assigned_supplier_ids[i - 1],
            "unit_cost": round(random.uniform(2.5, 850.0), 2),
            "weight_kg": round(random.uniform(0.1, 45.0), 2),
            "uom": random.choice(["EA", "KG", "SET"]),
        })
    return pd.DataFrame(rows)


def gen_plants():
    rows = []
    for i in range(1, N_PLANTS + 1):
        region = random.choice(REGIONS)
        rows.append({
            "plant_id": f"PLT{i:03d}",
            "plant_name": f"{fake.city()} Assembly Plant",
            "plant_region": region,
            "plant_country": fake.country(),
            "plant_city": fake.city(),
        })
    return pd.DataFrame(rows)


def gen_shipments(suppliers_df, parts_df, plants_df):
    supplier_otd = dict(zip(suppliers_df["supplier_id"], suppliers_df["otd_target_pct"]))
    part_to_supplier = dict(zip(parts_df["part_id"], parts_df["supplier_id"]))
    part_weight = dict(zip(parts_df["part_id"], parts_df["weight_kg"]))
    part_unit_cost = dict(zip(parts_df["part_id"], parts_df["unit_cost"]))
    part_ids = parts_df["part_id"].tolist()
    plant_ids = plants_df["plant_id"].tolist()

    rows = []
    for i in range(1, N_SHIPMENTS + 1):
        part_id = random.choice(part_ids)
        supplier_id = part_to_supplier[part_id]
        plant_id = random.choice(plant_ids)
        otd_target = supplier_otd[supplier_id]

        ship_dt = fake.date_between(start_date="-18mo", end_date="today")
        lead_time = random.randint(3, 20)
        confirmed_delivery_dt = ship_dt + timedelta(days=lead_time)

        on_time = random.random() * 100 < otd_target
        if on_time:
            delay_days = random.choice([-1, 0, 1])
        else:
            delay_days = random.randint(2, 10)
        actual_delivery_dt = confirmed_delivery_dt + timedelta(days=delay_days)

        # Landed cost inputs: freight scales with part weight + carrier/region
        # noise; duty is a small percentage of the part's own unit cost.
        freight_cost_per_unit = round(part_weight[part_id] * random.uniform(0.5, 3.0), 2)
        duty_cost_per_unit = round(part_unit_cost[part_id] * random.uniform(0.0, 0.08), 2)

        rows.append({
            "shipment_id": f"SHP{i:06d}",
            "supplier_id": supplier_id,
            "part_id": part_id,
            "plant_id": plant_id,
            "carrier": random.choice(CARRIERS),
            "ship_dt": ship_dt,
            "confirmed_delivery_dt": confirmed_delivery_dt,
            "actual_delivery_dt": actual_delivery_dt,
            "quantity_shipped": random.randint(10, 5000),
            "freight_cost_per_unit": freight_cost_per_unit,
            "duty_cost_per_unit": duty_cost_per_unit,
            "status": "Delivered" if actual_delivery_dt <= pd.Timestamp("today").date() else random.choice(SHIPMENT_STATUSES),
        })
    return pd.DataFrame(rows)


def gen_inventory_snapshots(parts_df, plants_df, shipments_df):
    """Monthly on-hand inventory per (part, plant), driven by each combo's own
    observed shipment volume so Days of Inventory reflects real generated
    demand rather than an unrelated random number."""
    part_ids = parts_df["part_id"].tolist()
    plant_ids = plants_df["plant_id"].tolist()

    span_days = max((shipments_df["ship_dt"].max() - shipments_df["ship_dt"].min()).days, 1)
    demand_by_combo = (
        shipments_df.groupby(["part_id", "plant_id"])["quantity_shipped"].sum() / span_days
    ).to_dict()

    snapshot_months = pd.date_range(end=pd.Timestamp("today").normalize(), periods=INVENTORY_SNAPSHOT_MONTHS, freq="MS")

    rows = []
    snapshot_id = 1
    for part_id in part_ids:
        for plant_id in plant_ids:
            avg_daily_demand = demand_by_combo.get((part_id, plant_id), random.uniform(5, 50))
            target_days_of_stock = random.uniform(10, 90)
            for snapshot_dt in snapshot_months:
                qty_on_hand = max(avg_daily_demand * target_days_of_stock * random.uniform(0.85, 1.15), 0)
                rows.append({
                    "snapshot_id": f"INV{snapshot_id:07d}",
                    "part_id": part_id,
                    "plant_id": plant_id,
                    "snapshot_dt": snapshot_dt.date(),
                    "qty_on_hand": round(qty_on_hand, 1),
                    "avg_daily_demand_qty": round(avg_daily_demand, 2),
                })
                snapshot_id += 1
    return pd.DataFrame(rows)


def gen_orders(parts_df, plants_df):
    part_ids = parts_df["part_id"].tolist()
    plant_ids = plants_df["plant_id"].tolist()
    unit_cost_by_part = dict(zip(parts_df["part_id"], parts_df["unit_cost"]))

    rows = []
    for i in range(1, N_ORDERS + 1):
        part_id = random.choice(part_ids)
        qty_ordered = random.randint(5, 2000)
        fill_ratio = random.choices([1.0, random.uniform(0.5, 0.99)], weights=[85, 15])[0]
        qty_fulfilled = int(qty_ordered * fill_ratio)

        order_dt = fake.date_between(start_date="-18mo", end_date="today")
        requested_delivery_dt = order_dt + timedelta(days=random.randint(5, 30))
        fulfilled_dt = requested_delivery_dt + timedelta(days=random.randint(-2, 7))

        rows.append({
            "order_id": f"ORD{i:06d}",
            "customer_id": f"CUS{random.randint(1, 1200):05d}",
            "customer_name": fake.company(),
            "plant_id": random.choice(plant_ids),
            "part_id": part_id,
            "order_dt": order_dt,
            "requested_delivery_dt": requested_delivery_dt,
            "fulfilled_dt": fulfilled_dt,
            "quantity_ordered": qty_ordered,
            "quantity_fulfilled": qty_fulfilled,
            "unit_price": round(unit_cost_by_part[part_id] * random.uniform(1.15, 1.6), 2),
            "order_status": "Fulfilled" if qty_fulfilled == qty_ordered else random.choice(ORDER_STATUSES),
        })
    return pd.DataFrame(rows)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    suppliers_df = gen_suppliers()
    parts_df = gen_parts(suppliers_df)
    plants_df = gen_plants()
    shipments_df = gen_shipments(suppliers_df, parts_df, plants_df)
    orders_df = gen_orders(parts_df, plants_df)
    inventory_df = gen_inventory_snapshots(parts_df, plants_df, shipments_df)

    suppliers_df.to_csv(os.path.join(OUTPUT_DIR, "suppliers.csv"), index=False)
    parts_df.to_csv(os.path.join(OUTPUT_DIR, "parts.csv"), index=False)
    plants_df.to_csv(os.path.join(OUTPUT_DIR, "plants.csv"), index=False)
    shipments_df.to_csv(os.path.join(OUTPUT_DIR, "shipments.csv"), index=False)
    orders_df.to_csv(os.path.join(OUTPUT_DIR, "orders.csv"), index=False)
    inventory_df.to_csv(os.path.join(OUTPUT_DIR, "inventory_snapshots.csv"), index=False)

    print(f"Wrote 6 CSVs to {OUTPUT_DIR}")
    print(f"  suppliers.csv            : {len(suppliers_df)} rows")
    print(f"  parts.csv                : {len(parts_df)} rows")
    print(f"  plants.csv                : {len(plants_df)} rows")
    print(f"  shipments.csv             : {len(shipments_df)} rows")
    print(f"  orders.csv                : {len(orders_df)} rows")
    print(f"  inventory_snapshots.csv   : {len(inventory_df)} rows")

    merged = shipments_df.merge(suppliers_df[["supplier_id", "supplier_name"]], on="supplier_id")
    merged["on_time"] = (
        (merged["actual_delivery_dt"] - merged["confirmed_delivery_dt"]).abs() <= pd.Timedelta(days=1)
    )
    otd_check = merged[merged["supplier_name"].isin(["Supplier A", "Supplier B", "Supplier C"])]
    otd_summary = otd_check.groupby("supplier_name")["on_time"].mean() * 100
    print("\nOTD sanity check (actual vs. target):")
    print(otd_summary.round(1).to_string())

    doi_check = inventory_df["qty_on_hand"].sum() / inventory_df["avg_daily_demand_qty"].replace(0, pd.NA).sum()
    print(f"\nDays of Inventory sanity check (fleet-wide avg): {doi_check:.1f} days (target band: 10-90)")

    landed_cost_check = (
        shipments_df["freight_cost_per_unit"].mean() + shipments_df["duty_cost_per_unit"].mean()
    )
    print(f"Landed cost add-on sanity check (avg freight+duty per unit): ${landed_cost_check:.2f}")


if __name__ == "__main__":
    main()
