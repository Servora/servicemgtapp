

#[starknet::contract]
mod ServiceCategories {
    use core::starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use core::traits::Into;

    // Category structure
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct Category {
        id: u32,
        name: felt252,
        description: felt252,
        parent_id: u32, // 0 for root categories
        is_active: bool,
        created_timestamp: u64,
        updated_timestamp: u64,
        creator: ContractAddress,
        service_count: u32,
        popularity_score: u64,
    }

    // Category metadata structure
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct CategoryMetadata {
        min_price_range: u256,
        max_price_range: u256,
        requirements: felt252,
        tags: felt252,
        estimated_duration: u32, // in minutes
        skill_level_required: u8, // 1-5 scale
    }

    // Service mapping structure
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct ServiceMapping {
        service_id: u32,
        category_id: u32,
        subcategory_id: u32,
        mapped_timestamp: u64,
        is_primary: bool,
    }

    // Trending data structure
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct TrendingData {
        category_id: u32,
        view_count: u32,
        booking_count: u32,
        last_updated: u64,
        trending_score: u64,
    }

    // Storage
    #[storage]
    struct Storage {
        // Core category data
        categories: LegacyMap<u32, Category>,
        category_metadata: LegacyMap<u32, CategoryMetadata>,
        category_count: u32,
        
        // Hierarchical relationships
        parent_children: LegacyMap<(u32, u32), bool>, // (parent_id, child_id) -> exists
        child_parent: LegacyMap<u32, u32>, // child_id -> parent_id
        category_depth: LegacyMap<u32, u32>, // category_id -> depth level
        
        // Service mappings
        service_categories: LegacyMap<u32, u32>, // service_id -> primary_category_id
        category_services: LegacyMap<(u32, u32), bool>, // (category_id, service_id) -> exists
        service_mapping_count: u32,
        
        // Search and trending
        trending_data: LegacyMap<u32, TrendingData>,
        category_search_index: LegacyMap<felt252, u32>, // keyword -> category_id
        
        // Access control
        owner: ContractAddress,
        authorized_managers: LegacyMap<ContractAddress, bool>,
        
        // Performance optimization
        root_categories: LegacyMap<u32, bool>, // category_id -> is_root
        max_depth: u32,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CategoryAdded: CategoryAdded,
        CategoryUpdated: CategoryUpdated,
        CategoryRemoved: CategoryRemoved,
        ServiceMapped: ServiceMapped,
        ServiceUnmapped: ServiceUnmapped,
        TrendingUpdated: TrendingUpdated,
        ManagerAuthorized: ManagerAuthorized,
    }

