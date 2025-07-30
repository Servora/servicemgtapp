// SPDX-License-Identifier: MIT
// Cairo 1.0 Event Manager Contract for Service Marketplace
// Manages event emission and notification systems for all platform activities

%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::math::uint256 import Uint256
from starkware::starknet::array::ArrayTrait
from starkware::starknet::context import get_tx_info

// ============================================================================
// CONSTANTS
// ============================================================================

// Event types for different platform activities
const EVENT_TYPE_BOOKING_CREATED = 1
const EVENT_TYPE_BOOKING_CONFIRMED = 2
const EVENT_TYPE_BOOKING_COMPLETED = 3
const EVENT_TYPE_BOOKING_CANCELLED = 4
const EVENT_TYPE_BOOKING_DISPUTED = 5
const EVENT_TYPE_PAYMENT_INITIATED = 6
const EVENT_TYPE_PAYMENT_COMPLETED = 7
const EVENT_TYPE_PAYMENT_REFUNDED = 8
const EVENT_TYPE_REVIEW_SUBMITTED = 9
const EVENT_TYPE_REVIEW_UPDATED = 10
const EVENT_TYPE_SERVICE_CREATED = 11
const EVENT_TYPE_SERVICE_UPDATED = 12
const EVENT_TYPE_SERVICE_DELETED = 13
const EVENT_TYPE_PROVIDER_REGISTERED = 14
const EVENT_TYPE_PROVIDER_VERIFIED = 15
const EVENT_TYPE_USER_REGISTERED = 16
const EVENT_TYPE_DISPUTE_CREATED = 17
const EVENT_TYPE_DISPUTE_RESOLVED = 18
const EVENT_TYPE_ESCROW_RELEASED = 19
const EVENT_TYPE_ESCROW_REFUNDED = 20
const EVENT_TYPE_CUSTOM_EVENT = 100

// Event priority levels
const PRIORITY_LOW = 1
const PRIORITY_MEDIUM = 2
const PRIORITY_HIGH = 3
const PRIORITY_CRITICAL = 4

// Subscription types
const SUBSCRIPTION_TYPE_ALL = 1
const SUBSCRIPTION_TYPE_BOOKING = 2
const SUBSCRIPTION_TYPE_PAYMENT = 3
const SUBSCRIPTION_TYPE_REVIEW = 4
const SUBSCRIPTION_TYPE_SERVICE = 5
const SUBSCRIPTION_TYPE_PROVIDER = 6
const SUBSCRIPTION_TYPE_CUSTOM = 7

// Event status
const EVENT_STATUS_PENDING = 1
const EVENT_STATUS_PROCESSED = 2
const EVENT_STATUS_FAILED = 3

// ============================================================================
// STORAGE VARIABLES
// ============================================================================

// Contract administration
@storage_var
func admin() -> (address: ContractAddress) {}

@storage_var
func authorized_contracts(contract_address: ContractAddress) -> (authorized: felt252) {}

// Event tracking
@storage_var
func event_count() -> (count: felt252) {}

@storage_var
func events(event_id: felt252) -> (
    event_type: felt252,
    source_contract: ContractAddress,
    user_address: ContractAddress,
    data_hash: felt252,
    priority: felt252,
    timestamp: felt252,
    status: felt252,
    batch_id: felt252
) {}

// Event batching for gas optimization
@storage_var
func batch_count() -> (count: felt252) {}

@storage_var
func event_batches(batch_id: felt252) -> (
    event_count: felt252,
    total_priority: felt252,
    timestamp: felt252,
    processed: felt252
) {}

@storage_var
func batch_events(batch_id: felt252, event_index: felt252) -> (event_id: felt252) {}

// Subscription management
@storage_var
func subscription_count() -> (count: felt252) {}

@storage_var
func subscriptions(subscription_id: felt252) -> (
    subscriber_address: ContractAddress,
    subscription_type: felt252,
    event_types: Array<felt252>,
    active: felt252,
    created_at: felt252,
    last_updated: felt252
) {}

