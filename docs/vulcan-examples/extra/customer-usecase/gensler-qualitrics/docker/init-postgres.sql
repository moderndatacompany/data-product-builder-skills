-- Create schema for our data warehouse
CREATE SCHEMA IF NOT EXISTS data_warehouse;

-- Create products table with sample data
CREATE TABLE IF NOT EXISTS data_warehouse.products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    in_stock BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample product data
INSERT INTO data_warehouse.products (product_id, product_name, category, price, in_stock)
VALUES
    (1, 'Laptop Pro 15', 'Electronics', 1299.99, true),
    (2, 'Wireless Mouse', 'Accessories', 29.99, true),
    (3, 'Mechanical Keyboard', 'Accessories', 89.99, true),
    (4, '27" Monitor', 'Electronics', 399.99, false),
    (5, 'USB-C Hub', 'Accessories', 49.99, true),
    (6, 'Laptop Backpack', 'Accessories', 79.99, true),
    (7, 'Wireless Headphones', 'Electronics', 199.99, true),
    (8, 'External SSD 1TB', 'Storage', 149.99, true),
    (9, 'Webcam HD', 'Electronics', 69.99, false),
    (10, 'Desk Lamp LED', 'Office', 39.99, true)
ON CONFLICT (product_id) DO NOTHING;

