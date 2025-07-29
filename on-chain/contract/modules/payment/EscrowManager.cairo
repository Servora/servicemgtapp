use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;
use starknet::contract_address_const;

#[starknet::interface]
trait IEscrowManager<TContractState> {
    fn create_escrow(
        ref self: TContractState,
        booking_id: u256,
        provider: ContractAddress,
        total_amount: u256,
        platform_fee: u256,
        auto_release_time: u64,
        milestones: Array<MilestoneData>
    ) -> u256;
    
    fn release_payment(ref self: TContractState, escrow_id: u256);
    fn release_milestone(ref self: TContractState, escrow_id: u256, milestone_index: u32);
    fn dispute_payment(ref self: TContractState, escrow_id: u256, reason: felt252);
    fn resolve_dispute(ref self: TContractState, escrow_id: u256, resolution: DisputeResolution);
    fn refund_payment(ref self: TContractState, escrow_id: u256, refund_amount: u256);
    fn emergency_withdraw(ref self: TContractState, escrow_id: u256);
    fn get_escrow_status(self: @TContractState, escrow_id: u256) -> EscrowDetails;
    fn get_escrow_by_booking(self: @TContractState, booking_id: u256) -> u256;
    fn claim_platform_fees(ref self: TContractState, token_address: ContractAddress);
    fn auto_release_escrow(ref self: TContractState, escrow_id: u256);
}

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
}

#[derive(Drop, Serde, starknet::Store)]
struct MilestoneData {
    description: felt252,
    amount: u256,
    due_date: u64,
    completed: bool,
    released: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct EscrowDetails {
    escrow_id: u256,
    booking_id: u256,
    consumer: ContractAddress,
    provider: ContractAddress,
    token_address: ContractAddress,
    total_amount: u256,
    platform_fee: u256,
    remaining_amount: u256,
    state: EscrowState,
    created_at: u64,
    updated_at: u64,
    auto_release_time: u64,
    dispute_deadline: u64,
    milestones: Array<MilestoneData>,
    dispute_reason: felt252,
    arbitrator: ContractAddress,
}

#[derive(Drop, Serde, starknet::Store, PartialEq)]
enum EscrowState {
    Active,
    Completed,
    Disputed,
    Refunded,
    PartiallyReleased,
    EmergencyWithdrawn,
    Expired,
}

#[derive(Drop, Serde, starknet::Store)]
enum DisputeResolution {
    FavorConsumer: u256, // Refund amount
    FavorProvider: u256, // Release amount
    Split: (u256, u256), // (consumer_refund, provider_payment)
}

#[starknet::contract]
mod EscrowManager {
    use super::{
        IEscrowManager, IERC20, EscrowDetails, EscrowState, MilestoneData, DisputeResolution
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Core escrow storage
        escrows: Map<u256, EscrowDetails>,
        escrow_counter: u256,
        booking_to_escrow: Map<u256, u256>,
        
        // Platform configuration
        owner: ContractAddress,
        platform_wallet: ContractAddress,
        booking_contract: ContractAddress,
        
        // Arbitration system
        arbitrators: Map<ContractAddress, bool>,
        dispute_fee: u256,
        dispute_timeout: u64, // Time limit for dispute resolution
        
        // Platform fees tracking
        platform_fees_collected: Map<ContractAddress, u256>, // token -> amount
        
        // Emergency controls
        emergency_pause: bool,
        emergency_withdrawal_delay: u64,
        
        // Auto-release settings
        default_auto_release_time: u64,
        max_auto_release_time: u64,
        
        // Supported tokens
        supported_tokens: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EscrowCreated: EscrowCreated,
        PaymentReleased: PaymentReleased,
        MilestoneReleased: MilestoneReleased,
        PaymentDisputed: PaymentDisputed,
        DisputeResolved: DisputeResolved,
        PaymentRefunded: PaymentRefunded,
        EmergencyWithdrawal: EmergencyWithdrawal,
        PlatformFeesCollected: PlatformFeesCollected,
        AutoReleaseExecuted: AutoReleaseExecuted,
        EscrowExpired: EscrowExpired,
    }