@storage_var
func subscriber_subscriptions(subscriber_address: ContractAddress, subscription_index: felt252) -> (subscription_id: felt252) {}

@storage_var
func subscriber_subscription_count(subscriber_address: ContractAddress) -> (count: felt252) {}

// Event history and filtering
@storage_var
func event_history(event_id: felt252) -> (
    event_type: felt252,
    source_contract: ContractAddress,
    user_address: ContractAddress,
    data_hash: felt252,
    priority: felt252,
    timestamp: felt252,
    processed_by: Array<ContractAddress>
) {}

@storage_var
func event_filters(filter_id: felt252) -> (
    name: felt252,
    event_types: Array<felt252>,
    priority_min: felt252,
    priority_max: felt252,
    active: felt252
) {}

// Custom event types
@storage_var
func custom_event_types(event_type_id: felt252) -> (
    name: felt252,
    description: felt252,
    data_schema: felt252,
    priority_default: felt252,
    active: felt252
) {}

@storage_var
func custom_event_count() -> (count: felt252) {}

// Event metadata storage
@storage_var
func event_metadata(event_id: felt252, key: felt252) -> (value: felt252) {}

// ============================================================================
// EVENTS
// ============================================================================

@event
func EventEmitted(event_id: felt252, event_type: felt252, source_contract: ContractAddress, user_address: ContractAddress, timestamp: felt252) {}

@event
func EventBatchProcessed(batch_id: felt252, event_count: felt252, timestamp: felt252) {}

@event
func SubscriptionCreated(subscription_id: felt252, subscriber_address: ContractAddress, subscription_type: felt252, timestamp: felt252) {}

@event
func SubscriptionUpdated(subscription_id: felt252, subscriber_address: ContractAddress, active: felt252, timestamp: felt252) {}

@event
func CustomEventTypeCreated(event_type_id: felt252, name: felt252, priority_default: felt252, timestamp: felt252) {}

@event
func EventFilterCreated(filter_id: felt252, name: felt252, event_types: Array<felt252>, timestamp: felt252) {}

// ============================================================================
// CONSTRUCTOR
// ============================================================================

@constructor
func constructor(admin_address: ContractAddress) {
    admin::write(admin_address);
    event_count::write(0);
    batch_count::write(0);
    subscription_count::write(0);
    custom_event_count::write(0);
    return ();
}

// ============================================================================
// ACCESS CONTROL
// ============================================================================

func only_admin() {
    let caller = get_caller_address();
    let admin_address = admin::read();
    assert(caller == admin_address, 'Only admin can call this');
    return ();
}

func only_authorized() {
    let caller = get_caller_address();
    let admin_address = admin::read();
    let is_authorized = authorized_contracts::read(caller);
    assert(caller == admin_address or is_authorized == 1, 'Only authorized contracts can call this');
    return ();
}

// ============================================================================
// CORE EVENT EMISSION FUNCTIONS
// ============================================================================

@external
func emit_booking_event{
    syscalls: SyscallPtr
}(
    booking_id: felt252,
    user_address: ContractAddress,
    provider_address: ContractAddress,
    service_id: felt252,
    amount: Uint256,
    event_subtype: felt252, // 1=created, 2=confirmed, 3=completed, 4=cancelled, 5=disputed
    metadata: felt252
) -> (event_id: felt252):
    alloc_locals
    only_authorized();
    
    let (current_count) = event_count::read();
    let event_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    let (caller) = get_caller_address();
    
    // Determine event type based on subtype
    let event_type = EVENT_TYPE_BOOKING_CREATED;
    if event_subtype == 2:
        let event_type = EVENT_TYPE_BOOKING_CONFIRMED;
    elif event_subtype == 3:
        let event_type = EVENT_TYPE_BOOKING_COMPLETED;
    elif event_subtype == 4:
        let event_type = EVENT_TYPE_BOOKING_CANCELLED;
    elif event_subtype == 5:
        let event_type = EVENT_TYPE_BOOKING_DISPUTED;
    end
    
    // Create data hash from booking details
    let data_hash = booking_id + service_id + amount.low + event_subtype;
    
    // Store event
    event_count::write(event_id);
    events::write(event_id, (event_type, caller, user_address, data_hash, PRIORITY_MEDIUM, timestamp, EVENT_STATUS_PENDING, 0));
    
    // Add to event history
    event_history::write(event_id, (event_type, caller, user_address, data_hash, PRIORITY_MEDIUM, timestamp, ArrayTrait::new()));
    
    // Emit event
    EventEmitted(event_id, event_type, caller, user_address, timestamp);
    
    return (event_id,);
