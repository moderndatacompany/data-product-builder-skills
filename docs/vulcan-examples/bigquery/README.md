# BigQuery Data Products — Vulcan Examples

A catalog of **Vulcan data products** that run on **Google BigQuery**. Use this page to decide which DP fits your use case before you clone the folder.

Counts legend: `M` = SQL models · `S` = Semantic models · `C` = Checks · `A` = Audits · `T` = Tests · `Sd` = Seeds.

---

## complex/

### `complex/ga4_analytics` — GA4 Analytics
**Domain:** marketing
**About:** Full Google Analytics 4 (GA4) BigQuery-export pipeline — sessions, conversions, traffic sources, e-commerce items, user behaviour.
**Use cases:** web analytics & user-behaviour tracking · session analysis & conversion tracking · traffic-source attribution · e-commerce performance metrics · user engagement & retention · event-based funnels · campaign performance measurement.
**Hierarchy:** `seeds + base/ → staging/ (sessions, conversions, ecommerce, events sub-folder) → marts/core/ (fct_* + dim_*) → semantics`.
**Counts:** `M=22 (4 base + 12 staging incl 7 events + 6 marts) · S=0 yaml semantics yet · C=0 · A=0 · T=0 · Sd=1 (`ga4_source_categories`)`.
**Output models you'd query:** `fct_ga4__sessions, fct_ga4__pages, fct_ga4__user_daily_behavior, fct_ga4__ecommerce_purchases, fct_ga4__ecommerce_items, fct_ga4__conversion_funnel, dim_ga4__users, dim_ga4__sessions, dim_ga4__products, dim_ga4__client_keys`.
**Extras:** dedicated `signals/` folder (Vulcan *Signals* component scaffold), `external_models.yaml`, `domain-resource.yaml`, `MIGRATION_NOTES.md`.
**Explore this when:** you want a rich GA4 / web-analytics reference on BigQuery with full staging→marts layering and Signals scaffolded.

---

## easy/

### `easy/orders360` — Orders 360 (BigQuery)
**Domain:** sales
**About:** Daily sales analytics pipeline tracking order volumes, revenue trends, and customer activity on BigQuery — minimal but fully-spec'd reference.
**Use cases:** daily sales reporting · customer activity tracking · revenue-trend analysis · product catalog metrics.
**Hierarchy:** `seeds → models/ (3 dimension/fact) → metrics + semantics + dq`.
**Counts:** `M=6 (3 dim/fact + 3 seed) · S=3 (+ 3 mirrored under models/semantics/) · C=3 (`models/dq/`) · A=1 (`audits/business_rules.sql`) · T=3 · Sd=3 csv`.
**Output models you'd query:** `customers, orders, products` plus 12 declarative metrics under `models/metrics/` (`total_revenue, total_orders, average_order_value, average_loyalty_score, platinum_customers, active_customers, total_customers, total_products, active_products, total_quantity_sold, total_tax_collected, total_shipping_cost`).
**Extras:** `external_models.yaml`, BigQuery service-account auth, postgres state store.
**Explore this when:** you want a minimal but complete Orders 360 reference on BigQuery — including Vulcan's *Business Metrics* file pattern (one yaml per metric).

---

## At-a-glance summary

| Tier | DP | M | S | C | A | T | Sd | Hierarchy | Best for |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| complex | ga4_analytics | 22 | 0 | 0 | 0 | 0 | 1 | base → staging → marts/core | GA4 / web analytics |
| easy | orders360 | 6 | 3 | 3 | 1 | 3 | 3 | flat (3-table sales) | Orders 360 + per-metric files |

---

## Pick a DP by your use case

| If your use case is… | Start with |
|---|---|
| GA4 / web analytics on BigQuery | `complex/ga4_analytics` |
| Daily sales / orders / customers / products | `easy/orders360` |

---



