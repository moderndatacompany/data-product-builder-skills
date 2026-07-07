MODEL (
  name qcommerce_returns_bronze.refund_reason_mapping,
  kind SEED (
    path '../../seeds/refund_reason_mapping.csv'
  ),
  owner 'shreyasikarwartmdcio',
  grains [raw_refund_reason],
  description 'Business mapping that groups raw refund reasons into reusable issue categories for finance and operations reporting.',
  tags ('seed', 'bronze', 'refunds', 'reference-data'),
  terms ('refund_reason_mapping', 'issue_group', 'refund_reason_group'),
  columns (
    raw_refund_reason STRING,
    refund_reason_group STRING,
    issue_group STRING,
    priority_label STRING
  )
)