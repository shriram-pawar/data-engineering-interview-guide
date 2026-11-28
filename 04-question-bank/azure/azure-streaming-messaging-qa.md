# Azure Streaming & Messaging — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is Azure Event Hubs, and how do partitions and consumer groups work?

**Answer:**
Event Hubs is a fully managed, high-throughput **event ingestion** service (millions of events per second), also usable through the **Kafka protocol**.
- **Partitions:** an event hub is split into partitions, each an ordered, append-only log. Events with the same **partition key** go to the same partition (ordering per key). The partition count sets the maximum consumer parallelism.
- **Consumer groups:** independent **views** of the stream; each group (e.g. "stream-analytics", "databricks") reads all partitions at its own pace, keeping its own offsets and checkpoints.
- **Retention:** events stay for the configured period (1–7 days on Standard, up to 90 on Premium/Dedicated), and **Capture** can write them automatically to ADLS or Blob as Avro or Parquet.
- **Throughput:** throughput units (Standard) or processing units (Premium).

Typical use: telemetry or clickstream → Event Hubs → Databricks Structured Streaming or Stream Analytics → Delta, Synapse or Power BI.

**Follow-ups:**
- How do you choose the number of partitions?
- Why use separate consumer groups for each downstream application?

**Difficulty:** Medium

---

### Q2: What is Azure Stream Analytics, and when would you use it?

**Answer:**
Azure Stream Analytics is a **serverless, SQL-based stream processing** service:
- **Inputs:** Event Hubs, IoT Hub, Blob/ADLS (also reference data for lookups).
- **Query:** a SQL dialect with **windowing** (tumbling, hopping, sliding, session), joins with reference data, and late or out-of-order event policies.
- **Outputs:** Synapse, SQL Database, ADLS, Cosmos DB, Power BI (real-time dashboards), Functions, and more.
- Scaled with **streaming units**; no cluster to manage.

```sql
SELECT DeviceId, AVG(Temperature) AS avg_temp, System.Timestamp() AS window_end
INTO PowerBIOutput
FROM IoTInput TIMESTAMP BY EventTime
GROUP BY DeviceId, TumblingWindow(minute, 5)
```

Use it for simple-to-moderate real-time aggregations and alerting with SQL skills. Use Databricks Structured Streaming for complex logic, custom code, or lakehouse integration.

**Follow-ups:**
- What does `TIMESTAMP BY` change?
- When would you choose Databricks instead?

**Difficulty:** Medium

---

### Q3: Event Hubs vs Service Bus: what's the difference?

**Answer:**
| | Event Hubs | Service Bus |
|---|---|---|
| Purpose | **Event streaming / telemetry ingestion** at huge scale | **Enterprise messaging** between applications |
| Model | Partitioned log; consumers track their own offsets, and events can be **re-read** within retention | Queues and topics with subscriptions; a message is **consumed and removed** after completion |
| Features | Very high throughput, Kafka endpoint, Capture to storage | Transactions, sessions (FIFO per session), duplicate detection, scheduled messages, **dead-letter queues**, peek-lock |
| Example | Clickstream, IoT, log aggregation | Order processing, payment commands, workflow steps |

Rule of thumb: many events that describe "what happened" go to **Event Hubs**; individual high-value messages that must be processed reliably exactly once go to **Service Bus**.

**Follow-ups:**
- Why can't a Service Bus consumer replay old messages the way Event Hubs can?
- What are Service Bus sessions used for?

**Difficulty:** Medium

---

### Q4: When would you use Azure Queue Storage, and when Service Bus queues?

**Answer:**
| | Queue Storage | Service Bus queues |
|---|---|---|
| Part of | A storage account | A dedicated messaging service |
| Scale | Very large queues (hundreds of TB), simple | Up to 80 GB per queue (Premium), richer semantics |
| Message size | Up to 64 KB | 256 KB (Standard) up to 100 MB (Premium) |
| Ordering | Best effort | **FIFO** with sessions |
| Features | Basic: visibility timeout, poison handling by hand | Dead-lettering, duplicate detection, transactions, scheduled delivery, topics and subscriptions |
| Cost | Very cheap | Higher |

Use **Queue Storage** for simple, high-volume background work queues; **Service Bus** when you need ordering, transactions, pub/sub, or built-in dead-lettering.

**Follow-ups:**
- How would you handle poison messages in Queue Storage?
- When do you need Service Bus topics instead of queues?

**Difficulty:** Easy

---

### Q5: What is event-driven architecture, and how does it apply to data pipelines?

**Answer:**
In an event-driven architecture, components **react to events** (a file arrived, an order was placed, a row changed) instead of polling on a schedule. Producers publish events to a broker; consumers subscribe and react independently.

