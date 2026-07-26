--QUESTION 1 : What is the total leakage and leakage rate?

SELECT ROUND(SUM(total_leakage), 2) as total_leakage,
ROUND((SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0))*100, 2) as leakage_rate
FROM fact_order_profitability;

--QUESTION 2 : How does leakage break down by type?

SELECT ROUND(SUM(discount_amount + allocated_refund), 2) as commercial_leakage,
ROUND(SUM(allocated_shipping_cost + allocated_payment_fee), 2) as operational_leakage,
ROUND(SUM(discount_amount + allocated_refund)/NULLIF(SUM(gross_revenue), 0)*100, 2) as commercial_leakage_pct,
ROUND(SUM(allocated_shipping_cost + allocated_payment_fee)/NULLIF(SUM(gross_revenue), 0)*100, 2) as operational_leakage_pct
FROM fact_order_profitability;

--QUESTION 3 : Is leakage trending worse QoQ?

WITH quarterly AS(
SELECT ROUND(SUM(total_leakage), 2) as total_leakage,
ROUND((SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0))*100, 2) as leakage_rate,
EXTRACT(QUARTER from order_date) as quarter
FROM fact_order_profitability
GROUP BY quarter
),
compared AS(
SELECT quarter,
total_leakage,
leakage_rate,
LAG(total_leakage) OVER(ORDER BY quarter) as prev_leakage,
LAG(leakage_rate) over(ORDER BY quarter) as prev_leakage_rate
FROM quarterly
)
SELECT
quarter,
total_leakage,
prev_leakage,
leakage_rate,
prev_leakage_rate,
ROUND(leakage_rate - prev_leakage_rate, 2) as leakage_change
FROM compared
ORDER BY quarter;

--QUESTION 4 : Which channel drives the most leakage?

SELECT channel,
ROUND(SUM(total_leakage), 2) as channel_leakage,
ROUND((SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0))*100, 2) as leakage_rate,
RANK()OVER(ORDER BY SUM(total_leakage)DESC) as rank
FROM fact_order_profitability
GROUP BY channel
ORDER BY rank;

--QUESTION 5: Which region is least profitable?

SELECT region,
ROUND(SUM(net_profit), 2) as region_profit,
ROUND((SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0))*100, 2) as leakage_rate,
RANK()OVER(ORDER BY SUM(net_profit)) as rank
FROM fact_order_profitability
GROUP BY region
ORDER BY rank;

--QUESTION 6 : Which customer segment is most affected ?

SELECT
segment,
ROUND((SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0))*100, 2) as leakage_rate,
ROUND(SUM(total_leakage)/NULLIF(COUNT(DISTINCT order_id),0), 2) as avg_leakage_per_order,
RANK()OVER(ORDER BY SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0) DESC) as leakage_rank
FROM fact_order_profitability
GROUP BY segment
ORDER BY leakage_rank;

--QUESTION 7 : Which product category drives the most refunds?
SELECT category,
COUNT(*) as total_items,
COUNT(CASE WHEN allocated_refund > 0 THEN 1 END) AS refunds_count,
ROUND(COUNT(CASE WHEN allocated_refund > 0 THEN 1 END)*1.0 / NULLIF(COUNT(*), 0), 2) as refund_rate,
ROUND(SUM(allocated_refund), 2)as total_refund_amount,
RANK()OVER(ORDER BY SUM(allocated_refund)DESC) as refund_rank
FROM fact_order_profitability
GROUP BY category
ORDER BY refund_rank;

--QUESTION 8 : Which discount campaigns destroy the most margin?

SELECT campaign_name,
ROUND(SUM(discount_amount), 2) as discount_total,
ROUND(SUM(gross_profit), 2) as gross_profit_total,
ROUND(
CASE WHEN SUM(gross_profit) <= 0 THEN NULL
ELSE SUM(discount_amount) / NULLIF(SUM(gross_profit), 0) END, 2) as discount_to_profit_ratio,
RANK()OVER(ORDER BY CASE WHEN SUM(gross_profit) <= 0 THEN NULL
ELSE SUM(discount_amount) / NULLIF(SUM(gross_profit), 0) END DESC) as campaign_rank
FROM fact_order_profitability
GROUP BY campaign_name
ORDER BY campaign_rank;

--QUESTION 9 : Are high-discount orders justified by volume?

