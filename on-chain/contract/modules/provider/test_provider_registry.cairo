use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::{set_caller_address, set_contract_address, set_block_timestamp};
use array::ArrayTrait;
use traits::Into;
use option::OptionTrait;

use verification::interfaces::Provider;
use provider::provider_registry::{
    ProviderRegistry, ServiceCategory, ServiceListing, Reputation, Rating
};
use provider::interfaces::IProviderRegistryExtendedDispatcher;
use provider::interfaces::IProviderRegistryExtendedDispatcherTrait;
use verification::interfaces::IProviderRegistryDispatcher;
use verification::interfaces::IProviderRegistryDispatcherTrait;

// Test constants
const ADMIN: felt252 = 0x123;
const PROVIDER_1: felt252 = 0x456;
const PROVIDER_2: felt252 = 0x789;
const USER_1: felt252 = 0xabc;
const CURRENT_TIME: u64 = 1000;

#[test]
fn test_register_provider() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = ProviderRegistry::contract_state_for_testing();
    ProviderRegistry::constructor(ref state, admin_address);
    
    // Set caller as provider
    let provider_address = contract_address_const::<PROVIDER_1>();
    set_caller_address(provider_address);
    set_block_timestamp(CURRENT_TIME);
    
    // Register provider
    let provider_name = 'Test Provider';
    let provider_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .register_provider(ref state, provider_address, provider_name);
    
    // Verify provider was registered
    assert(provider_id == 1.into(), 'Wrong provider ID');
    
    let provider = IProviderRegistryDispatcher { contract_address: contract_address_const::<0>() }
        .get_provider(@state, provider_id);
    
    assert(provider.address == provider_address, 'Wrong provider address');
    assert(provider.name == provider_name, 'Wrong provider name');
    assert(!provider.verified, 'Should not be verified');
    assert(provider.active, 'Should be active');
    assert(provider.registration_date == CURRENT_TIME, 'Wrong registration date');
}

#[test]
fn test_create_service_category() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = ProviderRegistry::contract_state_for_testing();
    ProviderRegistry::constructor(ref state, admin_address);
    
    // Set caller as admin
    set_caller_address(admin_address);
    
    // Create service category
    let category_name = 'Cleaning';
    let category_description = 'Home cleaning services';
    let category_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .create_service_category(ref state, category_name, category_description);
    
    // Verify category was created
    assert(category_id == 1, 'Wrong category ID');
    
    let category = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .get_service_category(@state, category_id);
    
    assert(category.name == category_name, 'Wrong category name');
    assert(category.description == category_description, 'Wrong category description');
    assert(category.active, 'Should be active');
}

#[test]
fn test_create_service_listing() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = ProviderRegistry::contract_state_for_testing();
    ProviderRegistry::constructor(ref state, admin_address);
    
    // Create service category
    set_caller_address(admin_address);
    let category_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .create_service_category(ref state, 'Cleaning', 'Home cleaning services');
    
    // Register provider
    let provider_address = contract_address_const::<PROVIDER_1>();
    set_caller_address(provider_address);
    set_block_timestamp(CURRENT_TIME);
    
    let provider_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .register_provider(ref state, provider_address, 'Test Provider');
    
    // Create service listing
    let service_title = 'Deep Cleaning';
    let service_description = 'Complete home deep cleaning service';
    let service_price = 100.into();
    
    let service_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .create_service_listing(ref state, category_id, service_title, service_description, service_price);
    
    // Verify service was created
    assert(service_id == 1.into(), 'Wrong service ID');
    
    let service = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .get_service_listing(@state, service_id);
    
    assert(service.provider_id == provider_id, 'Wrong provider ID');
    assert(service.category_id == category_id, 'Wrong category ID');
    assert(service.title == service_title, 'Wrong service title');
    assert(service.description == service_description, 'Wrong service description');
    assert(service.price == service_price, 'Wrong service price');
    assert(service.active, 'Should be active');
    assert(service.created_at == CURRENT_TIME, 'Wrong creation time');
}

#[test]
fn test_update_service_listing() {
    // Setup and create service listing
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = ProviderRegistry::contract_state_for_testing();
    ProviderRegistry::constructor(ref state, admin_address);
    
    // Create service category
    set_caller_address(admin_address);
    let category_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .create_service_category(ref state, 'Cleaning', 'Home cleaning services');
    
    // Register provider
    let provider_address = contract_address_const::<PROVIDER_1>();
    set_caller_address(provider_address);
    set_block_timestamp(CURRENT_TIME);
    
    let provider_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .register_provider(ref state, provider_address, 'Test Provider');
    
    // Create service listing
    let service_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .create_service_listing(ref state, category_id, 'Deep Cleaning', 'Complete home deep cleaning', 100.into());
    
    // Update service listing
    set_block_timestamp(CURRENT_TIME + 100);
    let new_title = 'Premium Deep Cleaning';
    let new_description = 'Premium complete home deep cleaning service';
    let new_price = 150.into();
    
    IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .update_service_listing(ref state, service_id, new_title, new_description, new_price, true);
    
    // Verify service was updated
    let updated_service = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .get_service_listing(@state, service_id);
    
    assert(updated_service.title == new_title, 'Title not updated');
    assert(updated_service.description == new_description, 'Description not updated');
    assert(updated_service.price == new_price, 'Price not updated');
    assert(updated_service.updated_at == CURRENT_TIME + 100, 'Update time not updated');
}

#[test]
fn test_submit_rating() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = ProviderRegistry::contract_state_for_testing();
    ProviderRegistry::constructor(ref state, admin_address);
    
    // Register provider
    let provider_address = contract_address_const::<PROVIDER_1>();
    set_caller_address(provider_address);
    set_block_timestamp(CURRENT_TIME);
    
    let provider_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .register_provider(ref state, provider_address, 'Test Provider');
    
    // Submit rating as user
    let user_address = contract_address_const::<USER_1>();
    set_caller_address(user_address);
    set_block_timestamp(CURRENT_TIME + 100);
    
    let score: u8 = 4;
    let comment = 'Great service!';
    
    let rating_id = IProviderRegistryExtendedDispatcher { contract_address: contract_address_const::<0>() }
        .submit_rating(ref