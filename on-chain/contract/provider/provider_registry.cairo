use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;
use array::ArrayTrait;
use option::OptionTrait;
use traits::Into;
use zeroable::Zeroable;

use verification::interfaces::{IProviderRegistry, Provider};

// Service category struct
#[derive(Copy, Drop, Serde, starknet::Store)]
struct ServiceCategory {
    id: u8,
    name: felt252,
    description: felt252,
    active: bool,
}

// Service listing struct
#[derive(Copy, Drop, Serde, starknet::Store)]
struct ServiceListing {
    id: u256,
    provider_id: u256,
    category_id: u8,
    title: felt252,
    description: felt252,
    price: u256,
    active: bool,
    created_at: u64,
    updated_at: u64,
}

// Reputation struct
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Reputation {
    provider_id: u256,
    rating_sum: u256,
    rating_count: u256,
    last_updated: u64,
}

// Rating struct
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Rating {
    id: u256,
    provider_id: u256,
    user_address: ContractAddress,
    score: u8,
    comment: felt252,
    timestamp: u64,
}

#[starknet::contract]
mod ProviderRegistry {
    use super::{
        ContractAddress, ServiceCategory, ServiceListing, Rating, Reputation,
        get_caller_address, get_block_timestamp, ArrayTrait
    };
    use verification::interfaces::Provider;
    use starknet::{get_contract_address, contract_address_const};
    use traits::{Into, TryInto};
    use option::OptionTrait;
    use zeroable::Zeroable;
    use array::SpanTrait;
    use dict::Felt252DictTrait;
    
    #[storage]
    struct Storage {
        // Admin and access control
        admin: ContractAddress,
        authorized_verifiers: LegacyMap<ContractAddress, bool>,
        
        // Provider management
        providers: LegacyMap<u256, Provider>,
        provider_by_address: LegacyMap<ContractAddress, u256>,
        provider_counter: u256,
        
        // Service categories
        service_categories: LegacyMap<u32, ServiceCategory>,
        category_counter: u32,
        
        // Service listings
        service_listings: LegacyMap<u256, ServiceListing>,
        service_counter: u256,
        provider_services: LegacyMap<(u256, u32), u256>, // (provider_id, index) -> service_id
        provider_service_count: LegacyMap<u256, u32>,
        category_services: LegacyMap<(u32, u32), u256>, // (category_id, index) -> service_id
        category_service_count: LegacyMap<u32, u32>,
        
