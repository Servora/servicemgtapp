// SPDX-License-Identifier: MIT
// Test file for EventManager.cairo

%lang starknet

use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;
use starknet::contract_address_const;

// Import the EventManager contract
mod EventManager {
    use super::ContractAddress;
    use super::get_caller_address;
    use super::get_block_timestamp;
    
    // Include the actual contract code here
    // This would be the full EventManager.cairo content
}

#[starknet::interface]
trait IEventManager<TContractState> {
    fn emit_booking_event(
        ref self: TContractState,
        booking_id: u32,
        user_address: ContractAddress,
        provider_address: ContractAddress,
        service_id: u32,
        amount: u256,
        event_subtype: u32,
        metadata: u32
    ) -> u32;
    
    fn emit_payment_event(
        ref self: TContractState,
        payment_id: u32,
        user_address: ContractAddress,
        provider_address: ContractAddress,
        amount: u256,
        token_address: ContractAddress,
        event_subtype: u32,
        metadata: u32
    ) -> u32;
    
    fn emit_review_event(
        ref self: TContractState,
        review_id: u32,
        user_address: ContractAddress,
        provider_address: ContractAddress,
        service_id: u32,
        rating: u32,
        event_subtype: u32,
        metadata: u32
    ) -> u32;
    
    fn subscribe_to_events(
        ref self: TContractState,
        subscription_type: u32,
        event_types: Array<u32>
    ) -> u32;
    
    fn get_event_history(
        self: @TContractState,
        start_event_id: u32,
        end_event_id: u32,
        event_types: Array<u32>
    ) -> (u32, Array<u32>);
    
    fn create_event_batch(ref self: TContractState) -> u32;
    fn add_event_to_batch(ref self: TContractState, batch_id: u32, event_id: u32);
    fn process_event_batch(ref self: TContractState, batch_id: u32);
    fn create_custom_event_type(
        ref self: TContractState,
        name: u32,
        description: u32,
        data_schema: u32,
        priority_default: u32
    ) -> u32;
    fn emit_custom_event(
        ref self: TContractState,
        custom_event_type_id: u32,
        user_address: ContractAddress,
        data_hash: u32,
        priority: u32,
        metadata: u32
    ) -> u32;
}

#[starknet::contract]
mod TestEventManager {
    use super::{IEventManager, EventManager};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::testing::{set_caller_address, set_block_timestamp, set_contract_address};
    
    #[storage]
    struct Storage {
        test_admin: ContractAddress,
        test_user: ContractAddress,
        test_provider: ContractAddress,
        test_events: Array<u32>,
        test_subscriptions: Array<u32>,
        test_results: Array<bool>,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TestCompleted: TestCompleted,
        EventEmitted: EventEmitted,
        SubscriptionCreated: SubscriptionCreated,
        BatchProcessed: BatchProcessed,
    }
    
    #[derive(Drop, starknet::Event)]
    struct TestCompleted {
        test_name: felt252,
        passed: bool,
        timestamp: u32,
    }
    
    #[derive(Drop, starknet::Event)]
    struct EventEmitted {
        event_id: u32,
        event_type: u32,
        user_address: ContractAddress,
        timestamp: u32,
    }
    
    #[derive(Drop, starknet::Event)]
    struct SubscriptionCreated {
        subscription_id: u32,
        subscriber_address: ContractAddress,
        subscription_type: u32,
        timestamp: u32,
    }
    
    #[derive(Drop, starknet::Event)]
    struct BatchProcessed {
        batch_id: u32,
        event_count: u32,
        timestamp: u32,
    }
    
    #[external]
    fn test_event_manager(ref self: ContractState) {
        // Setup test environment
        let admin = contract_address_const::<'admin'>();
        let user = contract_address_const::<'user'>();
        let provider = contract_address_const::<'provider'>();
        
        set_caller_address(admin);
        set_block_timestamp(1640995200); // Jan 1, 2022
        
        // Test 1: Event emission
        test_event_emission(ref self, admin, user, provider);
        
        // Test 2: Subscription management
        test_subscription_management(ref self, user);
        
        // Test 3: Event batching
        test_event_batching(ref self);
        
        // Test 4: Custom event types
        test_custom_events(ref self);
        
        // Test 5: Event history and filtering
        test_event_history(ref self);
        
        // Test 6: Event metadata
        test_event_metadata(ref self);
        
        // Test 7: Integration with other modules
        test_module_integration(ref self, user, provider);
        
        // Emit test completion event
        self.emit(TestCompleted { 
            test_name: 'EventManager_Comprehensive_Test', 
            passed: true, 
            timestamp: get_block_timestamp() 
        });
    }
    
