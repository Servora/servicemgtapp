use starknet::ContractAddress;
use starknet::get_caller_address;

use super::ServiceRegistry::{
    ServiceRegistry,
    ServiceRegistryDispatcher,
    ServiceRegistryDispatcherTrait
};

// Test constants
const ADMIN_ADDRESS: felt252 = 0x1234567890123456789012345678901234567890123456789012345678901234;
const PROVIDER_1: felt252 = 0x1111111111111111111111111111111111111111111111111111111111111111;
const PROVIDER_2: felt252 = 0x2222222222222222222222222222222222222222222222222222222222222222;
const PROVIDER_3: felt252 = 0x3333333333333333333333333333333333333333333333333333333333333333;

// Provider data constants
const PROVIDER_NAME_1: felt252 = 'Tech Solutions Inc';
const PROVIDER_DESC_1: felt252 = 'Professional IT services and consulting';
const PROVIDER_EMAIL_1: felt252 = 'contact@techsolutions.com';
const PROVIDER_PHONE_1: felt252 = '+1-555-0123';
const PROVIDER_WEBSITE_1: felt252 = 'https://techsolutions.com';
const PROVIDER_LAT_1: felt252 = 40750000; // 40.75 degrees * 1,000,000
const PROVIDER_LNG_1: felt252 = -73980000; // -73.98 degrees * 1,000,000

const PROVIDER_NAME_2: felt252 = 'Digital Marketing Pro';
const PROVIDER_DESC_2: felt252 = 'Comprehensive digital marketing services';
const PROVIDER_EMAIL_2: felt252 = 'hello@digitalmarketingpro.com';
const PROVIDER_PHONE_2: felt252 = '+1-555-0456';
const PROVIDER_WEBSITE_2: felt252 = 'https://digitalmarketingpro.com';
const PROVIDER_LAT_2: felt252 = 40800000; // 40.80 degrees * 1,000,000
const PROVIDER_LNG_2: felt252 = -73950000; // -73.95 degrees * 1,000,000

// Service data constants
const SERVICE_TITLE_1: felt252 = 'Web Development';
const SERVICE_DESC_1: felt252 = 'Custom web development and design services';
const SERVICE_CATEGORY_1: felt252 = 1; // Technology
const SERVICE_PRICE_LOW_1: felt252 = 5000; // $50.00 * 100
const SERVICE_PRICE_HIGH_1: felt252 = 25000; // $250.00 * 100
const SERVICE_DURATION_1: felt252 = 14; // 14 days

const SERVICE_TITLE_2: felt252 = 'SEO Optimization';
const SERVICE_DESC_2: felt252 = 'Search engine optimization services';
const SERVICE_CATEGORY_2: felt252 = 2; // Marketing
const SERVICE_PRICE_LOW_2: felt252 = 2000; // $20.00 * 100
const SERVICE_PRICE_HIGH_2: felt252 = 10000; // $100.00 * 100
const SERVICE_DURATION_2: felt252 = 7; // 7 days

// Category data constants
const CATEGORY_NAME_1: felt252 = 'Technology';
const CATEGORY_DESC_1: felt252 = 'IT and technology services';
const CATEGORY_NAME_2: felt252 = 'Marketing';
const CATEGORY_DESC_2: felt252 = 'Digital marketing and advertising';

// Verification levels
const VERIFICATION_BASIC: felt252 = 0;
const VERIFICATION_VERIFIED: felt252 = 1;
const VERIFICATION_PREMIUM: felt252 = 2;

// Provider statuses
const STATUS_ACTIVE: felt252 = 0;
const STATUS_INACTIVE: felt252 = 1;
const STATUS_SUSPENDED: felt252 = 2;
const STATUS_PENDING: felt252 = 3;

// KYC statuses
const KYC_PENDING: felt252 = 0;
const KYC_APPROVED: felt252 = 1;
const KYC_REJECTED: felt252 = 2;
const KYC_EXPIRED: felt252 = 3;

