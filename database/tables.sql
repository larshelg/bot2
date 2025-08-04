-- Create the base table
CREATE TABLE candles (
    time TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    open NUMERIC(20, 8) NOT NULL,
    high NUMERIC(20, 8) NOT NULL,
    low NUMERIC(20, 8) NOT NULL,
    close NUMERIC(20, 8) NOT NULL,
    volume NUMERIC(20, 8) NOT NULL,
    PRIMARY KEY (time, symbol)
);

-- Create the hypertable with only time as the partitioning dimension
SELECT create_hypertable('candles', 'time');

-- Create an index on the time and symbol columns
CREATE INDEX ON candles (time DESC, symbol);

-- Create an index on just the symbol for queries that filter by symbol
CREATE INDEX ON candles (symbol, time DESC);

-- 15-minute aggregate
CREATE MATERIALIZED VIEW fifteen_minute_candles
WITH (timescaledb.continuous) AS
SELECT time_bucket('15 minutes', time) AS bucket,
    symbol,
    first(open, time) AS open,
    max(high) AS high,
    min(low) AS low,
    last(close, time) AS close,
    sum(volume) AS volume
FROM candles
GROUP BY bucket, symbol;

-- 1-hour aggregate
CREATE MATERIALIZED VIEW one_hour_candles
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
    symbol,
    first(open, time) AS open,
    max(high) AS high,
    min(low) AS low,
    last(close, time) AS close,
    sum(volume) AS volume
FROM candles
GROUP BY bucket, symbol;

-- 4-hour aggregate
CREATE MATERIALIZED VIEW four_hour_candles
WITH (timescaledb.continuous) AS
SELECT time_bucket('4 hours', time) AS bucket,
    symbol,
    first(open, time) AS open,
    max(high) AS high,
    min(low) AS low,
    last(close, time) AS close,
    sum(volume) AS volume
FROM candles
GROUP BY bucket, symbol;

-- 1-day aggregate
CREATE MATERIALIZED VIEW one_day_candles
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', time) AS bucket,
    symbol,
    first(open, time) AS open,
    max(high) AS high,
    min(low) AS low,
    last(close, time) AS close,
    sum(volume) AS volume
FROM candles
GROUP BY bucket, symbol;

-- Refresh policy for 15-minute aggregate
SELECT add_continuous_aggregate_policy('fifteen_minute_candles',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '15 minutes');

