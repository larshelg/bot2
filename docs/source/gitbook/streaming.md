# Streaming Architecture for Pattern Recognition

*Why we need Kafka streaming even for historical backtesting and how to implement CEP with MATCH_RECOGNIZE*

## Table of Contents

- [The Challenge](#the-challenge)
- [Solution Architecture](#solution-architecture)
- [Implementation Steps](#implementation-steps)
- [Pattern Recognition Examples](#pattern-recognition-examples)
- [Mixing Streaming and Batch Sources](#mixing-streaming-and-batch-sources)
- [Best Practices](#best-practices)

## The Challenge

When implementing advanced pattern matching using Flink's **Complex Event Processing (CEP)** and **MATCH_RECOGNIZE** functionality, we encounter a fundamental requirement: **these features only work with streaming sources**, not batch tables.

### Why This Matters

{% hint style="warning" %}
**MATCH_RECOGNIZE Limitation**
Even when running historical backtests, Flink's MATCH_RECOGNIZE requires streaming sources to use advanced functions like `PREV()`, `NEXT()`, and temporal pattern matching.
{% endhint %}

### The Problem
- **Batch tables** (JDBC connections to PostgreSQL) don't support `PREV()` functions
- **Pattern recognition** needs streaming context for temporal relationships
- **Backtesting** still requires the same streaming infrastructure as live trading

### The Solution
Create a **hybrid architecture** that streams historical data through Kafka to enable pattern recognition, while still using batch sources for simple indicator calculations.

## Solution Architecture

```
PostgreSQL (Historical Data) 
        ↓
   Kafka Stream
        ↓
Flink Pattern Recognition (MATCH_RECOGNIZE)
        +
Flink Batch Processing (Simple Indicators)
        ↓
   Trading Signals
```

### Core Principle
> **Stream historical data through Kafka to unlock CEP capabilities, while mixing with batch sources for optimal performance**

## Implementation Steps

### Step 1: Create PostgreSQL Source Table

```sql
-- Flink table connecting to your existing PostgreSQL candles table
CREATE TABLE candles (
  `time` TIMESTAMP(3) NOT NULL,
  `symbol` VARCHAR(2147483647) NOT NULL,
  `open` DECIMAL(20, 8),
  `high` DECIMAL(20, 8),
  `low` DECIMAL(20, 8),
  `close` DECIMAL(20, 8),
  `volume` DECIMAL(20, 8),
  WATERMARK FOR `time` AS `time` - INTERVAL '5' SECOND,
  CONSTRAINT `PK_time_symbol` PRIMARY KEY (`time`, `symbol`) NOT ENFORCED
)
WITH (
  'connector' = 'jdbc',
  'driver' = 'org.postgresql.Driver',
  'password' = 'postgres',
  'table-name' = 'candles',
  'url' = 'jdbc:postgresql://postgresdb:5432/cursorDB',
  'username' = 'postgres'
);
```

### Step 2: Create Kafka Sink Table

```sql
-- Kafka sink to stream data for pattern recognition
CREATE TABLE candles_kafka_sink (
    `time` TIMESTAMP(3),
    symbol STRING,
    `open` DECIMAL(20, 8),
    high DECIMAL(20, 8),
    low DECIMAL(20, 8),
    `close` DECIMAL(20, 8),
    volume DECIMAL(20, 8)
) WITH (
    'connector' = 'kafka',
    'topic' = 'candles-stream',
    'properties.bootstrap.servers' = 'redpanda-0:9092',
    'format' = 'json',
    'sink.partitioner' = 'fixed'
);
```

### Step 3: Create Kafka Streaming Source

```sql
-- Kafka streaming source with watermarks for pattern recognition
CREATE TABLE candles_stream (
    `time` TIMESTAMP(3),
    symbol STRING,
    `open` DECIMAL(20, 8),
    high DECIMAL(20, 8),
    low DECIMAL(20, 8),
    `close` DECIMAL(20, 8),
    volume DECIMAL(20, 8),
    WATERMARK FOR `time` AS `time` - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'candles-stream',
    'properties.bootstrap.servers' = 'redpanda-0:9092',
    'properties.group.id' = 'candles-consumer',
    'format' = 'json',
    'scan.startup.mode' = 'earliest-offset'
);
```

### Step 5: Create Indicators Table Connection

```sql
-- Connect to your PostgreSQL indicators view for use in patterns
CREATE TABLE indicators_5m (
    symbol STRING,
    bucket TIMESTAMP(3),
    `open` DECIMAL(20, 8),
    high DECIMAL(20, 8),
    low DECIMAL(20, 8),
    `close` DECIMAL(20, 8),
    volume DECIMAL(20, 8),
    price_change DECIMAL(20, 8),
    sma21 DECIMAL(20, 8),
    sma10 DECIMAL(20, 8),
    rsi_14 DECIMAL(10, 4),
    WATERMARK FOR bucket AS bucket - INTERVAL '5' SECOND
) WITH (
    'connector' = 'jdbc',
    'driver' = 'org.postgresql.Driver',
    'url' = 'jdbc:postgresql://postgresdb:5432/cursorDB',
    'table-name' = 'ohlc_indicators_5m',
    'username' = 'postgres',
    'password' = 'postgres'
);
```

### Step 6: Start the Data Pipeline

```sql
-- Continuous job to stream historical data to Kafka
INSERT INTO candles_kafka_sink
SELECT * FROM candles;
```

## Pattern Recognition Examples

Now that we have streaming data, we can use advanced pattern matching!

### Example 1: Bullish Trend Pattern

```sql
-- Detect 3-candle bullish trend pattern
SELECT *
FROM candles_stream
MATCH_RECOGNIZE (
    PARTITION BY symbol
    ORDER BY `time`
    MEASURES
        FIRST(A.`time`) AS pattern_start,
        LAST(C.`time`) AS pattern_end,
        FIRST(A.`close`) AS first_close,
        LAST(C.`close`) AS last_close,
        (LAST(C.`close`) - FIRST(A.`close`)) / FIRST(A.`close`) * 100 AS price_change_pct
    ONE ROW PER MATCH
    AFTER MATCH SKIP PAST LAST ROW
    PATTERN (A B C)
    DEFINE
        B AS B.`close` > PREV(B.`close`),  -- PREV() works with streaming!
        C AS C.`close` > PREV(C.`close`)   -- Sequential price increases
) AS bullish_trend;
```

SELECT *
FROM candles_stream
MATCH_RECOGNIZE (
    PARTITION BY symbol
    ORDER BY `time`
    MEASURES
        FIRST(TREND.`time`) AS pattern_start,
        LAST(TREND.`time`) AS pattern_end,
        FIRST(TREND.`close`) AS first_close,
        LAST(TREND.`close`) AS last_close,
        (LAST(TREND.`close`) - FIRST(TREND.`close`)) / FIRST(TREND.`close`) * 100 AS price_change_pct
    ONE ROW PER MATCH
    AFTER MATCH SKIP PAST LAST ROW
    PATTERN (TREND{3})
    DEFINE
        TREND AS
            LAST(TREND.`close`, 1) IS NULL OR
            TREND.`close` > LAST(TREND.`close`, 1)  -- Cumulative check for increasing closes
) AS bullish_trend;

### Example 2: Doji Pattern Detection

```sql
-- Detect Doji candlestick patterns (open ≈ close)
SELECT *
FROM candles_stream
MATCH_RECOGNIZE (
    PARTITION BY symbol
    ORDER BY `time`
    MEASURES
        A.`time` AS doji_time,
        A.`open` AS doji_open,
        A.`close` AS doji_close,
        A.`high` AS doji_high,
        A.`low` AS doji_low,
        ABS(A.`close` - A.`open`) / ((A.`high` - A.`low`) + 0.001) AS doji_ratio
    ONE ROW PER MATCH
    AFTER MATCH SKIP PAST LAST ROW
    PATTERN (A)
    DEFINE
        A AS ABS(A.`close` - A.`open`) / ((A.`high` - A.`low`) + 0.001) < 0.1  -- Doji threshold
) AS doji_patterns;
```

### Example 4: RSI Oversold + Price Above SMA Pattern

```sql
-- The Holy Grail: Combine RSI conditions with price patterns using MATCH_RECOGNIZE
SELECT *
FROM (
    SELECT 
        c.symbol,
        c.`time`,
        c.`close`,
        i.rsi_14,
        i.sma21,
        i.sma10
    FROM candles_stream c
    JOIN indicators_5m i ON c.symbol = i.symbol 
        AND c.`time` BETWEEN i.bucket AND i.bucket + INTERVAL '5' MINUTE
) enriched_stream
MATCH_RECOGNIZE (
    PARTITION BY symbol
    ORDER BY `time`
    MEASURES
        FIRST(A.`time`) AS oversold_start,
        LAST(C.`time`) AS signal_time,
        FIRST(A.rsi_14) AS entry_rsi,
        LAST(C.`close`) AS signal_price,
        LAST(C.sma21) AS signal_sma21,
        (LAST(C.`close`) - FIRST(A.`close`)) / FIRST(A.`close`) * 100 AS pattern_gain_pct
    ONE ROW PER MATCH
    AFTER MATCH SKIP PAST LAST ROW
    PATTERN (A+ B C+)
    DEFINE
        A AS A.rsi_14 <= 30,                          -- RSI oversold condition
        B AS B.rsi_14 > PREV(B.rsi_14)                -- RSI starting to recover
             AND B.`close` > B.sma21,                  -- Price above SMA21
        C AS C.`close` > PREV(C.`close`)               -- Continuation of bullish momentum
             AND C.rsi_14 > 40                         -- RSI recovery confirmed
             AND C.`close` > C.sma10                   -- Price above shorter SMA
) AS rsi_oversold_recovery;
```

### Example 5: Golden Cross with RSI Confirmation

```sql
-- Detect SMA10 crossing above SMA21 (Golden Cross) with RSI confirmation
SELECT *
FROM indicators_5m
MATCH_RECOGNIZE (
    PARTITION BY symbol
    ORDER BY bucket
    MEASURES
        FIRST(A.bucket) AS setup_start,
        B.bucket AS golden_cross_time,
        C.bucket AS confirmation_time,
        B.sma10 AS cross_sma10,
        B.sma21 AS cross_sma21,
        C.rsi_14 AS confirm_rsi,
        C.`close` AS signal_price
    ONE ROW PER MATCH
    AFTER MATCH SKIP PAST LAST ROW
    PATTERN (A+ B C)
    DEFINE
        A AS A.sma10 <= A.sma21                       -- SMA10 below SMA21 (setup)
             AND A.rsi_14 > 25,                        -- Not extremely oversold
        B AS B.sma10 > B.sma21                         -- Golden Cross occurs!
             AND PREV(B.sma10) <= PREV(B.sma21),       -- Previous candle was still below
        C AS C.sma10 > C.sma21                         -- Cross confirmed
             AND C.rsi_14 > 50                         -- RSI showing strength
             AND C.`close` > PREV(C.`close`)           -- Price momentum up
) AS golden_cross_signals;
```

### Example 6: Multi-Timeframe Pattern Recognition

```sql
-- Advanced: RSI divergence pattern with price action
SELECT *
FROM indicators_5m
MATCH_RECOGNIZE (
    PARTITION BY symbol
    ORDER BY bucket
    MEASURES
        FIRST(A.bucket) AS divergence_start,
        LAST(D.bucket) AS signal_time,
        FIRST(A.`close`) AS first_low_price,
        C.`close` AS second_low_price,
        FIRST(A.rsi_14) AS first_low_rsi,
        C.rsi_14 AS second_low_rsi,
        (C.rsi_14 - FIRST(A.rsi_14)) AS rsi_improvement,
        D.`close` AS breakout_price
    ONE ROW PER MATCH
    AFTER MATCH SKIP PAST LAST ROW
    PATTERN (A B+ C D+)
    DEFINE
        A AS A.rsi_14 < 35,                           -- First oversold reading
        B AS B.`close` >= PREV(B.`close`)             -- Price recovery from first low
             AND B.rsi_14 >= PREV(B.rsi_14),           -- RSI recovery
        C AS C.`close` <= FIRST(A.`close`)            -- Second low similar/lower price
             AND C.rsi_14 > FIRST(A.rsi_14) + 5,      -- BUT RSI is higher (bullish divergence!)
        D AS D.`close` > PREV(D.`close`)              -- Bullish breakout
             AND D.`close` > D.sma21                   -- Above trend line
             AND D.rsi_14 > 45                         -- RSI confirming strength
) AS bullish_rsi_divergence;
```

## Mixing Streaming and Batch Sources

The beauty of this approach is you can **combine** streaming pattern recognition with batch indicator calculations:

### Example: Pattern + Indicator Fusion

```sql
-- Join streaming patterns with batch indicators
SELECT 
    p.symbol,
    p.pattern_start,
    p.breakout_close,
    p.breakout_pct,
    i.sma21,
    i.sma10,
    i.rsi_14,
    -- Trading signal logic
    CASE 
        WHEN p.breakout_pct > 2.0 
         AND i.rsi_14 < 70 
         AND i.sma10 > i.sma21 
        THEN 'STRONG_BUY'
        WHEN p.breakout_pct > 1.0 
         AND i.rsi_14 < 80 
        THEN 'BUY'
        ELSE 'HOLD'
    END AS signal
FROM resistance_breaks p
JOIN (
    -- Batch source for indicators
    SELECT symbol, bucket, sma21, sma10, rsi_14
    FROM ohlc_indicators_5m
) i ON p.symbol = i.symbol 
    AND p.breakout_time BETWEEN i.bucket AND i.bucket + INTERVAL '5' MINUTE;
```

## Best Practices

{% hint style="success" %}
**Streaming Strategy**
- Use streaming sources ONLY for pattern recognition and CEP
- Keep simple indicators in batch/continuous aggregates for performance
- Stream historical data through Kafka to enable MATCH_RECOGNIZE in backtests
- Use proper watermarks to handle late-arriving data
{% endhint %}

{% hint style="warning" %}
**Performance Considerations**
- Kafka streaming adds latency and complexity
- Only stream data when you need PREV(), NEXT(), or MATCH_RECOGNIZE functionality
- Consider streaming only the symbols and timeframes you actively pattern-match
- Monitor Kafka topic sizes and retention policies
{% endhint %}

{% hint style="info" %}
**Backtest Implementation**
- Historical backtests can use the same streaming infrastructure
- Set Kafka consumer to 'earliest-offset' for complete historical replay
- Pattern recognition works identically on historical and live data
- Combine streaming patterns with batch indicators for optimal performance
{% endhint %}

### Key Takeaways

1. **Pattern Recognition requires streaming** - MATCH_RECOGNIZE needs Kafka/streaming sources
2. **Simple indicators stay in TimescaleDB** - No need to stream for SMA, RSI, etc.
3. **Hybrid approach works for backtesting** - Stream historical data through Kafka for patterns
4. **Best of both worlds** - Combine streaming CEP with batch indicator efficiency

This architecture enables sophisticated pattern recognition while maintaining the performance benefits of our TimescaleDB indicator calculations!
