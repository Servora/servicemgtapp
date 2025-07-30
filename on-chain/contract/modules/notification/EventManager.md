# EventManager Contract Documentation

## Overview

The EventManager contract is a comprehensive event emission and notification system designed for the StarkNet Service Marketplace. It manages real-time updates and integration with off-chain notification services by providing structured event data that is easily parseable by external systems.

## Key Features

### 📡 **Comprehensive Event Emission**
- **Platform-wide Coverage**: Events for all major platform activities
- **Structured Data**: Consistent event format with metadata
- **Real-time Updates**: Immediate event emission for instant notifications
- **Priority System**: Event prioritization for critical notifications

### 🔔 **Subscription Management**
- **Selective Monitoring**: Subscribe to specific event types
- **Multiple Subscription Types**: Booking, payment, review, service, provider events
- **Active/Inactive Control**: Enable/disable subscriptions as needed
- **Event Filtering**: Advanced filtering based on event types and priorities

### ⚡ **Gas Optimization**
- **Event Batching**: Group multiple events for efficient processing
- **Batch Processing**: Process events in batches to reduce gas costs
- **Priority-based Batching**: High-priority events processed first
- **Efficient Storage**: Optimized data structures for minimal gas usage

### 🎯 **Custom Event Support**
- **Custom Event Types**: Create platform-specific event types
- **Flexible Metadata**: Extensible metadata system for custom data
- **Event Schemas**: Define data structures for custom events
- **Priority Configuration**: Set default priorities for custom events

## Contract Architecture

### Event Types

| Event Type | Constant | Description |
|------------|----------|-------------|
| Booking Created | `EVENT_TYPE_BOOKING_CREATED` | New booking created |
| Booking Confirmed | `EVENT_TYPE_BOOKING_CONFIRMED` | Booking confirmed by provider |
| Booking Completed | `EVENT_TYPE_BOOKING_COMPLETED` | Service completed |
| Booking Cancelled | `EVENT_TYPE_BOOKING_CANCELLED` | Booking cancelled |
| Booking Disputed | `EVENT_TYPE_BOOKING_DISPUTED` | Dispute raised |
| Payment Initiated | `EVENT_TYPE_PAYMENT_INITIATED` | Payment started |
| Payment Completed | `EVENT_TYPE_PAYMENT_COMPLETED` | Payment successful |
| Payment Refunded | `EVENT_TYPE_PAYMENT_REFUNDED` | Payment refunded |
| Review Submitted | `EVENT_TYPE_REVIEW_SUBMITTED` | New review posted |
| Review Updated | `EVENT_TYPE_REVIEW_UPDATED` | Review modified |
| Service Created | `EVENT_TYPE_SERVICE_CREATED` | New service listed |
| Service Updated | `EVENT_TYPE_SERVICE_UPDATED` | Service details modified |
| Service Deleted | `EVENT_TYPE_SERVICE_DELETED` | Service removed |
| Provider Registered | `EVENT_TYPE_PROVIDER_REGISTERED` | New provider joined |
| Provider Verified | `EVENT_TYPE_PROVIDER_VERIFIED` | Provider verification completed |
| User Registered | `EVENT_TYPE_USER_REGISTERED` | New user registered |
| Dispute Created | `EVENT_TYPE_DISPUTE_CREATED` | Dispute initiated |
| Dispute Resolved | `EVENT_TYPE_DISPUTE_RESOLVED` | Dispute resolved |
| Escrow Released | `EVENT_TYPE_ESCROW_RELEASED` | Escrow funds released |
| Escrow Refunded | `EVENT_TYPE_ESCROW_REFUNDED` | Escrow funds refunded |

### Priority Levels

| Priority | Constant | Description |
|----------|----------|-------------|
| Low | `PRIORITY_LOW` | Non-critical events |
| Medium | `PRIORITY_MEDIUM` | Standard events |
| High | `PRIORITY_HIGH` | Important events |
| Critical | `PRIORITY_CRITICAL` | Urgent notifications |

## Core Functions

### 1. `emit_booking_event()`
Emits events for booking-related activities.

```cairo
@external
func emit_booking_event(
    booking_id: felt252,
    user_address: ContractAddress,
    provider_address: ContractAddress,
    service_id: felt252,
    amount: Uint256,
    event_subtype: felt252, // 1=created, 2=confirmed, 3=completed, 4=cancelled, 5=disputed
    metadata: felt252
) -> (event_id: felt252)
```

**Parameters:**
- `booking_id`: Unique booking identifier
- `user_address`: Address of the user making the booking
- `provider_address`: Address of the service provider
- `service_id`: ID of the service being booked
- `amount`: Booking amount
- `event_subtype`: Type of booking event (1-5)
- `metadata`: Additional event metadata

