## Overview

This document outlines three different approaches for implementing buy-sell order pairing in Apache Flink streaming applications. The use case involves tracking buy orders for different trading strategies and waiting for corresponding sell orders to complete trading cycles.

## Architecture Context

- **Input**: Kafka stream containing buy and sell orders for different strategies
- **Goal**: Pair buy orders with subsequent sell orders per strategy
- **Output**: Completed trade cycles for further processing
- **State Management**: Each strategy maintains its own order state

## Approach 1: Keyed State with ValueState

### Description
Uses Flink's ValueState to maintain pending buy orders per strategy key. Simple and efficient for 1:1 buy-sell pairing scenarios.

### Implementation

```java
public class BuySellPairingFunction extends KeyedProcessFunction<String, Order, CompletedTrade> {
  
  private ValueState<Order> pendingBuyState;
  private ValueState<Boolean> hasPendingBuy;
  
  @Override
  public void open(Configuration config) {
    pendingBuyState = getRuntimeContext().getState(
      new ValueStateDescriptor<>(\"pending-buy\", Order.class)
    );
    hasPendingBuy = getRuntimeContext().getState(
      new ValueStateDescriptor<>(\"has-pending\", Boolean.class)
    );
  }
  
  @Override
  public void processElement(Order order, Context ctx, Collector<CompletedTrade> out) throws Exception {
    String strategy = order.getStrategy();
    
    if (order.getSide().equals(\"BUY\")) {
      // Store the buy order and wait for sell
      pendingBuyState.update(order);
      hasPendingBuy.update(true);
      
      // Optional: Set timer to expire old buy orders
      ctx.timerService().registerProcessingTimeTimer(
        ctx.timerService().currentProcessingTime() + Duration.ofMinutes(30).toMillis()
      );
      
    } else if (order.getSide().equals(\"SELL\")) {
      // Check if we have a pending buy
      Order pendingBuy = pendingBuyState.value();
      Boolean hasBuy = hasPendingBuy.value();
      
      if (hasBuy != null && hasBuy && pendingBuy != null) {
        // Complete the trade cycle
        CompletedTrade trade = new CompletedTrade(pendingBuy, order, strategy);
        out.collect(trade);
        
        // Clear state
        pendingBuyState.clear();
        hasPendingBuy.clear();
      } else {
        // Sell without buy - could log as warning or store for later
        System.out.println(\"Sell order without pending buy for strategy: \" + strategy);
      }
    }
  }
  
  @Override
  public void onTimer(long timestamp, OnTimerContext ctx, Collector<CompletedTrade> out) {
    // Expire old buy orders
    pendingBuyState.clear();
    hasPendingBuy.clear();
  }
}
```

### Pros
- Simple and lightweight
- Low memory overhead
- Built-in timer support for order expiration
- Easy to understand and maintain
- Efficient for high-throughput scenarios

### Cons
- Only handles 1:1 buy-sell pairing
- Cannot handle complex order patterns
- Limited to simple state management
- No built-in pattern matching capabilities

### Best Use Cases
- Simple trading strategies with clear buy→sell cycles
- High-frequency trading where performance is critical
- Scenarios with predictable order patterns
- When order expiration is important

## Approach 2: Complex Event Processing (CEP)

### Description
Uses Flink's CEP library to define and match complex event patterns. Provides declarative pattern matching with built-in timeout handling.

### Implementation

```java
// Define the pattern: Buy followed by Sell
Pattern<Order, ?> buySellPattern = Pattern.<Order>begin(\"buy\")
  .where(SimpleCondition.of(order -> order.getSide().equals(\"BUY\")))
  .followedBy(\"sell\")
  .where(SimpleCondition.of(order -> order.getSide().equals(\"SELL\")))
  .within(Time.minutes(30)); // Complete within 30 minutes

// Apply pattern to keyed stream
DataStream<CompletedTrade> completedTrades = CEP
  .pattern(orderStream.keyBy(Order::getStrategy), buySellPattern)
  .select(new BuySellPatternSelectFunction());
```

