# Trino Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **Trino** (with Apache Iceberg tables on object storage).

Counts legend: `M` = SQL models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.

---

## easy/

### `easy/trino-vulcan-dp-dg` — Trino Orders Pipeline
**Domain:** engineering
**About:** Daily sales analytics pipeline using Trino with Iceberg tables on MinIO object storage.
**Use cases:** daily sales reporting · customer activity tracking · revenue-trend analysis · product catalog metrics on a lakehouse architecture.
**Hierarchy:** `seeds → models/ (3 dimension/fact) → semantics`.
**Counts:** `M=6 (3 dim/fact + 3 seed) · S=3 · C=3 · A=1 (`validate_customer_id`) · T=3 · Sd=3 csv`.
**Output models you'd query:** `customers, orders, products`.
**Extras:** Trino catalog `iceberg`; postgres state store.
**Explore this when:** you want the Orders 360 reference on a **Trino + Iceberg + MinIO lakehouse** stack.

---

### `easy/trino-tpch-sample` — Trino TPC-H Sample
**Domain:** system / benchmark
**About:** Minimal Trino TPC-H scaffold pointing a single `tpch_customer_sf1` model at the TPC-H sample dataset, with a matching semantic model.
**Counts:** `M=1 · S=1 · C=0 · A=0 · T=0 · Sd=0`.
**Output models you'd query:** `tpch_customer_sf1`.
**Extras:** `external_models.yaml` for source contracts.
**Explore this when:** you need the smallest possible Trino+TPC-H smoke-test DP.

---

## At-a-glance summary

| Tier | DP                   | M | S | C | A | T | Sd | Hierarchy                  | Best for                                |
|------|----------------------|--:|--:|--:|--:|--:|---:|----------------------------|-----------------------------------------|
| easy | trino-vulcan-dp-dg   | 6 | 3 | 3 | 1 | 3 |  3 | seeds → models → semantics | Orders 360 on Trino+Iceberg lakehouse   |
| easy | trino-tpch-sample    | 1 | 1 | 0 | 0 | 0 |  0 | flat                       | Smallest TPC-H smoke test               |

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| Daily sales / orders / customers / products on Trino + Iceberg | `easy/trino-vulcan-dp-dg` |
| Smallest Trino TPC-H smoke test | `easy/trino-tpch-sample` |

---