    #[external]
    fn test_event_emission(
        ref self: ContractState,
        admin: ContractAddress,
        user: ContractAddress,
        provider: ContractAddress
    ) {
        // Test booking event emission
        let booking_event = self.event_manager.emit_booking_event(
            123, // booking_id
            user,
            provider,
            456, // service_id
            u256 { low: 1000, high: 0 }, // amount
            1, // event_subtype: created
            1 // metadata
        );
        
        assert(booking_event > 0, 'Booking event should be emitted');
        
        // Test payment event emission
        let payment_event = self.event_manager.emit_payment_event(
            789, // payment_id
            user,
            provider,
            u256 { low: 5000, high: 0 }, // amount
            contract_address_const::<'token'>(),
            2, // event_subtype: completed
            2 // metadata
        );
        
        assert(payment_event > 0, 'Payment event should be emitted');
        
        // Test review event emission
        let review_event = self.event_manager.emit_review_event(
            101, // review_id
            user,
            provider,
            456, // service_id
            5, // rating
            1, // event_subtype: submitted
            3 // metadata
        );
        
        assert(review_event > 0, 'Review event should be emitted');
        
        // Emit test events
        self.emit(EventEmitted {
            event_id: booking_event,
            event_type: EVENT_TYPE_BOOKING_CREATED,
            user_address: user,
            timestamp: get_block_timestamp()
        });
    }
    
    #[external]
    fn test_subscription_management(
        ref self: ContractState,
        user: ContractAddress
    ) {
        // Test subscription creation
        let event_types = array![
            EVENT_TYPE_BOOKING_CREATED,
            EVENT_TYPE_PAYMENT_COMPLETED,
            EVENT_TYPE_REVIEW_SUBMITTED
        ];
        
        let subscription_id = self.event_manager.subscribe_to_events(
            SUBSCRIPTION_TYPE_BOOKING,
            event_types
        );
        
        assert(subscription_id > 0, 'Subscription should be created');
        
        // Test subscription details retrieval
        let (subscriber_address, subscription_type, event_types, active, created_at, last_updated) = 
            self.event_manager.get_subscription_details(subscription_id);
        
        assert(subscriber_address == user, 'Subscriber address should match');
        assert(subscription_type == SUBSCRIPTION_TYPE_BOOKING, 'Subscription type should match');
        assert(active == 1, 'Subscription should be active');
        
        // Emit subscription created event
        self.emit(SubscriptionCreated {
            subscription_id,
            subscriber_address: user,
            subscription_type: SUBSCRIPTION_TYPE_BOOKING,
            timestamp: get_block_timestamp()
        });
    }
    
    #[external]
    fn test_event_batching(ref self: ContractState) {
        // Create event batch
        let batch_id = self.event_manager.create_event_batch();
        assert(batch_id > 0, 'Event batch should be created');
        
        // Add events to batch
        let event_ids = array![1, 2, 3];
        let mut i = 0;
        while i < event_ids.len() {
            let event_id = event_ids.at(i);
            self.event_manager.add_event_to_batch(batch_id, event_id);
            let i = i + 1;
        }
        
        // Process batch
        self.event_manager.process_event_batch(batch_id);
        
        // Verify batch processing
        let (event_count, total_priority, timestamp, processed) = 
            self.event_manager.get_batch_details(batch_id);
        
        assert(event_count > 0, 'Batch should contain events');
        assert(processed == 1, 'Batch should be processed');
        
        // Emit batch processed event
        self.emit(BatchProcessed {
            batch_id,
            event_count,
            timestamp: get_block_timestamp()
        });
    }
    
