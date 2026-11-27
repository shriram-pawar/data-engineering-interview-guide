# Datastream — Use Cases, Implementation & Code

## What it is
A serverless **Change Data Capture (CDC)** and replication service. It reads the transaction/redo/binary log of a source database (MySQL, PostgreSQL, Oracle, AlloyDB, SQL Server) and streams row-level inserts/updates/deletes to a destination (BigQuery or Cloud Storage) in near real-time — without adding load to the source database via repeated polling queries.

---

## Use Case 1: Real-time replication from Cloud SQL (MySQL) to BigQuery for live analytics

**Scenario**: An application's operational MySQL database should power near-real-time dashboards, without running analytical queries against production or building a custom CDC pipeline.

**Implementation steps**:
1. Enable binary logging (`log_bin`) on the source MySQL instance, and create a Datastream-specific DB user with `REPLICATION SLAVE`/`REPLICATION CLIENT` privileges.
2. Set up connectivity — for a Cloud SQL source in the same project, this can be a private connection; for external sources, configure a **private connectivity configuration** (VPC peering) or IP allowlisting.
3. Create source and destination **connection profiles**, then a **stream**.

```bash
# Source connection profile (MySQL)
gcloud datastream connection-profiles create mysql-source-profile \
  --location=us-central1 \
  --type=mysql \
  --mysql-hostname=10.0.0.5 \
  --mysql-port=3306 \
  --mysql-username=datastream_user \
  --mysql-password=$MYSQL_PASSWORD \
  --vpc-peering-config-vpc=my-vpc

# Destination connection profile (BigQuery)
gcloud datastream connection-profiles create bq-destination-profile \
  --location=us-central1 \
  --type=bigquery

# Create the stream
gcloud datastream streams create orders-cdc-stream \
  --location=us-central1 \
  --source=mysql-source-profile \
  --mysql-source-config=mysql_config.json \
  --destination=bq-destination-profile \
  --bigquery-destination-config=bq_config.json \
  --display-name="Orders DB CDC to BigQuery" \
  --backfill-all
```

```json
// mysql_config.json — which schemas/tables to capture
{
  "includeObjects": {
    "mysqlDatabases": [
      {"database": "shop_db", "mysqlTables": [{"table": "orders"}, {"table": "customers"}]}
    ]
  }
}
```

```json
// bq_config.json — how change events land in BigQuery
{
  "dataFreshness": "900s",
  "sourceHierarchyDatasets": {
    "datasetTemplate": {"location": "us-central1"}
  }
}
```

**Result**: Datastream performs an initial **backfill** of existing rows, then continuously streams change events. BigQuery ends up with tables that merge inserts/updates/deletes automatically (via Datastream's built-in merge into a BigQuery replica table), so `shop_db.orders` in BigQuery reflects near-real-time source state — typically within a minute or less.

---

## Use Case 2: Database migration with minimal downtime (Oracle/PostgreSQL → Cloud SQL/AlloyDB)

**Scenario**: Migrating a production database to GCP without a long downtime window — replicate continuously, then cut over once caught up.

**Pattern**:
1. Take an initial snapshot/dump and load it into the target database.
2. Configure Datastream to capture changes from the source starting at (or before) the snapshot point.
3. Let Datastream keep the target in sync via CDC while the old system stays live.
4. Monitor replication lag until it's near-zero, then perform the cutover (stop writes to source, confirm final sync, switch application traffic to the new database).

This dramatically shrinks the downtime window compared to a stop-the-world dump/restore, since only the final sync gap needs to be closed at cutover time.

---

## Use Case 3: Feeding a data lake (GCS) for downstream processing (Dataflow/Dataproc)

**Scenario**: Rather than landing directly in BigQuery, you want raw change events in GCS (e.g., Avro/JSON) to feed a custom Dataflow pipeline that applies business-specific merge/dedup logic before loading multiple downstream systems.

```bash
gcloud datastream connection-profiles create gcs-destination-profile \
  --location=us-central1 \
  --type=google-cloud-storage \
  --gcs-bucket=my-cdc-landing-bucket \
  --gcs-root-path=/orders-cdc

gcloud datastream streams create orders-cdc-to-gcs \
  --location=us-central1 \
  --source=mysql-source-profile \
  --mysql-source-config=mysql_config.json \
  --destination=gcs-destination-profile \
  --gcs-destination-config='{"avroFileFormat": {}}' \
  --backfill-all
```
A Dataflow (or Cloud Function-triggered) job then reads the landed Avro files, applies the change events (insert/update/delete op codes included in each record), and merges into whatever downstream store is needed.

---

## Monitoring a stream
```bash
gcloud datastream streams describe orders-cdc-stream --location=us-central1

# Check for errors on specific objects being replicated
gcloud datastream streams objects list orders-cdc-stream --location=us-central1
```
Datastream also emits metrics to **Cloud Monitoring** (e.g., `unsupported_event_count`, `total_latency`) — set alerts on replication latency to catch a stream falling behind before it becomes a problem.

---

## Best practices
- Grant the Datastream user the **minimum replication privileges** needed on the source — it should never need broader DB access.
- Use **private connectivity (VPC peering)** rather than public IP allowlisting where the source is in a private network.
- Start with `--backfill-all` for a complete initial sync, but for very large tables, consider excluding specific huge/rarely-queried tables and backfilling them separately to control initial load.
- Monitor **replication lag** continuously in Cloud Monitoring, not just at setup time.
- Remember Datastream handles **capture and delivery**, not transformation — pair it with Dataflow/scheduled BigQuery queries for any business logic beyond raw replication.