end

@external
func emit_payment_event{
    syscalls: SyscallPtr
}(
    payment_id: felt252,
    user_address: ContractAddress,
    provider_address: ContractAddress,
    amount: Uint256,
    token_address: ContractAddress,
    event_subtype: felt252, // 1=initiated, 2=completed, 3=refunded
    metadata: felt252
) -> (event_id: felt252):
    alloc_locals
    only_authorized();
    
    let (current_count) = event_count::read();
    let event_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    let (caller) = get_caller_address();
    
    // Determine event type based on subtype
    let event_type = EVENT_TYPE_PAYMENT_INITIATED;
    if event_subtype == 2:
        let event_type = EVENT_TYPE_PAYMENT_COMPLETED;
    elif event_subtype == 3:
        let event_type = EVENT_TYPE_PAYMENT_REFUNDED;
    end
    
    // Create data hash from payment details
    let data_hash = payment_id + amount.low + event_subtype;
    
    // Store event
    event_count::write(event_id);
    events::write(event_id, (event_type, caller, user_address, data_hash, PRIORITY_HIGH, timestamp, EVENT_STATUS_PENDING, 0));
    
    // Add to event history
    event_history::write(event_id, (event_type, caller, user_address, data_hash, PRIORITY_HIGH, timestamp, ArrayTrait::new()));
    
    // Emit event
    EventEmitted(event_id, event_type, caller, user_address, timestamp);
    
    return (event_id,);
end

@external
func emit_review_event{
    syscalls: SyscallPtr
}(
    review_id: felt252,
    user_address: ContractAddress,
    provider_address: ContractAddress,
    service_id: felt252,
    rating: felt252,
    event_subtype: felt252, // 1=submitted, 2=updated
    metadata: felt252
) -> (event_id: felt252):
    alloc_locals
    only_authorized();
    
    let (current_count) = event_count::read();
    let event_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    let (caller) = get_caller_address();
    
    // Determine event type based on subtype
    let event_type = EVENT_TYPE_REVIEW_SUBMITTED;
    if event_subtype == 2:
        let event_type = EVENT_TYPE_REVIEW_UPDATED;
    end
    
    // Create data hash from review details
    let data_hash = review_id + service_id + rating + event_subtype;
    
    // Store event
    event_count::write(event_id);
    events::write(event_id, (event_type, caller, user_address, data_hash, PRIORITY_MEDIUM, timestamp, EVENT_STATUS_PENDING, 0));
    
    // Add to event history
    event_history::write(event_id, (event_type, caller, user_address, data_hash, PRIORITY_MEDIUM, timestamp, ArrayTrait::new()));
    
    // Emit event
    EventEmitted(event_id, event_type, caller, user_address, timestamp);
    
    return (event_id,);
end

// ============================================================================
// SUBSCRIPTION MANAGEMENT
// ============================================================================

