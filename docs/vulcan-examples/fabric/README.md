# Microsoft Fabric Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **Microsoft Fabric** (Synapse Data Warehouse / Lakehouse via the Fabric ODBC driver).

Counts legend: `M` = SQL models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.

---

## easy/

### `easy/orders360` — Orders 360 (Fabric)
**Domain:** sales
**About:** Daily sales analytics pipeline tracking order volumes, revenue trends, and customer activity on Microsoft Fabric.
**Use cases:** daily sales reporting · customer activity tracking · revenue-trend analysis · product catalog metrics.
**Hierarchy:** `seeds → models/ (3 dimension/fact) → semantics`.
**Counts:** `M=6 (3 dim/fact + 3 seed) · S=3 · C=3 · A=1 (`validate_customer_id`) · T=3 · Sd=3 csv`.
**Output models you'd query:** `customers, orders, products`.
**Extras:** Fabric ODBC + Active Directory Service Principal authentication wired in `config.yaml`; postgres state store.
**Explore this when:** you want the Orders 360 reference adapted for Microsoft Fabric (ODBC Driver 18 + AAD service-principal auth).

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| Daily sales / orders / customers / products on Microsoft Fabric | `easy/orders360` |

---