// Service statuses
const SERVICE_ACTIVE: felt252 = 0;
const SERVICE_INACTIVE: felt252 = 1;
const SERVICE_PAUSED: felt252 = 2;

// Specializations
const SPECIALIZATION_WEB_DEV: felt252 = 1;
const SPECIALIZATION_MOBILE_DEV: felt252 = 2;
const SPECIALIZATION_SEO: felt252 = 3;
const SPECIALIZATION_SOCIAL_MEDIA: felt252 = 4;

#[test]
fn test_constructor() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Verify admin is set correctly
    let (admin) = ServiceRegistry::get_admin(contract_address);
    assert(admin == ADMIN_ADDRESS, 'Admin should be set correctly');
    
    // Verify contract name and symbol
    let (name) = ServiceRegistry::name(contract_address);
    assert(name == 'Service Registry', 'Name should be set correctly');
    
    let (symbol) = ServiceRegistry::symbol(contract_address);
    assert(symbol == 'SR', 'Symbol should be set correctly');
    
    return ();
}

#[test]
fn test_register_provider() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register first provider
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV, SPECIALIZATION_MOBILE_DEV]
    );
    
    assert(provider_id == 1, 'First provider ID should be 1');
    
    // Verify provider data
    let (provider_data) = ServiceRegistry::get_provider(contract_address, provider_id);
    assert(provider_data.name == PROVIDER_NAME_1, 'Provider name should match');
    assert(provider_data.description == PROVIDER_DESC_1, 'Provider description should match');
    assert(provider_data.contact_email == PROVIDER_EMAIL_1, 'Provider email should match');
    assert(provider_data.contact_phone == PROVIDER_PHONE_1, 'Provider phone should match');
    assert(provider_data.website == PROVIDER_WEBSITE_1, 'Provider website should match');
    assert(provider_data.location_lat == PROVIDER_LAT_1, 'Provider latitude should match');
    assert(provider_data.location_lng == PROVIDER_LNG_1, 'Provider longitude should match');
    assert(provider_data.verification_level == VERIFICATION_BASIC, 'Provider should start with basic verification');
    assert(provider_data.status == STATUS_PENDING, 'Provider should start with pending status');
    assert(provider_data.kyc_status == KYC_PENDING, 'Provider should start with pending KYC');
    
    // Register second provider
    let (provider_id_2) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_2,
        PROVIDER_DESC_2,
        PROVIDER_EMAIL_2,
        PROVIDER_PHONE_2,
        PROVIDER_WEBSITE_2,
        PROVIDER_LAT_2,
        PROVIDER_LNG_2,
        array![SPECIALIZATION_SEO, SPECIALIZATION_SOCIAL_MEDIA]
    );
    
    assert(provider_id_2 == 2, 'Second provider ID should be 2');
    
    // Verify total provider count
    let (total_providers) = ServiceRegistry::get_total_providers(contract_address);
    assert(total_providers == 2, 'Total providers should be 2');
    
    return ();
}

