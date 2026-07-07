# Order Migration (`complex/order-migration`)

End-to-end orders-analytics data product with the **most complete folder layout** of any postgres DP — raw seed models, raw layer, root-level transformed entities, curated facts / dimensions, aggregated business models, custom Python macros, custom Python linter rules, and a full quality stack.

**Domain:** engineering / sales_operations

**Use cases:**
- Daily & weekly sales reporting
- Customer segmentation & RFM
- Sales-funnel conversion tracking
- Product performance
- Regional sales
- Inventory & shipment tracking
- Cross-engine migration reference

**Counts:** `M=29 (7 seed + 9 raw + 7 root + 4 curated + 2 aggregated) · S=13 (largest postgres semantic catalog) · C=18 (largest postgres check coverage) · A=2 · T=8 · Sd=7 csv`

**Output models you'd query:** `fct_daily_sales, fct_weekly_sales, dim_customer_profile, dim_product_profile, sales_funnel_analysis, rfm_customer_segmentation` plus root-level `customers / orders / order_items / products / payments / returns / shipments`.

**Hierarchy:** `seeds → models/seeds → models/raw → models/{shipments, returns, products, payments, orders, order_items, customers} (root-level) → models/curated/ → models/aggregated/ → semantics`.

**Extras:** Python `macros/orders360.py` (Vulcan *Macros* component), `linter/linters.py` (custom Python lint rules), seed generator under `scripts/`, `external_models.yaml`, `domain-resource.yaml`.

Explore this when you want the **richest postgres reference** that exercises macros, custom linter, multi-layer hierarchy, and full quality stack at once.
