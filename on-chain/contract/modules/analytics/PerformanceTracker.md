# PerformanceTracker Contract Documentation

## Overview

The PerformanceTracker contract is a comprehensive analytics and metrics collection system designed for the StarkNet Service Marketplace. It provides data-driven insights for platform optimization by collecting and analyzing platform performance metrics, provider statistics, and market trends.

## Key Features

### 📊 **Comprehensive Metrics Collection**
- **Transaction Tracking**: Records all platform transactions with metadata
- **Platform Metrics**: Aggregates data across different time periods (hourly, daily, weekly, monthly)
- **Provider Analytics**: Provider-specific performance metrics
- **Market Trends**: Calculates rate of change and trend direction
- **Category & Location Analytics**: Geographic and categorical performance analysis

### 🔒 **Privacy-Preserving Analytics**
- **Minimum Aggregation Size**: Ensures privacy by requiring minimum participant counts
- **Data Retention Controls**: Configurable data retention periods
- **Anonymization Levels**: Multiple levels of data anonymization
- **Aggregated Data Access**: Only returns data when privacy thresholds are met

### ⚡ **Efficient Data Storage**
- **Optimized Storage**: Minimal gas overhead for data collection
- **Caching System**: Report caching for improved performance
- **Period-based Aggregation**: Efficient time-based data organization
- **Custom Metrics**: Extensible metric definition system

## Contract Architecture

### Storage Structure

```cairo
// Core tracking
@storage_var
func transactions(transaction_id: felt252) -> (
    transaction_type: felt252,
    user_address: ContractAddress,
    amount: Uint256,
    timestamp: felt252,
    metadata: felt252
) {}

// Platform metrics aggregation
@storage_var
func platform_metrics(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    total_value: Uint256,
    average_value: felt252,
    min_value: felt252,
    max_value: felt252,
    last_updated: felt252
) {}

// Provider-specific analytics
@storage_var
func provider_metrics(provider_address: ContractAddress, metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    total_value: Uint256,
    average_value: felt252,
    last_updated: felt252
) {}
```

### Metric Types

| Metric Type | Constant | Description |
|-------------|----------|-------------|
| Booking Count | `METRIC_TYPE_BOOKING_COUNT` | Number of service bookings |
| Payment Volume | `METRIC_TYPE_PAYMENT_VOLUME` | Total payment amounts |
| User Activity | `METRIC_TYPE_USER_ACTIVITY` | User engagement metrics |
| Service Views | `METRIC_TYPE_SERVICE_VIEWS` | Service listing views |
| Completion Rate | `METRIC_TYPE_COMPLETION_RATE` | Service completion percentage |
| Average Rating | `METRIC_TYPE_AVERAGE_RATING` | Provider rating averages |
| Response Time | `METRIC_TYPE_RESPONSE_TIME` | Provider response times |
| Revenue per Provider | `METRIC_TYPE_REVENUE_PER_PROVIDER` | Provider revenue metrics |
| Category Popularity | `METRIC_TYPE_CATEGORY_POPULARITY` | Service category trends |
| Location Activity | `METRIC_TYPE_LOCATION_ACTIVITY` | Geographic activity patterns |
| Dispute Rate | `METRIC_TYPE_DISPUTE_RATE` | Dispute frequency |
| Platform Fees | `METRIC_TYPE_PLATFORM_FEES` | Platform fee collection |

## Core Functions

### 1. `record_transaction()`
Records a new transaction with associated metrics.

```cairo
@external
func record_transaction(
    transaction_type: felt252,
    user_address: ContractAddress,
    amount: Uint256,
    metadata: felt252
) -> (transaction_id: felt252)
```

**Parameters:**
- `transaction_type`: Type of transaction (maps to metric type)
- `user_address`: Address of the user performing the transaction
- `amount`: Transaction amount/value
- `metadata`: Additional transaction metadata

**Returns:**
- `transaction_id`: Unique identifier for the recorded transaction

### 2. `get_platform_metrics()`
Retrieves aggregated platform metrics for a specific period.

```cairo
@external
func get_platform_metrics(
    metric_type: felt252,
    period_type: felt252,
    period_id: felt252
) -> (count: felt252, total_value: Uint256, average_value: felt252, min_value: felt252, max_value: felt252, last_updated: felt252)
```

**Parameters:**
- `metric_type`: Type of metric to retrieve
- `period_type`: Time period (hourly, daily, weekly, monthly)
- `period_id`: Specific period identifier

**Returns:**
- `count`: Number of transactions in the period
- `total_value`: Sum of all values
- `average_value`: Average value
- `min_value`: Minimum value
- `max_value`: Maximum value
- `last_updated`: Timestamp of last update

### 3. `get_provider_analytics()`
Retrieves provider-specific analytics.

```cairo
@external
func get_provider_analytics(
    provider_address: ContractAddress,
    metric_type: felt252,
    period_type: felt252,
    period_id: felt252
) -> (count: felt252, total_value: Uint256, average_value: felt252, last_updated: felt252)
```

### 4. `calculate_trends()`
Calculates trend analysis between two periods.

```cairo
@external
func calculate_trends(
    metric_type: felt252,
    period_type: felt252,
    current_period_id: felt252,
    previous_period_id: felt252
) -> (rate_of_change: felt252, acceleration: felt252, trend_direction: felt252)
```

**Returns:**
- `rate_of_change`: Percentage change between periods
- `acceleration`: Rate of acceleration
- `trend_direction`: 1 (increasing), 0 (stable), -1 (decreasing)

### 5. `generate_reports()`
Generates comprehensive analytics reports.

```cairo
@external
func generate_reports(
    report_type: felt252,
    period_type: felt252,
    period_id: felt252,
    include_providers: felt252,
    include_categories: felt252
) -> (report_hash: felt252)
```

