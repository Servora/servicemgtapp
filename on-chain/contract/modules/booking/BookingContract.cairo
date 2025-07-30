use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;
use starknet::contract_address_const;

#[starknet::interface]
trait IBookingContract<TContractState> {
    fn create_booking(
        ref self: TContractState,
        provider: ContractAddress,
        service_id: u256,
        start_time: u64,
        end_time: u64,
        total_amount: u256
    ) -> u256;
    
    fn confirm_booking(ref self: TContractState, booking_id: u256);
    fn cancel_booking(ref self: TContractState, booking_id: u256);
    fn complete_booking(ref self: TContractState, booking_id: u256);
    fn get_booking_details(self: @TContractState, booking_id: u256) -> BookingDetails;
    fn get_provider_bookings(self: @TContractState, provider: ContractAddress, start_time: u64, end_time: u64) -> Array<u256>;
    fn withdraw_escrow(ref self: TContractState, booking_id: u256);
    fn dispute_booking(ref self: TContractState, booking_id: u256, reason: felt252);
}

#[derive(Drop, Serde, starknet::Store)]
struct BookingDetails {
    booking_id: u256,
    client: ContractAddress,
    provider: ContractAddress,
    service_id: u256,
    start_time: u64,
    end_time: u64,
    total_amount: u256,
    escrow_amount: u256,
    state: BookingState,
    created_at: u64,
    updated_at: u64,
    cancellation_fee: u256,
    dispute_reason: felt252,
}

#[derive(Drop, Serde, starknet::Store, PartialEq)]
enum BookingState {
    Pending,
    Confirmed,
    InProgress,
    Completed,
    Cancelled,
    Disputed,
    Expired,
}

#[starknet::contract]
mod BookingContract {
    use super::{IBookingContract, BookingDetails, BookingState};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Core booking storage
        bookings: Map<u256, BookingDetails>,
        booking_counter: u256,
        
        // Provider availability tracking
        provider_bookings: Map<(ContractAddress, u64), Array<u256>>,
        
        // Escrow management
        escrow_balances: Map<u256, u256>,
        
        // Contract configuration
        owner: ContractAddress,
        cancellation_fee_percentage: u256, // Basis points (e.g., 500 = 5%)
        booking_expiry_time: u64, // Seconds
        dispute_resolution_time: u64, // Seconds
        
