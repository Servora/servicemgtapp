use starknet::ContractAddress;

#[starknet::interface]
trait IRevenueSharing<TContractState> {
    fn calculate_revenue_share(self: @TContractState, provider: ContractAddress) -> u256;
    fn update_tier_status(ref self: TContractState, provider: ContractAddress);
    fn distribute_revenue(ref self: TContractState, total_revenue: u256);
    fn get_provider_tier(self: @TContractState, provider: ContractAddress) -> u8;
    fn get_tier_requirements(self: @TContractState, tier: u8) -> TierRequirements;
    fn claim_revenue_share(ref self: TContractState);
    fn get_pending_revenue(self: @TContractState, provider: ContractAddress) -> u256;
}

#[derive(Drop, Serde, starknet::Store)]
struct ProviderMetrics {
    total_services: u256,
    completed_services: u256,
    average_rating: u256, 
    total_revenue: u256,
    response_time_avg: u64, 
    dispute_count: u256,
    join_date: u64,
    last_service_date: u64,
    current_tier: u8,
    tier_updated_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct TierRequirements {
    min_services: u256,
    min_rating: u256,
    max_response_time: u64,
    max_dispute_rate: u256, 
    min_completion_rate: u256, 
    revenue_share_percent: u256, 
}

#[derive(Drop, Serde, starknet::Store)]
struct RevenueDistribution {
    period_id: u256,
    total_revenue: u256,
    bronze_share: u256,
    silver_share: u256,
    gold_share: u256,
    platinum_share: u256,
    participants_count: u256,
    timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct ProviderRevenue {
    pending_amount: u256,
    total_earned: u256,
    last_claim_time: u64,
    lifetime_share: u256,
}

#[starknet::contract]
mod RevenueSharing {
    use super::{IRevenueSharing, ProviderMetrics, TierRequirements, RevenueDistribution, ProviderRevenue};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        provider_metrics: Map<ContractAddress, ProviderMetrics>,
        tier_requirements: Map<u8, TierRequirements>,
        revenue_distributions: Map<u256, RevenueDistribution>,
        provider_revenue: Map<ContractAddress, ProviderRevenue>,
        
