-- Core products dimension table containing product catalog information
-- Central reference for inventory, pricing, and supplier relationships
MODEL (
    name raw.products,
    kind FULL,
    grains (product_id),
    cron '*/15 * * * *',
    tags (
        'dimension',
        'product',
        'inventory',
        'pricing'
    ),
    terms (
        'product.catalog',
        'inventory.product'
    ),
    description 'Product catalog dimension table containing all products available for purchase with details on supplier, category, pricing, and product identification',
    column_descriptions (
        product_id = 'Unique identifier for each product',
        supplier_id = 'Foreign key to suppliers table - identifies which supplier provides this product',
        name = 'Product name or title',
        category = 'Product category classification (Widgets, Gadgets, Doohickeys, Thingamajigs)',
        price = 'Current price per unit of product in USD'
    ),
    column_tags (
        product_id = ('primary_key', 'identifier'),
        supplier_id = (
            'foreign_key',
            'reference',
            'supply_chain'
        ),
        name = ('dimension', 'label'),
        category = ('dimension', 'classification'),
        price = (
            'measure',
            'financial',
            'metric'
        )
    ),
    column_terms (
        product_id = (
            'product.product_id',
            'inventory.product_id'
        ),
        supplier_id = (
            'supplier.supplier_id',
            'supply_chain.supplier_id'
        ),
        name = (
            'product.name',
            'inventory.product_name'
        ),
        category = (
            'product.category',
            'classification.product_category'
        ),
        price = (
            'product.price',
            'finance.unit_price'
        )
    ),
    assertions (
        unique_values (columns := product_id),
        not_null (
            columns := (
                product_id,
                supplier_id,
                name,
                category,
                price
            )
        ),
        not_empty_string (column := name),
        not_empty_string (column := category),
        accepted_values (
            column := category,
            is_in := (
                'Widgets',
                'Gadgets',
                'Doohickeys',
                'Thingamajigs'
            )
        ),
        accepted_range (
            column := price,
            min_v := 0,
            max_v := 10000
        ),
        forall (
            criteria := (
                product_id > 0,
                supplier_id > 0
            )
        )
    ),
    profiles (
        name,
        category,
        price,
        supplier_id
    )
);

SELECT
    product_id,
    supplier_id,
    name,
    category,
    price
FROM vulcan_demo.products