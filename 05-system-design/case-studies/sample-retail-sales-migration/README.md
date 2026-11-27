# Case Study: Retail Sales Warehouse Migration to GCP

> **Sample case study.** This scenario is illustrative and anonymized: the company, data volumes and numbers are generic. Use it as a reference for the expected layout.

## Overview

A regional grocery retailer with about 500 stores runs its daily sales reporting on an on-prem SQL Server warehouse loaded by SSIS. The team migrated it to a GCP batch pipeline: Cloud Storage, Dataproc Serverless, BigQuery, Cloud Composer and Looker.

## Business Problem

- **The nightly load misses its window.** Sales data should be ready by 6 AM, but the SSIS load now often finishes after 9 AM, so store managers start the day with stale numbers.
- **Data volume keeps growing** (about 50 GB a day of POS exports, and 3+ years of history), and the on-prem hardware is reaching end of support.
- **Reruns are manual and risky.** A failed night means an engineer reruns packages by hand, sometimes double-loading data.
- **Reporting is rigid.** New questions mean new SSRS reports or emailed Excel extracts.

## Goals

| Goal | Target |
|---|---|
| Data freshness | Curated sales available by **6 AM** daily |
| Reliability | Idempotent reruns and backfills, with no manual cleanup |
| History | 3 years queryable, with late-arriving files handled automatically |
| Cost | Pay for processing used, not idle hardware |

## Solution Summary

POS files land in a **Cloud Storage** raw bucket. A **Dataproc Serverless** PySpark job validates, deduplicates and casts the data, sending bad rows to a quarantine bucket. Clean data loads into **BigQuery** staging, then a `MERGE` updates partitioned, clustered curated tables. **Cloud Composer** orchestrates the run and **Looker** replaces SSRS and the Excel extracts. The migration ran in phases, with a 4-week parallel run before cutover.

## Documents

| File | Contents |
|---|---|
| [legacy-architecture.md](legacy-architecture.md) | The on-prem system and its pain points |
| [target-architecture.md](target-architecture.md) | The GCP design and key decisions |
| [migration-design.md](migration-design.md) | Approach, stack mapping, validation and cutover |
| [lessons-learned.md](lessons-learned.md) | Challenges, trade-offs and interview talking points |
| [diagrams/](diagrams/) | Editable `.drawio` sources with PNG exports |
