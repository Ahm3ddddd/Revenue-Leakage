# Revenue Leakage Analysis: Where Margin Goes and Why

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

> For every $1 this company earns, it keeps only $0.825. This project finds the missing $0.175 — and maps a path to recovering $0.07 of it.

---

## Dashboard Preview

*Screenshots coming soon*

---

## Business Context

A mid-sized e-commerce company is growing revenue but shrinking on profitability. Gross margins are declining quarter over quarter despite increasing order volumes. Leadership suspects discounts, returns, and high-cost orders are eroding the bottom line — but no one has quantified it.

**The business lacks visibility into where revenue is being lost after the point of sale.**

This analysis answers three questions:
1. **How much** is the company losing and is it getting worse?
2. **Where** is the leakage concentrated — which channels, regions, segments, and products?
3. **What to do** — ranked recommendations with estimated dollar recovery

---

## Key Findings

**1. The problem is structural, not seasonal**
Leakage stayed between 17.27% and 17.86% across all four quarters with no downward trend. This is not a campaign anomaly — it is baked into how the business operates.

**2. Discounts are destroying margin without driving volume**
High-discount orders generate the least revenue ($8,610) and fewest units (1.96/order). Low-discount orders generate $1.4M at 6 units/order. Ad-hoc non-campaign discounts are the worst offender with a 0.81 discount-to-profit ratio — higher than Black Friday (0.77).

**3. "Not As Described" is the root cause of refunds**
Across both Clothing Subcategory C (72% of refund value) and Electronics on Mobile (79% of refund value), the dominant refund reason is "Not As Described." This is not a quality or logistics problem — it is a product content problem.

**4. New customers are the common thread**
New customers appear at the top of every leakage breakdown — highest leakage rate (17.82%), highest refund rate on Mobile (0.37), top refund driver in Clothing across all three regions. The business is acquiring customers who are not converting into retained, low-leakage buyers.

**5. The problem is concentrated**
40% of orders drive 80% of total leakage. Fixing the right orders, campaigns, and products would recover the majority of lost margin without touching the rest of the business.

---

## Recommendations & Estimated Impact

| Priority | Action | Basis | Estimated Recovery |
|---|---|---|---|
| 1 | Fix product descriptions — Clothing Subcategory C and Electronics | 50% reduction in Not As Described refunds ($27,198 combined) | ~$13,600 |
| 2 | Implement discount governance across all orders | 25% reduction in unstructured and campaign discount spend | ~$15,000 |
| 3 | Build New customer onboarding flow with Mobile focus | Leakage rate drops 1.5 points on New segment ($170K leakage base) | ~$14,350 |
| 4 | Target top 40% high-leakage orders with focused intervention | 10% leakage reduction on $270,902 concentrated leakage | ~$27,090 |
| | **Total estimated recovery** | | **~$70,040** |
| | **New leakage rate after implementation** | | **~13.9%** |

*All estimates are assumption-based projections, not predictions. Assumptions are stated explicitly per row.*

---

## Project Architecture

The project follows a full analytical pipeline across four layers:

```
Raw Tables → Staging & Cleaning → Analysis → Star Schema → Power BI
```

| Layer | Schema | Purpose |
|---|---|---|
| Raw | `raw` | Source tables with constraints, foreign keys, and data type enforcement |
| Staging | `staging` | Cleaned and validated tables — TRIM, INITCAP, NULL handling, integrity checks |
| Analysis | `analysis` | Flat fact table with item-weight allocation for SQL analysis |
| Datamart | `datamart` | Star schema (dim + fact) optimized for Power BI |

### Star Schema
```
              dim_dates
                  │
dim_customers ── fact_orders ── dim_products
                  │
           fact_order_items
```

---

## Technical Highlights

### Item-Weight Allocation
The most important design decision in this project. Order-level costs (shipping, payment fees, refunds) cannot be fairly assigned to individual items without an allocation method. Each item receives a proportional share based on its revenue contribution to the order:

