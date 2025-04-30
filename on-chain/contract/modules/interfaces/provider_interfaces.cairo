use starknet::ContractAddress;
use array::Array;

// Import existing Provider struct from verification interfaces
use verification::interfaces::Provider;

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

#[starknet::interface]
trait IProviderRegistryExtended {
    // Basic provider management
    fn register_provider(
        ref self: ContractState,
        provider_address: ContractAddress,
        name: felt252
    ) -> u256;
    
    fn get_provider_by_address(self: @ContractState, provider_address: ContractAddress) -> Provider;
    
    // Service category management
    fn create_service_category(
        ref self: ContractState,
        name: felt252,
        description: felt252
    ) -> u8;
    
    fn get_service_category(self: @ContractState, category_id: u8) -> ServiceCategory;
    
    fn get_all_categories(self: @ContractState) -> Array<ServiceCategory>;
    
    // Service listing management
    fn create_service_listing(
        ref self: ContractState,
        category_id: u8,
        title: felt252,
        description: felt252,
        price: u256
    ) -> u256;
    
    fn update_service_listing(
        ref self: ContractState,
        service_id: u256,
        title: felt252,
        description: felt252,
        price: u256,
        active: bool
    );
    
    fn get_service_listing(self: @ContractState, service_id: u256) -> ServiceListing;
    
    fn get_provider_services(self: @ContractState, provider_id: u256) -> Array<ServiceListing>;
    
    // Reputation management
    fn submit_rating(
        ref self: ContractState,
        provider_id: u256,
        score: u8,
        comment: felt252
    ) -> u256;
    
    fn get_provider_reputation(self: @ContractState, provider_id: u256) -> (u256, u256);
    
    fn get_provider_average_rating(self: @ContractState, provider_id: u256) -> u256;
}