        // Ratings and reputation
        ratings: LegacyMap<u256, Rating>,
        rating_counter: u256,
        provider_ratings: LegacyMap<(u256, u32), u256>, // (provider_id, index) -> rating_id
        provider_rating_count: LegacyMap<u256, u32>,
        user_ratings: LegacyMap<(ContractAddress, u32), u256>, // (user_address, index) -> rating_id
        user_rating_count: LegacyMap<ContractAddress, u32>,
        provider_reputations: LegacyMap<u256, Reputation>,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProviderRegistered: ProviderRegistered,
        ProviderUpdated: ProviderUpdated,
        ProviderVerified: ProviderVerified,
        ServiceCategoryCreated: ServiceCategoryCreated,
        ServiceCategoryUpdated: ServiceCategoryUpdated,
        ServiceListingCreated: ServiceListingCreated,
        ServiceListingUpdated: ServiceListingUpdated,
        RatingSubmitted: RatingSubmitted,
        ReputationUpdated: ReputationUpdated,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ProviderRegistered {
        provider_id: u256,
        provider_address: ContractAddress,
        name: felt252,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ProviderUpdated {
        provider_id: u256,
        name: felt252,
        active: bool,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ProviderVerified {
        provider_id: u256,
        verified: bool,
        verifier: ContractAddress,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ServiceCategoryCreated {
        category_id: u32,
        name: felt252,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ServiceCategoryUpdated {
        category_id: u32,
        name: felt252,
        active: bool,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ServiceListingCreated {
        service_id: u256,
        provider_id: u256,
        category_id: u32,
        title: felt252,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ServiceListingUpdated {
        service_id: u256,
        title: felt252,
        price: u256,
        active: bool,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct RatingSubmitted {
        rating_id: u256,
        provider_id: u256,
        user_address: ContractAddress,
        score: u8,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ReputationUpdated {
        provider_id: u256,
        average_score: u8,
        total_ratings: u32,
        timestamp: u64,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        self.admin.write(admin_address);
        self.authorized_verifiers.write(admin_address, true);
    }
    
    // Provider Registry Implementation
    #[external(v0)]
    impl ProviderRegistryImpl of verification::interfaces::IProviderRegistry {
        fn get_provider(self: @ContractState, provider_id: u256) -> Provider {
            let provider = self.providers.read(provider_id);
            assert(provider.id == provider_id, 'Provider not found');
            provider
        }
        
        fn is_verified_provider(self: @ContractState, provider_address: ContractAddress) -> bool {
            let provider_id = self.provider_by_address.read(provider_address);
            if (provider_id.is_zero()) {
                return false;
            }
            
            let provider = self.providers.read(provider_id);
            provider.verified && provider.active
        }
        
        fn update_verification_status(ref self: ContractState, provider_address: ContractAddress, status: bool) {
            // Only authorized verifiers can update verification status
            let caller = get_caller_address();
            assert(self.authorized_verifiers.read(caller), 'Not authorized');
            
            let provider_id = self.provider_by_address.read(provider_address);
            assert(!provider_id.is_zero(), 'Provider not found');
            
            let mut provider = self.providers.read(provider_id);
            provider.verified = status;
            self.providers.write(provider_id, provider);
            
            // Emit event
            self.emit(ProviderVerified {
                provider_id: provider_id,
                verified: status,
                verifier: caller,
                timestamp: get_block_timestamp(),
            });
        }
    }
    
    // Extended Provider Registry Implementation
    #[external(v0)]
    impl ProviderRegistryExtendedImpl of provider::interfaces::IProviderRegistryExtended {
        // Provider Management
        fn register_provider(
            ref self: ContractState,
            provider_address: ContractAddress,
            name: felt252
        ) -> u256 {
            // Check if provider already exists
            let existing_id = self.provider_by_address.read(provider_address);
            assert(existing_id.is_zero(), 'Provider already registered');
            
            // Increment provider counter
            let provider_id = self.provider_counter.read() + 1.into();
            self.provider_counter.write(provider_id);
            
            // Create and store the provider
            let current_time = get_block_timestamp();
            let provider = Provider {
                id: provider_id,
                address: provider_address,
                name: name,
                verified: false,
                active: true,
                registration_date: current_time,
            };
            
            self.providers.write(provider_id, provider);
            self.provider_by_address.write(provider_address, provider_id);
            
            // Initialize provider reputation
            let reputation = Reputation {
                provider_id: provider_id,
                average_score: 0,
                total_ratings: 0,
                last_updated: current_time,
            };
            self.provider_reputations.write(provider_id, reputation);
            
            // Emit event
            self.emit(ProviderRegistered {
                provider_id: provider_id,
                provider_address: provider_address,
                name: name,
                timestamp: current_time,
            });
            
            provider_id
        }
        
        fn update_provider(
            ref self: ContractState,
            provider_id: u256,
            name: felt252,
            active: bool
        ) {
            // Only provider or admin can update provider
            let caller = get_caller_address();
            let provider = self.providers.read(provider_id);
            
            assert(provider.id == provider_id, 'Provider not found');
            assert(
                caller == provider.address || caller == self.admin.read(),
                'Not authorized'
            );
            
            // Update provider
            let mut updated_provider = provider;
            updated_provider.name = name;
            updated_provider.active = active;
            
            self.providers.write(provider_id, updated_provider);
            
            // Emit event
            self.emit(ProviderUpdated {
                provider_id: provider_id,
                name: name,
                active: active,
                timestamp: get_block_timestamp(),
            });
        }
        
        fn get_provider_by_address(self: @ContractState, provider_address: ContractAddress) -> Provider {
            let provider_id = self.provider_by_address.read(provider_address);
            assert(!provider_id.is_zero(), 'Provider not found');
            
            self.providers.read(provider_id)
        }
        
        // Service Category Management
        fn create_service_category(
            ref self: ContractState,
            name: felt252,
            description: felt252
        ) -> u32 {
            // Only admin can create service categories
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Only admin can create categories');
            
            // Increment category counter
            let category_id = self.category_counter.read() + 1;
            self.category_counter.write(category_id);
            
            // Create and store the category
            let current_time = get_block_timestamp();
            let category = ServiceCategory {
                id: category_id,
                name: name,
                description: description,
                active: true,
                created_at: current_time,
                updated_at: current_time,
            };
            
            self.service_categories.write(category_id, category);
            
            // Emit event
            self.emit(ServiceCategoryCreated {
                category_id: category_id,
                name: name,
                timestamp: current_time,
            });
            
            category_id
        }
        
        fn update_service_category(
            ref self: ContractState,
            category_id: u32,
            name: felt252,
            description: felt252,
            active: bool
        ) {
            // Only admin can update service categories
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Only admin can update categories');
            
            // Check if category exists
            let category = self.service_categories.read(category_id);
            assert(category.id == category_id, 'Category not found');
            
            // Update category
            let current_time = get_block_timestamp();
            let updated_category = ServiceCategory {
                id: category_id,
                name: name,
                description: description,
                active: active,
                created_at: category.created_at,
                updated_at: current_time,
            };
            
            self.service_categories.write(category_id, updated_category);
            
            // Emit event
            self.emit(ServiceCategoryUpdated {
                category_id: category_id,
                name: name,
                active: active,
                timestamp: current_time,
            });
        }
        
        fn get_service_category(self: @ContractState, category_id: u32) -> ServiceCategory {
            let category = self.service_categories.read(category_id);
            assert(category.id == category_id, 'Category not found');
            category
        }
        
        fn get_all_service_categories(self: @ContractState) -> Array<ServiceCategory> {
            let count = self.category_counter.read();
            let mut categories = ArrayTrait::new();
            
            let mut i: u32 = 1;
            while i <= count {
                let category = self.service_categories.read(i);
                if (category.id == i) {
                    categories.append(category);
                }
                i += 1;
            }
            
            categories
        }
        
        // Service Listing Management
        fn create_service_listing(
            ref self: ContractState,
            category_id: u32,
            title: felt252,
            description: felt252,
            price: u256
        ) -> u256 {
            // Check if category exists and is active
            let category = self.service_categories.read(category_id);
            assert(category.id == category_id, 'Category not found');
            assert(category.active, 'Category not active');
            
            // Get provider ID from caller
            let caller = get_caller_address();
            let provider_id = self.provider_by_address.read(caller);
            assert(!provider_id.is_zero(), 'Not a registered provider');
            
            // Check if provider is active
            let provider = self.providers.read(provider_id);
            assert(provider.active, 'Provider not active');
            
            // Increment service counter
            let service_id = self.service_counter.read() + 1.into();
            self.service_counter.write(service_id);
            
            // Create and store the service listing
            let current_time = get_block_timestamp();
            let service = ServiceListing {
                id: service_id,
                provider_id: provider_id,
                category_id: category_id,
                title: title,
                description: description,
                price: price,
                active: true,
                created_at: current_time,
                updated_at: current_time,
            };
            
            self.service_listings.write(service_id, service);
            
            // Add to provider's services
            let provider_count = self.provider_service_count.read(provider_id);
            self.provider_services.write((provider_id, provider_count), service_id);
            self.provider_service_count.write(provider_id, provider_count + 1);
            
            // Add to category's services
            let category_count = self.category_service_count.read(category_id);
            self.category_services.write((category_id, category_count), service_id);
            self.category_service_count.write(category_id, category_count + 1);
            
            // Emit event
            self.emit(ServiceListingCreated {
                service_id: service_id,
                provider_id: provider_id,
                category_id: category_id,
                title: title,
                timestamp: current_time,
            });
            
            service_id
        }
        
        fn update_service_listing(
            ref self: ContractState,
            service_id: u256,
            title: felt252,
            description: felt252,
            price: u256,
            active: bool
        ) {
            // Get service listing
            let service = self.service_listings.read(service_id);
            assert(service.id == service_id, 'Service not found');
            
            // Check if caller is the provider
            let caller = get_caller_address();
            let provider_id = self.provider_by_address.read(caller);
            
            assert(
                provider_id == service.provider_id || caller == self.admin.read(),
                'Not authorized'
            );
            
            // Update service listing
            let current_time = get_block_timestamp();
            let updated_service = ServiceListing {
                id: service_id,
                provider_id: service.provider_id,
                category_id: service.category_id,
                title: title,
                description: description,
                price: price,
                active: active,
                created_at: service.created_at,
                updated_at: current_time,
            };
            
            self.service_listings.write(service_id, updated_service);
            
            // Emit event
            self.emit(ServiceListingUpdated {
                service_id: service_id,
                title: title,
                price: price,
                active: active,
                timestamp: current_time,
            });
        }
        
        fn get_service_listing(self: @ContractState, service_id: u256) -> ServiceListing {
            let service = self.service_listings.read(service_id);
            assert(service.id == service_id, 'Service not found');
            service
        }
        
        fn get_provider_services(self: @ContractState, provider_id: u256) -> Array<ServiceListing> {
            let count = self.provider_service_count.read(provider_id);
            let mut services = ArrayTrait::new();
            
            let mut i: u32 = 0;
            while i < count {
                let service_id = self.provider_services.read((provider_id, i));
                let service = self.service_listings.read(service_id);
                services.append(service);
                i += 1;
            }
            
            services
        }
        
        fn get_category_services(self: @ContractState, category_id: u32) -> Array<ServiceListing> {
            let count = self.category_service_count.read(category_id);
            let mut services = ArrayTrait::new();
            
            let mut i: u32 = 0;
            while i < count {
                let service_id = self.category_services.read((category_id, i));
                let service = self.service_listings.read(service_id);
                if (service.active) {
                    services.append(service);
                }
                i += 1;
            }
            
            services
        }
        
        // Rating and Reputation Management
        fn submit_rating(
            ref self: ContractState,
            provider_id: u256,
            score: u8,
            comment: felt252
        ) -> u256 {
            // Check if provider exists
            let provider = self.providers.read(provider_id);
            assert(provider.id == provider_id, 'Provider not found');
            
            // Check score range (1-5)
            assert(score >= 1 && score <= 5, 'Invalid score range');
            
            // Get caller as user
            let user_address = get_caller_address();
            
            // Increment rating counter
            let rating_id = self.rating_counter.read() + 1.into();
            self.rating_counter.write(rating_id);
            
            // Create and store the rating
            let current_time = get_block_timestamp();
            let rating = Rating {
                id: rating_id,
                provider_id: provider_id,
                user_address: user_address,
                score: score,
                comment: comment,
                timestamp: current_time,
            };
            
            self.ratings.write(rating_id, rating);
            
            // Add to provider's ratings
            let provider_count = self.provider_rating_count.read(provider_id);
            self.provider_ratings.write((provider_id, provider_count), rating_id);
            self.provider_rating_count.write(provider_id, provider_count + 1);
            
            // Add to user's ratings
            let user_count = self.user_rating_count.read(user_address);
            self.user_ratings.write((user_address, user_count), rating_id);
            self.user_rating_count.write(user_address, user_count + 1);
            
            // Update provider reputation
            self._update_provider_reputation(provider_id);
            
            // Emit event
            self.emit(RatingSubmitted {
                rating_id: rating_id,
                provider_id: provider_id,
                user_address: user_address,
                score: score,
                timestamp: current_time,
            });
            
            rating_id
        }
        
        fn get_rating(self: @ContractState, rating_id: u256) -> Rating {
            let rating = self.ratings.read(rating_id);
            assert(rating.id == rating_id, 'Rating not found');
            rating
        }
        
        fn get_provider_ratings(self: @ContractState, provider_id: u256) -> Array<Rating> {
            let count = self.provider_rating_count.read(provider_id);
            let mut ratings = ArrayTrait::new();
            
            let mut i: u32 = 0;
            while i < count {
                let rating_id = self.provider_ratings.read((provider_id, i));
                let rating = self.ratings.read(rating_id);
                ratings.append(rating);
                i += 1;
            }
            
            ratings
        }
        
        fn get_provider_reputation(self: @ContractState, provider_id: u256) -> Reputation {
            let reputation = self.provider_reputations.read(provider_id);
            assert(reputation.provider_id == provider_id, 'Reputation not found');
            reputation
        }
        
        // Batch Operations for Gas Optimization
        fn batch_get_providers(self: @ContractState, provider_ids: Array<u256>) -> Array<Provider> {
            let mut providers = ArrayTrait::new();
            let mut ids_span = provider_ids.span();
            
            loop {
                match ids_span.pop_front() {
                    Option::Some(id) => {
                        let provider = self.providers.read(*id);
                        if (provider.id == *id) {
                            providers.append(provider);
                        }
                    },
                    Option::None => { break; }
                };
            };
            
            providers
        }
        
        fn batch_get_service_listings(self: @ContractState, service_ids: Array<u256>) -> Array<ServiceListing> {
            let mut services = ArrayTrait::new();
            let mut ids_span = service_ids.span();
            
            loop {
                match ids_span.pop_front() {
                    Option::Some(id) => {
                        let service = self.service_listings.read(*id);
                        if (service.id == *id) {
                            services.append(service);
                        }
                    },
                    Option::None => { break; }
                };
            };
            
            services
        }
    }
    
    // Admin functions
    #[external(v0)]
    fn add_verifier(ref self: ContractState, verifier_address: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can add verifiers');
        self.authorized_verifiers.write(verifier_address, true);
    }
    
    #[external(v0)]
    fn remove_verifier(ref self: ContractState, verifier_address: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can remove verifiers');
        self.authorized_verifiers.write(verifier_address, false);
    }
    
    #[external(v0)]
    fn is_verifier(self: @ContractState, address: ContractAddress) -> bool {
        self.authorized_verifiers.read(address)
    }
    
    #[external(v0)]
    fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can transfer admin');
        assert(!new_admin.is_zero(), 'Invalid admin address');
        self.admin.write(new_admin);
    }
    
    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _update_provider_reputation(ref self: ContractState, provider_id: u256) {
            let count = self.provider_rating_count.read(provider_id);
            if (count == 0) {
                return;
            }
            
            let mut total_score: u64 = 0;
            let mut i: u32 = 0;
            
            while i < count {
                let rating_id = self.provider_ratings.read((provider_id, i));
                let rating = self.ratings.read(rating_id);
                total_score += rating.score.into();
                i += 1;
            }
            
            let average_score: u8 = (total_score / count.into()).try_into().unwrap();
            
            // Update reputation
            let current_time = get_block_timestamp();
            let reputation = Reputation {
                provider_id: provider_id,
                average_score: average_score,
                total_ratings: count,
                last_updated: current_time,
            };
            
            self.provider_reputations.write(provider_id, reputation);
            
            // Emit event
            self.emit(ReputationUpdated {
                provider_id: provider_id,
                average_score: average_score,
                total_ratings: count,
                timestamp: current_time,
            });
        }
    }
}