-- Refresh policy for 1-hour aggregate
SELECT add_continuous_aggregate_policy('one_hour_candles',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- Refresh policy for 4-hour aggregate
SELECT add_continuous_aggregate_policy('four_hour_candles',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '4 hours',
    schedule_interval => INTERVAL '4 hours');

-- Refresh policy for 1-day aggregate
SELECT add_continuous_aggregate_policy('one_day_candles',
    start_offset => INTERVAL '90 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');

    CALL refresh_continuous_aggregate('candles5m', NULL, NULL);



    CREATE OR REPLACE VIEW ohlc_indicators_1m AS
WITH price_changes AS (
    SELECT 
        symbol,
        time_bucket('1 minute', time) AS bucket,
        first(open, time) AS open,
        max(high) AS high,
        min(low) AS low,
        last(close, time) AS close,
        sum(volume) AS volume,
        last(close, time) - LAG(last(close, time)) OVER (PARTITION BY symbol ORDER BY time_bucket('1 minute', time)) AS price_change
    FROM candles
    WHERE time > NOW() - INTERVAL '365 day'
    GROUP BY symbol, time_bucket('1 minute', time)
)
SELECT 
    symbol, 
    bucket,
    open,
    high,
    low,
    close,
    volume,
    price_change,
    -- Simple Moving Averages
    AVG(close) OVER(
        PARTITION BY symbol 
        ORDER BY bucket 
        ROWS BETWEEN 20 PRECEDING AND CURRENT ROW
    ) AS sma21,
    AVG(close) OVER(
        PARTITION BY symbol 
        ORDER BY bucket 
        ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
    ) AS sma10,
    -- RSI 14-period calculation
    100 - (100 / (1 + 
        AVG(CASE WHEN price_change > 0 THEN price_change ELSE 0 END) OVER (
            PARTITION BY symbol 
            ORDER BY bucket 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) / NULLIF(
            AVG(CASE WHEN price_change < 0 THEN ABS(price_change) ELSE 0 END) OVER (
                PARTITION BY symbol 
                ORDER BY bucket 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ), 0
        )
    )) AS rsi_14
FROM price_changes
ORDER BY symbol, bucket DESC;


CREATE OR REPLACE VIEW ohlc_indicators_5m AS
WITH price_changes AS (
    SELECT 
        symbol,
        bucket,
        open,
        high,
        low,
        close,
        volume,
        close - LAG(close) OVER (PARTITION BY symbol ORDER BY bucket) AS price_change
    FROM candles5m
    WHERE bucket > NOW() - INTERVAL '365 day'
)
SELECT 
    symbol, 
    bucket,
    open,
    high,
    low,
    close,
    volume,
    price_change,
    -- Simple Moving Averages
    AVG(close) OVER(
        PARTITION BY symbol 
        ORDER BY bucket 
        ROWS BETWEEN 20 PRECEDING AND CURRENT ROW
    ) AS sma21,
    AVG(close) OVER(
        PARTITION BY symbol 
        ORDER BY bucket 
        ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
    ) AS sma10,
    -- RSI 14-period calculation
    100 - (100 / (1 + 
        AVG(CASE WHEN price_change > 0 THEN price_change ELSE 0 END) OVER (
            PARTITION BY symbol 
            ORDER BY bucket 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) / NULLIF(
            AVG(CASE WHEN price_change < 0 THEN ABS(price_change) ELSE 0 END) OVER (
                PARTITION BY symbol 
                ORDER BY bucket 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ), 0
        )
    )) AS rsi_14
FROM price_changes
ORDER BY symbol, bucket DESC;
🎯 What this creates:
Base data: OHLCV from your 5-minute candles
SMA10: 10-period simple moving average
SMA21: 21-period simple moving average
RSI_14: 14-period Relative Strength Index
Price changes: Included for RSI calculation and potential future indicators
This follows our documentation perfectly - all "simple indicators" calculated efficiently in TimescaleDB using SQL window functions!

Ready to run this and test it?




great it worked, lets create the same based on candles which has 1m candles

Edit
Perfect! Here's the SQL for the 1-minute version using your candles table:

sql
CREATE OR REPLACE VIEW ohlc_indicators_1m AS
WITH price_changes AS (
    SELECT 
        symbol,
        time_bucket('1 minute', time) AS bucket,
        first(open, time) AS open,
        max(high) AS high,
        min(low) AS low,
        last(close, time) AS close,
        sum(volume) AS volume,
        last(close, time) - LAG(last(close, time)) OVER (PARTITION BY symbol ORDER BY time_bucket('1 minute', time)) AS price_change
    FROM candles
    WHERE time > NOW() - INTERVAL '365 day'
    GROUP BY symbol, time_bucket('1 minute', time)
)
SELECT 
    symbol, 
    bucket,
    open,
    high,
    low,
    close,
    volume,
    price_change,
    -- Simple Moving Averages
    AVG(close) OVER(
        PARTITION BY symbol 
        ORDER BY bucket 
        ROWS BETWEEN 20 PRECEDING AND CURRENT ROW
    ) AS sma21,
    AVG(close) OVER(
        PARTITION BY symbol 
        ORDER BY bucket 
        ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
    ) AS sma10,
    -- RSI 14-period calculation
    100 - (100 / (1 + 
        AVG(CASE WHEN price_change > 0 THEN price_change ELSE 0 END) OVER (
            PARTITION BY symbol 
            ORDER BY bucket 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) / NULLIF(
            AVG(CASE WHEN price_change < 0 THEN ABS(price_change) ELSE 0 END) OVER (
                PARTITION BY symbol 
                ORDER BY bucket 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ), 0
        )
    )) AS rsi_14
FROM price_changes
ORDER BY symbol, bucket DESC;
🔍 Key Differences from 5m version:
Source: Uses candles table instead of candles5m view
Bucketing: Creates 1-minute buckets with time_bucket('1 minute', time)
Aggregation: Groups raw tick data into 1-minute OHLCV first, then calculates indicators
Same indicators: SMA10, SMA21, RSI_14 - consistent across timeframes
This gives you the same indicator set at both 1m and 5m timeframes, perfect for multi-timeframe analysis in your 1m-1h trading strategy! 🚀