#[test]
fn test_add_service() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider first
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    // Add first service
    let (service_id) = ServiceRegistry::add_service(
        contract_address,
        provider_id,
        SERVICE_TITLE_1,
        SERVICE_DESC_1,
        SERVICE_CATEGORY_1,
        SERVICE_PRICE_LOW_1,
        SERVICE_PRICE_HIGH_1,
        SERVICE_DURATION_1
    );
    
    assert(service_id == 1, 'First service ID should be 1');
    
    // Verify service data
    let (service_data) = ServiceRegistry::get_service(contract_address, service_id);
    assert(service_data.provider_id == provider_id, 'Service provider ID should match');
    assert(service_data.title == SERVICE_TITLE_1, 'Service title should match');
    assert(service_data.description == SERVICE_DESC_1, 'Service description should match');
    assert(service_data.category_id == SERVICE_CATEGORY_1, 'Service category should match');
    assert(service_data.price_low == SERVICE_PRICE_LOW_1, 'Service price low should match');
    assert(service_data.price_high == SERVICE_PRICE_HIGH_1, 'Service price high should match');
    assert(service_data.duration == SERVICE_DURATION_1, 'Service duration should match');
    assert(service_data.status == SERVICE_ACTIVE, 'Service should be active');
    
    // Add second service
    let (service_id_2) = ServiceRegistry::add_service(
        contract_address,
        provider_id,
        SERVICE_TITLE_2,
        SERVICE_DESC_2,
        SERVICE_CATEGORY_2,
        SERVICE_PRICE_LOW_2,
        SERVICE_PRICE_HIGH_2,
        SERVICE_DURATION_2
    );
    
    assert(service_id_2 == 2, 'Second service ID should be 2');
    
    // Verify total services count
    let (total_services) = ServiceRegistry::get_total_services(contract_address);
    assert(total_services == 2, 'Total services should be 2');
    
    return ();
}

#[test]
fn test_update_service() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider and add service
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    let (service_id) = ServiceRegistry::add_service(
        contract_address,
        provider_id,
        SERVICE_TITLE_1,
        SERVICE_DESC_1,
        SERVICE_CATEGORY_1,
        SERVICE_PRICE_LOW_1,
        SERVICE_PRICE_HIGH_1,
        SERVICE_DURATION_1
    );
    
    // Update service
    let new_title: felt252 = 'Updated Web Development';
    let new_desc: felt252 = 'Enhanced web development services';
    let new_price_low: felt252 = 7500; // $75.00 * 100
    let new_price_high: felt252 = 30000; // $300.00 * 100
    
    ServiceRegistry::update_service(
        contract_address,
        service_id,
        new_title,
        new_desc,
        SERVICE_CATEGORY_1,
        new_price_low,
        new_price_high,
        SERVICE_DURATION_1
    );
    
    // Verify updated service data
    let (service_data) = ServiceRegistry::get_service(contract_address, service_id);
    assert(service_data.title == new_title, 'Service title should be updated');
    assert(service_data.description == new_desc, 'Service description should be updated');
    assert(service_data.price_low == new_price_low, 'Service price low should be updated');
    assert(service_data.price_high == new_price_high, 'Service price high should be updated');
    
    return ();
}

#[test]
fn test_deactivate_provider() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    // Deactivate provider
    ServiceRegistry::deactivate_provider(contract_address, provider_id);
    
    // Verify provider status
    let (provider_data) = ServiceRegistry::get_provider(contract_address, provider_id);
    assert(provider_data.status == STATUS_INACTIVE, 'Provider should be inactive');
    
    return ();
}

#[test]
fn test_get_provider_services() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    // Add multiple services
    let (service_id_1) = ServiceRegistry::add_service(
        contract_address,
        provider_id,
        SERVICE_TITLE_1,
        SERVICE_DESC_1,
        SERVICE_CATEGORY_1,
        SERVICE_PRICE_LOW_1,
        SERVICE_PRICE_HIGH_1,
        SERVICE_DURATION_1
    );
    
    let (service_id_2) = ServiceRegistry::add_service(
        contract_address,
        provider_id,
        SERVICE_TITLE_2,
        SERVICE_DESC_2,
        SERVICE_CATEGORY_2,
        SERVICE_PRICE_LOW_2,
        SERVICE_PRICE_HIGH_2,
        SERVICE_DURATION_2
    );
    
    // Get provider services
    let (service_ids) = ServiceRegistry::get_provider_services(contract_address, provider_id);
    
    // Verify service IDs
    assert(service_ids.len() == 2, 'Provider should have 2 services');
    assert(service_ids.at(0) == service_id_1, 'First service ID should match');
    assert(service_ids.at(1) == service_id_2, 'Second service ID should match');
    
    return ();
}

