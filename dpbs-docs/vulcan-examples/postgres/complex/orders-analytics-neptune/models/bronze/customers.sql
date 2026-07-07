-- Core customers dimension table containing customer profile information
-- Central dimension for customer analytics and order attribution
MODEL (
    name bronze_v1.customers,
    kind SEED (
        path '../../seeds/seed_customers.csv'
    ),
    columns (
        customer_id INTEGER,
        region_id INTEGER,
        name VARCHAR,
        email VARCHAR
    ),
    grains (customer_id),
    tags (
        'dimension',
        'customer',
        'classification:PII'
    ),
    terms (
        'customer.profile',
        'identity.customer',
        'customer.profile'
    ),
    description 'Customer dimension table containing registered customers with their profile information including contact details and regional classification',
    column_descriptions (
        customer_id = 'Unique identifier for each customer',
        region_id = 'Foreign key to regions table - geographic region where customer is located',
        name = 'Customer full name',
        email = 'Customer email address for communication and identification'
    ),
    column_tags (
        customer_id = ('primary_key', 'identifier'),
        region_id = (
            'foreign_key',
            'reference',
            'geography'
        ),
        name = ('pii', 'identifier'),
        email = (
            'pii',
            'contact',
            'identifier'
        )
    ),
    column_terms (
        customer_id = (
            'customer.customer_id',
            'identity.customer_id'
        ),
        region_id = (
            'geography.region_id',
            'reference.region_id'
        ),
        name = (
            'customer.name',
            'identity.name'
        ),
        email = (
            'contact.email_address',
            'identity.email'
        )
    ),
    -- assertions (
    --     unique_values (columns := customer_id),
    --     not_null (
    --         columns := (
    --             customer_id,
    --             region_id,
    --             name,
    --             email
    --         )
    --     ),
    --     not_empty_string (column := name),
    --     not_empty_string (column := email),
    --     forall (
    --         criteria := (
    --             customer_id > 0,
    --             region_id > 0
    --         )
    --     )
    -- ),
    profiles (name, email, region_id)
);