**Benefits:** lower latency (process as soon as data arrives), loose coupling (producers don't know consumers), independent scaling, and easy fan-out to several consumers.

**In data pipelines on Azure:**
- A blob created in ADLS → **Event Grid** → an ADF storage-event trigger or Azure Function → process that file.
- Database changes (CDC) → **Event Hubs** → Databricks streaming → Delta tables.
- A pipeline finished → a custom event → trigger downstream jobs.

**Challenges:** at-least-once delivery (consumers must be idempotent), ordering, monitoring flows across services, and handling poison events (dead-letter).

**Follow-ups:**
- How do you make an event-driven consumer idempotent?
- When is a scheduled batch better than event-driven processing?

**Difficulty:** Medium

---

### Q6: Kafka vs Azure Event Hubs: how do they compare?

**Answer:**
| | Apache Kafka (self-managed or Confluent) | Azure Event Hubs |
|---|---|---|
| Operation | You run brokers (or use a managed vendor): scaling, upgrades, ZooKeeper/KRaft | Fully managed PaaS |
| Protocol | Kafka | Native AMQP plus a **Kafka-compatible endpoint** (most Kafka clients work unchanged) |
| Concepts | Topics, partitions, consumer groups, offsets | Event hubs (≈ topics), partitions, consumer groups, checkpoints |
| Retention | Configurable, unlimited with tiered storage | 1–90 days depending on tier; Capture for long-term storage |
| Ecosystem | Kafka Connect, ksqlDB, Streams, log compaction | Azure integrations (Stream Analytics, Functions, Capture); limited Kafka Streams/Connect features |
| Cost | Infrastructure plus operations staff | Pay per throughput or processing units |

Choose **Event Hubs** for managed Azure-native streaming with Kafka clients; **Kafka** (or Confluent Cloud) when you need the full Kafka ecosystem, compaction, very long retention, or multi-cloud portability.

**Follow-ups:**
- What Kafka features aren't available on Event Hubs?
- How do you migrate a Kafka producer to Event Hubs?

**Difficulty:** Medium

---

### Q7: How is event ordering guaranteed in a streaming system like Event Hubs?

**Answer:**
Ordering is guaranteed **only within a partition**, never across the whole stream:
- Send related events with the same **partition key** (e.g. `device_id`, `order_id`), so they land in the same partition, in the order they were sent.
- A consumer reads each partition sequentially, so per-key order is preserved, as long as processing for a partition isn't parallelized out of order.
- Retries on the producer side can reorder or duplicate events unless idempotent producers or sequence numbers are used.

If business logic needs order, carry a **sequence number or event timestamp** in the event and have consumers or sinks apply "newer wins" (`MERGE ... WHEN src.seq > tgt.seq`). Don't rely on global ordering; it would force a single partition and kill throughput.

**Follow-ups:**
- What happens to ordering if you increase the partition count later?
- How do you handle an event that arrives out of order?

**Difficulty:** Medium

---

### Q8: What is checkpointing in Event Hubs consumers, and why does it matter?

**Answer:**
A **checkpoint** records the **offset (position) up to which a consumer group has processed** each partition, typically stored in Blob Storage by the Event Processor client (or in the Spark checkpoint location for Structured Streaming).
- After a restart or rebalance, consumers resume from the last checkpoint instead of from the start or the end.
- **When** you checkpoint defines the delivery semantics: checkpoint **after** successfully writing results, which gives **at-least-once** (possible reprocessing after a crash), so sinks should be idempotent. Checkpointing before processing risks losing events.
- Checkpointing after every event is expensive; checkpoint every N events or seconds.

In Databricks, the Structured Streaming checkpoint (offsets plus state) plays this role, giving exactly-once into Delta sinks.

**Follow-ups:**
- What happens if you checkpoint before writing to the sink?
- Why shouldn't two applications share one consumer group?

**Difficulty:** Medium

---

### Q9: What is Azure Event Grid, and how is it different from Event Hubs?

**Answer:**
- **Event Grid** is a **serverless event routing** service: it pushes **discrete events** ("something happened") from sources (Blob created, resource changed, custom topics) to handlers (Functions, Logic Apps, webhooks, ADF triggers, queues), with filtering and retries. It's reactive and low volume per event, and you pay per operation.
- **Event Hubs** is a **streaming ingestion** service for high-volume event **streams** (telemetry, clickstream), stored in a partitioned log for consumers to pull and replay.

| | Event Grid | Event Hubs |
|---|---|---|
| Pattern | Push and route events to handlers | Ingest and buffer streams for consumers to pull |
| Volume | Individual events (discrete) | Millions of events per second (continuous) |
| Replay | No (delivery with retry, then dead-letter) | Yes, within retention |

They're often combined: Event Grid notifies "file landed", while Event Hubs carries the telemetry stream.

**Follow-ups:**
- Which service powers ADF storage event triggers?
- How does Event Grid handle a handler that's down?

**Difficulty:** Easy
