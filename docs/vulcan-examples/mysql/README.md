# MySQL Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **MySQL**.

Counts legend: `M` = SQL models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.

---

## easy/

### `easy/orders360` — Orders 360 (MySQL)
**Domain:** sales
**About:** Daily sales analytics pipeline tracking order volumes, revenue trends, and customer activity on MySQL.
**Use cases:** daily sales reporting · customer activity tracking · revenue-trend analysis · product catalog metrics.
**Hierarchy:** `seeds → models/ (3 dimension/fact) → semantics`.
**Counts:** `M=6 (3 dim/fact + 3 seed) · S=3 · C=3 · A=1 (`validate_customer_id`) · T=3 · Sd=3 csv`.
**Output models you'd query:** `customers, orders, products`.
**Extras:** postgres state store.
**Explore this when:** you want the Orders 360 reference adapted for MySQL.

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| Daily sales / orders / customers / products on MySQL | `easy/orders360` |

---
