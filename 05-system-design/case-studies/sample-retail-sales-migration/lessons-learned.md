# Lessons Learned

## Challenges

- **Undocumented business rules.** About 15% of the transformation logic was hidden in SSIS expressions and derived columns, not in stored procedures. Reconciliation differences during the parallel run were the main way these rules came to light.
- **Late and partial files.** Some stores regularly uploaded after 2 AM. The old system silently dropped them; the new one included them, which at first looked like a mismatch in reconciliation.
- **Time zones.** Stores in two time zones wrote local timestamps without an offset. A store-to-time-zone lookup was added, and `sale_date` was defined in store-local time.
- **Duplicate transactions.** POS retries produced duplicate lines. The legacy dedupe was inconsistent, so dedupe on a business key had to be defined explicitly.
- **Early BigQuery cost surprises.** Analysts queried the unpartitioned backfill tables during testing. `require_partition_filter` and per-user custom quotas fixed this.

## Trade-offs

| Decision | Chosen | Alternative | Why |
|---|---|---|---|
| Processing engine | Dataproc Serverless (PySpark) | Dataflow, or BigQuery-only ELT | The team already knew Spark; the validation logic was easier to unit-test in PySpark. BigQuery-only ELT was close and remains an option. |
| Load pattern | `MERGE` by business key | Partition overwrite | `MERGE` handles corrected and late rows within a partition without rebuilding the whole day. |
| Migration style | Re-platform (keep the star schema) | Full redesign | Kept reports comparable during the parallel run and lowered risk; the redesign was deferred. |
| Run trigger | File arrival plus a deadline | Fixed schedule | Balances completeness against the 6 AM SLA. |
| Report migration | Rebuild the top 25 reports, retire the rest | Port all ~120 reports | Usage logs showed most reports had no recent viewers. |

## Interview Talking Points

- **Frame it as business outcomes:** "Data ready by 6 AM instead of 9 AM, and no manual reruns." Then explain how the architecture achieves that.
- **Idempotency is the core design principle:** per-date staging, `MERGE` by key, and immutable raw data together make reruns and backfills safe.
- **Parallel run and reconciliation:** explain how you proved parity, how differences were categorized, and that some were legacy bugs.
- **Use the stack mapping table** to show you thought about each component (replaced, kept or retired), not just the new tools.
- **Explain the cutover and rollback plan:** interviewers want to hear how you limited risk on switch-over day.
- **Be ready for follow-ups:** "Why not Dataflow?", "How do you handle a store that uploads two days late?", "What would you change at 10x volume?"