WITH order_level AS (
SELECT order_id,
SUM(discount_amount) * 1.0 / NULLIF(SUM(gross_revenue), 0) as discount_rate,
SUM(quantity)as quantity_per_order,
SUM(gross_revenue) as revenue_per_order
FROM fact_order_profitability
GROUP BY order_id
)
SELECT
CASE WHEN discount_rate < 0.1 THEN 'Low'
     WHEN discount_rate < 0.3 THEN 'Medium'
	 WHEN discount_rate IS NULL THEN 'Low'
		  ELSE 'High'
END AS discount_bucket,
ROUND(AVG(quantity_per_order), 2) as avg_quantity,
SUM(revenue_per_order) as total_revenue,
ROUND(AVG(revenue_per_order), 2) as avg_revenue_per_order
FROM order_level
GROUP BY discount_bucket
ORDER BY discount_bucket;


--QUESTION 10 : Which segments are unprofitable after all costs?
SELECT 
segment, 
CASE WHEN SUM(net_profit) > 0 THEN 'Profitable' 
     WHEN SUM(net_profit) = 0 THEN 'Breakeven' 
	 ELSE 'Unprofitable' END AS profitablity_tier, 
ROUND(SUM(net_profit), 2) as profit_per_segment 
FROM fact_order_profitability 
GROUP BY segment 
ORDER BY profit_per_segment ASC;

--QUESTION 11 : Which product have near-zero or negative gross profit ?

SELECT product_name,
CASE WHEN SUM(gross_profit) > 0 THEN 'Profitable'
     WHEN SUM(gross_profit) = 0 THEN 'Breakeven'
	 ELSE 'Unprofitable'
	 END AS profitability_tier,
ROUND(SUM(gross_profit), 2) as product_profit,
RANK()OVER(ORDER BY SUM(gross_profit)ASC) as rank
FROM fact_order_profitability
GROUP BY product_name
HAVING SUM(gross_profit) <= 0
ORDER BY product_profit;

--Question 12 : Does leakage worsen as customers age ?

SELECT 
DATE_PART('month', AGE(order_date, signup_date)) AS months_since_signup,
COUNT(DISTINCT order_id) AS orders,
ROUND((SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0))*100, 2) as leakage_rate,
ROUND(SUM(total_leakage), 2) AS total_leakage
FROM fact_order_profitability
WHERE order_date >= signup_date
GROUP BY months_since_signup
ORDER BY months_since_signup;

--QUESTION 13 : What % of orders account for 80% of leakage?
WITH order_level AS (
SELECT order_id,
SUM(total_leakage) AS order_total_leakage
FROM fact_order_profitability
GROUP BY order_id
),
pareto AS (
SELECT order_id,
ROUND(order_total_leakage, 2) AS total_leakage,
ROUND(SUM(order_total_leakage) OVER(ORDER BY order_total_leakage DESC) / NULLIF(SUM(order_total_leakage) OVER(), 0) * 100, 2) AS running_leakage_pct,
ROW_NUMBER()OVER(ORDER BY order_total_leakage DESC) AS order_rank,
ROUND(ROW_NUMBER()OVER(ORDER BY order_total_leakage DESC) / NULLIF(COUNT(*) OVER(),0)::DECIMAL * 100,2) AS pct_of_orders
FROM order_level
)
SELECT order_id,
total_leakage,
running_leakage_pct,
order_rank,
pct_of_orders
FROM pareto
WHERE running_leakage_pct <= 80
ORDER BY order_rank;

--Deep-Dive Analysis

--Clothing refunds
--Question 1 : Which subcategory within clothing has the highest refund rate?

SELECT subcategory,
COUNT(*) AS total_items,
COUNT(CASE WHEN allocated_refund > 0 THEN 1 END) AS refunds_count,
ROUND(SUM(allocated_refund), 2) AS total_refund_value,
ROUND(COUNT(CASE WHEN allocated_refund > 0 THEN 1 END)*1.0 / NULLIF(COUNT(*), 0), 2) AS refund_rate,
RANK() OVER (ORDER BY SUM(allocated_refund) DESC) AS rank
FROM fact_order_profitability
WHERE category = 'Clothing'
GROUP BY subcategory
ORDER BY rank;

--Question 2: Which specific products within the worst subcategory drive the most refunds?

SELECT product_name,
COUNT(*) AS total_items,
COUNT(CASE WHEN allocated_refund > 0 THEN 1 END) AS refunds_count,
ROUND(SUM(allocated_refund), 2) AS total_refund_value,
ROUND(COUNT(CASE WHEN allocated_refund > 0 THEN 1 END)*1.0 / NULLIF(COUNT(*), 0), 2) AS refund_rate,
RANK() OVER (ORDER BY SUM(allocated_refund) DESC) AS rank
FROM fact_order_profitability
WHERE category = 'Clothing' AND subcategory = 'C'
GROUP BY product_name
ORDER BY rank;

