# Databricks Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **Databricks**. Use this page to decide which DP fits your use case before you clone the folder.

Counts legend: `M` = SQL models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.

---

## complex/

### `complex/databricks-test` — Databricks Subscription Usage Analytics
**Domain:** subscriptions / saas
**About:** Subscription-based usage-analytics DP modelling users, subscriptions, usage events, and sessions across plan types — full-shape Databricks reference with seeds, models, semantics, checks, and audits.
**Use cases:** subscription usage tracking · plan-level revenue & engagement · session analytics · user enrichment · subscription-usage cross-analysis.
**Hierarchy:** `seeds → models/seeds → models/ (users, subscriptions, usage_events, usage_sessions, subscription_plans, subscription_usage_analysis) → semantics`.
**Counts:** `M=8 (incl. 6 seed models) · Py=0 · S=6 (incl. metrics.yml) · C=3 · A=1 (`business_rules.sql`) · T=0 · Sd=5 csv`.
**Output models you'd query:** `users, users_enriched, subscriptions, subscription_plans, usage_events, usage_sessions, subscription_usage_analysis`.
**Extras:** `metrics.yml` declarative metrics file.
**Explore this when:** you want a subscription / SaaS-usage analytics reference on Databricks with the full quality stack.

---

## easy/

### `easy/orders360` — Orders 360 (Databricks)
**Domain:** sales
**About:** Daily sales analytics pipeline tracking order volumes, revenue trends, and customer activity on Databricks (Unity Catalog).
**Use cases:** daily sales reporting · customer activity tracking · revenue-trend analysis · product catalog metrics.
**Hierarchy:** `seeds → models/ (3 dimension/fact) → metrics + semantics + dq`.
**Counts:** `M=6 (3 dim/fact + 3 seed) · S=3 (+ 3 mirrored under models/semantics/) · C=3 (`models/dq/`) · A=1 (`audits/business_rules.sql`) · T=3 · Sd=3 csv`.
**Output models you'd query:** `customers, orders, products` plus 12 declarative metrics under `models/metrics/` (`total_revenue, total_orders, average_order_value, average_loyalty_score, platinum_customers, active_customers, total_customers, total_products, active_products, total_quantity_sold, total_tax_collected, total_shipping_cost`).
**Extras:** openlineage, transpiler, and graphql endpoints pre-wired in `config.yaml`; Databricks Unity Catalog connection via env vars.
**Explore this when:** you want a minimal but complete Orders 360 reference on Databricks Lakehouse — including Vulcan's *Business Metrics* file pattern (one yaml per metric) and pre-wired observability endpoints.

---

## At-a-glance summary

| Tier    | DP              | M | S | C | A | T | Sd | Hierarchy                          | Best for                                |
|---------|-----------------|--:|--:|--:|--:|--:|---:|------------------------------------|-----------------------------------------|
| complex | databricks-test | 8 | 6 | 3 | 1 | 0 |  5 | seeds → models → semantics         | Subscription / SaaS usage analytics     |
| easy    | orders360       | 6 | 3 | 3 | 1 | 3 |  3 | flat (3-table sales) + metrics/dq  | Orders 360 + per-metric files           |

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| Subscription / SaaS usage analytics on Databricks | `complex/databricks-test` |
| Daily sales / orders / customers / products on Databricks | `easy/orders360` |

---