```sql
item_weight             = total_price / order_total
allocated_shipping_cost = item_weight × shipping_cost
allocated_payment_fee   = item_weight × payment_fee
allocated_refund        = item_weight × total_refund
```

This enables accurate item-level, category-level, and segment-level profitability analysis — impossible with flat allocation.

### Analysis Framework — 13 Questions Across 4 Layers

| Layer | Focus | Techniques |
|---|---|---|
| How Much? | Total leakage, type breakdown, QoQ trend | Aggregations, `LAG()` |
| Where? | Channel, region, segment, category, campaign | `RANK()`, `DENSE_RANK()`, GROUP BY |
| So What? | Discount justification, segment profitability, product margins | `CASE WHEN` bucketing, `HAVING` |
| Why & Where to Focus? | Cohort analysis, Pareto analysis | `DATE_TRUNC`, `AGE()`, `SUM() OVER()` |

### Deep Dives
Two root cause investigations beyond the surface questions:

**Clothing Refunds** — Subcategory → Product → Region × Segment → Refund Reason
Conclusion: Subcategory C drives 54% of Clothing refund value. "Not As Described" accounts for 72% of that — systemic across all 15 products, concentrated in New customers.

**Mobile Channel** — Leakage type → Segment → Category → Refund Reason
Conclusion: Mobile's elevated leakage comes from New customers buying Electronics on discount and returning them. "Not As Described" drives 79% of Electronics refund value on Mobile.

---

## Dashboard Structure

6-page Power BI dashboard built around the analytical narrative:

| Page | Core Finding | Key Visuals |
|---|---|---|
| Executive Overview | Leakage is stable at 17.5% — systemic, not seasonal | Waterfall · KPI cards · QoQ trend · Leakage type donut |
| Leakage Concentration | Mobile, North America, New customers consistently lead | Leakage rate by channel · region · segment |
| Discount Impact | High discounts destroy margin without driving volume | Bucket performance · Campaign ratio · Net profit by bucket |
| Refund Drivers | Not As Described dominates — a description problem | Reason breakdown · Category + segment matrix · Subcategory drill |
| Prioritization & Actions | 40% of orders drive 80% of leakage | Pareto finding · Action table |
| Estimated Impact | $70K recoverable with four targeted actions | Recovery table · New leakage rate |

---

## Repository Structure

```
/sql
  /01_raw             → raw table creation and constraints
  /02_staging         → cleaning, validation, and staging tables
  /03_analysis        → flat fact table and all 13 analysis queries
  /04_datamart        → star schema creation scripts
/dashboard
  /screenshots        → Power BI dashboard page screenshots
README.md
```

---

## Limitations & Tradeoffs

| Area | Detail |
|---|---|
| Data | Synthetic — patterns are cleaner than real transaction data |
| Time range | Single year (2024) — limits trend and cohort depth |
| Allocation | Item-weight by revenue share — not physical weight or volume |
| Leakage scope | Post-sale erosion only — COGS excluded by design |
| Causality | Findings are correlational — concentration identified, not proven cause |
| Refund reasons | NULLs relabeled "Not As Described" — some may be system errors |
| Estimates | Recovery projections are assumption-based, not predictive models |

---

## About the Project

This is Project 1 of a three-project e-commerce analytics portfolio built to demonstrate end-to-end analytical thinking — from raw data to prioritized, dollar-quantified business recommendations.

The portfolio is built around a single fictional e-commerce company across all three projects, allowing each project to build on the previous one rather than starting from scratch. Project 2 focuses on Customer Retention & Churn Analysis. Project 3 covers Regional Sales Performance and Growth Diagnosis.

**What this project demonstrates:**
- End-to-end analytical pipeline from raw data to business recommendation
- Ability to translate SQL findings into dollar-quantified, prioritized actions
- Understanding of when to go deeper — two root cause investigations beyond the surface questions
- Honest documentation of assumptions, tradeoffs, and limitations

---

*Ahmed · Data Analyst Portfolio · SQL · Power BI · Data Modeling*