#[test]
fn test_verify_provider() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    // Verify provider (upgrade to verified level)
    ServiceRegistry::verify_provider(
        contract_address,
        provider_id,
        VERIFICATION_VERIFIED,
        KYC_APPROVED,
        1735689600 // Expiry timestamp
    );
    
    // Verify provider verification level and KYC status
    let (provider_data) = ServiceRegistry::get_provider(contract_address, provider_id);
    assert(provider_data.verification_level == VERIFICATION_VERIFIED, 'Provider should be verified');
    assert(provider_data.kyc_status == KYC_APPROVED, 'Provider KYC should be approved');
    assert(provider_data.status == STATUS_ACTIVE, 'Provider should be active');
    
    return ();
}

#[test]
fn test_add_service_category() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Add first category
    let (category_id) = ServiceRegistry::add_service_category(
        contract_address,
        CATEGORY_NAME_1,
        CATEGORY_DESC_1
    );
    
    assert(category_id == 1, 'First category ID should be 1');
    
    // Verify category data
    let (category_data) = ServiceRegistry::get_service_category(contract_address, category_id);
    assert(category_data.name == CATEGORY_NAME_1, 'Category name should match');
    assert(category_data.description == CATEGORY_DESC_1, 'Category description should match');
    assert(category_data.status == 0, 'Category should be active');
    
    // Add second category
    let (category_id_2) = ServiceRegistry::add_service_category(
        contract_address,
        CATEGORY_NAME_2,
        CATEGORY_DESC_2
    );
    
    assert(category_id_2 == 2, 'Second category ID should be 2');
    
    return ();
}

#[test]
fn test_search_providers() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register multiple providers
    let (provider_id_1) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    let (provider_id_2) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_2,
        PROVIDER_DESC_2,
        PROVIDER_EMAIL_2,
        PROVIDER_PHONE_2,
        PROVIDER_WEBSITE_2,
        PROVIDER_LAT_2,
        PROVIDER_LNG_2,
        array![SPECIALIZATION_SEO]
    );
    
    // Search providers by specialization
    let (providers) = ServiceRegistry::search_providers(
        contract_address,
        SPECIALIZATION_WEB_DEV,
        0, // Any verification level
        0, // Any status
        0, // Any KYC status
        10 // Max results
    );
    
    // Verify search results
    assert(providers.len() == 1, 'Should find 1 provider with web dev specialization');
    assert(providers.at(0) == provider_id_1, 'Should find the correct provider');
    
    return ();
}

#[test]
fn test_get_provider_by_address() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    // Get provider by address
    let (found_provider_id) = ServiceRegistry::get_provider_by_address(
        contract_address,
        PROVIDER_1
    );
    
    assert(found_provider_id == provider_id, 'Should find provider by address');
    
    return ();
}

#[test]
fn test_update_provider_metadata() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    // Update provider metadata
    let new_name: felt252 = 'Updated Tech Solutions';
    let new_desc: felt252 = 'Updated professional IT services';
    let new_email: felt252 = 'updated@techsolutions.com';
    let new_phone: felt252 = '+1-555-9999';
    let new_website: felt252 = 'https://updated-techsolutions.com';
    
    ServiceRegistry::update_provider_metadata(
        contract_address,
        provider_id,
        new_name,
        new_desc,
        new_email,
        new_phone,
        new_website
    );
    
    // Verify updated metadata
    let (provider_data) = ServiceRegistry::get_provider(contract_address, provider_id);
    assert(provider_data.name == new_name, 'Provider name should be updated');
    assert(provider_data.description == new_desc, 'Provider description should be updated');
    assert(provider_data.contact_email == new_email, 'Provider email should be updated');
    assert(provider_data.contact_phone == new_phone, 'Provider phone should be updated');
    assert(provider_data.website == new_website, 'Provider website should be updated');
    
    return ();
}

