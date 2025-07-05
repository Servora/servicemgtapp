use starknet::ContractAddress;

#[starknet::interface]
trait IVotingPower<TContractState> {
    fn calculate_voting_power(self: @TContractState, user: ContractAddress) -> u256;
    fn update_user_metrics(
        ref self: TContractState,
        user: ContractAddress,
        token_balance: u256,
        service_count: u256,
        reputation_score: u256
    );
    fn get_voting_power(self: @TContractState, user: ContractAddress) -> u256;
    fn delegate_voting_power(ref self: TContractState, delegate: ContractAddress);
    fn revoke_delegation(ref self: TContractState);
    fn get_delegated_power(self: @TContractState, delegate: ContractAddress) -> u256;
}

#[derive(Drop, Serde, starknet::Store)]
struct UserMetrics {
    token_balance: u256,
    service_count: u256,
    reputation_score: u256,
    join_timestamp: u64,
    last_update: u64,
    total_voting_power: u256,
}

#[derive(Drop, Serde, starknet::Store)]
struct VotingPowerSnapshot {
    user: ContractAddress,
    power: u256,
    timestamp: u64,
    block_number: u64,
}

#[starknet::contract]
mod VotingPower {
    use super::{IVotingPower, UserMetrics, VotingPowerSnapshot};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_block_number};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        user_metrics: Map<ContractAddress, UserMetrics>,
        delegations: Map<ContractAddress, ContractAddress>, // delegator -> delegate
        delegated_power: Map<ContractAddress, u256>, // delegate -> total delegated power
        snapshots: Map<(ContractAddress, u64), VotingPowerSnapshot>,
        snapshot_count: Map<ContractAddress, u64>,
        
        // Configuration parameters
        token_weight: u256,
        service_weight: u256,
        reputation_weight: u256,
        time_multiplier_base: u256,
        max_delegation_count: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        VotingPowerUpdated: VotingPowerUpdated,
        PowerDelegated: PowerDelegated,
        DelegationRevoked: DelegationRevoked,
        SnapshotCreated: SnapshotCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct VotingPowerUpdated {
        #[key]
        user: ContractAddress,
        old_power: u256,
        new_power: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PowerDelegated {
        #[key]
        delegator: ContractAddress,
        #[key]
        delegate: ContractAddress,
        power: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct DelegationRevoked {
        #[key]
        delegator: ContractAddress,
        #[key]
        delegate: ContractAddress,
        power: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct SnapshotCreated {
        #[key]
        user: ContractAddress,
        power: u256,
        timestamp: u64,
        block_number: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_weight: u256,
        service_weight: u256,
        reputation_weight: u256,
        time_multiplier_base: u256
    ) {
        self.token_weight.write(token_weight);
        self.service_weight.write(service_weight);
        self.reputation_weight.write(reputation_weight);
        self.time_multiplier_base.write(time_multiplier_base);
        self.max_delegation_count.write(10); // Max 10 delegations per user
    }

    #[abi(embed_v0)]
    impl VotingPowerImpl of IVotingPower<ContractState> {
        fn calculate_voting_power(self: @ContractState, user: ContractAddress) -> u256 {
            let metrics = self.user_metrics.entry(user).read();
            let current_time = get_block_timestamp();
            
            if metrics.join_timestamp == 0 {
                return 0;
            }
            
            // Base power calculation from metrics
            let token_power = metrics.token_balance * self.token_weight.read() / 1000;
            let service_power = metrics.service_count * self.service_weight.read();
            let reputation_power = metrics.reputation_score * self.reputation_weight.read() / 100;
            
            let base_power = token_power + service_power + reputation_power;
            
            // Time-weighted multiplier (longer participation = higher multiplier)
            let participation_time = current_time - metrics.join_timestamp;
            let time_bonus = self._calculate_time_bonus(participation_time);
            
            let total_power = base_power * (1000 + time_bonus) / 1000;
            
            // Add delegated power if this user is a delegate
            let delegated_power = self.delegated_power.entry(user).read();
            
            total_power + delegated_power
        }

        fn update_user_metrics(
            ref self: ContractState,
            user: ContractAddress,
            token_balance: u256,
            service_count: u256,
            reputation_score: u256
        ) {
            let current_time = get_block_timestamp();
            let mut metrics = self.user_metrics.entry(user).read();
            let old_power = self.calculate_voting_power(user);
            
            // Initialize if first time
            if metrics.join_timestamp == 0 {
                metrics.join_timestamp = current_time;
            }
            
            metrics.token_balance = token_balance;
            metrics.service_count = service_count;
            metrics.reputation_score = reputation_score;
            metrics.last_update = current_time;
            
            self.user_metrics.entry(user).write(metrics);
            
            let new_power = self.calculate_voting_power(user);
            
            // Create snapshot for historical tracking
            self._create_snapshot(user, new_power);
            
            self.emit(VotingPowerUpdated {
                user,
                old_power,
                new_power,
                timestamp: current_time,
            });
        }

        fn get_voting_power(self: @ContractState, user: ContractAddress) -> u256 {
            self.calculate_voting_power(user)
        }

        fn delegate_voting_power(ref self: ContractState, delegate: ContractAddress) {
            let caller = get_caller_address();
            assert(caller != delegate, 'Cannot delegate to self');
            
            // Check if already delegated
            let current_delegate = self.delegations.entry(caller).read();
            if current_delegate.is_non_zero() {
                // Remove from current delegate first
                let power = self.get_voting_power(caller);
                let current_delegated = self.delegated_power.entry(current_delegate).read();
                self.delegated_power.entry(current_delegate).write(current_delegated - power);
                
                self.emit(DelegationRevoked {
                    delegator: caller,
                    delegate: current_delegate,
                    power,
                });
            }
            
            // Add to new delegate
            let power = self.get_voting_power(caller);
            let delegated_power = self.delegated_power.entry(delegate).read();
            self.delegated_power.entry(delegate).write(delegated_power + power);
            self.delegations.entry(caller).write(delegate);
            
            self.emit(PowerDelegated {
                delegator: caller,
                delegate,
                power,
            });
        }

        fn revoke_delegation(ref self: ContractState) {
            let caller = get_caller_address();
            let delegate = self.delegations.entry(caller).read();
            
            assert(delegate.is_non_zero(), 'No active delegation');
            
            let power = self.get_voting_power(caller);
            let current_delegated = self.delegated_power.entry(delegate).read();
            self.delegated_power.entry(delegate).write(current_delegated - power);
            
            // Clear delegation
            self.delegations.entry(caller).write(starknet::contract_address_const::<0>());
            
            self.emit(DelegationRevoked {
                delegator: caller,
                delegate,
                power,
            });
        }

        fn get_delegated_power(self: @ContractState, delegate: ContractAddress) -> u256 {
            self.delegated_power.entry(delegate).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _calculate_time_bonus(self: @ContractState, participation_time: u64) -> u256 {
            // Calculate time bonus: max 50% bonus for 2+ years participation
            let days = participation_time / 86400; // seconds to days
            let base_multiplier = self.time_multiplier_base.read();
            
            if days < 30 {
                0 // No bonus for less than 30 days
            } else if days < 365 {
                (days - 30) * base_multiplier / 365 // Linear increase for first year
            } else {
                let year_bonus = base_multiplier;
                let additional_years = (days - 365) / 365;
                let additional_bonus = additional_years * base_multiplier / 4; // 25% per additional year
                let max_bonus = base_multiplier * 2; // Cap at 200% of base
                
                if year_bonus + additional_bonus > max_bonus {
                    max_bonus
                } else {
                    year_bonus + additional_bonus
                }
            }
        }

        fn _create_snapshot(ref self: ContractState, user: ContractAddress, power: u256) {
            let current_time = get_block_timestamp();
            let current_block = get_block_number();
            let snapshot_id = self.snapshot_count.entry(user).read() + 1;
            
            let snapshot = VotingPowerSnapshot {
                user,
                power,
                timestamp: current_time,
                block_number: current_block,
            };
            
            self.snapshots.entry((user, snapshot_id)).write(snapshot);
            self.snapshot_count.entry(user).write(snapshot_id);
            
            self.emit(SnapshotCreated {
                user,
                power,
                timestamp: current_time,
                block_number: current_block,
            });
        }
    }
}