CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    signup_date DATE,
    segment VARCHAR(20),
    country VARCHAR(50)
);
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    cogs DECIMAL(10,2) NOT NULL CHECK (cogs >= 0)
);
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    region VARCHAR(50),
    channel VARCHAR(50),

    gross_revenue DECIMAL(12,2) CHECK (gross_revenue >= 0),
    discount_amount DECIMAL(12,2) CHECK (discount_amount >= 0),
    net_revenue DECIMAL(12,2) CHECK (net_revenue >= 0),

    shipping_cost DECIMAL(10,2) CHECK (shipping_cost >= 0),
    payment_fee DECIMAL(10,2) CHECK (payment_fee >= 0),

    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,

    quantity INT CHECK (quantity > 0),
    unit_price DECIMAL(10,2) CHECK (unit_price >= 0),
    discount_amount DECIMAL(10,2) DEFAULT 0 CHECK (discount_amount >= 0),
    total_price DECIMAL(12,2) CHECK (total_price >= 0),

    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
CREATE TABLE discounts (
    discount_id INT PRIMARY KEY,
    order_item_id INT,

    discount_type VARCHAR(50),
    campaign_name VARCHAR(100),
    discount_rate DECIMAL(5,2) CHECK (discount_rate >= 0 AND discount_rate <= 1),

    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
);
CREATE TABLE refunds (
    refund_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,

    refund_date DATE,
    refund_amount DECIMAL(10,2) CHECK (refund_amount >= 0),
    reason VARCHAR(100),

    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
SELECT * FROM refunds LIMIT 20;
--Data validation
SELECT *
FROM orders
WHERE net_revenue != gross_revenue - discount_amount;

SELECT *
FROM order_items
WHERE total_price != (quantity*unit_price - discount_amount);

SELECT *
FROM order_items oi
LEFT JOIN orders o
ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

SELECT *
FROM order_items
WHERE quantity <= 0
   OR unit_price < 0
   OR total_price < 0;

-- Rename Tables
ALTER TABLE orders RENAME TO raw_orders;
ALTER TABLE order_items RENAME TO raw_order_items;
ALTER TABLE customers RENAME TO raw_customers;
ALTER TABLE products RENAME TO raw_products;
ALTER TABLE discounts RENAME TO raw_discounts;
ALTER TABLE refunds RENAME TO raw_refunds;

-- Create Staging Tables
CREATE TABLE stg_orders AS SELECT * FROM raw_orders;
CREATE TABLE stg_order_items AS SELECT * FROM raw_order_items;
CREATE TABLE stg_customers AS SELECT * FROM raw_customers;
CREATE TABLE stg_products AS SELECT * FROM raw_products;
CREATE TABLE stg_discounts AS SELECT * FROM raw_discounts;
CREATE TABLE stg_refunds AS SELECT * FROM raw_refunds;

-- Data Cleaning
UPDATE stg_orders 
SET region = TRIM(INITCAP(region)),
    channel = TRIM(INITCAP(channel));
DELETE FROM stg_orders
WHERE gross_revenue < 0 OR net_revenue < 0;
DELETE FROM stg_orders
WHERE net_revenue != gross_revenue - discount_amount;

UPDATE stg_order_items
SET total_price = unit_price * quantity - discount_amount;

UPDATE stg_products
SET category = TRIM(INITCAP(category)),
    product_name = TRIM(INITCAP(product_name)),
	subcategory = TRIM(UPPER(subcategory));

UPDATE stg_customers
SET 
   segment = CASE 
   WHEN TRIM(segment) = 'VIP' THEN 'VIP'
   else TRIM(INITCAP(segment))
   END,
   country = CASE 
   WHEN TRIM(country) IN ('USA', 'UK') THEN trim(country)
   ELSE TRIM(INITCAP(country))
   END;

UPDATE stg_discounts
SET
    discount_type = TRIM(INITCAP(discount_type)),
    campaign_name = CASE
        WHEN campaign_name IS NULL THEN 'No Campaign'
        ELSE TRIM(INITCAP(campaign_name))
    END;

UPDATE stg_refunds
SET reason = TRIM(INITCAP(reason));

UPDATE refunds
SET reason = 'Not As Described'
WHERE reason IS NULL;

-- Duplicates check
SELECT order_id, COUNT(*)
FROM stg_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

--Handling Nulls
UPDATE fact_order_profitability
SET campaign_name = 'No Campaign',
discount_type = 'No Discount'
WHERE campaign_name IS NULL OR discount_type IS NULL;

--Creating Cleaned Tables
CREATE TABLE orders AS SELECT * FROM stg_orders;
CREATE TABLE order_items AS SELECT * FROM stg_order_items;
CREATE TABLE customers AS SELECT * FROM stg_customers;
CREATE TABLE products AS SELECT * FROM stg_products;
CREATE TABLE discounts AS SELECT * FROM stg_discounts;
CREATE TABLE refunds AS SELECT * FROM stg_refunds;

--Adding Primary and Foreign Keys
ALTER TABLE customers ADD PRIMARY KEY (customer_id);
ALTER TABLE products ADD PRIMARY KEY (product_id);
ALTER TABLE orders ADD PRIMARY KEY (order_id);
ALTER TABLE order_items ADD PRIMARY KEY (order_item_id);
ALTER TABLE discounts ADD PRIMARY KEY (discount_id);
ALTER TABLE refunds ADD PRIMARY KEY (refund_id);

-- orders → customers
ALTER TABLE orders
ADD FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

-- order_items → orders
ALTER TABLE order_items
ADD FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- order_items → products
ALTER TABLE order_items
ADD FOREIGN KEY (product_id) REFERENCES products(product_id);

-- discounts → order_items
ALTER TABLE discounts
ADD FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id);

-- refunds → orders
ALTER TABLE refunds
ADD FOREIGN KEY (order_id) REFERENCES orders(order_id);