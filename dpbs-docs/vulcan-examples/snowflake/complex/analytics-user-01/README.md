# User Engagement Analytics (`complex/analytics-user-01`)

Consumer-analytics events analyzed across product, hardware, and software dimensions for Power BI dashboards.

**Domain:** sales_operations

**Use cases:**
- Device engagement across roll-up periods (7 / 30 / 90 / 180 / 365 days)
- Regional BU analytics
- User segmentation
- Hardware component usage
- Software OS adoption
- Multi-tab views

**Counts:** `M=23 · Py=0 · S=4 · C=5 · A=1 · T=0 · Sd=3`

**Output models you'd query:** `flattened_main_base_table, geo_mapping, model_brand_mapping, os_family` plus `hardware_*`, `product_*`, `software_*` groups.

**Hierarchy:** sub-domain folders `models/{hardware_tab, product_tab, software_tab}/` + `flattened_main_base_table` + `models/{metrics, semantics, dq}/`.

**Extras:** `external_models.yaml` for source contracts, dedicated `models/dq/` quality folder.

Explore this when you want sub-domain model organization plus external-model declarations for a Power BI–facing engagement DP.