    #[derive(Drop, starknet::Event)]
    struct EscrowCreated {
        #[key]
        escrow_id: u256,
        #[key]
        booking_id: u256,
        #[key]
        consumer: ContractAddress,
        #[key]
        provider: ContractAddress,
        token_address: ContractAddress,
        total_amount: u256,
        platform_fee: u256,
        auto_release_time: u64,
        milestone_count: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct PaymentReleased {
        #[key]
        escrow_id: u256,
        #[key]
        provider: ContractAddress,
        amount: u256,
        platform_fee: u256,
        released_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct MilestoneReleased {
        #[key]
        escrow_id: u256,
        milestone_index: u32,
        #[key]
        provider: ContractAddress,
        amount: u256,
        released_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PaymentDisputed {
        #[key]
        escrow_id: u256,
        #[key]
        disputed_by: ContractAddress,
        reason: felt252,
        disputed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct DisputeResolved {
        #[key]
        escrow_id: u256,
        #[key]
        arbitrator: ContractAddress,
        consumer_refund: u256,
        provider_payment: u256,
        resolved_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PaymentRefunded {
        #[key]
        escrow_id: u256,
        #[key]
        consumer: ContractAddress,
        refund_amount: u256,
        refunded_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyWithdrawal {
        #[key]
        escrow_id: u256,
        #[key]
        withdrawn_by: ContractAddress,
        amount: u256,
        withdrawn_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PlatformFeesCollected {
        #[key]
        token_address: ContractAddress,
        amount: u256,
        collected_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AutoReleaseExecuted {
        #[key]
        escrow_id: u256,
        amount: u256,
        executed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EscrowExpired {
        #[key]
        escrow_id: u256,
        expired_at: u64,
    }

    mod Errors {
        const UNAUTHORIZED: felt252 = 'Unauthorized access';
        const INVALID_ESCROW: felt252 = 'Invalid escrow ID';
        const INVALID_STATE: felt252 = 'Invalid escrow state';
        const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        const INVALID_AMOUNT: felt252 = 'Invalid amount';
        const DISPUTE_TIMEOUT: felt252 = 'Dispute resolution timeout';
        const EMERGENCY_PAUSED: felt252 = 'Emergency pause active';
        const UNSUPPORTED_TOKEN: felt252 = 'Token not supported';
        const MILESTONE_NOT_FOUND: felt252 = 'Milestone not found';
        const MILESTONE_ALREADY_RELEASED: felt252 = 'Milestone already released';
        const AUTO_RELEASE_NOT_DUE: felt252 = 'Auto release not due';
        const INVALID_MILESTONE_DATA: felt252 = 'Invalid milestone data';
        const BOOKING_ALREADY_HAS_ESCROW: felt252 = 'Booking already has escrow';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        platform_wallet: ContractAddress,
        booking_contract: ContractAddress,
        dispute_fee: u256,
        dispute_timeout: u64,
        default_auto_release_time: u64
    ) {
        self.owner.write(owner);
        self.platform_wallet.write(platform_wallet);
        self.booking_contract.write(booking_contract);
        self.dispute_fee.write(dispute_fee);
        self.dispute_timeout.write(dispute_timeout);
        self.default_auto_release_time.write(default_auto_release_time);
        self.max_auto_release_time.write(2592000); // 30 days
        self.emergency_withdrawal_delay.write(86400); // 24 hours
        self.escrow_counter.write(0);
        self.emergency_pause.write(false);
    }

    #[abi(embed_v0)]
    impl EscrowManagerImpl of IEscrowManager<ContractState> {
        fn create_escrow(
            ref self: ContractState,
            booking_id: u256,
            provider: ContractAddress,
            total_amount: u256,
            platform_fee: u256,
            auto_release_time: u64,
            milestones: Array<MilestoneData>
        ) -> u256 {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Validation
            assert(total_amount > 0, Errors::INVALID_AMOUNT);
            assert(platform_fee <= total_amount, Errors::INVALID_AMOUNT);
            assert(auto_release_time <= self.max_auto_release_time.read(), Errors::INVALID_AMOUNT);
            
            // Check if booking already has escrow
            let existing_escrow = self.booking_to_escrow.entry(booking_id).read();
            assert(existing_escrow == 0, Errors::BOOKING_ALREADY_HAS_ESCROW);
            
            // Validate milestones
            self._validate_milestones(@milestones, total_amount - platform_fee);
            
            // Generate escrow ID
            let escrow_id = self.escrow_counter.read() + 1;
            self.escrow_counter.write(escrow_id);
            
            // Set auto-release time
            let final_auto_release_time = if auto_release_time == 0 {
                current_time + self.default_auto_release_time.read()
            } else {
                current_time + auto_release_time
            };
            
            // Create escrow details
            let escrow = EscrowDetails {
                escrow_id,
                booking_id,
                consumer: caller,
                provider,
                token_address: contract_address_const::<0>(), // ETH for now
                total_amount,
                platform_fee,
                remaining_amount: total_amount,
                state: EscrowState::Active,
                created_at: current_time,
                updated_at: current_time,
                auto_release_time: final_auto_release_time,
                dispute_deadline: 0,
                milestones,
                dispute_reason: 0,
                arbitrator: contract_address_const::<0>(),
            };
            
            // Store escrow
            self.escrows.entry(escrow_id).write(escrow);
            self.booking_to_escrow.entry(booking_id).write(escrow_id);
            
            // Transfer funds to contract (ETH transfer would be handled differently)
            // For ERC20 tokens, we would use transfer_from
            
            self.emit(EscrowCreated {
                escrow_id,
                booking_id,
                consumer: caller,
                provider,
                token_address: contract_address_const::<0>(),
                total_amount,
                platform_fee,
                auto_release_time: final_auto_release_time,
                milestone_count: milestones.len(),
            });
            
            escrow_id
        }

        fn release_payment(ref self: ContractState, escrow_id: u256) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut escrow = self._get_escrow_or_panic(escrow_id);
            
            // Only consumer can release payment
            assert(caller == escrow.consumer, Errors::UNAUTHORIZED);
            
            // Check valid state
            assert(
                escrow.state == EscrowState::Active || 
                escrow.state == EscrowState::PartiallyReleased,
                Errors::INVALID_STATE
            );
            
            // Calculate amounts
            let provider_amount = escrow.remaining_amount - escrow.platform_fee;
            let platform_fee = escrow.platform_fee;
            
            // Update escrow state
            escrow.state = EscrowState::Completed;
            escrow.remaining_amount = 0;
            escrow.updated_at = current_time;
            self.escrows.entry(escrow_id).write(escrow);
            
            // Transfer funds
            self._transfer_funds(escrow.provider, provider_amount, escrow.token_address);
            
            // Track platform fees
            let current_fees = self.platform_fees_collected.entry(escrow.token_address).read();
            self.platform_fees_collected.entry(escrow.token_address).write(current_fees + platform_fee);
            
            self.emit(PaymentReleased {
                escrow_id,
                provider: escrow.provider,
                amount: provider_amount,
                platform_fee,
                released_at: current_time,
            });
        }

        fn release_milestone(ref self: ContractState, escrow_id: u256, milestone_index: u32) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut escrow = self._get_escrow_or_panic(escrow_id);
            
            // Only consumer can release milestones
            assert(caller == escrow.consumer, Errors::UNAUTHORIZED);
            
            // Check valid state
            assert(
                escrow.state == EscrowState::Active || 
                escrow.state == EscrowState::PartiallyReleased,
                Errors::INVALID_STATE
            );
            
            // Validate milestone index
            assert(milestone_index < escrow.milestones.len(), Errors::MILESTONE_NOT_FOUND);
            
            // Get milestone
            let mut milestone = *escrow.milestones.at(milestone_index);
            assert(!milestone.released, Errors::MILESTONE_ALREADY_RELEASED);
            
            // Mark milestone as completed and released
            milestone.completed = true;
            milestone.released = true;
            
            // Update milestone in array (simplified - in practice, need proper array update)
            let mut updated_milestones = ArrayTrait::new();
            let mut i = 0;
            while i < escrow.milestones.len() {
                if i == milestone_index {
                    updated_milestones.append(milestone);
                } else {
                    updated_milestones.append(*escrow.milestones.at(i));
                }
                i += 1;
            };
            
            // Update escrow
            escrow.milestones = updated_milestones;
            escrow.remaining_amount -= milestone.amount;
            escrow.updated_at = current_time;
            
            // Check if all milestones are released
            let all_released = self._all_milestones_released(@escrow.milestones);
            if all_released {
                escrow.state = EscrowState::Completed;
            } else {
                escrow.state = EscrowState::PartiallyReleased;
            }
            
            self.escrows.entry(escrow_id).write(escrow);
            
            // Transfer milestone amount
            self._transfer_funds(escrow.provider, milestone.amount, escrow.token_address);
            
            self.emit(MilestoneReleased {
                escrow_id,
                milestone_index,
                provider: escrow.provider,
                amount: milestone.amount,
                released_at: current_time,
            });
        }

        fn dispute_payment(ref self: ContractState, escrow_id: u256, reason: felt252) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut escrow = self._get_escrow_or_panic(escrow_id);
            
            // Only consumer or provider can dispute
            assert(
                caller == escrow.consumer || caller == escrow.provider,
                Errors::UNAUTHORIZED
            );
            
            // Check valid state
            assert(
                escrow.state == EscrowState::Active || 
                escrow.state == EscrowState::PartiallyReleased,
                Errors::INVALID_STATE
            );
            
            // Update escrow state
            escrow.state = EscrowState::Disputed;
            escrow.dispute_reason = reason;
            escrow.dispute_deadline = current_time + self.dispute_timeout.read();
            escrow.updated_at = current_time;
            self.escrows.entry(escrow_id).write(escrow);
            
            self.emit(PaymentDisputed {
                escrow_id,
                disputed_by: caller,
                reason,
                disputed_at: current_time,
            });
        }

        fn resolve_dispute(
            ref self: ContractState,
            escrow_id: u256,
            resolution: DisputeResolution
        ) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut escrow = self._get_escrow_or_panic(escrow_id);
            
            // Only arbitrator can resolve disputes
            assert(self.arbitrators.entry(caller).read(), Errors::UNAUTHORIZED);
            
            // Check valid state
            assert(escrow.state == EscrowState::Disputed, Errors::INVALID_STATE);
            
            // Check dispute deadline
            assert(current_time <= escrow.dispute_deadline, Errors::DISPUTE_TIMEOUT);
            
            let (consumer_refund, provider_payment) = match resolution {
                DisputeResolution::FavorConsumer(refund_amount) => {
                    (refund_amount, 0)
                },
                DisputeResolution::FavorProvider(payment_amount) => {
                    (0, payment_amount)
                },
                DisputeResolution::Split((refund, payment)) => {
                    (refund, payment)
                },
            };
            
            // Validate amounts
            assert(
                consumer_refund + provider_payment <= escrow.remaining_amount,
                Errors::INVALID_AMOUNT
            );
            
            // Update escrow
            escrow.state = EscrowState::Completed;
            escrow.remaining_amount = 0;
            escrow.arbitrator = caller;
            escrow.updated_at = current_time;
            self.escrows.entry(escrow_id).write(escrow);
            
            // Transfer funds according to resolution
            if consumer_refund > 0 {
                self._transfer_funds(escrow.consumer, consumer_refund, escrow.token_address);
            }
            
            if provider_payment > 0 {
                self._transfer_funds(escrow.provider, provider_payment, escrow.token_address);
            }
            
            // Handle remaining platform fees
            let remaining_amount = escrow.total_amount - consumer_refund - provider_payment;
            if remaining_amount > 0 {
                let current_fees = self.platform_fees_collected.entry(escrow.token_address).read();
                self.platform_fees_collected.entry(escrow.token_address).write(current_fees + remaining_amount);
            }
            
            self.emit(DisputeResolved {
                escrow_id,
                arbitrator: caller,
                consumer_refund,
                provider_payment,
                resolved_at: current_time,
            });
        }

        fn refund_payment(ref self: ContractState, escrow_id: u256, refund_amount: u256) {
            self._assert_not_paused();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut escrow = self._get_escrow_or_panic(escrow_id);
            
            // Only provider can initiate refunds
            assert(caller == escrow.provider, Errors::UNAUTHORIZED);
            
            // Check valid state
            assert(
                escrow.state == EscrowState::Active || 
                escrow.state == EscrowState::PartiallyReleased,
                Errors::INVALID_STATE
            );
            
            // Validate refund amount
            assert(refund_amount <= escrow.remaining_amount, Errors::INVALID_AMOUNT);
            
            // Update escrow
            escrow.remaining_amount -= refund_amount;
            escrow.updated_at = current_time;
            
            if escrow.remaining_amount == 0 {
                escrow.state = EscrowState::Refunded;
            }
            
            self.escrows.entry(escrow_id).write(escrow);
            
            // Transfer refund
            self._transfer_funds(escrow.consumer, refund_amount, escrow.token_address);
            
            self.emit(PaymentRefunded {
                escrow_id,
                consumer: escrow.consumer,
                refund_amount,
                refunded_at: current_time,
            });
        }

        fn emergency_withdraw(ref self: ContractState, escrow_id: u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            let mut escrow = self._get_escrow_or_panic(escrow_id);
            
            // Only owner can perform emergency withdrawal
            assert(caller == self.owner.read(), Errors::UNAUTHORIZED);
            
            // Check emergency conditions
            assert(self.emergency_pause.read(), Errors::UNAUTHORIZED);
            
            // Update escrow state
            escrow.state = EscrowState::EmergencyWithdrawn;
            escrow.updated_at = current_time;
            self.escrows.entry(escrow_id).write(escrow);
            
            // Transfer remaining funds to platform wallet
            let withdrawal_amount = escrow.remaining_amount;
            escrow.remaining_amount = 0;
            
            self._transfer_funds(self.platform_wallet.read(), withdrawal_amount, escrow.token_address);
            
            self.emit(EmergencyWithdrawal {
                escrow_id,
                withdrawn_by: caller,
                amount: withdrawal_amount,
                withdrawn_at: current_time,
            });
        }

        fn get_escrow_status(self: @ContractState, escrow_id: u256) -> EscrowDetails {
            self._get_escrow_or_panic(escrow_id)
        }

        fn get_escrow_by_booking(self: @ContractState, booking_id: u256) -> u256 {
            self.booking_to_escrow.entry(booking_id).read()
        }

        fn claim_platform_fees(ref self: ContractState, token_address: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), Errors::UNAUTHORIZED);
            
            let fee_amount = self.platform_fees_collected.entry(token_address).read();
            assert(fee_amount > 0, Errors::INVALID_AMOUNT);
            
            // Reset collected fees
            self.platform_fees_collected.entry(token_address).write(0);
            
            // Transfer to platform wallet
            self._transfer_funds(self.platform_wallet.read(), fee_amount, token_address);
            
            self.emit(PlatformFeesCollected {
                token_address,
                amount: fee_amount,
                collected_at: get_block_timestamp(),
            });
        }

        fn auto_release_escrow(ref self: ContractState, escrow_id: u256) {
            self._assert_not_paused();
            let current_time = get_block_timestamp();
            
            let mut escrow = self._get_escrow_or_panic(escrow_id);
            
            // Check if auto-release is due
            assert(current_time >= escrow.auto_release_time, Errors::AUTO_RELEASE_NOT_DUE);
            
            // Check valid state
            assert(
                escrow.state == EscrowState::Active || 
                escrow.state == EscrowState::PartiallyReleased,
                Errors::INVALID_STATE
            );
            
            // Calculate release amount (excluding platform fee)
            let release_amount = escrow.remaining_amount - escrow.platform_fee;
            
            // Update escrow
            escrow.state = EscrowState::Completed;
            escrow.remaining_amount = escrow.platform_fee; // Keep platform fee
            escrow.updated_at = current_time;
            self.escrows.entry(escrow_id).write(escrow);
            
            // Transfer to provider
            self._transfer_funds(escrow.provider, release_amount, escrow.token_address);
            
            // Track platform fees
            let current_fees = self.platform_fees_collected.entry(escrow.token_address).read();
            self.platform_fees_collected.entry(escrow.token_address).write(current_fees + escrow.platform_fee);
            
            self.emit(AutoReleaseExecuted {
                escrow_id,
                amount: release_amount,
                executed_at: current_time,
            });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.emergency_pause.read(), Errors::EMERGENCY_PAUSED);
        }

        fn _get_escrow_or_panic(self: @ContractState, escrow_id: u256) -> EscrowDetails {
            let escrow = self.escrows.entry(escrow_id).read();
            assert(escrow.escrow_id != 0, Errors::INVALID_ESCROW);
            escrow
        }

        fn _validate_milestones(
            self: @ContractState,
            milestones: @Array<MilestoneData>,
            total_service_amount: u256
        ) {
            if milestones.len() == 0 {
                return;
            }
            
            let mut total_milestone_amount = 0;
            let mut i = 0;
            while i < milestones.len() {
                let milestone = milestones.at(i);
                assert(milestone.amount > 0, Errors::INVALID_MILESTONE_DATA);
                total_milestone_amount += *milestone.amount;
                i += 1;
            };
            
            assert(total_milestone_amount == total_service_amount, Errors::INVALID_MILESTONE_DATA);
        }

        fn _all_milestones_released(self: @ContractState, milestones: @Array<MilestoneData>) -> bool {
            let mut i = 0;
            while i < milestones.len() {
                if !milestones.at(i).released {
                    return false;
                }
                i += 1;
            };
            true
        }

        fn _transfer_funds(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            token_address: ContractAddress
        ) {
            // For ETH transfers (token_address == 0)
            if token_address == contract_address_const::<0>() {
                // ETH transfer implementation would go here
                // This is platform-specific and depends on how ETH transfers are handled
                return;
            }
            
            // For ERC20 token transfers
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let success = token_dispatcher.transfer(recipient, amount);
            assert(success, 'Transfer failed');
        }
    }

    // Admin functions
    #[external(v0)]
    fn add_arbitrator(ref self: ContractState, arbitrator: ContractAddress) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.arbitrators.entry(arbitrator).write(true);
    }

