# Hybrid Technical Indicators Architecture

*Combining TimescaleDB Continuous Aggregates with Flink Stream Processing*

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Hybrid Architecture Components](#hybrid-architecture-components)
- [Approach Comparison](#approach-comparison)
- [Timeframe Strategy](#timeframe-strategy)
- [Implementation Details](#implementation-details)
- [Practical Examples](#practical-examples)
- [Best Practices](#best-practices)

## Architecture Overview

The hybrid approach combines the strengths of both TimescaleDB continuous aggregates and Apache Flink stream processing to create an optimal technical indicators system that serves both real-time trading and historical analysis needs.

### Data Flow Architecture

```
Stock Price Data
       ↓
TimescaleDB + Apache Flink
       ↓
Hybrid Indicator Fusion → Trading Signals
```

### Key Benefits

**🚀 Optimal Performance**
Pre-computed aggregates for historical data, real-time processing for current indicators

**⚡ True Real-Time**
Sub-second latency for short-term trading strategies

**📊 Complete Coverage**
Supports all timeframes from milliseconds to months

**💰 Cost Efficient**
Minimal resource usage by leveraging the best tool for each job

## Hybrid Architecture Components

### 1. Data Ingestion Layer
Raw stock price data flows into TimescaleDB hypertables. This serves as the single source of truth for all historical and real-time price data.

### 2. TimescaleDB Processing Layer
Continuous aggregates calculate longer-term indicators (1h+) with automatic refresh policies. These are optimized for historical analysis and backtesting.

### 3. CDC Bridge Layer
PostgreSQL CDC streams both raw price data and computed indicators from TimescaleDB to Flink for real-time processing.

### 4. Flink Stream Processing
Real-time calculation of short-term indicators (1m-15m) with stateful processing and immediate signal generation.

### 5. Indicator Fusion Layer
Combines real-time short-term indicators with longer-term indicators from TimescaleDB to create comprehensive trading signals.

## Approach Comparison

### TimescaleDB Continuous Aggregates

**✅ Advantages**
- Extremely fast queries
- Pre-computed results
- Automatic incremental updates
- SQL simplicity
- Perfect for backtesting
- Storage efficient

**❌ Limitations**
- Minimum 1-second refresh
- Limited complex logic
- Requires CDC for streaming
- Additional storage overhead
- Less flexible than code

### Apache Flink Stream Processing

**✅ Advantages**
- Sub-second real-time updates
- Flexible custom logic
- Stateful processing
- Event-driven architecture
- Horizontally scalable
- Memory efficient

**❌ Limitations**
- Higher implementation complexity
- Resource intensive
- Cold start issues
- State recovery challenges
- No pre-computed queries

## Timeframe Strategy

The hybrid approach strategically divides indicator calculations based on timeframe characteristics and use cases.

| Timeframe | Interval | Processing Engine | Use Case | Latency Requirement | Update Frequency |
|-----------|----------|-------------------|----------|-------------------|------------------|
| 1s - 1m | Tick to 1 minute | **Apache Flink** | Scalping | < 100ms | Every tick |
| 5m - 15m | 5 to 15 minutes | **Apache Flink** | Day Trading | < 1s | Every update |
| 30m - 1h | 30 minutes to 1 hour | **TimescaleDB** | Intraday Analysis | 1-5s | 1s refresh |
| 4h - 1d | 4 hours to daily | **TimescaleDB** | Swing Trading | 5-30s | 5s refresh |
| 1w - 1M | Weekly to monthly | **TimescaleDB** | Position Trading | Minutes | 1min refresh |

{% hint style="info" %}
**Strategy Rationale**
Short timeframes (<15m) require immediate updates for trading decisions, while longer timeframes can tolerate small delays in exchange for better performance and resource efficiency.
{% endhint %}

## Implementation Details

### TimescaleDB Continuous Aggregates Setup

```sql
-- Create continuous aggregates for longer timeframes
CREATE MATERIALIZED VIEW hourly_indicators
WITH (timescaledb.continuous) AS
SELECT
    symbol,
    time_bucket('1 hour', time) AS hour,
    -- Simple Moving Averages
    AVG(price) OVER (
        PARTITION BY symbol
        ORDER BY time_bucket('1 hour', time)
        ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
    ) AS sma_20,
    AVG(price) OVER (
        PARTITION BY symbol
        ORDER BY time_bucket('1 hour', time)
        ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
    ) AS sma_50,
    -- OHLC data
    first(price, time) AS open,
    max(price) AS high,
    min(price) AS low,
    last(price, time) AS close,
    sum(volume) AS volume
FROM stock_prices
GROUP BY symbol, time_bucket('1 hour', time);

-- Set refresh policy for near real-time updates
SELECT add_continuous_aggregate_policy('hourly_indicators',
    start_offset => INTERVAL '2 hours',
    end_offset => INTERVAL '1 second',
    schedule_interval => INTERVAL '1 second');

-- Enable CDC for streaming to Flink
ALTER MATERIALIZED VIEW hourly_indicators REPLICA IDENTITY FULL;
```

### Flink Real-Time Processing

```java
// Real-time SMA calculation in Flink
public class RealTimeSMAProcessor extends KeyedProcessFunction<String, PriceEvent, IndicatorEvent> {

    private ValueState<CircularBuffer> priceBuffer;
    private ValueState<Double> currentSMA;

    @Override
    public void open(Configuration parameters) {
        ValueStateDescriptor<CircularBuffer> bufferDescriptor =
            new ValueStateDescriptor<>("price-buffer", CircularBuffer.class);
        priceBuffer = getRuntimeContext().getState(bufferDescriptor);

        ValueStateDescriptor<Double> smaDescriptor =
            new ValueStateDescriptor<>("current-sma", Double.class);
        currentSMA = getRuntimeContext().getState(smaDescriptor);
    }

    @Override
    public void processElement(PriceEvent price, Context ctx, Collector<IndicatorEvent> out)
            throws Exception {

        CircularBuffer buffer = priceBuffer.value();
        if (buffer == null) {
            buffer = new CircularBuffer(20); // SMA period
        }

        // Add new price and calculate SMA
        buffer.add(price.getPrice());

        if (buffer.isFull()) {
            double sma = buffer.average();
            currentSMA.update(sma);

            // Emit indicator update
            IndicatorEvent indicator = new IndicatorEvent(
                price.getSymbol(),
                "SMA_20_1m",
                sma,
                ctx.timestamp()
            );
            out.collect(indicator);
        }

        priceBuffer.update(buffer);
    }
}
```

### Hybrid Data Fusion

```java
// Combine real-time and historical indicators
public class HybridIndicatorFusion extends CoProcessFunction<
    IndicatorEvent,      // Real-time indicators from Flink
    IndicatorEvent,      // Historical indicators from TimescaleDB
    TradingSignal> {

    private MapState<String, IndicatorEvent> realtimeIndicators;
    private MapState<String, IndicatorEvent> historicalIndicators;

    @Override
    public void processElement1(IndicatorEvent realtimeIndicator, Context ctx,
                               Collector<TradingSignal> out) throws Exception {
        // Store real-time indicator
        realtimeIndicators.put(realtimeIndicator.getIndicatorType(), realtimeIndicator);

        // Check for signal generation opportunities
        generateSignals(realtimeIndicator.getSymbol(), ctx.timestamp(), out);
    }

    @Override
    public void processElement2(IndicatorEvent historicalIndicator, Context ctx,
                               Collector<TradingSignal> out) throws Exception {
        // Store historical indicator
        historicalIndicators.put(historicalIndicator.getIndicatorType(), historicalIndicator);

        // Check for signal generation opportunities
        generateSignals(historicalIndicator.getSymbol(), ctx.timestamp(), out);
    }

    private void generateSignals(String symbol, long timestamp,
                               Collector<TradingSignal> out) throws Exception {

        // Get short-term indicators (from Flink)
        IndicatorEvent sma5m = realtimeIndicators.get("SMA_20_5m");
        IndicatorEvent rsi5m = realtimeIndicators.get("RSI_14_5m");

        // Get long-term indicators (from TimescaleDB)
        IndicatorEvent sma1h = historicalIndicators.get("SMA_50_1h");
        IndicatorEvent sma1d = historicalIndicators.get("SMA_200_1d");

        // Multi-timeframe analysis
        if (sma5m != null && sma1h != null && sma1d != null) {
            boolean shortTermBullish = sma5m.getValue() > sma1h.getValue();
            boolean longTermBullish = sma1h.getValue() > sma1d.getValue();

            if (shortTermBullish && longTermBullish && rsi5m != null && rsi5m.getValue() < 70) {
                TradingSignal signal = new TradingSignal(
                    symbol,
                    "BUY",
                    "Multi-timeframe SMA confluence + RSI confirmation",
                    timestamp
                );
                out.collect(signal);
            }
        }
    }
}
```

### CDC Configuration for Streaming

```sql
-- Flink Table API configuration for CDC sources
CREATE TABLE realtime_prices (
    symbol STRING,
    price DECIMAL(10,2),
    volume BIGINT,
    timestamp TIMESTAMP(3),
    WATERMARK FOR timestamp AS timestamp - INTERVAL '1' SECOND
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'timescaledb-host',
    'port' = '5432',
    'username' = 'trading_user',
    'password' = 'password',
    'database-name' = 'trading_db',
    'schema-name' = 'public',
    'table-name' = 'stock_prices'
);

CREATE TABLE historical_indicators (
    symbol STRING,
    indicator_type STRING,
    value DECIMAL(10,4),
    timeframe STRING,
    calculated_at TIMESTAMP(3)
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'timescaledb-host',
    'port' = '5432',
    'username' = 'trading_user',
    'password' = 'password',
    'database-name' = 'trading_db',
    'schema-name' = 'public',
    'table-name' = 'hourly_indicators'
);
```

## Practical Examples

### RSI Calculation Split

```sql
-- TimescaleDB: Daily RSI for swing trading
CREATE MATERIALIZED VIEW daily_rsi
WITH (timescaledb.continuous) AS
WITH price_changes AS (
    SELECT
        symbol,
        time_bucket('1 day', time) AS day,
        last(price, time) - first(price, time) AS price_change
    FROM stock_prices
    GROUP BY symbol, time_bucket('1 day', time)
),
rsi_components AS (
    SELECT
        symbol,
        day,
        price_change,
        CASE WHEN price_change > 0 THEN price_change ELSE 0 END AS gain,
        CASE WHEN price_change < 0 THEN ABS(price_change) ELSE 0 END AS loss,
        AVG(CASE WHEN price_change > 0 THEN price_change ELSE 0 END)
            OVER (PARTITION BY symbol ORDER BY day ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_gain,
        AVG(CASE WHEN price_change < 0 THEN ABS(price_change) ELSE 0 END)
            OVER (PARTITION BY symbol ORDER BY day ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_loss
    FROM price_changes
)
SELECT
    symbol,
    day,
    100 - (100 / (1 + (avg_gain / NULLIF(avg_loss, 0)))) AS rsi_14
FROM rsi_components;
```

## Best Practices

{% hint style="success" %}
**Indicator Selection Strategy**
- Use TimescaleDB for all simple indicators (SMA, EMA, RSI, MACD) across 1m-1h timeframes
- Use Flink for complex indicators requiring advanced calculations (ATR, Bollinger Bands, custom patterns)
- Leverage SQL window functions for efficient moving averages and momentum indicators
- Pre-compute indicators in TimescaleDB for faster backtesting queries
{% endhint %}

{% hint style="warning" %}
**Resource Management**
- Set 1-second refresh policies for TimescaleDB continuous aggregates on trading timeframes
- Configure appropriate parallelism for Flink jobs based on symbol count and complexity
- Monitor TimescaleDB storage usage as continuous aggregates create additional tables
- Implement proper state management and checkpointing in Flink for complex indicators
{% endhint %}

{% hint style="info" %}
**Performance Optimization**
- Create indexes on symbol and time columns for faster continuous aggregate refreshes
- Use TimescaleDB compression for historical indicator data beyond active trading periods
- Implement proper watermarks and late data handling in Flink streams
- Consider using TimescaleDB real-time aggregates for frequently queried indicator combinations
{% endhint %}

### Decision Matrix: When to Use Each System

| Indicator Characteristic | TimescaleDB | Apache Flink |
|-------------------------|-------------|---------------|
| **Simple mathematical operations** | ✅ Preferred | ❌ Overkill |
| **SQL window functions sufficient** | ✅ Preferred | ❌ Unnecessary |
| **Requires standard deviation** | ❌ Limited | ✅ Preferred |
| **Multi-asset correlations** | ❌ Complex | ✅ Preferred |
| **Custom pattern recognition** | ❌ Not feasible | ✅ Preferred |
| **Historical backtesting queries** | ✅ Optimal | ❌ Inefficient |
| **Sub-second latency required** | ❌ Limited to 1s | ✅ Preferred |
| **Simple moving averages** | ✅ Preferred | ❌ Overkill |
| **RSI, MACD, Stochastic** | ✅ Preferred | ❌ Overkill |
| **ATR, Bollinger Bands** | ❌ Complex | ✅ Preferred |

### Example Implementation Workflow

1. **Start with TimescaleDB** for all basic indicators (SMA, EMA, RSI, MACD)
2. **Add Flink processing** only for indicators requiring:
   - Standard deviation calculations (Bollinger Bands)
   - Complex state management (ATR with proper True Range)
   - Multi-symbol analysis (correlations, relative strength)
   - Custom trading logic and pattern recognition
3. **Use CDC streaming** to combine both systems in the fusion layer
4. **Optimize based on actual performance** metrics and trading requirements

### Monitoring and Alerting

- **TimescaleDB Metrics**: Continuous aggregate refresh lag, query performance, storage usage
- **Flink Metrics**: Processing latency, checkpoint duration, state size, throughput
- **CDC Health**: Replication lag, connection status, data consistency checks
- **Indicator Accuracy**: Cross-validation between systems for overlapping calculations
- **Trading Performance**: Signal generation latency, indicator update frequency