#[test]
fn test_get_provider_statistics() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Register provider
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV, SPECIALIZATION_MOBILE_DEV]
    );
    
    // Add services
    let (service_id_1) = ServiceRegistry::add_service(
        contract_address,
        provider_id,
        SERVICE_TITLE_1,
        SERVICE_DESC_1,
        SERVICE_CATEGORY_1,
        SERVICE_PRICE_LOW_1,
        SERVICE_PRICE_HIGH_1,
        SERVICE_DURATION_1
    );
    
    let (service_id_2) = ServiceRegistry::add_service(
        contract_address,
        provider_id,
        SERVICE_TITLE_2,
        SERVICE_DESC_2,
        SERVICE_CATEGORY_2,
        SERVICE_PRICE_LOW_2,
        SERVICE_PRICE_HIGH_2,
        SERVICE_DURATION_2
    );
    
    // Get provider statistics
    let (stats) = ServiceRegistry::get_provider_statistics(contract_address, provider_id);
    
    // Verify statistics
    assert(stats.total_services == 2, 'Provider should have 2 services');
    assert(stats.total_specializations == 2, 'Provider should have 2 specializations');
    assert(stats.verification_level == VERIFICATION_BASIC, 'Provider should have basic verification');
    assert(stats.status == STATUS_PENDING, 'Provider should have pending status');
    
    return ();
}

#[test]
fn test_admin_functions() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Test admin-only functions
    ServiceRegistry::set_verification_requirement(contract_address, true);
    
    let (requires_verification) = ServiceRegistry::get_verification_requirement(contract_address);
    assert(requires_verification == true, 'Verification requirement should be set');
    
    // Test KYC expiry update
    ServiceRegistry::update_kyc_expiry(
        contract_address,
        1, // provider_id
        1735689600 // new_expiry
    );
    
    let (provider_data) = ServiceRegistry::get_provider(contract_address, 1);
    assert(provider_data.kyc_expiry == 1735689600, 'KYC expiry should be updated');
    
    return ();
}

#[test]
fn test_error_handling() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Test registering provider with invalid data
    // This should be handled gracefully by the contract
    
    // Test accessing non-existent provider
    let (provider_data) = ServiceRegistry::get_provider(contract_address, 999);
    // Should return default/empty data for non-existent provider
    
    // Test accessing non-existent service
    let (service_data) = ServiceRegistry::get_service(contract_address, 999);
    // Should return default/empty data for non-existent service
    
    return ();
}

#[test]
fn test_integration_with_other_modules() {
    let (contract_address) = ServiceRegistry::constructor(
        ADMIN_ADDRESS,
        'Service Registry',
        'SR'
    );
    
    // Test integration with location-based search
    // Register provider with location
    let (provider_id) = ServiceRegistry::register_provider(
        contract_address,
        PROVIDER_NAME_1,
        PROVIDER_DESC_1,
        PROVIDER_EMAIL_1,
        PROVIDER_PHONE_1,
        PROVIDER_WEBSITE_1,
        PROVIDER_LAT_1,
        PROVIDER_LNG_1,
        array![SPECIALIZATION_WEB_DEV]
    );
    
    // Verify location data is stored correctly
    let (provider_data) = ServiceRegistry::get_provider(contract_address, provider_id);
    assert(provider_data.location_lat == PROVIDER_LAT_1, 'Location latitude should be stored');
    assert(provider_data.location_lng == PROVIDER_LNG_1, 'Location longitude should be stored');
    
    // Test integration with verification system
    ServiceRegistry::verify_provider(
        contract_address,
        provider_id,
        VERIFICATION_PREMIUM,
        KYC_APPROVED,
        1735689600
    );
    
    let (provider_data_verified) = ServiceRegistry::get_provider(contract_address, provider_id);
    assert(provider_data_verified.verification_level == VERIFICATION_PREMIUM, 'Provider should be premium verified');
    
    return ();
} 