@external
func subscribe_to_events{
    syscalls: SyscallPtr
}(
    subscription_type: felt252,
    event_types: Array<felt252>
) -> (subscription_id: felt252):
    alloc_locals
    let (caller) = get_caller_address();
    let (current_count) = subscription_count::read();
    let subscription_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    
    // Create subscription
    subscription_count::write(subscription_id);
    subscriptions::write(subscription_id, (caller, subscription_type, event_types, 1, timestamp, timestamp));
    
    // Add to subscriber's subscription list
    let (subscriber_count) = subscriber_subscription_count::read(caller);
    subscriber_subscriptions::write(caller, subscriber_count, subscription_id);
    subscriber_subscription_count::write(caller, subscriber_count + 1);
    
    // Emit event
    SubscriptionCreated(subscription_id, caller, subscription_type, timestamp);
    
    return (subscription_id,);
end

@external
func update_subscription(
    subscription_id: felt252,
    active: felt252
) {
    let (caller) = get_caller_address();
    let (subscriber_address, subscription_type, event_types, current_active, created_at, last_updated) = subscriptions::read(subscription_id);
    
    // Only subscriber or admin can update
    let admin_address = admin::read();
    assert(caller == subscriber_address or caller == admin_address, 'Only subscriber or admin can update subscription');
    
    let (timestamp) = get_block_timestamp();
    subscriptions::write(subscription_id, (subscriber_address, subscription_type, event_types, active, created_at, timestamp));
    
    // Emit event
    SubscriptionUpdated(subscription_id, subscriber_address, active, timestamp);
    
    return ();
}

@external
func get_subscription_details(subscription_id: felt252) -> (
    subscriber_address: ContractAddress,
    subscription_type: felt252,
    event_types: Array<felt252>,
    active: felt252,
    created_at: felt252,
    last_updated: felt252
):
    let (subscriber_address, subscription_type, event_types, active, created_at, last_updated) = subscriptions::read(subscription_id);
    return (subscriber_address, subscription_type, event_types, active, created_at, last_updated);
end

// ============================================================================
// EVENT HISTORY AND FILTERING
// ============================================================================

@external
func get_event_history{
    syscalls: SyscallPtr
}(
    start_event_id: felt252,
    end_event_id: felt252,
    event_types: Array<felt252>
) -> (event_count: felt252, events_data: Array<felt252>):
    alloc_locals
    // This is a simplified implementation
    // In a real contract, this would iterate through events and filter
    let event_count = 0;
    let events_data = ArrayTrait::new();
    
    return (event_count, events_data);
end

@external
func create_event_filter(
    name: felt252,
    event_types: Array<felt252>,
    priority_min: felt252,
    priority_max: felt252
) -> (filter_id: felt252):
    only_admin();
    
    let (current_count) = event_count::read();
    let filter_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    
    event_filters::write(filter_id, (name, event_types, priority_min, priority_max, 1));
    
    // Emit event
    EventFilterCreated(filter_id, name, event_types, timestamp);
    
    return (filter_id,);
end

// ============================================================================
// EVENT BATCHING FOR GAS OPTIMIZATION
// ============================================================================

@external
func create_event_batch{
    syscalls: SyscallPtr
}() -> (batch_id: felt252):
    alloc_locals
    only_authorized();
    
    let (current_batch_count) = batch_count::read();
    let batch_id = current_batch_count + 1;
    let (timestamp) = get_block_timestamp();
    
    batch_count::write(batch_id);
    event_batches::write(batch_id, (0, 0, timestamp, 0));
    
    return (batch_id,);
end

@external
func add_event_to_batch(
    batch_id: felt252,
    event_id: felt252
) {
    only_authorized();
    
    let (event_count, total_priority, timestamp, processed) = event_batches::read(batch_id);
    let (event_type, source_contract, user_address, data_hash, priority, event_timestamp, status, current_batch_id) = events::read(event_id);
    
    // Add event to batch
    batch_events::write(batch_id, event_count, event_id);
    event_batches::write(batch_id, (event_count + 1, total_priority + priority, timestamp, 0));
    
    // Update event with batch ID
    events::write(event_id, (event_type, source_contract, user_address, data_hash, priority, event_timestamp, status, batch_id));
    
    return ();
}