## Privacy Features

### Aggregated Metrics Access
```cairo
@external
func get_aggregated_metrics(
    metric_type: felt252,
    period_type: felt252,
    period_id: felt252
) -> (aggregated_value: Uint256, participant_count: felt252)
```

Only returns data when minimum aggregation size is met, ensuring privacy.

### Privacy Settings
```cairo
@external
func set_privacy_settings(
    metric_type: felt252,
    min_aggregation_size: felt252,
    data_retention_period: felt252,
    anonymization_level: felt252
)
```

Configurable privacy controls for each metric type.

## Custom Metrics Support

### Creating Custom Metrics
```cairo
@external
func create_custom_metric(
    name: felt252,
    description: felt252,
    data_type: felt252,
    privacy_level: felt252,
    aggregation_method: felt252
) -> (metric_id: felt252)
```

### Recording Custom Metrics
```cairo
@external
func record_custom_metric(
    metric_id: felt252,
    value: Uint256,
    metadata: felt252
)
```

## Integration with Platform Modules

### Booking Contract Integration
```cairo
// Example: Recording booking transaction
let booking_transaction = performance_tracker.record_transaction(
    METRIC_TYPE_BOOKING_COUNT,
    user_address,
    booking_amount,
    booking_metadata
);
```

### Payment Contract Integration
```cairo
// Example: Recording payment transaction
let payment_transaction = performance_tracker.record_transaction(
    METRIC_TYPE_PAYMENT_VOLUME,
    user_address,
    payment_amount,
    payment_metadata
);
```

### Service Marketplace Integration
```cairo
// Example: Recording service view
let view_transaction = performance_tracker.record_transaction(
    METRIC_TYPE_SERVICE_VIEWS,
    user_address,
    Uint256(1, 0), // Single view
    service_id
);
```

## Events

### Transaction Events
```cairo
@event
func TransactionRecorded(
    transaction_id: felt252,
    transaction_type: felt252,
    user_address: ContractAddress,
    amount: Uint256,
    timestamp: felt252
) {}
```

### Analytics Events
```cairo
@event
func MetricUpdated(
    metric_type: felt252,
    period_type: felt252,
    period_id: felt252,
    value: Uint256,
    timestamp: felt252
) {}

@event
func TrendCalculated(
    metric_type: felt252,
    period_type: felt252,
    rate_of_change: felt252,
    timestamp: felt252
) {}
```

## Usage Examples

### 1. Recording Platform Activity
```cairo
// Record a booking
performance_tracker.record_transaction(
    METRIC_TYPE_BOOKING_COUNT,
    user_address,
    Uint256(1000, 0), // Booking value
    1 // Metadata: booking type
);

// Record a payment
performance_tracker.record_transaction(
    METRIC_TYPE_PAYMENT_VOLUME,
    user_address,
    Uint256(5000, 0), // Payment amount
    2 // Metadata: payment method
);
```

### 2. Retrieving Platform Metrics
```cairo
// Get daily booking metrics
let (count, total, avg, min, max, updated) = 
    performance_tracker.get_platform_metrics(
        METRIC_TYPE_BOOKING_COUNT,
        PERIOD_TYPE_DAILY,
        current_day
    );
```

### 3. Analyzing Trends
```cairo
// Calculate booking trend
let (rate_change, acceleration, direction) = 
    performance_tracker.calculate_trends(
        METRIC_TYPE_BOOKING_COUNT,
        PERIOD_TYPE_DAILY,
        current_period,
        previous_period
    );
```

### 4. Generating Reports
```cairo
// Generate monthly report
let report_hash = performance_tracker.generate_reports(
    1, // Report type: comprehensive
    PERIOD_TYPE_MONTHLY,
    current_month,
    1, // Include providers
    1  // Include categories
);
```

## Gas Optimization

### Efficient Storage
- **Period-based Aggregation**: Reduces storage costs by aggregating data by time periods
- **Minimal Metadata**: Stores only essential transaction data
- **Caching System**: Reduces repeated calculations

### Privacy Compliance
- **Minimum Aggregation**: Only stores data when privacy thresholds are met
- **Data Retention**: Configurable retention periods to manage storage costs
- **Anonymization**: Reduces storage overhead through data anonymization

## Security Considerations

### Access Control
- **Admin-only Functions**: Critical functions restricted to admin
- **Authorized Contracts**: Only authorized contracts can record transactions
- **Privacy Controls**: Configurable privacy settings per metric type

### Data Integrity
- **Immutable Records**: All transactions are permanently recorded
- **Timestamp Validation**: All data includes block timestamps
- **Event Emission**: All activities emit events for transparency

## Testing

The contract includes comprehensive test coverage:
- Transaction recording and retrieval
- Platform metrics aggregation
- Provider analytics
- Trend calculations
- Report generation
- Privacy-preserving features
- Custom metrics functionality
- Module integration testing

## Deployment

### Constructor
```cairo
@constructor
func constructor(admin_address: ContractAddress)
```

### Authorization
```cairo
@external
func authorize_contract(contract_address: ContractAddress)
```

Authorize other contracts to record transactions.

## Future Enhancements

1. **Advanced Analytics**: Machine learning-based trend predictions
2. **Real-time Metrics**: Sub-second metric updates
3. **Cross-chain Analytics**: Integration with other blockchain networks
4. **Custom Dashboards**: User-defined analytics views
5. **Predictive Analytics**: Forecasting based on historical data

## Conclusion

The PerformanceTracker contract provides a robust foundation for platform analytics while maintaining user privacy and optimizing gas costs. Its modular design allows for easy integration with other platform components and supports extensible custom metrics for future growth. 