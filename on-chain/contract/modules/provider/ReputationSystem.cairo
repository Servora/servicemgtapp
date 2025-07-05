reputation system task

use starknet::ContractAddress;
use starknet::get_block_timestamp;

#[starknet::interface]
trait IReputationSystem<TContractState> {
    fn update_reputation(
        ref self: TContractState,
        provider: ContractAddress,
        rating: u8,
        completion_status: bool,
        response_time: u64,
        dispute_occurred: bool
    );
    fn calculate_reputation_score(
        self: @TContractState,
        provider: ContractAddress
    ) -> u64;
    fn get_provider_reputation(
        self: @TContractState,
        provider: ContractAddress
    ) -> ProviderReputation;
    fn penalize_provider(
        ref self: TContractState,
        provider: ContractAddress,
        penalty_type: PenaltyType,
        severity: u8
    );
    fn get_reputation_history(
        self: @TContractState,
        provider: ContractAddress,
        limit: u32
    ) -> Array<ReputationEntry>;
    fn get_provider_ranking(
        self: @TContractState,
        start_index: u32,
        limit: u32
    ) -> Array<ProviderRanking>;
    fn update_reputation_weights(
        ref self: TContractState,
        rating_weight: u8,
        completion_weight: u8,
        response_time_weight: u8,
        dispute_weight: u8
    );
    fn get_reputation_weights(self: @TContractState) -> ReputationWeights;
}

#[derive(Drop, Serde, starknet::Store)]
struct ProviderReputation {
    provider: ContractAddress,
    reputation_score: u64,
    total_ratings: u32,
    average_rating: u64,
    completion_rate: u64,
    average_response_time: u64,
    dispute_count: u32,
    last_updated: u64,
    reputation_tier: ReputationTier,
    is_active: bool
}

#[derive(Drop, Serde, starknet::Store)]
struct ReputationEntry {
    timestamp: u64,
    reputation_score: u64,
    rating: u8,
    completion_status: bool,
    response_time: u64,
    dispute_occurred: bool,
    penalty_applied: bool
}

#[derive(Drop, Serde, starknet::Store)]
struct ProviderRanking {
    provider: ContractAddress,
    reputation_score: u64,
    rank: u32,
    reputation_tier: ReputationTier
}

#[derive(Drop, Serde, starknet::Store)]
struct ReputationWeights {
    rating_weight: u8,
    completion_weight: u8,
    response_time_weight: u8,
    dispute_weight: u8
}

#[derive(Drop, Serde, starknet::Store)]
struct PerformanceMetrics {
    total_services: u32,
    completed_services: u32,
    total_response_time: u64,
    total_rating_sum: u64,
    dispute_count: u32,
    penalty_count: u32,
    first_service_timestamp: u64,
    last_service_timestamp: u64
}

#[derive(Drop, Serde, starknet::Store)]
enum ReputationTier {
    Bronze,
    Silver,
    Gold,
    Platinum,
    Diamond
}

#[derive(Drop, Serde, starknet::Store)]
enum PenaltyType {
    MinorViolation,
    MajorViolation,
    ServiceFailure,
    DisputeLoss,
    FraudAttempt
}