@external
func process_event_batch(batch_id: felt252) {
    only_authorized();
    
    let (event_count, total_priority, timestamp, processed) = event_batches::read(batch_id);
    
    // Mark batch as processed
    event_batches::write(batch_id, (event_count, total_priority, timestamp, 1));
    
    // Emit batch processed event
    EventBatchProcessed(batch_id, event_count, timestamp);
    
    return ();
}

// ============================================================================
// CUSTOM EVENT TYPES
// ============================================================================

@external
func create_custom_event_type(
    name: felt252,
    description: felt252,
    data_schema: felt252,
    priority_default: felt252
) -> (event_type_id: felt252):
    only_admin();
    
    let (current_count) = custom_event_count::read();
    let event_type_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    
    custom_event_count::write(event_type_id);
    custom_event_types::write(event_type_id, (name, description, data_schema, priority_default, 1));
    
    // Emit event
    CustomEventTypeCreated(event_type_id, name, priority_default, timestamp);
    
    return (event_type_id,);
end

@external
func emit_custom_event{
    syscalls: SyscallPtr
}(
    custom_event_type_id: felt252,
    user_address: ContractAddress,
    data_hash: felt252,
    priority: felt252,
    metadata: felt252
) -> (event_id: felt252):
    alloc_locals
    only_authorized();
    
    let (current_count) = event_count::read();
    let event_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    let (caller) = get_caller_address();
    
    // Store custom event
    event_count::write(event_id);
    events::write(event_id, (custom_event_type_id, caller, user_address, data_hash, priority, timestamp, EVENT_STATUS_PENDING, 0));
    
    // Add to event history
    event_history::write(event_id, (custom_event_type_id, caller, user_address, data_hash, priority, timestamp, ArrayTrait::new()));
    
    // Emit event
    EventEmitted(event_id, custom_event_type_id, caller, user_address, timestamp);
    
    return (event_id,);
end

// ============================================================================
// EVENT METADATA MANAGEMENT
// ============================================================================

@external
func set_event_metadata(
    event_id: felt252,
    key: felt252,
    value: felt252
) {
    only_authorized();
    event_metadata::write(event_id, key, value);
    return ();
}

@external
func get_event_metadata(event_id: felt252, key: felt252) -> (value: felt252):
    let value = event_metadata::read(event_id, key);
    return (value,);
end

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

@external
func get_event_details(event_id: felt252) -> (
    event_type: felt252,
    source_contract: ContractAddress,
    user_address: ContractAddress,
    data_hash: felt252,
    priority: felt252,
    timestamp: felt252,
    status: felt252,
    batch_id: felt252
):
    let (event_type, source_contract, user_address, data_hash, priority, timestamp, status, batch_id) = events::read(event_id);
    return (event_type, source_contract, user_address, data_hash, priority, timestamp, status, batch_id);
end

@external
func get_subscriber_subscriptions(subscriber_address: ContractAddress) -> (subscription_count: felt252):
    let subscription_count = subscriber_subscription_count::read(subscriber_address);
    return (subscription_count,);
end

@external
func get_batch_details(batch_id: felt252) -> (
    event_count: felt252,
    total_priority: felt252,
    timestamp: felt252,
    processed: felt252
):
    let (event_count, total_priority, timestamp, processed) = event_batches::read(batch_id);
    return (event_count, total_priority, timestamp, processed);
end

// ============================================================================
// ADMINISTRATIVE FUNCTIONS
// ============================================================================

@external
func authorize_contract(contract_address: ContractAddress) {
    only_admin();
    authorized_contracts::write(contract_address, 1);
    return ();
}

@external
func revoke_authorization(contract_address: ContractAddress) {
    only_admin();
    authorized_contracts::write(contract_address, 0);
    return ();
}

@external
func update_admin(new_admin: ContractAddress) {
    only_admin();
    admin::write(new_admin);
    return ();
} 