    #[external(v0)]
    fn remove_arbitrator(ref self: ContractState, arbitrator: ContractAddress) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.arbitrators.entry(arbitrator).write(false);
    }

    #[external(v0)]
    fn add_supported_token(ref self: ContractState, token_address: ContractAddress) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.supported_tokens.entry(token_address).write(true);
    }

    #[external(v0)]
    fn emergency_pause(ref self: ContractState) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.emergency_pause.write(true);
    }

    #[external(v0)]
    fn emergency_unpause(ref self: ContractState) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.emergency_pause.write(false);
    }

    #[external(v0)]
    fn update_dispute_fee(ref self: ContractState, new_fee: u256) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.dispute_fee.write(new_fee);
    }

    #[external(v0)]
    fn update_platform_wallet(ref self: ContractState, new_wallet: ContractAddress) {
        assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        self.platform_wallet.write(new_wallet);
    }

    // View functions
    #[external(v0)]
    fn get_platform_fees(self: @ContractState, token_address: ContractAddress) -> u256 {
        self.platform_fees_collected.entry(token_address).read()
    }

    #[external(v0)]
    fn is_arbitrator(self: @ContractState, address: ContractAddress) -> bool {
        self.arbitrators.entry(address).read()
    }

    #[external(v0)]
    fn is_token_supported(self: @ContractState, token_address: ContractAddress) -> bool {
        self.supported_tokens.entry(token_address).read()
    }
}

// Dispatcher for external contract calls
#[starknet::interface]
trait IERC20Dispatcher<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

use starknet::syscalls::deploy_syscall;
use starknet::class_hash::ClassHash;

#[starknet::contract]
mod ERC20Dispatcher {
    use super::IERC20;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl ERC20DispatcherImpl of IERC20<ContractState> {
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            true // Placeholder implementation
        }
        
        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
            true // Placeholder implementation
        }
        
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            0 // Placeholder implementation
        }
        
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            true // Placeholder implementation
        }
    }
}