    #[derive(Drop, starknet::Event)]
    struct CategoryAdded {
        category_id: u32,
        name: felt252,
        parent_id: u32,
        creator: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CategoryUpdated {
        category_id: u32,
        updated_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CategoryRemoved {
        category_id: u32,
        removed_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ServiceMapped {
        service_id: u32,
        category_id: u32,
        is_primary: bool,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ServiceUnmapped {
        service_id: u32,
        category_id: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TrendingUpdated {
        category_id: u32,
        new_score: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ManagerAuthorized {
        manager: ContractAddress,
        authorized_by: ContractAddress,
        timestamp: u64,
    }

    // Interface
    #[starknet::interface]
    trait IServiceCategories<TContractState> {
        fn add_category(
            ref self: TContractState,
            name: felt252,
            description: felt252,
            parent_id: u32,
            metadata: CategoryMetadata
        ) -> u32;
        
        fn remove_category(
            ref self: TContractState,
            category_id: u32
        ) -> bool;
        
        fn update_category(
            ref self: TContractState,
            category_id: u32,
            name: felt252,
            description: felt252,
            metadata: CategoryMetadata
        ) -> bool;
        
        fn get_category_tree(
            self: @TContractState,
            root_category_id: u32
        ) -> Array<u32>;
        
        fn search_by_category(
            self: @TContractState,
            keyword: felt252,
            max_results: u32
        ) -> Array<u32>;
        
        fn map_service_to_category(
            ref self: TContractState,
            service_id: u32,
            category_id: u32,
            is_primary: bool
        ) -> bool;
        
        fn get_category_services(
            self: @TContractState,
            category_id: u32
        ) -> Array<u32>;
        
        fn get_trending_categories(
            self: @TContractState,
            limit: u32
        ) -> Array<u32>;
        
        fn update_category_popularity(
            ref self: TContractState,
            category_id: u32,
            view_increment: u32,
            booking_increment: u32
        ) -> bool;
        
        fn get_category_info(
            self: @TContractState,
            category_id: u32
        ) -> (Category, CategoryMetadata);
        
        fn authorize_manager(
            ref self: TContractState,
            manager: ContractAddress
        ) -> bool;
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.category_count.write(0);
        self.service_mapping_count.write(0);
        self.max_depth.write(0);
        
        // Owner is automatically authorized manager
        self.authorized_managers.write(owner, true);
    }

    // External functions
    #[external(v0)]
    impl ServiceCategoriesImpl of IServiceCategories<ContractState> {
        fn add_category(
            ref self: ContractState,
            name: felt252,
            description: felt252,
            parent_id: u32,
            metadata: CategoryMetadata
        ) -> u32 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check authorization
            assert!(self.authorized_managers.read(caller), "Unauthorized manager");
            
            // Validate parent category if not root
            if parent_id != 0 {
                let parent_category = self.categories.read(parent_id);
                assert!(parent_category.is_active, "Parent category inactive");
                
                // Check depth limit (prevent infinite nesting)
                let parent_depth = self.category_depth.read(parent_id);
                assert!(parent_depth < 10, "Maximum category depth exceeded");
            }
            
            // Generate new category ID
            let category_id = self.category_count.read() + 1;
            self.category_count.write(category_id);
            
            // Calculate depth
            let depth = if parent_id == 0 {
                0
            } else {
                self.category_depth.read(parent_id) + 1
            };
            
            // Create category
            let category = Category {
                id: category_id,
                name,
                description,
                parent_id,
                is_active: true,
                created_timestamp: current_time,
                updated_timestamp: current_time,
                creator: caller,
                service_count: 0,
                popularity_score: 0,
            };
            
            // Store category data
            self.categories.write(category_id, category);
            self.category_metadata.write(category_id, metadata);
            self.category_depth.write(category_id, depth);
            
            // Update hierarchical relationships
            if parent_id != 0 {
                self.parent_children.write((parent_id, category_id), true);
                self.child_parent.write(category_id, parent_id);
            } else {
                self.root_categories.write(category_id, true);
            }
            
            // Update max depth
            let current_max_depth = self.max_depth.read();
            if depth > current_max_depth {
                self.max_depth.write(depth);
            }
            
            // Initialize trending data
            let trending_data = TrendingData {
                category_id,
                view_count: 0,
                booking_count: 0,
                last_updated: current_time,
                trending_score: 0,
            };
            self.trending_data.write(category_id, trending_data);
            
            // Add to search index
            self.category_search_index.write(name, category_id);
            
            // Emit event
            self.emit(CategoryAdded {
                category_id,
                name,
                parent_id,
                creator: caller,
                timestamp: current_time,
            });
            
            category_id
        }

        fn remove_category(
            ref self: ContractState,
            category_id: u32
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check authorization
            assert!(self.authorized_managers.read(caller), "Unauthorized manager");
            
            // Get category
            let mut category = self.categories.read(category_id);
            assert!(category.is_active, "Category not found or inactive");
            
            // Check if category has children
            assert!(!self._has_children(category_id), "Cannot remove category with children");
            
            // Check if category has mapped services
            assert!(category.service_count == 0, "Cannot remove category with mapped services");
            
            // Deactivate category
            category.is_active = false;
            category.updated_timestamp = current_time;
            self.categories.write(category_id, category);
            
            // Remove from parent-child relationships
            if category.parent_id != 0 {
                self.parent_children.write((category.parent_id, category_id), false);
                self.child_parent.write(category_id, 0);
            } else {
                self.root_categories.write(category_id, false);
            }
            
            // Remove from search index
            self.category_search_index.write(category.name, 0);
            
            // Emit event
            self.emit(CategoryRemoved {
                category_id,
                removed_by: caller,
                timestamp: current_time,
            });
            
            true
        }

        fn update_category(
            ref self: ContractState,
            category_id: u32,
            name: felt252,
            description: felt252,
            metadata: CategoryMetadata
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check authorization
            assert!(self.authorized_managers.read(caller), "Unauthorized manager");
            
            // Get category
            let mut category = self.categories.read(category_id);
            assert!(category.is_active, "Category not found or inactive");
            
            // Update search index if name changed
            if category.name != name {
                self.category_search_index.write(category.name, 0); // Remove old
                self.category_search_index.write(name, category_id); // Add new
            }
            
            // Update category
            category.name = name;
            category.description = description;
            category.updated_timestamp = current_time;
            
            // Store updates
            self.categories.write(category_id, category);
            self.category_metadata.write(category_id, metadata);
            
            // Emit event
            self.emit(CategoryUpdated {
                category_id,
                updated_by: caller,
                timestamp: current_time,
            });
            
            true
        }

        fn get_category_tree(
            self: @ContractState,
            root_category_id: u32
        ) -> Array<u32> {
            let mut tree = ArrayTrait::new();
            
            // Add root category
            tree.append(root_category_id);
            
            // Recursively add children
            self._get_children_recursive(root_category_id, ref tree);
            
            tree
        }

        fn search_by_category(
            self: @ContractState,
            keyword: felt252,
            max_results: u32
        ) -> Array<u32> {
            let mut results = ArrayTrait::new();
            let mut count = 0;
            
            // Direct keyword match
            let direct_match = self.category_search_index.read(keyword);
            if direct_match != 0 {
                let category = self.categories.read(direct_match);
                if category.is_active {
                    results.append(direct_match);
                    count += 1;
                }
            }
            
            // Search through all categories for partial matches
            let total_categories = self.category_count.read();
            let mut i = 1;
            loop {
                if i > total_categories || count >= max_results {
                    break;
                }
                
                let category = self.categories.read(i);
                if category.is_active && i != direct_match {
                    // Simple substring matching (in production, use more sophisticated search)
                    if self._contains_keyword(category.name, keyword) || 
                       self._contains_keyword(category.description, keyword) {
                        results.append(i);
                        count += 1;
                    }
                }
                
                i += 1;
            };
            
            results
        }

        fn map_service_to_category(
            ref self: ContractState,
            service_id: u32,
            category_id: u32,
            is_primary: bool
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check authorization
            assert!(self.authorized_managers.read(caller), "Unauthorized manager");
            
            // Validate category exists and is active
            let category = self.categories.read(category_id);
            assert!(category.is_active, "Category not found or inactive");
            
            // Check if mapping already exists
            assert!(!self.category_services.read((category_id, service_id)), "Service already mapped");
            
            // Create mapping
            self.category_services.write((category_id, service_id), true);
            
            // Update primary mapping if specified
            if is_primary {
                self.service_categories.write(service_id, category_id);
            }
            
            // Update service count
            let mut updated_category = category;
            updated_category.service_count += 1;
            self.categories.write(category_id, updated_category);
            
            // Increment mapping count
            let mapping_count = self.service_mapping_count.read();
            self.service_mapping_count.write(mapping_count + 1);
            
            // Emit event
            self.emit(ServiceMapped {
                service_id,
                category_id,
                is_primary,
                timestamp: current_time,
            });
            
            true
        }

        fn get_category_services(
            self: @ContractState,
            category_id: u32
        ) -> Array<u32> {
            let mut services = ArrayTrait::new();
            
            // This is a simplified implementation
            // In production, you'd maintain a more efficient index
            let total_mappings = self.service_mapping_count.read();
            let mut i = 1;
            loop {
                if i > total_mappings {
                    break;
                }
                
                if self.category_services.read((category_id, i)) {
                    services.append(i);
                }
                
                i += 1;
            };
            
            services
        }

        fn get_trending_categories(
            self: @ContractState,
            limit: u32
        ) -> Array<u32> {
            let mut trending = ArrayTrait::new();
            let mut added = 0;
            
            // Simple trending algorithm - in production use more sophisticated sorting
            let total_categories = self.category_count.read();
            let mut i = 1;
            loop {
                if i > total_categories || added >= limit {
                    break;
                }
                
                let category = self.categories.read(i);
                let trending_data = self.trending_data.read(i);
                
                if category.is_active && trending_data.trending_score > 0 {
                    trending.append(i);
                    added += 1;
                }
                
                i += 1;
            };
            
            trending
        }

        fn update_category_popularity(
            ref self: ContractState,
            category_id: u32,
            view_increment: u32,
            booking_increment: u32
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check authorization
            assert!(self.authorized_managers.read(caller), "Unauthorized manager");
            
            // Get trending data
            let mut trending_data = self.trending_data.read(category_id);
            
            // Update counts
            trending_data.view_count += view_increment;
            trending_data.booking_count += booking_increment;
            trending_data.last_updated = current_time;
            
            // Calculate new trending score (weighted formula)
            trending_data.trending_score = (trending_data.view_count.into() * 1 + 
                                          trending_data.booking_count.into() * 10).try_into().unwrap();
            
            // Store updates
            self.trending_data.write(category_id, trending_data);
            
            // Update category popularity score
            let mut category = self.categories.read(category_id);
            category.popularity_score = trending_data.trending_score;
            self.categories.write(category_id, category);
            
            // Emit event
            self.emit(TrendingUpdated {
                category_id,
                new_score: trending_data.trending_score,
                timestamp: current_time,
            });
            
            true
        }

        fn get_category_info(
            self: @ContractState,
            category_id: u32
        ) -> (Category, CategoryMetadata) {
            let category = self.categories.read(category_id);
            let metadata = self.category_metadata.read(category_id);
            (category, metadata)
        }

        fn authorize_manager(
            ref self: ContractState,
            manager: ContractAddress
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Only owner can authorize managers
            assert!(caller == self.owner.read(), "Only owner can authorize managers");
            
            // Authorize manager
            self.authorized_managers.write(manager, true);
            
            // Emit event
            self.emit(ManagerAuthorized {
                manager,
                authorized_by: caller,
                timestamp: current_time,
            });
            
            true
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _has_children(self: @ContractState, category_id: u32) -> bool {
            let total_categories = self.category_count.read();
            let mut i = 1;
            loop {
                if i > total_categories {
                    break false;
                }
                
                if self.parent_children.read((category_id, i)) {
                    break true;
                }
                
                i += 1;
            }
        }

        fn _get_children_recursive(
            self: @ContractState,
            parent_id: u32,
            ref tree: Array<u32>
        ) {
            let total_categories = self.category_count.read();
            let mut i = 1;
            loop {
                if i > total_categories {
                    break;
                }
                
                if self.parent_children.read((parent_id, i)) {
                    tree.append(i);
                    self._get_children_recursive(i, ref tree);
                }
                
                i += 1;
            };
        }

        fn _contains_keyword(self: @ContractState, text: felt252, keyword: felt252) -> bool {
            // Simplified substring matching
            // In production, implement proper text search algorithms
            text == keyword
        }
    }
}