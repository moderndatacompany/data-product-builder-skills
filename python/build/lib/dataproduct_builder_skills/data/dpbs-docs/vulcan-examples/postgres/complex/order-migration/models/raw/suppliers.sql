-- Core suppliers dimension table containing supplier information
-- Used to track product sources and supply chain relationships
MODEL (
    name raw.suppliers,
    kind FULL,
    grains (supplier_id),
    cron '*/15 * * * *',
    tags (
        'dimension',
        'supplier',
        'supply_chain'
    ),
    terms (
        'supplier.profile',
        'supply_chain.supplier'
    ),
    description 'Supplier dimension table containing registered suppliers who provide products, including their name and regional location',
    column_descriptions (
        supplier_id = 'Unique identifier for each supplier',
        region_id = 'Foreign key to regions table - geographic region where supplier operates',
        name = 'Supplier company or organization name'
    ),
    column_tags (
        supplier_id = ('primary_key', 'identifier'),
        region_id = (
            'foreign_key',
            'reference',
            'geography'
        ),
        name = (
            'dimension',
            'label',
            'business'
        )
    ),
    column_terms (
        supplier_id = (
            'supplier.supplier_id',
            'supply_chain.supplier_id'
        ),
        region_id = (
            'geography.region_id',
            'reference.region_id'
        ),
        name = (
            'supplier.name',
            'business.company_name'
        )
    ),
    assertions (
        unique_values (columns := supplier_id),
        not_null (
            columns := (supplier_id, region_id, name)
        ),
        not_empty_string (column := name),
        forall (
            criteria := (
                supplier_id > 0,
                region_id > 0
            )
        )
    ),
    profiles (name, region_id)
);

SELECT supplier_id, region_id, name FROM vulcan_demo.suppliers