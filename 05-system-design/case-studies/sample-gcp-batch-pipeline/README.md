# Case Study: Daily Sales Batch Pipeline on GCP

## Problem
A retail company wants a daily sales dashboard built from transactional data exported by 500 stores.

## Requirements
- Ingest ~50 GB/day of CSV files from stores
- Data ready for BI by 6 AM daily
- Keep 3 years of history; support late-arriving files

## Solution Summary
Files land in **GCS**, are processed by **Dataproc (PySpark)**, loaded into partitioned **BigQuery** tables, orchestrated by **Cloud Composer (Airflow)**, and visualized in **Looker**.

See [architecture.md](architecture.md) for the detailed design.
