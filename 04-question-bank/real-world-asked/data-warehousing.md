# Real-World Asked: Data Warehousing & Modeling

Data warehousing and data modeling questions reported from real interviews.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Deloitte

### Q1: Tell us about your data modeling experience.

**Answer:**
Structure the answer around the models you actually built:
- **Approach:** dimensional modeling (Kimball star schemas) for analytics; normalized models for operational stores; possibly Data Vault for integration layers.
- **Process:** identify business processes, then define the **grain** of each fact, then choose dimensions and measures, then handle history (SCD Type 1 or 2) and conformed dimensions shared across facts.
- **Example:** "For the sales mart I modeled `fct_sales` at order-line grain with `dim_customer` (SCD2), `dim_product`, `dim_store` and `dim_date`; I partitioned the fact by date and clustered it by customer in BigQuery."
- **Physical design for the platform:** denormalization and nested fields in BigQuery, partitioning and clustering, surrogate keys.
- **Results:** faster reports, consistent metrics across teams.

**Follow-ups:**
- How do you decide the grain of a fact table?
- When would you denormalize a dimension into the fact?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q2: How would you model data for an insurance business?

**Answer:**
Start from the core business processes, each becoming a fact at a clear grain:
- **Policies:** `fct_policy_transactions` (new business, endorsement, renewal, cancellation) and a periodic snapshot `fct_policy_monthly` (premium in force, exposure).
- **Premiums and billing:** `fct_premium` (written vs earned premium by period).
- **Claims:** `fct_claim_transactions` (reported, reserved, paid, recovered) and an accumulating snapshot `fct_claim_lifecycle` with milestone dates (reported → assessed → settled → closed).

**Dimensions:** `dim_policyholder` (SCD2, PII-protected), `dim_policy` (product, coverage, terms), `dim_coverage`, `dim_agent` / broker, `dim_vehicle` or `dim_property` (insured object), `dim_geography`, `dim_date` (several roles: effective, expiry, loss, report dates).

**Key points:** policies change over time (endorsements), so use SCD2 and effective-dated facts; claims and policies relate many-to-many through coverages (bridge tables); KPIs such as loss ratio (claims paid ÷ earned premium) need consistent grain across facts.

**Follow-ups:**
- Why would you use an accumulating snapshot for claims?
- How do you calculate earned premium over a policy period?

**Difficulty:** Hard


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q3: Star schema vs snowflake schema: how do they differ, and when would you pick each?

**Answer:**
Both are dimensional modeling patterns with a central **fact table** (measurable events, e.g., sales) surrounded by **dimension tables** (descriptive context, e.g., customer, product, date). In a **star schema**, dimensions are fully denormalized (flat, one table each). In a **snowflake schema**, dimensions are further normalized into sub-dimensions (e.g., `product` → `product_category` as a separate table) — saves storage/redundancy but requires more joins per query. Star schemas are generally preferred in modern columnar warehouses since storage is cheap and join reduction matters more.

**Follow-ups:**
- Which performs better for BI queries?
- What's a conformed dimension?

**Difficulty:** Easy


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

## Persistent Systems

### Q4: What is dimensional modeling? Model sales with a fact table plus product and customer dimensions.

**Answer:**
**Dimensional modeling** organizes data for analysis into **facts** (measurable events) and **dimensions** (descriptive context), usually as a star schema.

**Design steps for sales:**
1. **Business process:** sales orders.
2. **Grain:** one row per **order line** (product per order), the most detailed useful level.
3. **Dimensions:** `dim_date`, `dim_customer` (SCD2 for attributes like segment and city), `dim_product` (category, brand), `dim_store` / channel.
4. **Measures:** quantity, unit price, discount, net amount, cost, margin (additive where possible).

```
fct_sales(order_line_id, order_id, date_key, customer_key, product_key, store_key,
          quantity, unit_price, discount_amount, net_amount, cost_amount)
dim_customer(customer_key, customer_id, name, segment, city, valid_from, valid_to, is_current)
dim_product(product_key, product_id, name, category, brand)
```

Use **surrogate keys**, so facts point at the right historical version of an SCD2 dimension, and a degenerate dimension (`order_id`) in the fact. Physically: partition by date and cluster by customer or product in BigQuery.

**Follow-ups:**
- Why choose order-line grain rather than order grain?
- How would you handle returns in this model?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** Round 1 – Technical

**Asked:** 
