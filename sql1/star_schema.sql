--Data Modeling



-- Create the schema
CREATE SCHEMA datamart;


-- 1. DIM CUSTOMERS
CREATE TABLE datamart.dim_customers AS
SELECT
    customer_id,
    signup_date,
    segment,
    country
FROM staging.stg_customers;

ALTER TABLE datamart.dim_customers
ADD PRIMARY KEY (customer_id);


-- 2. DIM PRODUCTS
CREATE TABLE datamart.dim_products AS
SELECT
    product_id,
    product_name,
    category,
    subcategory,
    cogs
FROM staging.stg_products;

ALTER TABLE datamart.dim_products
ADD PRIMARY KEY (product_id);


-- 3. DIM DATES
CREATE TABLE datamart.dim_dates AS
SELECT
    CAST(generate_series AS DATE)                   AS date_id,
    EXTRACT(YEAR FROM generate_series)::INT         AS year,
    EXTRACT(QUARTER FROM generate_series)::INT      AS quarter,
    EXTRACT(MONTH FROM generate_series)::INT        AS month,
    TO_CHAR(generate_series, 'Month')               AS month_name,
    EXTRACT(WEEK FROM generate_series)::INT         AS week,
    EXTRACT(DOW FROM generate_series)::INT          AS day_of_week,
    TO_CHAR(generate_series, 'Day')                 AS day_name
FROM generate_series('2024-01-01'::DATE, '2024-12-31'::DATE, '1 day');

ALTER TABLE datamart.dim_dates
ADD PRIMARY KEY (date_id);


-- 4. FACT ORDERS
CREATE TABLE datamart.fact_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date                                                AS date_id,
    o.region,
    o.channel,
    o.gross_revenue,
    o.discount_amount,
    o.net_revenue,
    o.shipping_cost,
    o.payment_fee,
    (o.net_revenue - o.shipping_cost - o.payment_fee)          AS contribution_margin,
    COALESCE(r.total_refund, 0)                                 AS total_refund,
    (
        o.discount_amount
        + o.shipping_cost
        + o.payment_fee
        + COALESCE(r.total_refund, 0)
    )                                                           AS total_leakage,
    ROUND(
        (
            o.discount_amount
            + o.shipping_cost
            + o.payment_fee
            + COALESCE(r.total_refund, 0)
        ) / NULLIF(o.gross_revenue, 0) * 100, 2
    )                                                           AS leakage_rate_pct
FROM staging.stg_orders o
LEFT JOIN (
    SELECT order_id, SUM(refund_amount) AS total_refund
    FROM staging.stg_refunds
    GROUP BY order_id
) r ON o.order_id = r.order_id;

ALTER TABLE datamart.fact_orders
ADD PRIMARY KEY (order_id);

ALTER TABLE datamart.fact_orders
ADD FOREIGN KEY (customer_id) REFERENCES datamart.dim_customers(customer_id);

ALTER TABLE datamart.fact_orders
ADD FOREIGN KEY (date_id) REFERENCES datamart.dim_dates(date_id);


-- 5. FACT ORDER ITEMS
DROP TABLE datamart.fact_order_items;
CREATE TABLE datamart.fact_order_items AS
SELECT
    -- Keys
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    o.customer_id,
    o.order_date                                                            AS date_id,

    -- Dimensions
    o.region,
    o.channel,
    c.segment,
    c.country,
    c.signup_date,
    p.category,
    p.subcategory,
    p.product_name,
    d.discount_type,
    d.campaign_name,
    d.discount_rate,
    ri.reason                                                                AS refund_reason,

    -- Revenue & quantity
    oi.quantity,
    oi.unit_price,
    (oi.unit_price * oi.quantity)                                           AS gross_revenue,
    oi.discount_amount,
    oi.total_price                                                          AS net_revenue,

    -- Cost
    (p.cogs * oi.quantity)                                                  AS total_cogs,

    -- Allocation weight
    (oi.total_price / NULLIF(ot.order_total, 0))                            AS item_weight,

    -- Allocated costs
    (oi.total_price / NULLIF(ot.order_total, 0)) * o.shipping_cost          AS allocated_shipping_cost,
    (oi.total_price / NULLIF(ot.order_total, 0)) * o.payment_fee            AS allocated_payment_fee,
    COALESCE(
        (oi.total_price / NULLIF(ot.order_total, 0)) * rt.total_refund, 0
    )                                                                        AS allocated_refund,
    COALESCE(ri.refund_amount, 0)                                            AS refund_amount,
    ri.reason                                                                AS refund_reason_direct,

    -- Profit metrics
    (oi.total_price - (p.cogs * oi.quantity))                               AS gross_profit,
    (
        oi.total_price
        - (p.cogs * oi.quantity)
        - ((oi.total_price / NULLIF(ot.order_total, 0)) * o.shipping_cost)
        - ((oi.total_price / NULLIF(ot.order_total, 0)) * o.payment_fee)
        - COALESCE(
            (oi.total_price / NULLIF(ot.order_total, 0)) * rt.total_refund, 0
        )
    )                                                                        AS net_profit,

    -- Leakage
    (
        oi.discount_amount
        + ((oi.total_price / NULLIF(ot.order_total, 0)) * o.shipping_cost)
        + ((oi.total_price / NULLIF(ot.order_total, 0)) * o.payment_fee)
        + COALESCE(
            (oi.total_price / NULLIF(ot.order_total, 0)) * rt.total_refund, 0
        )
    )                                                                        AS total_leakage

FROM staging.stg_order_items oi
JOIN staging.stg_orders o               ON oi.order_id = o.order_id
JOIN staging.stg_customers c            ON o.customer_id = c.customer_id
JOIN staging.stg_products p             ON oi.product_id = p.product_id
LEFT JOIN staging.stg_discounts d       ON oi.order_item_id = d.order_item_id
LEFT JOIN (
    SELECT
        order_id,
        product_id,
        SUM(refund_amount)  AS refund_amount,
        MAX(reason)         AS reason
    FROM staging.stg_refunds
    GROUP BY order_id, product_id
) ri ON oi.order_id = ri.order_id
    AND oi.product_id = ri.product_id
LEFT JOIN (
    SELECT order_id, SUM(total_price) AS order_total
    FROM staging.stg_order_items
    GROUP BY order_id
) ot ON oi.order_id = ot.order_id
LEFT JOIN (
    SELECT order_id, SUM(refund_amount) AS total_refund
    FROM staging.stg_refunds
    GROUP BY order_id
) rt ON oi.order_id = rt.order_id;

ALTER TABLE datamart.fact_order_items
ADD PRIMARY KEY (order_item_id);

ALTER TABLE datamart.fact_order_items
ADD FOREIGN KEY (order_id) REFERENCES datamart.fact_orders(order_id);

ALTER TABLE datamart.fact_order_items
ADD FOREIGN KEY (product_id) REFERENCES datamart.dim_products(product_id);

ALTER TABLE datamart.fact_order_items
ADD FOREIGN KEY (customer_id) REFERENCES datamart.dim_customers(customer_id);

ALTER TABLE datamart.fact_order_items
ADD FOREIGN KEY (date_id) REFERENCES datamart.dim_dates(date_id);