**Returns:**
- `event_id`: Unique identifier for the emitted event

### 2. `emit_payment_event()`
Emits events for payment-related activities.

```cairo
@external
func emit_payment_event(
    payment_id: felt252,
    user_address: ContractAddress,
    provider_address: ContractAddress,
    amount: Uint256,
    token_address: ContractAddress,
    event_subtype: felt252, // 1=initiated, 2=completed, 3=refunded
    metadata: felt252
) -> (event_id: felt252)
```

### 3. `emit_review_event()`
Emits events for review-related activities.

```cairo
@external
func emit_review_event(
    review_id: felt252,
    user_address: ContractAddress,
    provider_address: ContractAddress,
    service_id: felt252,
    rating: felt252,
    event_subtype: felt252, // 1=submitted, 2=updated
    metadata: felt252
) -> (event_id: felt252)
```

### 4. `subscribe_to_events()`
Creates a subscription for specific event types.

```cairo
@external
func subscribe_to_events(
    subscription_type: felt252,
    event_types: Array<felt252>
) -> (subscription_id: felt252)
```

**Parameters:**
- `subscription_type`: Type of subscription (1-7)
- `event_types`: Array of event types to subscribe to

**Returns:**
- `subscription_id`: Unique identifier for the subscription

### 5. `get_event_history()`
Retrieves event history with filtering.

```cairo
@external
func get_event_history(
    start_event_id: felt252,
    end_event_id: felt252,
    event_types: Array<felt252>
) -> (event_count: felt252, events_data: Array<felt252>)
```

## Event Batching for Gas Optimization

### Batch Creation
```cairo
@external
func create_event_batch() -> (batch_id: felt252)
```

### Adding Events to Batch
```cairo
@external
func add_event_to_batch(
    batch_id: felt252,
    event_id: felt252
)
```

### Processing Batches
```cairo
@external
func process_event_batch(batch_id: felt252)
```

## Custom Event Types

### Creating Custom Event Types
```cairo
@external
func create_custom_event_type(
    name: felt252,
    description: felt252,
    data_schema: felt252,
    priority_default: felt252
) -> (event_type_id: felt252)
```

### Emitting Custom Events
```cairo
@external
func emit_custom_event(
    custom_event_type_id: felt252,
    user_address: ContractAddress,
    data_hash: felt252,
    priority: felt252,
    metadata: felt252
) -> (event_id: felt252)
```

## Subscription Types

| Subscription Type | Constant | Description |
|------------------|----------|-------------|
| All Events | `SUBSCRIPTION_TYPE_ALL` | Subscribe to all events |
| Booking Events | `SUBSCRIPTION_TYPE_BOOKING` | Booking-related events only |
| Payment Events | `SUBSCRIPTION_TYPE_PAYMENT` | Payment-related events only |
| Review Events | `SUBSCRIPTION_TYPE_REVIEW` | Review-related events only |
| Service Events | `SUBSCRIPTION_TYPE_SERVICE` | Service-related events only |
| Provider Events | `SUBSCRIPTION_TYPE_PROVIDER` | Provider-related events only |
| Custom Events | `SUBSCRIPTION_TYPE_CUSTOM` | Custom event types only |

## Event Metadata Management

### Setting Event Metadata
```cairo
@external
func set_event_metadata(
    event_id: felt252,
    key: felt252,
    value: felt252
)
```

### Retrieving Event Metadata
```cairo
@external
func get_event_metadata(
    event_id: felt252,
    key: felt252
) -> (value: felt252)
```

## Integration with Platform Modules

### Booking Contract Integration
```cairo
// Example: Emit booking event when booking is created
let booking_event = event_manager.emit_booking_event(
    booking_id,
    user_address,
    provider_address,
    service_id,
    booking_amount,
    1, // event_subtype: created
    booking_metadata
);
```

### Payment Contract Integration
```cairo
// Example: Emit payment event when payment is completed
let payment_event = event_manager.emit_payment_event(
    789, // payment_id
    user_address,
    provider_address,
    Uint256(5000, 0), // amount
    token_address,
    2, // event_subtype: completed
    2 // metadata
);
```

### Review Contract Integration
```cairo
// Example: Emit review event when review is submitted
let review_event = event_manager.emit_review_event(
    review_id,
    user_address,
    provider_address,
    service_id,
    rating,
    1, // event_subtype: submitted
    review_metadata
);
```

## Events

### Core Event Events
```cairo
@event
func EventEmitted(
    event_id: felt252,
    event_type: felt252,
    source_contract: ContractAddress,
    user_address: ContractAddress,
    timestamp: felt252
) {}
```

