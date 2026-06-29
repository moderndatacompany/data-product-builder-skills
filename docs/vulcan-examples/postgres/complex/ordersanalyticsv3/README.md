# Orders Analytics V3 (`complex/ordersanalyticsv3`)

Variant of the orders-analytics pipeline where transformations live under `raw/`, `curated/`, and `aggregated/` instead of bronze/silver/gold. Includes Python macros, custom linter, and full quality stack.

**Domain:** engineering

**Use cases:**
- Daily & weekly sales reporting
- Customer segmentation & RFM
- Sales-funnel conversion tracking
- Product performance
- Regional sales
- Inventory & shipment tracking

**Counts:** `M=15 (9 raw + 4 curated + 2 aggregated) · S=7 · C=18 (tied for largest postgres check coverage) · A=2 · T=8 · Sd=7 csv`

**Output models you'd query:** `fct_daily_sales, fct_weekly_sales, dim_customer_profile, dim_product_profile, sales_funnel_analysis, rfm_customer_segmentation`.

**Hierarchy:** `seeds → models/raw → models/curated → models/aggregated → semantics`.

**Extras:** Python `macros/orders360.py` (Vulcan *Macros* component), `linter/linters.py` (custom Python lint rules), seed generator under `scripts/`, `external_models.yaml`, `domain-resource.yaml`.

Explore this when you want the **raw → curated → aggregated** naming variant (instead of medallion bronze/silver/gold), with macros and a custom linter.