--Question 3: Is there a pattern by region or segment for clothing refunds?

SELECT region,
       segment,
	   refund_reason,
       COUNT(CASE WHEN allocated_refund > 0 THEN 1 END) AS refunds_count,
       ROUND(SUM(allocated_refund), 2) AS total_refund_value,
       ROUND(COUNT(CASE WHEN allocated_refund > 0 THEN 1 END)*1.0 / NULLIF(COUNT(*), 0), 2) AS refund_rate,
       RANK() OVER (ORDER BY SUM(allocated_refund) DESC) AS rank
FROM fact_order_profitability
WHERE category = 'Clothing'
GROUP BY segment, region, refund_reason
ORDER BY rank;

--DeepDive question : What are the most common refund reasons in Subcategory C?

SELECT refund_reason AS reason,
COUNT(*) AS refund_count,
ROUND(SUM(allocated_refund), 2) AS total_refund_value,
ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(*)OVER(), 0) * 100, 2) AS reason_pct
FROM fact_order_profitability
WHERE category = 'Clothing'
      AND subcategory = 'C'
	  AND allocated_refund > 0
GROUP BY reason
ORDER BY refund_count DESC;

--Mobile Channel refunds
--Question 1: How does leakage break down by type for Mobile specifically?

SELECT ROUND(SUM(discount_amount + allocated_refund), 2) as commercial_leakage,
ROUND(SUM(allocated_shipping_cost + allocated_payment_fee), 2) as operational_leakage,
ROUND(SUM(discount_amount + allocated_refund)/NULLIF(SUM(gross_revenue), 0)*100, 2) as commercial_leakage_pct,
ROUND(SUM(allocated_shipping_cost + allocated_payment_fee)/NULLIF(SUM(gross_revenue), 0)*100, 2) as operational_leakage_pct
FROM fact_order_profitability
WHERE channel = 'Mobile';

--Question 2: Which segment uses Mobile the most and are they high-leakage segments?

SELECT 
       segment,
	   COUNT(*) AS total_items,
       COUNT(CASE WHEN allocated_refund > 0 THEN 1 END) AS refunds_count,
       ROUND(SUM(allocated_refund), 2) AS total_refund_value,
       ROUND(COUNT(CASE WHEN allocated_refund > 0 THEN 1 END)*1.0 / NULLIF(COUNT(*), 0), 2) AS refund_rate,
	   ROUND(SUM(total_leakage) / NULLIF(SUM(gross_revenue), 0) * 100, 2) AS leakage_rate_pct,
       RANK() OVER (ORDER BY SUM(allocated_refund) DESC) AS rank
FROM fact_order_profitability
WHERE channel = 'Mobile'
GROUP BY segment
ORDER BY rank;

--Question 3: Which product category drives the most leakage on Mobile?

SELECT
category,
ROUND(SUM(total_leakage), 2) as total_leakage,
ROUND((SUM(total_leakage)/NULLIF(SUM(gross_revenue), 0))*100, 2) as leakage_rate,
RANK() OVER (ORDER BY SUM(total_leakage) / NULLIF(SUM(gross_revenue), 0) DESC) as leakage_rank
FROM fact_order_profitability
WHERE channel = 'Mobile'
GROUP BY category
ORDER BY leakage_rank;

--Follow-up

SELECT
    ROUND(SUM(discount_amount), 2) AS total_discounts,
    ROUND(SUM(allocated_refund), 2) AS total_refunds,
    ROUND(SUM(discount_amount) / NULLIF(SUM(gross_revenue), 0) * 100, 2) AS discount_rate_pct,
    ROUND(SUM(allocated_refund) / NULLIF(SUM(gross_revenue), 0) * 100, 2) AS refund_rate_pct
FROM fact_order_profitability
WHERE channel = 'Mobile' AND category = 'Electronics';

--reason deepdive
SELECT
    refund_reason AS reason,
    COUNT(*) AS refund_count,
    ROUND(SUM(allocated_refund), 2) AS total_refund_value,
    ROUND(COUNT(*) * 1.0 / NULLIF(SUM(COUNT(*)) OVER(), 0) * 100, 2) AS reason_pct
FROM fact_order_profitability
WHERE channel = 'Mobile' 
AND category = 'Electronics'
AND allocated_refund > 0
GROUP BY reason
ORDER BY refund_count DESC;