### Subscription Events
```cairo
@event
func SubscriptionCreated(
    subscription_id: felt252,
    subscriber_address: ContractAddress,
    subscription_type: felt252,
    timestamp: felt252
) {}

@event
func SubscriptionUpdated(
    subscription_id: felt252,
    subscriber_address: ContractAddress,
    active: felt252,
    timestamp: felt252
) {}
```

### Batch Processing Events
```cairo
@event
func EventBatchProcessed(
    batch_id: felt252,
    event_count: felt252,
    timestamp: felt252
) {}
```

## Usage Examples

### 1. Emitting Platform Events
```cairo
// Emit booking created event
let booking_event = event_manager.emit_booking_event(
    123, // booking_id
    user_address,
    provider_address,
    456, // service_id
    Uint256(1000, 0), // amount
    1, // event_subtype: created
    1 // metadata
);

// Emit payment completed event
let payment_event = event_manager.emit_payment_event(
    789, // payment_id
    user_address,
    provider_address,
    Uint256(5000, 0), // amount
    token_address,
    2, // event_subtype: completed
    2 // metadata
);
```

### 2. Creating Subscriptions
```cairo
// Subscribe to booking events
let event_types = array![
    EVENT_TYPE_BOOKING_CREATED,
    EVENT_TYPE_BOOKING_CONFIRMED,
    EVENT_TYPE_BOOKING_COMPLETED
];

let subscription_id = event_manager.subscribe_to_events(
    SUBSCRIPTION_TYPE_BOOKING,
    event_types
);
```

### 3. Event Batching
```cairo
// Create event batch
let batch_id = event_manager.create_event_batch();

// Add events to batch
event_manager.add_event_to_batch(batch_id, event_id_1);
event_manager.add_event_to_batch(batch_id, event_id_2);
event_manager.add_event_to_batch(batch_id, event_id_3);

// Process batch
event_manager.process_event_batch(batch_id);
```

### 4. Custom Events
```cairo
// Create custom event type
let custom_event_type_id = event_manager.create_custom_event_type(
    12345, // name
    67890, // description
    11111, // data_schema
    PRIORITY_MEDIUM // priority_default
);

// Emit custom event
let custom_event = event_manager.emit_custom_event(
    custom_event_type_id,
    user_address,
    99999, // data_hash
    PRIORITY_HIGH, // priority
    55555 // metadata
);
```

## Gas Optimization Strategies

### Event Batching
- **Batch Creation**: Group multiple events into a single batch
- **Priority Processing**: Process high-priority events first
- **Batch Size Limits**: Control batch size for optimal gas usage
- **Processing Efficiency**: Process batches in single transactions

### Storage Optimization
- **Minimal Metadata**: Store only essential event data
- **Efficient Indexing**: Optimized storage for quick retrieval
- **Data Compression**: Compress event data where possible
- **Cleanup Mechanisms**: Remove old events to save storage

## Security Considerations

### Access Control
- **Authorized Contracts**: Only authorized contracts can emit events
- **Admin Controls**: Critical functions restricted to admin
- **Subscription Security**: Only subscribers can manage their subscriptions

### Data Integrity
- **Immutable Events**: All events are permanently recorded
- **Timestamp Validation**: All events include block timestamps
- **Event Verification**: Events can be verified against source contracts

## Off-chain Integration

### Event Parsing
Events are structured for easy parsing by off-chain services:
- **Consistent Format**: Standardized event structure
- **Metadata Support**: Extensible metadata system
- **Priority Information**: Priority levels for notification systems
- **Source Tracking**: Track which contract emitted each event

### Notification Services
The contract supports integration with:
- **Email Services**: Priority-based email notifications
- **Push Notifications**: Real-time mobile notifications
- **Webhook Systems**: HTTP callbacks for events
- **Analytics Platforms**: Event data for analytics

## Testing

The contract includes comprehensive test coverage:
- Event emission for all event types
- Subscription creation and management
- Event batching and processing
- Custom event type creation
- Event history and filtering
- Event metadata management
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

Authorize other contracts to emit events.

## Future Enhancements

1. **Advanced Filtering**: Complex event filtering rules
2. **Event Encryption**: Encrypted events for sensitive data
3. **Event Replay**: Event replay capabilities for debugging
4. **Cross-chain Events**: Events for cross-chain operations
5. **Event Analytics**: Built-in event analytics and reporting

## Conclusion

The EventManager contract provides a robust foundation for real-time event emission and notification systems. Its comprehensive event coverage, efficient gas optimization, and flexible subscription system make it ideal for integrating with off-chain notification services while maintaining platform performance and security. 