#[starknet::contract]
mod ReputationSystem {
    use super::{
        IReputationSystem, ProviderReputation, ReputationEntry, ProviderRanking,
        ReputationWeights, PerformanceMetrics, ReputationTier, PenaltyType
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        provider_reputations: Map<ContractAddress, ProviderReputation>,
        provider_metrics: Map<ContractAddress, PerformanceMetrics>,
        reputation_history: Map<(ContractAddress, u32), ReputationEntry>,
        provider_history_count: Map<ContractAddress, u32>,
        reputation_weights: ReputationWeights,
        total_providers: u32,
        provider_rankings: Map<u32, ContractAddress>,
        ranking_last_updated: u64,
        authorized_updaters: Map<ContractAddress, bool>,
        
        // Reputation decay parameters
        decay_rate: u64,
        decay_period: u64,
        min_reputation_score: u64,
        max_reputation_score: u64,
        
        // Anti-manipulation parameters
        min_services_for_ranking: u32,
        max_rating_impact: u64,
        dispute_cooldown: u64
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ReputationUpdated: ReputationUpdated,
        ProviderPenalized: ProviderPenalized,
        ReputationWeightsUpdated: ReputationWeightsUpdated,
        ProviderRankingUpdated: ProviderRankingUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct ReputationUpdated {
        provider: ContractAddress,
        old_score: u64,
        new_score: u64,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct ProviderPenalized {
        provider: ContractAddress,
        penalty_type: PenaltyType,
        severity: u8,
        score_reduction: u64,
        timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    struct ReputationWeightsUpdated {
        rating_weight: u8,
        completion_weight: u8,
        response_time_weight: u8,
        dispute_weight: u8
    }

    #[derive(Drop, starknet::Event)]
    struct ProviderRankingUpdated {
        provider: ContractAddress,
        old_rank: u32,
        new_rank: u32,
        reputation_score: u64
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        rating_weight: u8,
        completion_weight: u8,
        response_time_weight: u8,
        dispute_weight: u8
    ) {
        assert(rating_weight + completion_weight + response_time_weight + dispute_weight == 100, 'Invalid weights sum');
        
        self.owner.write(owner);
        self.reputation_weights.write(ReputationWeights {
            rating_weight,
            completion_weight,
            response_time_weight,
            dispute_weight
        });
        
        // Initialize parameters
        self.decay_rate.write(5); 
        self.decay_period.write(2592000); 
        self.min_reputation_score.write(0);
        self.max_reputation_score.write(10000);
        self.min_services_for_ranking.write(5);
        self.max_rating_impact.write(500);
        self.dispute_cooldown.write(86400); 
        
        self.total_providers.write(0);
        self.ranking_last_updated.write(get_block_timestamp());
    }

    #[abi(embed_v0)]
    impl ReputationSystemImpl of IReputationSystem<ContractState> {
        fn update_reputation(
            ref self: ContractState,
            provider: ContractAddress,
            rating: u8,
            completion_status: bool,
            response_time: u64,
            dispute_occurred: bool
        ) {
            self._assert_authorized();
            assert(rating >= 1 && rating <= 5, 'Invalid rating');
            
            let current_timestamp = get_block_timestamp();
            let mut reputation = self.provider_reputations.read(provider);
            let mut metrics = self.provider_metrics.read(provider);
            
            // Initialize if new provider
            if reputation.provider.is_zero() {
                reputation.provider = provider;
                reputation.reputation_score = 5000; 
                reputation.is_active = true;
                reputation.reputation_tier = ReputationTier::Bronze;
                metrics.first_service_timestamp = current_timestamp;
                self.total_providers.write(self.total_providers.read() + 1);
            }
            
            let old_score = reputation.reputation_score;
            
            // Apply reputation decay
            self._apply_reputation_decay(ref reputation, current_timestamp);
            
            // Update metrics
            metrics.total_services += 1;
            if completion_status {
                metrics.completed_services += 1;
            }
            metrics.total_response_time += response_time;
            metrics.total_rating_sum += rating.into();
            if dispute_occurred {
                metrics.dispute_count += 1;
            }
            metrics.last_service_timestamp = current_timestamp;
            
            // Calculate new reputation components
            let completion_rate = if metrics.total_services > 0 {
                (metrics.completed_services * 10000) / metrics.total_services
            } else {
                0
            };
            
            let average_rating = if metrics.total_services > 0 {
                (metrics.total_rating_sum * 1000) / metrics.total_services.into()
            } else {
                0
            };
            
            let average_response_time = if metrics.total_services > 0 {
                metrics.total_response_time / metrics.total_services.into()
            } else {
                0
            };
            
            // Calculate reputation score
            let new_score = self._calculate_score(
                average_rating,
                completion_rate,
                average_response_time,
                metrics.dispute_count,
                metrics.total_services
            );
            
            // Update reputation
            reputation.reputation_score = new_score;
            reputation.total_ratings = metrics.total_services;
            reputation.average_rating = average_rating;
            reputation.completion_rate = completion_rate;
            reputation.average_response_time = average_response_time;
            reputation.dispute_count = metrics.dispute_count;
            reputation.last_updated = current_timestamp;
            reputation.reputation_tier = self._calculate_tier(new_score);
            
            // Store updates
            self.provider_reputations.write(provider, reputation);
            self.provider_metrics.write(provider, metrics);
            
            // Add to history
            self._add_reputation_history(
                provider,
                current_timestamp,
                new_score,
                rating,
                completion_status,
                response_time,
                dispute_occurred,
                false
            );
            
            // Emit event
            self.emit(ReputationUpdated {
                provider,
                old_score,
                new_score,
                timestamp: current_timestamp
            });
        }
        
        fn calculate_reputation_score(
            self: @ContractState,
            provider: ContractAddress
        ) -> u64 {
            let reputation = self.provider_reputations.read(provider);
            if reputation.provider.is_zero() {
                return 0;
            }
            
            let metrics = self.provider_metrics.read(provider);
            let current_timestamp = get_block_timestamp();
            
            // Apply decay calculation
            let time_since_last_update = current_timestamp - reputation.last_updated;
            let decay_periods = time_since_last_update / self.decay_period.read();
            
            if decay_periods == 0 {
                return reputation.reputation_score;
            }
            
            // Calculate decayed score
            let decay_factor = self._calculate_decay_factor(decay_periods);
            let decayed_score = (reputation.reputation_score * decay_factor) / 10000;
            
            // Ensure minimum score
            if decayed_score < self.min_reputation_score.read() {
                self.min_reputation_score.read()
            } else {
                decayed_score
            }
        }
        
        fn get_provider_reputation(
            self: @ContractState,
            provider: ContractAddress
        ) -> ProviderReputation {
            let mut reputation = self.provider_reputations.read(provider);
            if !reputation.provider.is_zero() {
                // Apply real-time decay calculation
                reputation.reputation_score = self.calculate_reputation_score(provider);
            }
            reputation
        }
        
        fn penalize_provider(
            ref self: ContractState,
            provider: ContractAddress,
            penalty_type: PenaltyType,
            severity: u8
        ) {
            self._assert_authorized();
            assert(severity >= 1 && severity <= 10, 'Invalid severity');
            
            let mut reputation = self.provider_reputations.read(provider);
            assert(!reputation.provider.is_zero(), 'Provider not found');
            
            let current_timestamp = get_block_timestamp();
            let old_score = reputation.reputation_score;
            
            // Calculate penalty amount based on type and severity
            let penalty_amount = match penalty_type {
                PenaltyType::MinorViolation => severity.into() * 50,
                PenaltyType::MajorViolation => severity.into() * 150,
                PenaltyType::ServiceFailure => severity.into() * 100,
                PenaltyType::DisputeLoss => severity.into() * 200,
                PenaltyType::FraudAttempt => severity.into() * 500
            };
            
            // Apply penalty
            let new_score = if reputation.reputation_score > penalty_amount {
                reputation.reputation_score - penalty_amount
            } else {
                self.min_reputation_score.read()
            };
            
            reputation.reputation_score = new_score;
            reputation.last_updated = current_timestamp;
            reputation.reputation_tier = self._calculate_tier(new_score);
            
            // Update metrics
            let mut metrics = self.provider_metrics.read(provider);
            metrics.penalty_count += 1;
            
            // Store updates
            self.provider_reputations.write(provider, reputation);
            self.provider_metrics.write(provider, metrics);
            
            // Add to history
            self._add_reputation_history(
                provider,
                current_timestamp,
                new_score,
                0,
                false,
                0,
                false,
                true
            );
            
            // Emit event
            self.emit(ProviderPenalized {
                provider,
                penalty_type,
                severity,
                score_reduction: penalty_amount,
                timestamp: current_timestamp
            });
        }
        
        fn get_reputation_history(
            self: @ContractState,
            provider: ContractAddress,
            limit: u32
        ) -> Array<ReputationEntry> {
            let mut history = ArrayTrait::new();
            let history_count = self.provider_history_count.read(provider);
            
            let start_index = if history_count > limit {
                history_count - limit
            } else {
                0
            };
            
            let mut i = start_index;
            loop {
                if i >= history_count {
                    break;
                }
                
                let entry = self.reputation_history.read((provider, i));
                history.append(entry);
                i += 1;
            };
            
            history
        }
        
        fn get_provider_ranking(
            self: @ContractState,
            start_index: u32,
            limit: u32
        ) -> Array<ProviderRanking> {
            let mut rankings = ArrayTrait::new();
            let total_providers = self.total_providers.read();
            
            let end_index = if start_index + limit > total_providers {
                total_providers
            } else {
                start_index + limit
            };
            
            let mut i = start_index;
            loop {
                if i >= end_index {
                    break;
                }
                
                let provider = self.provider_rankings.read(i);
                if !provider.is_zero() {
                    let reputation = self.get_provider_reputation(provider);
                    rankings.append(ProviderRanking {
                        provider,
                        reputation_score: reputation.reputation_score,
                        rank: i + 1,
                        reputation_tier: reputation.reputation_tier
                    });
                }
                i += 1;
            };
            
            rankings
        }
        
        fn update_reputation_weights(
            ref self: ContractState,
            rating_weight: u8,
            completion_weight: u8,
            response_time_weight: u8,
            dispute_weight: u8
        ) {
            self._assert_owner();
            assert(rating_weight + completion_weight + response_time_weight + dispute_weight == 100, 'Invalid weights sum');
            
            self.reputation_weights.write(ReputationWeights {
                rating_weight,
                completion_weight,
                response_time_weight,
                dispute_weight
            });
            
            self.emit(ReputationWeightsUpdated {
                rating_weight,
                completion_weight,
                response_time_weight,
                dispute_weight
            });
        }
        
        fn get_reputation_weights(self: @ContractState) -> ReputationWeights {
            self.reputation_weights.read()
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'Not authorized');
        }
        
        fn _assert_authorized(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                caller == self.owner.read() || self.authorized_updaters.read(caller),
                'Not authorized'
            );
        }
        
        fn _calculate_score(
            self: @ContractState,
            average_rating: u64,
            completion_rate: u64,
            average_response_time: u64,
            dispute_count: u32,
            total_services: u32
        ) -> u64 {
            let weights = self.reputation_weights.read();
            
            // Rating score (1-5 scale to 0-10000)
            let rating_score = (average_rating * 2000) / 1000;
            
            // Completion rate score (0-100% to 0-10000)
            let completion_score = completion_rate;
            
            // Response time score (inverse relationship, capped at reasonable limits)
            let response_score = if average_response_time == 0 {
                10000
            } else if average_response_time > 86400 { // > 24 hours
                1000
            } else {
                10000 - ((average_response_time * 9000) / 86400)
            };
            
            // Dispute penalty
            let dispute_penalty = if total_services > 0 {
                (dispute_count.into() * 2000) / total_services.into()
            } else {
                0
            };
            let dispute_score = if dispute_penalty > 10000 {
                0
            } else {
                10000 - dispute_penalty
            };
            
            // Weighted average
            let weighted_score = (
                (rating_score * weights.rating_weight.into()) +
                (completion_score * weights.completion_weight.into()) +
                (response_score * weights.response_time_weight.into()) +
                (dispute_score * weights.dispute_weight.into())
            ) / 100;
            
            // Ensure within bounds
            if weighted_score > self.max_reputation_score.read() {
                self.max_reputation_score.read()
            } else if weighted_score < self.min_reputation_score.read() {
                self.min_reputation_score.read()
            } else {
                weighted_score
            }
        }
        
        fn _calculate_tier(self: @ContractState, score: u64) -> ReputationTier {
            if score >= 9000 {
                ReputationTier::Diamond
            } else if score >= 7500 {
                ReputationTier::Platinum
            } else if score >= 6000 {
                ReputationTier::Gold
            } else if score >= 4000 {
                ReputationTier::Silver
            } else {
                ReputationTier::Bronze
            }
        }
        
        fn _apply_reputation_decay(
            self: @ContractState,
            ref reputation: ProviderReputation,
            current_timestamp: u64
        ) {
            let time_since_last_update = current_timestamp - reputation.last_updated;
            let decay_periods = time_since_last_update / self.decay_period.read();
            
            if decay_periods > 0 {
                let decay_factor = self._calculate_decay_factor(decay_periods);
                let decayed_score = (reputation.reputation_score * decay_factor) / 10000;
                
                reputation.reputation_score = if decayed_score < self.min_reputation_score.read() {
                    self.min_reputation_score.read()
                } else {
                    decayed_score
                };
                
                reputation.last_updated = current_timestamp;
                reputation.reputation_tier = self._calculate_tier(reputation.reputation_score);
            }
        }
        
        fn _calculate_decay_factor(self: @ContractState, decay_periods: u64) -> u64 {
            let decay_rate = self.decay_rate.read();
            let mut factor = 10000;
            
            let mut i = 0;
            loop {
                if i >= decay_periods {
                    break;
                }
                factor = (factor * (10000 - decay_rate)) / 10000;
                i += 1;
            };
            
            factor
        }
        
        fn _add_reputation_history(
            ref self: ContractState,
            provider: ContractAddress,
            timestamp: u64,
            reputation_score: u64,
            rating: u8,
            completion_status: bool,
            response_time: u64,
            dispute_occurred: bool,
            penalty_applied: bool
        ) {
            let history_count = self.provider_history_count.read(provider);
            
            let entry = ReputationEntry {
                timestamp,
                reputation_score,
                rating,
                completion_status,
                response_time,
                dispute_occurred,
                penalty_applied
            };
            
            self.reputation_history.write((provider, history_count), entry);
            self.provider_history_count.write(provider, history_count + 1);
        }
    }
}