```java
public class BuySellPatternSelectFunction implements PatternSelectFunction<Order, CompletedTrade> {
  @Override
  public CompletedTrade select(Map<String, List<Order>> pattern) {
    Order buyOrder = pattern.get(\"buy\").get(0);
    Order sellOrder = pattern.get(\"sell\").get(0);
    
    return new CompletedTrade(buyOrder, sellOrder, buyOrder.getStrategy());
  }
}
```

### Advanced CEP Patterns

```java
// More complex patterns
Pattern<Order, ?> complexPattern = Pattern.<Order>begin(\"buy\")
  .where(SimpleCondition.of(order -> order.getSide().equals(\"BUY\")))
  .followedBy(\"optionalSecondBuy\")
  .where(SimpleCondition.of(order -> order.getSide().equals(\"BUY\")))
  .optional() // Second buy is optional
  .followedBy(\"sell\")
  .where(SimpleCondition.of(order -> order.getSide().equals(\"SELL\")))
  .within(Time.minutes(45));

// Pattern with conditions
Pattern<Order, ?> conditionalPattern = Pattern.<Order>begin(\"largeBuy\")
  .where(SimpleCondition.of(order -> 
    order.getSide().equals(\"BUY\") && order.getQuantity().compareTo(BigDecimal.valueOf(10)) > 0))
  .followedBy(\"anySell\")
  .where(SimpleCondition.of(order -> order.getSide().equals(\"SELL\")))
  .within(Time.minutes(60));
```

### Pros
- Declarative pattern definition
- Built-in timeout handling
- Supports complex event sequences
- Rich pattern matching capabilities
- Good for detecting missing patterns
- Handles multiple event combinations

### Cons
- Higher memory overhead
- More complex for simple use cases
- Additional dependency (Flink CEP)
- Learning curve for pattern syntax
- Can be overkill for basic scenarios

### Best Use Cases
- Complex trading strategies with multiple order types
- Need to detect incomplete patterns
- Requirements for sophisticated timeout logic
- Multi-step trading workflows
- Pattern analysis and compliance monitoring

## Approach 3: Process Function with Multiple States

### Description
Uses multiple state descriptors to handle complex order management scenarios. Provides maximum flexibility for custom business logic.

### Implementation

