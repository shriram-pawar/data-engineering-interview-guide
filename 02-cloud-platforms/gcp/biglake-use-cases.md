# BigLake — Use Cases, Implementation & Code

## What it is
BigLake extends BigQuery's governance (fine-grained access control, encryption, audit logging) to data that lives **outside** BigQuery's native storage — in Cloud Storage (as Parquet/ORC/Avro/CSV, including open table formats like Iceberg/Delta/Hudi) — and lets multiple engines (BigQuery, Spark via the BigLake connector, etc.) query the *same* files with **consistent, centrally-managed security**, instead of each engine enforcing its own separate access rules.

---

## Use Case 1: Query data-lake files as a governed BigQuery table (no data movement/copy)

**Scenario**: Parquet files land in GCS from an upstream Spark job. Analysts want to query them from BigQuery without a separate load/ETL step, but still need row/column-level security like a native BigQuery table.

**Step 1 — Create a BigLake connection** (the identity BigQuery uses to read GCS on the querying user's behalf):
```bash
bq mk --connection --location=us-central1 \
  --connection_type=CLOUD_RESOURCE \
  my-gcs-connection

# Grant that connection's service account read access to the bucket
gsutil iam ch serviceAccount:<connection-service-account>:objectViewer gs://my-datalake-bucket
```

**Step 2 — Create the BigLake table**:
```sql
CREATE EXTERNAL TABLE `my_project.sales.orders_biglake`
WITH CONNECTION `my_project.us-central1.my-gcs-connection`
OPTIONS (
  format = 'PARQUET',
  uris = ['gs://my-datalake-bucket/orders/*.parquet']
);
```

**Step 3 — Query it exactly like a native table**:
```sql
SELECT region, SUM(amount) AS total
FROM `my_project.sales.orders_biglake`
WHERE order_date = CURRENT_DATE() - 1
GROUP BY region;
```
Unlike a plain BigQuery external table, access here is enforced through BigQuery's IAM/row/column-security layer — the querying user never needs direct GCS permissions; BigLake mediates access via the connection's service account.

---

## Use Case 2: Fine-grained row-level and column-level security over lake data

**Scenario**: The `orders_biglake` table above contains PII and region-restricted data. Different analyst teams should see different subsets.

**Column-level security** (mask/restrict a sensitive column):
```sql
-- Tag a column with a policy tag defined in Data Catalog's taxonomy
ALTER TABLE `my_project.sales.orders_biglake`
ALTER COLUMN customer_ssn
SET OPTIONS (policy_tags = ["projects/my-project/locations/us/taxonomies/123/policyTags/456"]);
```
Only principals granted the **Fine-Grained Reader** role on that policy tag can see `customer_ssn`; everyone else gets it nulled/redacted automatically, with zero changes to downstream queries.

**Row-level security** (region-based restriction):
```sql
CREATE ROW ACCESS POLICY us_east_only
ON `my_project.sales.orders_biglake`
GRANT TO ("group:us-east-analysts@my-company.com")
FILTER USING (region = 'us-east');
```

---

## Use Case 3: Unified governance across BigQuery AND Spark (Dataproc)

**Scenario**: A Spark job on Dataproc needs to read the *same* governed lake table that BigQuery users query — with the *same* access rules enforced, rather than duplicating IAM logic in two places.

```python
# PySpark reading a BigLake table via the Spark-BigQuery connector
from pyspark.sql import SparkSession

spark = (SparkSession.builder
    .appName("read-biglake")
    .config("spark.jars.packages", "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.34.0")
    .getOrCreate())

df = (spark.read
      .format("bigquery")
      .option("table", "my_project.sales.orders_biglake")
      .load())

df.filter(df.amount > 100).show()
```
Because the underlying table is a BigLake table (not a plain GCS path), the same row/column-level security policies configured in BigQuery apply here too — Spark users can't bypass masking/row filters by reading the files directly through this connector.

---

## Use Case 4: Open table formats — querying Iceberg tables via BigLake

**Scenario**: A team uses Apache Iceberg for its lake tables (for schema evolution, time travel, ACID updates) but still wants BigQuery-native governance and query access.

```sql
CREATE EXTERNAL TABLE `my_project.sales.orders_iceberg`
WITH CONNECTION `my_project.us-central1.my-gcs-connection`
OPTIONS (
  format = 'ICEBERG',
  uris = ['gs://my-datalake-bucket/iceberg/orders/metadata/v3.metadata.json']
);
```
BigQuery reads Iceberg's metadata layer directly, so schema evolution and snapshots managed by Iceberg-writing engines (Spark, Flink) are reflected automatically without redefining the BigLake table.

---

## Best practices
- Use a **BigLake connection with a dedicated service account** per data domain/bucket rather than one broad connection for everything — keeps the blast radius of a misconfiguration small.
- Apply **policy tags** for column-level security consistently across both native BigQuery tables and BigLake tables so PII handling doesn't depend on where data physically lives.
- Prefer BigLake over plain BigQuery **external tables** whenever you need governed, secure, multi-engine access — plain external tables don't get row/column security enforcement.
- For frequently-queried lake data with heavy analytical use, consider **BigLake materialized views** or periodic loads into native BigQuery storage for better performance, using BigLake for the raw/broad-access layer.
- Keep GCS bucket-level IAM tight regardless — BigLake governs *query* access through BigQuery, but direct bucket access (e.g., via `gsutil`) is a separate exposure to lock down.