        // Emergency controls
        contract_paused: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BookingCreated: BookingCreated,
        BookingConfirmed: BookingConfirmed,
        BookingCancelled: BookingCancelled,
        BookingCompleted: BookingCompleted,
        BookingDisputed: BookingDisputed,
        EscrowReleased: EscrowReleased,
        BookingExpired: BookingExpired,
    }

    #[derive(Drop, starknet::Event)]
    struct BookingCreated {
        #[key]
        booking_id: u256,
        #[key]
        client: ContractAddress,
        #[key]
        provider: ContractAddress,
        service_id: u256,
        start_time: u64,
        end_time: u64,
        total_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct BookingConfirmed {
        #[key]
        booking_id: u256,
        confirmed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct BookingCancelled {
        #[key]
        booking_id: u256,
        cancelled_by: ContractAddress,
        cancellation_fee: u256,
        cancelled_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct BookingCompleted {
        #[key]
        booking_id: u256,
        completed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct BookingDisputed {
        #[key]
        booking_id: u256,
        disputed_by: ContractAddress,
        reason: felt252,
        disputed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EscrowReleased {
        #[key]
        booking_id: u256,
        recipient: ContractAddress,
        amount: u256,
        released_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct BookingExpired {
        #[key]
        booking_id: u256,
        expired_at: u64,
    }

    mod Errors {
        const UNAUTHORIZED: felt252 = 'Unauthorized access';
        const INVALID_BOOKING: felt252 = 'Invalid booking ID';
        const INVALID_STATE_TRANSITION: felt252 = 'Invalid state transition';
        const BOOKING_CONFLICT: felt252 = 'Booking time conflict';
        const INSUFFICIENT_PAYMENT: felt252 = 'Insufficient payment';
        const BOOKING_EXPIRED: felt252 = 'Booking has expired';
        const CONTRACT_PAUSED: felt252 = 'Contract is paused';
        const INVALID_TIME_RANGE: felt252 = 'Invalid time range';
        const SELF_BOOKING_NOT_ALLOWED: felt252 = 'Cannot book own service';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        cancellation_fee_percentage: u256,
        booking_expiry_time: u64,
        dispute_resolution_time: u64
    ) {
        self.owner.write(owner);
        self.cancellation_fee_percentage.write(cancellation_fee_percentage);
        self.booking_expiry_time.write(booking_expiry_time);
        self.dispute_resolution_time.write(dispute_resolution_time);
        self.booking_counter.write(0);
        self.contract_paused.write(false);
    }

    #[abi(embed_v0)]
    impl BookingContractImpl of IBookingContract<ContractState> {
        fn create_booking(
            ref self: ContractState,
            provider: ContractAddress,
            service_id: u256,
            start_time: u64,
            end_time: u64,
            total_amount: u256
        ) -> u256 {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Validation checks
            assert(caller != provider, Errors::SELF_BOOKING_NOT_ALLOWED);
            assert(start_time > current_time, Errors::INVALID_TIME_RANGE);
            assert(end_time > start_time, Errors::INVALID_TIME_RANGE);
            assert(total_amount > 0, Errors::INSUFFICIENT_PAYMENT);
            
            // Check for booking conflicts
            self._check_booking_conflicts(provider, start_time, end_time);
            
            // Generate new booking ID
            let booking_id = self.booking_counter.read() + 1;
            self.booking_counter.write(booking_id);
            
            // Create booking details
            let booking = BookingDetails {
                booking_id,
                client: caller,
                provider,
                service_id,
                start_time,
                end_time,
                total_amount,
                escrow_amount: total_amount,
                state: BookingState::Pending,
                created_at: current_time,
                updated_at: current_time,
                cancellation_fee: 0,
                dispute_reason: 0,
            };
            
            // Store booking
            self.bookings.entry(booking_id).write(booking);
            
            // Store escrow amount
            self.escrow_balances.entry(booking_id).write(total_amount);
            
            // Add to provider's booking schedule
            self._add_to_provider_schedule(provider, start_time, end_time, booking_id);
            
            // Emit event
            self.emit(BookingCreated {
                booking_id,
                client: caller,
                provider,
                service_id,
                start_time,
                end_time,
                total_amount,
            });
            
            booking_id
        }

        fn confirm_booking(ref self: ContractState, booking_id: u256) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut booking = self._get_booking_or_panic(booking_id);
            
            // Only provider can confirm
            assert(caller == booking.provider, Errors::UNAUTHORIZED);
            
            // Check current state
            assert(booking.state == BookingState::Pending, Errors::INVALID_STATE_TRANSITION);
            
            // Check if booking hasn't expired
            let expiry_time = booking.created_at + self.booking_expiry_time.read();
            assert(current_time <= expiry_time, Errors::BOOKING_EXPIRED);
            
            // Update booking state
            booking.state = BookingState::Confirmed;
            booking.updated_at = current_time;
            self.bookings.entry(booking_id).write(booking);
            
            self.emit(BookingConfirmed {
                booking_id,
                confirmed_at: current_time,
            });
        }

        fn cancel_booking(ref self: ContractState, booking_id: u256) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut booking = self._get_booking_or_panic(booking_id);
            
            // Only client or provider can cancel
            assert(
                caller == booking.client || caller == booking.provider,
                Errors::UNAUTHORIZED
            );
            
            // Check valid states for cancellation
            assert(
                booking.state == BookingState::Pending || 
                booking.state == BookingState::Confirmed,
                Errors::INVALID_STATE_TRANSITION
            );
            
            // Calculate cancellation fee
            let cancellation_fee = self._calculate_cancellation_fee(
                booking.total_amount,
                booking.start_time,
                current_time,
                caller == booking.provider
            );
            
            // Update booking
            booking.state = BookingState::Cancelled;
            booking.updated_at = current_time;
            booking.cancellation_fee = cancellation_fee;
            self.bookings.entry(booking_id).write(booking);
            
            // Handle escrow refund
            self._handle_cancellation_refund(booking_id, booking.total_amount, cancellation_fee, caller == booking.provider);
            
            // Remove from provider schedule
            self._remove_from_provider_schedule(booking.provider, booking.start_time, booking.end_time, booking_id);
            
            self.emit(BookingCancelled {
                booking_id,
                cancelled_by: caller,
                cancellation_fee,
                cancelled_at: current_time,
            });
        }

        fn complete_booking(ref self: ContractState, booking_id: u256) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut booking = self._get_booking_or_panic(booking_id);
            
            // Only client can mark as complete
            assert(caller == booking.client, Errors::UNAUTHORIZED);
            
            // Check valid state
            assert(
                booking.state == BookingState::Confirmed || 
                booking.state == BookingState::InProgress,
                Errors::INVALID_STATE_TRANSITION
            );
            
            // Update booking state
            booking.state = BookingState::Completed;
            booking.updated_at = current_time;
            self.bookings.entry(booking_id).write(booking);
            
            // Release escrow to provider
            let escrow_amount = self.escrow_balances.entry(booking_id).read();
            self.escrow_balances.entry(booking_id).write(0);
            
            // Transfer funds to provider (implementation depends on token contract)
            // self._transfer_funds(booking.provider, escrow_amount);
            
            self.emit(BookingCompleted {
                booking_id,
                completed_at: current_time,
            });
            
            self.emit(EscrowReleased {
                booking_id,
                recipient: booking.provider,
                amount: escrow_amount,
                released_at: current_time,
            });
        }

        fn get_booking_details(self: @ContractState, booking_id: u256) -> BookingDetails {
            self._get_booking_or_panic(booking_id)
        }

        fn get_provider_bookings(
            self: @ContractState,
            provider: ContractAddress,
            start_time: u64,
            end_time: u64
        ) -> Array<u256> {
            // Implementation to return booking IDs for provider in time range
            // This is a simplified version - in practice, you'd need more sophisticated indexing
            let mut result = ArrayTrait::new();
            
            // Iterate through time slots and collect booking IDs
            let mut current_time = start_time;
            while current_time <= end_time {
                let bookings_at_time = self.provider_bookings.entry((provider, current_time)).read();
                let mut i = 0;
                while i < bookings_at_time.len() {
                    result.append(*bookings_at_time.at(i));
                    i += 1;
                };
                current_time += 3600; // Check hourly slots
            };
            
            result
        }

        fn withdraw_escrow(ref self: ContractState, booking_id: u256) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let booking = self._get_booking_or_panic(booking_id);
            
            // Only client can withdraw from cancelled bookings
            assert(caller == booking.client, Errors::UNAUTHORIZED);
            assert(booking.state == BookingState::Cancelled, Errors::INVALID_STATE_TRANSITION);
            
            let escrow_amount = self.escrow_balances.entry(booking_id).read();
            assert(escrow_amount > 0, Errors::INSUFFICIENT_PAYMENT);
            
            // Clear escrow
            self.escrow_balances.entry(booking_id).write(0);
            
            // Transfer refund amount (total - cancellation fee)
            let refund_amount = escrow_amount - booking.cancellation_fee;
            // self._transfer_funds(booking.client, refund_amount);
            
            self.emit(EscrowReleased {
                booking_id,
                recipient: booking.client,
                amount: refund_amount,
                released_at: current_time,
            });
        }

        fn dispute_booking(ref self: ContractState, booking_id: u256, reason: felt252) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut booking = self._get_booking_or_panic(booking_id);
            
            // Only client or provider can dispute
            assert(
                caller == booking.client || caller == booking.provider,
                Errors::UNAUTHORIZED
            );
            
            // Check valid states for dispute
            assert(
                booking.state == BookingState::Confirmed || 
                booking.state == BookingState::InProgress ||
                booking.state == BookingState::Completed,
                Errors::INVALID_STATE_TRANSITION
            );
            
            // Update booking state
            booking.state = BookingState::Disputed;
            booking.updated_at = current_time;
            booking.dispute_reason = reason;
            self.bookings.entry(booking_id).write(booking);
            
            self.emit(BookingDisputed {
                booking_id,
                disputed_by: caller,
                reason,
                disputed_at: current_time,
            });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.contract_paused.read(), Errors::CONTRACT_PAUSED);
        }

        fn _get_booking_or_panic(self: @ContractState, booking_id: u256) -> BookingDetails {
            let booking = self.bookings.entry(booking_id).read();
            assert(booking.booking_id != 0, Errors::INVALID_BOOKING);
            booking
        }

        fn _check_booking_conflicts(
            self: @ContractState,
            provider: ContractAddress,
            start_time: u64,
            end_time: u64
        ) {
            // Check for overlapping bookings
            let mut current_time = start_time;
            while current_time < end_time {
                let existing_bookings = self.provider_bookings.entry((provider, current_time)).read();
                let mut i = 0;
                while i < existing_bookings.len() {
                    let existing_booking_id = *existing_bookings.at(i);
                    let existing_booking = self.bookings.entry(existing_booking_id).read();
                    
                    // Check if booking is active (not cancelled or completed)
                    if existing_booking.state == BookingState::Confirmed || 
                       existing_booking.state == BookingState::InProgress {
                        // Check for time overlap
                        if self._times_overlap(
                            start_time, end_time,
                            existing_booking.start_time, existing_booking.end_time
                        ) {
                            panic_with_felt252(Errors::BOOKING_CONFLICT);
                        }
                    }
                    i += 1;
                };
                current_time += 3600; // Check hourly
            };
        }

        fn _times_overlap(
            self: @ContractState,
            start1: u64, end1: u64,
            start2: u64, end2: u64
        ) -> bool {
            start1 < end2 && start2 < end1
        }

        fn _add_to_provider_schedule(
            ref self: ContractState,
            provider: ContractAddress,
            start_time: u64,
            end_time: u64,
            booking_id: u256
        ) {
            let mut current_time = start_time;
            while current_time < end_time {
                let mut bookings = self.provider_bookings.entry((provider, current_time)).read();
                bookings.append(booking_id);
                self.provider_bookings.entry((provider, current_time)).write(bookings);
                current_time += 3600; // Hourly slots
            };
        }

        fn _remove_from_provider_schedule(
            ref self: ContractState,
            provider: ContractAddress,
            start_time: u64,
            end_time: u64,
            booking_id: u256
        ) {
            let mut current_time = start_time;
            while current_time < end_time {
                let mut bookings = self.provider_bookings.entry((provider, current_time)).read();
                // Remove booking_id from array (simplified - in practice, use more efficient method)
                let mut new_bookings = ArrayTrait::new();
                let mut i = 0;
                while i < bookings.len() {
                    let id = *bookings.at(i);
                    if id != booking_id {
                        new_bookings.append(id);
                    }
                    i += 1;
                };
                self.provider_bookings.entry((provider, current_time)).write(new_bookings);
                current_time += 3600;
            };
        }

        fn _calculate_cancellation_fee(
            self: @ContractState,
            total_amount: u256,
            start_time: u64,
            current_time: u64,
            cancelled_by_provider: bool
        ) -> u256 {
            if cancelled_by_provider {
                // Provider cancellation - no fee to client
                return 0;
            }
            
            let time_until_start = start_time - current_time;
            let fee_percentage = self.cancellation_fee_percentage.read();
            
            // Sliding scale based on time until booking
            let adjusted_percentage = if time_until_start > 86400 { // > 24 hours
                fee_percentage / 2 // 50% of normal fee
            } else if time_until_start > 3600 { // > 1 hour
                fee_percentage // Normal fee
            } else {
                fee_percentage * 2 // Double fee for last-minute cancellation
            };
            
            (total_amount * adjusted_percentage) / 10000 // Basis points conversion
        }

        fn _handle_cancellation_refund(
            ref self: ContractState,
            booking_id: u256,
            total_amount: u256,
            cancellation_fee: u256,
            cancelled_by_provider: bool
        ) {
            if cancelled_by_provider {
                // Full refund to client, provider pays penalty
                // Implementation depends on penalty system
            } else {
                // Client pays cancellation fee
                let refund_amount = total_amount - cancellation_fee;
                // Update escrow to reflect refund amount
                self.escrow_balances.entry(booking_id).write(refund_amount);
            }
        }
    }

    // Admin functions (only owner)
    #[external(v0)]
    fn pause_contract(ref self: ContractState) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.contract_paused.write(true);
    }

    #[external(v0)]
    fn unpause_contract(ref self: ContractState) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.contract_paused.write(false);
    }

    #[external(v0)]
    fn update_cancellation_fee(ref self: ContractState, new_fee_percentage: u256) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        assert(new_fee_percentage <= 2000, 'Fee too high'); // Max 20%
        self.cancellation_fee_percentage.write(new_fee_percentage);
    }

    // Automatic expiry function (can be called by anyone)
    #[external(v0)]
    fn expire_booking(ref self: ContractState, booking_id: u256) {
        let current_time = get_block_timestamp();
        let mut booking = self._get_booking_or_panic(booking_id);
        
        // Check if booking is pending and expired
        assert(booking.state == BookingState::Pending, Errors::INVALID_STATE_TRANSITION);
        
        let expiry_time = booking.created_at + self.booking_expiry_time.read();
        assert(current_time > expiry_time, 'Booking not expired');
        
        // Update state to expired
        booking.state = BookingState::Expired;
        booking.updated_at = current_time;
        self.bookings.entry(booking_id).write(booking);
        
        // Refund client (no cancellation fee for expiry)
        let escrow_amount = self.escrow_balances.entry(booking_id).read();
        self.escrow_balances.entry(booking_id).write(0);
        
        // Remove from provider schedule
        self._remove_from_provider_schedule(booking.provider, booking.start_time, booking.end_time, booking_id);
        
        self.emit(BookingExpired {
            booking_id,
            expired_at: current_time,
        });
        
        self.emit(EscrowReleased {
            booking_id,
            recipient: booking.client,
            amount: escrow_amount,
            released_at: current_time,
        });
    }
}