```java
public class StrategyOrderManager extends KeyedProcessFunction<String, Order, TradeEvent> {
  
  // Multiple states for different order tracking
  private ValueState<Order> activeBuyOrder;
  private ListState<Order> pendingSellOrders;
  private ValueState<Long> buyTimestamp;
  private MapState<String, Order> orderHistory;
  
  @Override
  public void open(Configuration config) {
    activeBuyOrder = getRuntimeContext().getState(
      new ValueStateDescriptor<>(\"active-buy\", Order.class)
    );
    pendingSellOrders = getRuntimeContext().getListState(
      new ListStateDescriptor<>(\"pending-sells\", Order.class)
    );
    buyTimestamp = getRuntimeContext().getState(
      new ValueStateDescriptor<>(\"buy-timestamp\", Long.class)
    );
    orderHistory = getRuntimeContext().getMapState(
      new MapStateDescriptor<>(\"order-history\", String.class, Order.class)
    );
  }
  
  @Override
  public void processElement(Order order, Context ctx, Collector<TradeEvent> out) throws Exception {
    
    // Store in history for audit trail
    orderHistory.put(order.getOrderId(), order);
    
    if (order.getSide().equals(\"BUY\")) {
      handleBuyOrder(order, ctx, out);
    } else if (order.getSide().equals(\"SELL\")) {
      handleSellOrder(order, ctx, out);
    }
  }
  
  private void handleBuyOrder(Order order, Context ctx, Collector<TradeEvent> out) throws Exception {
    // Check if we already have an active buy
    Order existingBuy = activeBuyOrder.value();
    if (existingBuy != null) {
      // Strategy logic: replace old buy or reject new one
      out.collect(new TradeEvent(\"BUY_REPLACED\", existingBuy, order));
    }
    
    activeBuyOrder.update(order);
    buyTimestamp.update(ctx.timestamp());
    
    // Check if we have pending sells
    Iterable<Order> sells = pendingSellOrders.get();
    for (Order sell : sells) {
      // Process pending sells against new buy
      out.collect(new TradeEvent(\"TRADE_COMPLETED\", order, sell));
      pendingSellOrders.clear();
      activeBuyOrder.clear();
      buyTimestamp.clear();
      break; // Only match first sell
    }
  }
  
  private void handleSellOrder(Order order, Context ctx, Collector<TradeEvent> out) throws Exception {
    Order activeBuy = activeBuyOrder.value();
    
    if (activeBuy != null) {
      // Complete the trade
      out.collect(new TradeEvent(\"TRADE_COMPLETED\", activeBuy, order));
      activeBuyOrder.clear();
      buyTimestamp.clear();
    } else {
      // No active buy - store sell for later
      pendingSellOrders.add(order);
      
      // Set timer to clean up old pending sells
      ctx.timerService().registerProcessingTimeTimer(
        ctx.timerService().currentProcessingTime() + Duration.ofMinutes(15).toMillis()
      );
    }
  }
  
  @Override
  public void onTimer(long timestamp, OnTimerContext ctx, Collector<TradeEvent> out) throws Exception {
    // Clean up expired orders
    Order activeBuy = activeBuyOrder.value();
    Long buyTime = buyTimestamp.value();
    
    // Expire old buy orders
    if (activeBuy != null && buyTime != null && 
        (timestamp - buyTime) > Duration.ofMinutes(30).toMillis()) {
      out.collect(new TradeEvent(\"BUY_EXPIRED\", activeBuy, null));
      activeBuyOrder.clear();
      buyTimestamp.clear();
    }
    
    // Clean up old pending sells
    pendingSellOrders.clear();
  }
}
```

### Advanced State Management

```java
// Risk management integration
private ValueState<BigDecimal> positionSize;
private ValueState<BigDecimal> maxRiskLimit;

private boolean isWithinRiskLimits(Order order) throws Exception {
  BigDecimal currentPosition = positionSize.value();
  BigDecimal riskLimit = maxRiskLimit.value();
  
  if (currentPosition != null && riskLimit != null) {
    BigDecimal newPosition = currentPosition.add(order.getQuantity());
    return newPosition.compareTo(riskLimit) <= 0;
  }
  return true;
}
```

### Pros
- Maximum flexibility
- Custom business logic implementation
- Multiple state types support
- Rich audit trail capabilities
- Complex order management
- Integration with risk management

### Cons
- Most complex implementation
- Higher memory usage
- Requires careful state management
- More prone to bugs
- Harder to test and maintain

### Best Use Cases
- Complex trading strategies with custom logic
- Need for detailed audit trails
- Integration with risk management systems
- Handling partial fills and order modifications
- Requirements for custom timeout logic

## Data Models

### Order Model
```java
public class Order {
  private String orderId;
  private String strategy;
  private String side; // \"BUY\" or \"SELL\"
  private String symbol;
  private BigDecimal quantity;
  private BigDecimal price;
  private long timestamp;
  private OrderType type; // MARKET, LIMIT, STOP
  
  // Constructors, getters, setters
}
```

### CompletedTrade Model
```java
public class CompletedTrade {
  private Order buyOrder;
  private Order sellOrder;
  private String strategy;
  private long completionTime;
  private BigDecimal profit;
  private Duration holdingPeriod;
  
  public CompletedTrade(Order buyOrder, Order sellOrder, String strategy) {
    this.buyOrder = buyOrder;
    this.sellOrder = sellOrder;
    this.strategy = strategy;
    this.completionTime = System.currentTimeMillis();
    this.profit = calculateProfit();
    this.holdingPeriod = Duration.ofMillis(completionTime - buy`
}