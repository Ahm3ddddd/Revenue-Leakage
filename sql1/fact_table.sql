--Creating one Flat Fact Table

CREATE TABLE fact_order_profitability AS
WITH order_totals AS (
    SELECT 
        order_id,
        SUM(total_price) AS order_total
    FROM order_items
    GROUP BY order_id
),
refund_totals AS (
    SELECT 
        order_id,
        SUM(refund_amount) AS total_refund
		
    FROM refunds
    GROUP BY order_id
)
SELECT 
    -- Keys
    o.order_id,
    oi.order_item_id,
    o.customer_id,
    oi.product_id,
    
    -- Dimensions
    o.order_date,
    c.signup_date,                          
    o.region,
    o.channel,
    c.segment,
    c.country,
    p.category,
    p.subcategory,
    p.product_name,
    d.discount_type,                        
    d.campaign_name,                       
    d.discount_rate,
	r.reason                                                    AS refund_reason,

    -- Revenue & costs
    oi.quantity,
    oi.unit_price,
    (oi.unit_price * oi.quantity)                               AS gross_revenue,
    oi.discount_amount,
    oi.total_price                                              AS net_revenue,
    (p.cogs * oi.quantity)                                      AS total_cogs,

    -- Allocation weight
    (oi.total_price / ot.order_total)                           AS item_weight,

    -- Allocated costs
    (oi.total_price / ot.order_total) * o.shipping_cost         AS allocated_shipping_cost,
    (oi.total_price / ot.order_total) * o.payment_fee           AS allocated_payment_fee,
    COALESCE((oi.total_price / ot.order_total) * rt.total_refund, 0) AS allocated_refund,

    -- Profit metrics
    (oi.total_price - (p.cogs * oi.quantity))                   AS gross_profit,
    (
        oi.total_price
        - (p.cogs * oi.quantity)
        - ((oi.total_price / ot.order_total) * o.shipping_cost)
        - ((oi.total_price / ot.order_total) * o.payment_fee)
        - COALESCE((oi.total_price / ot.order_total) * rt.total_refund, 0)
    )                                                           AS net_profit,

    -- Total leakage 
    (
        oi.discount_amount
        + ((oi.total_price / ot.order_total) * o.shipping_cost)
        + ((oi.total_price / ot.order_total) * o.payment_fee)
        + COALESCE((oi.total_price / ot.order_total) * rt.total_refund, 0)
    )                                                           AS total_leakage

FROM order_items oi
JOIN orders o          ON oi.order_id = o.order_id
JOIN customers c       ON o.customer_id = c.customer_id
JOIN products p        ON oi.product_id = p.product_id
JOIN order_totals ot   ON oi.order_id = ot.order_id
LEFT JOIN refund_totals rt ON oi.order_id = rt.order_id
LEFT JOIN discounts d  ON oi.order_item_id = d.order_item_id
LEFT JOIN refunds r ON o.order_id = r.order_id 
    AND oi.product_id = r.product_id;


--Creating Indexes to improve query performance
CREATE INDEX idx_fact_category ON fact_order_profitability(category);
CREATE INDEX idx_fact_segment ON fact_order_profitability(segment);
CREATE INDEX idx_fact_order_date ON fact_order_profitability(order_date);
CREATE INDEX idx_fact_region ON fact_order_profitability(region);
CREATE INDEX idx_fact_channel ON fact_order_profitability(channel);