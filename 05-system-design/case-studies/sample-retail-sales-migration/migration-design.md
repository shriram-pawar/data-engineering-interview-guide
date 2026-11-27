# Migration Design

## Approach

A **phased re-platform:** keep the dimensional model, rebuild the pipelines natively on GCP, and prove parity before switching users over.

| Phase | Scope | Exit criteria |
|---|---|---|
| 1. Foundation | Projects, IAM, networking, buckets, BigQuery datasets, Composer environment (Terraform) | Environments provisioned through CI |
| 2. Historical backfill | Export 3 years of warehouse tables and the raw archive to Cloud Storage, then load into BigQuery | Row counts and totals match per month |
| 3. Pipeline rebuild | Port the SSIS and stored-procedure logic to PySpark and BigQuery SQL, documenting each business rule | Unit tests pass for every rule |
| 4. Parallel run | Run both systems for 4 weeks on the same inputs, reconciling daily | 20 consecutive days with zero unexplained differences |
| 5. Cutover | Switch reporting to Looker, then freeze the legacy system | Sign-off from finance and store operations |
| 6. Decommission | Keep legacy read-only for 30 days, then retire it | Final archive taken and hardware released |

## Stack Mapping

| Legacy component | Target component | Decision | Notes |
|---|---|---|---|
| Store POS CSV export | Store POS CSV export | **Kept** | No changes at the stores; only the upload destination changes |
| SFTP server | Cloud Storage raw bucket + signed-URL upload | **Replaced** | Durable, versioned, and kept for 3 years |
| SSIS packages | Dataproc Serverless PySpark | **Replaced** | Validation and dedupe rules ported and unit-tested |
| SQL Server staging DB | BigQuery `sales_staging` | **Replaced** | Per-run-date tables instead of truncate-and-reload |
| Stored procedures | BigQuery SQL (`MERGE`), run from Composer | **Replaced** | Logic kept in version control, with tests |
| Star schema data model | BigQuery `sales_curated` star schema | **Kept** | Same facts and dimensions; partitioning and clustering added |
| SQL Server Agent | Cloud Composer | **Replaced** | Dependency-aware DAG with retries and SLA alerts |
| SSRS reports | Looker dashboards | **Replaced** | Rebuilt top 25 reports; the rest were reviewed with users |
| Emailed Excel extracts | — | **Retired** | Replaced by Looker self-service exploration |
| Manual rerun runbook | — | **Retired** | Idempotent DAG reruns and backfills |
| On-prem servers and storage | — | **Retired** | Decommissioned after the read-only period |

## Validation

- **Row counts** per `sale_date` and `store_id`, legacy against GCP.
- **Aggregate checks:** total sales amount, quantity and distinct transactions per day and store, with zero tolerance.
- **Hash comparison** of key columns on a sample of 1% of rows per day.
- **Report-level reconciliation:** the top 25 reports compared side by side with business owners.
- **Every difference investigated and categorized:** legacy bug, new bug, or expected (e.g. late files now included). The categories are tracked in a reconciliation log.

## Cutover

1. **Freeze:** pause changes to legacy logic 2 weeks before cutover.
2. **Final sync:** run the last incremental load on both systems and reconcile.
3. **Switch:** point users to Looker dashboards, disable SSRS subscriptions, and announce through store operations.
4. **Monitor:** run a hypercare period of 2 weeks, with daily reconciliation still running against the read-only legacy warehouse.
5. **Rollback plan:** legacy stays loadable for 30 days. If a critical issue appears, re-enable the SSRS subscriptions and Agent jobs; the runbook was tested during the parallel run.
6. **Decommission:** take a final archive of the legacy warehouse to Cloud Storage, then retire the servers.