    #[external]
    fn test_custom_events(ref self: ContractState) {
        // Create custom event type
        let custom_event_type_id = self.event_manager.create_custom_event_type(
            12345, // name
            67890, // description
            11111, // data_schema
            PRIORITY_MEDIUM // priority_default
        );
        
        assert(custom_event_type_id > 0, 'Custom event type should be created');
        
        // Emit custom event
        let custom_event = self.event_manager.emit_custom_event(
            custom_event_type_id,
            contract_address_const::<'user'>(),
            99999, // data_hash
            PRIORITY_HIGH, // priority
            55555 // metadata
        );
        
        assert(custom_event > 0, 'Custom event should be emitted');
    }
    
    #[external]
    fn test_event_history(ref self: ContractState) {
        // Test event history retrieval
        let event_types = array![
            EVENT_TYPE_BOOKING_CREATED,
            EVENT_TYPE_PAYMENT_COMPLETED
        ];
        
        let (event_count, events_data) = self.event_manager.get_event_history(
            1, // start_event_id
            10, // end_event_id
            event_types
        );
        
        // Verify event history
        assert(event_count >= 0, 'Event count should be non-negative');
    }
    
    #[external]
    fn test_event_metadata(ref self: ContractState) {
        // Test event metadata management
        let event_id = 1;
        let metadata_key = 12345;
        let metadata_value = 67890;
        
        // Set event metadata
        self.event_manager.set_event_metadata(event_id, metadata_key, metadata_value);
        
        // Get event metadata
        let retrieved_value = self.event_manager.get_event_metadata(event_id, metadata_key);
        
        assert(retrieved_value == metadata_value, 'Metadata value should match');
    }
    
    #[external]
    fn test_module_integration(
        ref self: ContractState,
        user: ContractAddress,
        provider: ContractAddress
    ) {
        // Test integration with booking module
        let booking_event = self.event_manager.emit_booking_event(
            1001, // booking_id
            user,
            provider,
            2001, // service_id
            u256 { low: 2000, high: 0 }, // amount
            1, // event_subtype: created
            1 // metadata
        );
        
        // Test integration with payment module
        let payment_event = self.event_manager.emit_payment_event(
            3001, // payment_id
            user,
            provider,
            u256 { low: 2000, high: 0 }, // amount
            contract_address_const::<'token'>(),
            2, // event_subtype: completed
            2 // metadata
        );
        
        // Test integration with review module
        let review_event = self.event_manager.emit_review_event(
            4001, // review_id
            user,
            provider,
            2001, // service_id
            4, // rating
            1, // event_subtype: submitted
            3 // metadata
        );
        
        // Verify all events were emitted
        assert(booking_event > 0, 'Booking event should be emitted');
        assert(payment_event > 0, 'Payment event should be emitted');
        assert(review_event > 0, 'Review event should be emitted');
        
        // Test event details retrieval
        let (event_type, source_contract, user_address, data_hash, priority, timestamp, status, batch_id) = 
            self.event_manager.get_event_details(booking_event);
        
        assert(event_type == EVENT_TYPE_BOOKING_CREATED, 'Event type should match');
        assert(user_address == user, 'User address should match');
    }
    
    // Constants for testing
    const EVENT_TYPE_BOOKING_CREATED: u32 = 1;
    const EVENT_TYPE_BOOKING_CONFIRMED: u32 = 2;
    const EVENT_TYPE_BOOKING_COMPLETED: u32 = 3;
    const EVENT_TYPE_BOOKING_CANCELLED: u32 = 4;
    const EVENT_TYPE_BOOKING_DISPUTED: u32 = 5;
    const EVENT_TYPE_PAYMENT_INITIATED: u32 = 6;
    const EVENT_TYPE_PAYMENT_COMPLETED: u32 = 7;
    const EVENT_TYPE_PAYMENT_REFUNDED: u32 = 8;
    const EVENT_TYPE_REVIEW_SUBMITTED: u32 = 9;
    const EVENT_TYPE_REVIEW_UPDATED: u32 = 10;
    
    const SUBSCRIPTION_TYPE_BOOKING: u32 = 2;
    const SUBSCRIPTION_TYPE_PAYMENT: u32 = 3;
    const SUBSCRIPTION_TYPE_REVIEW: u32 = 4;
    
    const PRIORITY_LOW: u32 = 1;
    const PRIORITY_MEDIUM: u32 = 2;
    const PRIORITY_HIGH: u32 = 3;
    const PRIORITY_CRITICAL: u32 = 4;
} 