        distribution_count: u256,
        total_providers_by_tier: Map<u8, u256>,
        
        
        revenue_sharing_token: ContractAddress,
        owner: ContractAddress,
        service_registry: ContractAddress,
        
        
        tier_performance_periods: Map<(ContractAddress, u256), ProviderMetrics>, 
        revenue_sharing_active: bool,
    }

    
    const BRONZE_TIER: u8 = 1;
    const SILVER_TIER: u8 = 2; 
    const GOLD_TIER: u8 = 3;
    const PLATINUM_TIER: u8 = 4;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TierUpdated: TierUpdated,
        RevenueDistributed: RevenueDistributed,
        RevenueShareClaimed: RevenueShareClaimed,
        ProviderMetricsUpdated: ProviderMetricsUpdated,
        TierRequirementsUpdated: TierRequirementsUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct TierUpdated {
        #[key]
        provider: ContractAddress,
        old_tier: u8,
        new_tier: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct RevenueDistributed {
        #[key]
        period_id: u256,
        total_revenue: u256,
        bronze_providers: u256,
        silver_providers: u256,
        gold_providers: u256,
        platinum_providers: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct RevenueShareClaimed {
        #[key]
        provider: ContractAddress,
        amount: u256,
        tier: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProviderMetricsUpdated {
        #[key]
        provider: ContractAddress,
        total_services: u256,
        average_rating: u256,
        completion_rate: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TierRequirementsUpdated {
        tier: u8,
        min_services: u256,
        min_rating: u256,
        revenue_share_percent: u256,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        revenue_sharing_token: ContractAddress,
        owner: ContractAddress,
        service_registry: ContractAddress
    ) {
        self.revenue_sharing_token.write(revenue_sharing_token);
        self.owner.write(owner);
        self.service_registry.write(service_registry);
        self.revenue_sharing_active.write(true);
        
        
        self._initialize_tier_requirements();
    }

    #[abi(embed_v0)]
    impl RevenueSharingImpl of IRevenueSharing<ContractState> {
        fn calculate_revenue_share(self: @ContractState, provider: ContractAddress) -> u256 {
            let metrics = self.provider_metrics.entry(provider).read();
            let tier = metrics.current_tier;
            
            if tier == 0 {
                return 0; 
            }
            
            let requirements = self.tier_requirements.entry(tier).read();
            let base_share = requirements.revenue_share_percent;
            
            
            let performance_multiplier = self._calculate_performance_multiplier(metrics);
            
            
            base_share * performance_multiplier / 100
        }

        fn update_tier_status(ref self: ContractState, provider: ContractAddress) {
            let metrics = self.provider_metrics.entry(provider).read();
            let current_tier = metrics.current_tier;
            let new_tier = self._determine_tier(metrics);
            
            if new_tier != current_tier {
                
                if current_tier > 0 {
                    let old_count = self.total_providers_by_tier.entry(current_tier).read();
                    self.total_providers_by_tier.entry(current_tier).write(old_count - 1);
                }
                
                let new_count = self.total_providers_by_tier.entry(new_tier).read();
                self.total_providers_by_tier.entry(new_tier).write(new_count + 1);
                
                
                let mut updated_metrics = metrics;
                updated_metrics.current_tier = new_tier;
                updated_metrics.tier_updated_at = get_block_timestamp();
                self.provider_metrics.entry(provider).write(updated_metrics);
                
                self.emit(TierUpdated {
                    provider,
                    old_tier: current_tier,
                    new_tier,
                    timestamp: get_block_timestamp(),
                });
            }
        }

        fn distribute_revenue(ref self: ContractState, total_revenue: u256) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Only owner can distribute');
            assert(self.revenue_sharing_active.read(), 'Revenue sharing inactive');
            
            let period_id = self.distribution_count.read() + 1;
            self.distribution_count.write(period_id);
            
            
            let bronze_count = self.total_providers_by_tier.entry(BRONZE_TIER).read();
            let silver_count = self.total_providers_by_tier.entry(SILVER_TIER).read();
            let gold_count = self.total_providers_by_tier.entry(GOLD_TIER).read();
            let platinum_count = self.total_providers_by_tier.entry(PLATINUM_TIER).read();
            
            
            let bronze_weight = bronze_count * 1; 
            let silver_weight = silver_count * 2; 
            let gold_weight = gold_count * 4; 
            let platinum_weight = platinum_count * 8; 
            
            let total_weight = bronze_weight + silver_weight + gold_weight + platinum_weight;
            
            if total_weight == 0 {
                return; 
            }
            
            let bronze_share = total_revenue * bronze_weight / total_weight;
            let silver_share = total_revenue * silver_weight / total_weight;
            let gold_share = total_revenue * gold_weight / total_weight;
            let platinum_share = total_revenue * platinum_weight / total_weight;
            
            
            self._distribute_to_tier_providers(BRONZE_TIER, bronze_share, bronze_count);
            self._distribute_to_tier_providers(SILVER_TIER, silver_share, silver_count);
            self._distribute_to_tier_providers(GOLD_TIER, gold_share, gold_count);
            self._distribute_to_tier_providers(PLATINUM_TIER, platinum_share, platinum_count);
            
            
            let distribution = RevenueDistribution {
                period_id,
                total_revenue,
                bronze_share,
                silver_share,
                gold_share,
                platinum_share,
                participants_count: bronze_count + silver_count + gold_count + platinum_count,
                timestamp: get_block_timestamp(),
            };
            
            self.revenue_distributions.entry(period_id).write(distribution);
            
            self.emit(RevenueDistributed {
                period_id,
                total_revenue,
                bronze_providers: bronze_count,
                silver_providers: silver_count,
                gold_providers: gold_count,
                platinum_providers: platinum_count,
                timestamp: get_block_timestamp(),
            });
        }

        fn get_provider_tier(self: @ContractState, provider: ContractAddress) -> u8 {
            self.provider_metrics.entry(provider).read().current_tier
        }

        fn get_tier_requirements(self: @ContractState, tier: u8) -> TierRequirements {
            self.tier_requirements.entry(tier).read()
        }

        fn claim_revenue_share(ref self: ContractState) {
            let caller = get_caller_address();
            let mut revenue = self.provider_revenue.entry(caller).read();
            
            assert(revenue.pending_amount > 0, 'No revenue to claim');
            
            let amount = revenue.pending_amount;
            revenue.pending_amount = 0;
            revenue.total_earned += amount;
            revenue.last_claim_time = get_block_timestamp();
            
            self.provider_revenue.entry(caller).write(revenue);
            
            
            let token = IERC20Dispatcher { contract_address: self.revenue_sharing_token.read() };
            token.transfer(caller, amount);
            
            let tier = self.provider_metrics.entry(caller).read().current_tier;
            
            self.emit(RevenueShareClaimed {
                provider: caller,
                amount,
                tier,
                timestamp: get_block_timestamp(),
            });
        }

        fn get_pending_revenue(self: @ContractState, provider: ContractAddress) -> u256 {
            self.provider_revenue.entry(provider).read().pending_amount
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _initialize_tier_requirements(ref self: ContractState) {
            
            let bronze = TierRequirements {
                min_services: 10,
                min_rating: 350, 
                max_response_time: 60, 
                max_dispute_rate: 500, 
                min_completion_rate: 8000, 
                revenue_share_percent: 100, 
            };
            self.tier_requirements.entry(BRONZE_TIER).write(bronze);
            
            
            let silver = TierRequirements {
                min_services: 50,
                min_rating: 400, 
                max_response_time: 30, 
                max_dispute_rate: 300, 
                min_completion_rate: 8500, 
                revenue_share_percent: 250, 
            };
            self.tier_requirements.entry(SILVER_TIER).write(silver);
            
            
            let gold = TierRequirements {
                min_services: 200,
                min_rating: 450, 
                max_response_time: 15, 
                max_dispute_rate: 200, 
                min_completion_rate: 9000, 
                revenue_share_percent: 500, 
            };
            self.tier_requirements.entry(GOLD_TIER).write(gold);
            
            
            let platinum = TierRequirements {
                min_services: 500,
                min_rating: 475, 
                max_response_time: 10, 
                max_dispute_rate: 100, 
                min_completion_rate: 9500, 
                revenue_share_percent: 1000, 
            };
            self.tier_requirements.entry(PLATINUM_TIER).write(platinum);
        }

        fn _determine_tier(self: @ContractState, metrics: ProviderMetrics) -> u8 {
            let completion_rate = if metrics.total_services > 0 {
                metrics.completed_services * 10000 / metrics.total_services
            } else {
                0
            };
            
            let dispute_rate = if metrics.total_services > 0 {
                metrics.dispute_count * 10000 / metrics.total_services
            } else {
                0
            };
            
            
            let plat_req = self.tier_requirements.entry(PLATINUM_TIER).read();
            if metrics.total_services >= plat_req.min_services &&
               metrics.average_rating >= plat_req.min_rating &&
               metrics.response_time_avg <= plat_req.max_response_time &&
               dispute_rate <= plat_req.max_dispute_rate &&
               completion_rate >= plat_req.min_completion_rate {
                return PLATINUM_TIER;
            }
            
            
            let gold_req = self.tier_requirements.entry(GOLD_TIER).read();
            if metrics.total_services >= gold_req.min_services &&
               metrics.average_rating >= gold_req.min_rating &&
               metrics.response_time_avg <= gold_req.max_response_time &&
               dispute_rate <= gold_req.max_dispute_rate &&
               completion_rate >= gold_req.min_completion_rate {
                return GOLD_TIER;
            }
            
            
            let silver_req = self.tier_requirements.entry(SILVER_TIER).read();
            if metrics.total_services >= silver_req.min_services &&
               metrics.average_rating >= silver_req.min_rating &&
               metrics.response_time_avg <= silver_req.max_response_time &&
               dispute_rate <= silver_req.max_dispute_rate &&
               completion_rate >= silver_req.min_completion_rate {
                return SILVER_TIER;
            }
            
            
            let bronze_req = self.tier_requirements.entry(BRONZE_TIER).read();
            if metrics.total_services >= bronze_req.min_services &&
               metrics.average_rating >= bronze_req.min_rating &&
               metrics.response_time_avg <= bronze_req.max_response_time &&
               dispute_rate <= bronze_req.max_dispute_rate &&
               completion_rate >= bronze_req.min_completion_rate {
                return BRONZE_TIER;
            }
            
            0 
        }

        fn _calculate_performance_multiplier(self: @ContractState, metrics: ProviderMetrics) -> u256 {
            
            let mut multiplier = 100;
            
            
            if metrics.average_rating >= 475 { 
                multiplier += 20; 
            } else if metrics.average_rating >= 450 { 
                multiplier += 10; 
            }
            
            
            if metrics.response_time_avg <= 5 { 
                multiplier += 15; 
            } else if metrics.response_time_avg <= 15 { 
                multiplier += 5; 
            }
            
            multiplier
        }

        fn _distribute_to_tier_providers(
            ref self: ContractState,
            tier: u8,
            total_share: u256,
            provider_count: u256
        ) {
            if provider_count == 0 {
                return;
            }
            
            let share_per_provider = total_share / provider_count;
            
            
            
        }

        fn _add_provider_revenue(ref self: ContractState, provider: ContractAddress, amount: u256) {
            let mut revenue = self.provider_revenue.entry(provider).read();
            revenue.pending_amount += amount;
            revenue.lifetime_share += amount;
            self.provider_revenue.entry(provider).write(revenue);
        }
    }
}