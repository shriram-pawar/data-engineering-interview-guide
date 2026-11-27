# BigQuery — Use Cases, Implementation & Code

## What it is
A serverless, fully-managed columnar data warehouse. You don't manage clusters or storage sizing — you write SQL, and BigQuery separates storage from compute, auto-scaling query execution behind the scenes. Billing is by data scanned (on-demand) or by reserved slots (capacity-based).

---

## Use Case 1: Central analytics warehouse with partitioned/clustered tables

**Scenario**: Daily order data lands in a bucket; analysts need fast, cheap dashboards filtering by date and region.

**Implementation**:
1. Load raw data into a staging table.
2. Create the production table **partitioned by date** (limits bytes scanned per query) and **clustered by region/customer_id** (further prunes data within a partition, speeds up filters/joins on that column).

```sql
CREATE TABLE `my_project.sales.orders`
(
  order_id STRING,
  customer_id STRING,
  region STRING,
  amount NUMERIC,
  order_date DATE
)
PARTITION BY order_date
CLUSTER BY region, customer_id
OPTIONS (
  partition_expiration_days = 400,
  require_partition_filter = TRUE   -- forces queries to filter by order_date, avoiding full scans
);
```

```sql
-- Cheap query: only scans the Jan 2024 partition(s), pruned further by region
SELECT customer_id, SUM(amount) AS total
FROM `my_project.sales.orders`
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31'
  AND region = 'us-east'
GROUP BY customer_id;
```

Load data via the `bq` CLI or a scheduled pipeline (Dataflow/Cloud Function/Composer):
```bash
bq load --source_format=PARQUET \
  my_project:sales.orders \
  gs://my-bucket/orders/2024-01-*.parquet
```

---

## Use Case 2: Automated recurring transformations with Scheduled Queries

**Scenario**: Build a daily aggregated summary table without standing up a separate orchestrator.

```sql
-- Saved as a scheduled query, runs daily at 03:00
CREATE OR REPLACE TABLE `my_project.sales.daily_summary`
PARTITION BY summary_date AS
SELECT
  order_date AS summary_date,
  region,
  COUNT(*) AS order_count,
  SUM(amount) AS total_revenue
FROM `my_project.sales.orders`
WHERE order_date = CURRENT_DATE() - 1
GROUP BY summary_date, region;
```
```bash
bq query --use_legacy_sql=false --schedule='every 24 hours' \
  --display_name="daily_sales_summary" \
  --destination_table=my_project:sales.daily_summary \
  --replace=true \
  'SELECT ... '  # or reference a saved query
```
For anything needing conditional logic/dependencies on other systems, trigger this from **Cloud Composer** instead (`BigQueryInsertJobOperator`).

---

## Use Case 3: In-warehouse ML with BigQuery ML

**Scenario**: Predict customer churn without exporting data to a separate ML platform.

```sql
CREATE OR REPLACE MODEL `my_project.ml.churn_model`
OPTIONS(model_type='logistic_reg', input_label_cols=['churned']) AS
SELECT
  tenure_months, monthly_spend, support_tickets, churned
FROM `my_project.sales.customer_features`;

-- Evaluate
SELECT * FROM ML.EVALUATE(MODEL `my_project.ml.churn_model`);

-- Predict on new customers
SELECT customer_id, predicted_churned
FROM ML.PREDICT(MODEL `my_project.ml.churn_model`,
  (SELECT * FROM `my_project.sales.new_customers`));
```

---

## Use Case 4: Querying data engineers actually build pipelines against — Python client

```python
from google.cloud import bigquery

client = bigquery.Client(project="my_project")

query = """
    SELECT region, SUM(amount) AS total
    FROM `my_project.sales.orders`
    WHERE order_date = @target_date
    GROUP BY region
"""
job_config = bigquery.QueryJobConfig(
    query_parameters=[bigquery.ScalarQueryParameter("target_date", "DATE", "2024-01-15")]
)
results = client.query(query, job_config=job_config).result()
for row in results:
    print(row.region, row.total)

# Loading a DataFrame directly
import pandas as pd
df = pd.DataFrame({"id": [1, 2], "value": ["a", "b"]})
client.load_table_from_dataframe(df, "my_project.sales.staging_table").result()
```

---

## Best practices
- Always partition large tables (usually by date) and cluster on common filter columns.
- Use `require_partition_filter=TRUE` to prevent accidental full-table scans.
- Prefer `MERGE` for upserts instead of delete+insert patterns.
- Use **materialized views** for frequently repeated aggregations — they auto-refresh and BigQuery can route queries to them transparently.
- Control cost with a **query byte limit** (`maximum_bytes_billed`) during development, and consider **flat-rate/slot reservations** once query volume is high and predictable.
