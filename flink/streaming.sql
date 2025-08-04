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
)

-- Create a Kafka sink table connected to our JDBC candles table
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

-- Create streaming source table from Kafka with watermarks
CREATE TABLE candles_kafka_source (
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

-- Continuous job to stream data from PostgreSQL to Kafka
INSERT INTO candles_kafka_sink
SELECT * FROM candles;


-- Now you can use PREV() on the streaming Kafka source!
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
        B AS B.`close` > PREV(B.`close`),  -- PREV() works here!
        C AS C.`close` > PREV(C.`close`)   -- PREV() works here!
) AS bullish_trend;
