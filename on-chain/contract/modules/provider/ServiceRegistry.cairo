// SPDX-License-Identifier: MIT
// Cairo 1.0 Service Registry Contract for Service Marketplace
// Optimized for performance and comprehensive provider management

%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::math::uint256 import Uint256
from starkware::starknet::array::ArrayTrait
from starkware::starknet::math::uint256_math::Uint256MathTrait

// Verification level constants
const VERIFICATION_BASIC: felt252 = 0
const VERIFICATION_VERIFIED: felt252 = 1
const VERIFICATION_PREMIUM: felt252 = 2

// Provider status constants
const STATUS_INACTIVE: felt252 = 0
const STATUS_ACTIVE: felt252 = 1
const STATUS_SUSPENDED: felt252 = 2
const STATUS_PENDING_VERIFICATION: felt252 = 3

// Service status constants
const SERVICE_STATUS_INACTIVE: felt252 = 0
const SERVICE_STATUS_ACTIVE: felt252 = 1
const SERVICE_STATUS_PAUSED: felt252 = 2
const SERVICE_STATUS_DELETED: felt252 = 3

// KYC verification status
const KYC_STATUS_PENDING: felt252 = 0
const KYC_STATUS_APPROVED: felt252 = 1
const KYC_STATUS_REJECTED: felt252 = 2
const KYC_STATUS_EXPIRED: felt252 = 3

// Storage variables for provider management
@storage_var
func admin() -> (address: ContractAddress) {}

@storage_var
func verification_contract_address() -> (address: ContractAddress) {}

@storage_var
func geolocation_service_address() -> (address: ContractAddress) {}

@storage_var
func provider_counter() -> (count: felt252) {}

@storage_var
func service_counter() -> (count: felt252) {}

@storage_var
func category_counter() -> (count: felt252) {}

// Provider storage with comprehensive metadata
@storage_var
func providers(provider_id: felt252) -> (
    address: ContractAddress,
    name: felt252,
    description: felt252,
    verification_level: felt252,
    status: felt252,
    kyc_status: felt252,
    kyc_expiry: felt252,
    location_lat: felt252,
    location_lng: felt252,
    contact_email: felt252,
    contact_phone: felt252,
    website: felt252,
    created_at: felt252,
    updated_at: felt252
) {}

// Provider to address mapping
@storage_var
func provider_by_address(address: ContractAddress) -> (provider_id: felt252) {}

// Provider specializations/tags
@storage_var
func provider_specializations(provider_id: felt252, specialization_index: felt252) -> (specialization: felt252) {}

@storage_var
func provider_specialization_count(provider_id: felt252) -> (count: felt252) {}

// Service storage with categorization
@storage_var
func services(service_id: felt252) -> (
    provider_id: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252,
    status: felt252,
    created_at: felt252,
    updated_at: felt252
) {}

// Service tags for searchability
@storage_var
func service_tags(service_id: felt252, tag_index: felt252) -> (tag: felt252) {}

@storage_var
func service_tag_count(service_id: felt252) -> (count: felt252) {}

// Provider services mapping
@storage_var
func provider_services(provider_id: felt252, service_index: felt252) -> (service_id: felt252) {}

@storage_var
func provider_service_count(provider_id: felt252) -> (count: felt252) {}

// Category services mapping
@storage_var
func category_services(category_id: felt252, service_index: felt252) -> (service_id: felt252) {}

@storage_var
func category_service_count(category_id: felt252) -> (count: felt252) {}

// Service categories
@storage_var
func categories(category_id: felt252) -> (
    name: felt252,
    description: felt252,
    parent_category: felt252,
    active: felt252,
    created_at: felt252
) {}

// Verification records
@storage_var
func verification_records(provider_id: felt252) -> (
    verifier: ContractAddress,
    verification_level: felt252,
    verification_date: felt252,
    expiry_date: felt252,
    notes: felt252
) {}

// KYC documents and verification
@storage_var
func kyc_documents(provider_id: felt252, document_type: felt252) -> (
    document_hash: felt252,
    verified: felt252,
    verification_date: felt252,
    verifier: ContractAddress
) {}

// Provider ratings and reviews
@storage_var
func provider_ratings(provider_id: felt252) -> (
    average_rating: felt252,
    total_reviews: felt252,
    last_updated: felt252
) {}

// Search and filter indexes
@storage_var
func verified_providers(verification_level: felt252, index: felt252) -> (provider_id: felt252) {}

@storage_var
func verified_provider_count(verification_level: felt252) -> (count: felt252) {}

@storage_var
func active_providers(index: felt252) -> (provider_id: felt252) {}

@storage_var
func active_provider_count() -> (count: felt252) {}

// Events
@event
func ProviderRegistered(provider_id: felt252, address: ContractAddress, name: felt252, verification_level: felt252, timestamp: felt252) {}

@event
func ProviderUpdated(provider_id: felt252, address: ContractAddress, name: felt252, timestamp: felt252) {}

@event
func ProviderDeactivated(provider_id: felt252, address: ContractAddress, reason: felt252, timestamp: felt252) {}

@event
func ServiceAdded(service_id: felt252, provider_id: felt252, title: felt252, category_id: felt252, timestamp: felt252) {}

@event
func ServiceUpdated(service_id: felt252, provider_id: felt252, title: felt252, timestamp: felt252) {}

@event
func VerificationUpdated(provider_id: felt252, verification_level: felt252, verifier: ContractAddress, timestamp: felt252) {}

@event
func KYCStatusChanged(provider_id: felt252, old_status: felt252, new_status: felt252, timestamp: felt252) {}

@event
func CategoryCreated(category_id: felt252, name: felt252, parent_category: felt252, timestamp: felt252) {}

// Constructor
@constructor
func constructor(
    admin_address: ContractAddress,
    verification_contract: ContractAddress,
    geolocation_service: ContractAddress
) {
    admin::write(admin_address);
    verification_contract_address::write(verification_contract);
    geolocation_service_address::write(geolocation_service);
    provider_counter::write(0);
    service_counter::write(0);
    category_counter::write(0);
    active_provider_count::write(0);
    return ();
}

// Access control
func only_admin() {
    let caller = get_caller_address();
    let admin_address = admin::read();
    assert(caller == admin_address, 'Only admin can call this');
    return ();
}

func only_authorized() {
    let caller = get_caller_address();
    let admin_address = admin::read();
    let verification_contract = verification_contract_address::read();
    
    assert(
        caller == admin_address || 
        caller == verification_contract,
        'Unauthorized caller'
    );
    return ();
}

// Utility functions
func validate_provider_data(
    name: felt252,
    description: felt252,
    contact_email: felt252,
    contact_phone: felt252
) -> (valid: felt252) {
    // Basic validation - in production, add more comprehensive checks
    let name_valid = name != 0;
    let description_valid = description != 0;
    let email_valid = contact_email != 0;
    let phone_valid = contact_phone != 0;
    
    return (name_valid && description_valid && email_valid && phone_valid);
}

func validate_service_data(
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252
) -> (valid: felt252) {
    let title_valid = title != 0;
    let description_valid = description != 0;
    let category_valid = category_id > 0;
    let price_valid = price_low > 0 && price_high >= price_low;
    
    return (title_valid && description_valid && category_valid && price_valid);
}

// Register a new provider
@external
func register_provider(
    name: felt252,
    description: felt252,
    contact_email: felt252,
    contact_phone: felt252,
    website: felt252,
    location_lat: felt252,
    location_lng: felt252,
    specializations: Array<felt252>
) -> (provider_id: felt252) {
    let caller = get_caller_address();
    
    // Validate provider data
    let (valid) = validate_provider_data(name, description, contact_email, contact_phone);
    assert(valid == 1, 'Invalid provider data');
    
    // Check if address is already registered
    let (existing_provider) = provider_by_address::read(caller);
    assert(existing_provider == 0, 'Address already registered');
    
    let timestamp = get_block_timestamp();
    
    // Generate provider ID
    let current_count = provider_counter::read();
    let provider_id = current_count + 1;
    provider_counter::write(provider_id);
    
    // Store provider data
    providers::write(
        provider_id,
        caller,
        name,
        description,
        VERIFICATION_BASIC,
        STATUS_PENDING_VERIFICATION,
        KYC_STATUS_PENDING,
        0, // kyc_expiry
        location_lat,
        location_lng,
        contact_email,
        contact_phone,
        website,
        timestamp,
        timestamp
    );
    
    // Store provider address mapping
    provider_by_address::write(caller, provider_id);
    
    // Store specializations
    let mut i = 0;
    while i < specializations.len() {
        let specialization = specializations.at(i);
        let current_count = provider_specialization_count::read(provider_id);
        provider_specializations::write(provider_id, current_count, specialization);
        provider_specialization_count::write(provider_id, current_count + 1);
        i = i + 1;
    }
    
    // Update active provider count
    let active_count = active_provider_count::read();
    active_provider_count::write(active_count + 1);
    active_providers::write(active_count, provider_id);
    
    // Register location with geolocation service
    if location_lat != 0 && location_lng != 0 {
        // Note: In a full implementation, you would call the geolocation service
        // GeolocationService::register_location(provider_id, location_lat, location_lng, 1, 1, 5000);
    }
    
    // Emit event
    ProviderRegistered(provider_id, caller, name, VERIFICATION_BASIC, timestamp);
    
    return (provider_id);
}

// Add a new service for a provider
@external
func add_service(
    provider_id: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252,
    tags: Array<felt252>
) -> (service_id: felt252) {
    let caller = get_caller_address();
    
    // Verify caller is the provider
    let (provider_address, name, desc, verification_level, status, kyc_status, kyc_expiry, lat, lng, email, phone, website, created_at, updated_at) = 
        providers::read(provider_id);
    
    assert(caller == provider_address, 'Only provider can add services');
    assert(status == STATUS_ACTIVE, 'Provider must be active');
    
    // Validate service data
    let (valid) = validate_service_data(title, description, category_id, price_low, price_high);
    assert(valid == 1, 'Invalid service data');
    
    let timestamp = get_block_timestamp();
    
    // Generate service ID
    let current_count = service_counter::read();
    let service_id = current_count + 1;
    service_counter::write(service_id);
    
    // Store service data
    services::write(
        service_id,
        provider_id,
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        SERVICE_STATUS_ACTIVE,
        timestamp,
        timestamp
    );
    
    // Store service tags
    let mut i = 0;
    while i < tags.len() {
        let tag = tags.at(i);
        let current_count = service_tag_count::read(service_id);
        service_tags::write(service_id, current_count, tag);
        service_tag_count::write(service_id, current_count + 1);
        i = i + 1;
    }
    
    // Update provider services mapping
    let provider_service_count = provider_service_count::read(provider_id);
    provider_services::write(provider_id, provider_service_count, service_id);
    provider_service_count::write(provider_id, provider_service_count + 1);
    
    // Update category services mapping
    let category_service_count = category_service_count::read(category_id);
    category_services::write(category_id, category_service_count, service_id);
    category_service_count::write(category_id, category_service_count + 1);
    
    // Emit event
    ServiceAdded(service_id, provider_id, title, category_id, timestamp);
    
    return (service_id);
}

// Update an existing service
@external
func update_service(
    service_id: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252
) -> () {
    let caller = get_caller_address();
    
    // Get service data
    let (provider_id, old_title, old_description, old_category, old_price_low, old_price_high, old_duration, status, created_at, old_updated) = 
        services::read(service_id);
    
    // Verify caller is the provider
    let (provider_address, name, desc, verification_level, provider_status, kyc_status, kyc_expiry, lat, lng, email, phone, website, provider_created_at, provider_updated_at) = 
        providers::read(provider_id);
    
    assert(caller == provider_address, 'Only provider can update services');
    assert(status == SERVICE_STATUS_ACTIVE, 'Service must be active');
    
    // Validate service data
    let (valid) = validate_service_data(title, description, category_id, price_low, price_high);
    assert(valid == 1, 'Invalid service data');
    
    let timestamp = get_block_timestamp();
    
    // Update service data
    services::write(
        service_id,
        provider_id,
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        status,
        created_at,
        timestamp
    );
    
    // Update category mapping if category changed
    if old_category != category_id {
        // Remove from old category
        let old_category_count = category_service_count::read(old_category);
        // Note: In a full implementation, you'd need to handle category service removal
        
        // Add to new category
        let new_category_count = category_service_count::read(category_id);
        category_services::write(category_id, new_category_count, service_id);
        category_service_count::write(category_id, new_category_count + 1);
    }
    
    // Emit event
    ServiceUpdated(service_id, provider_id, title, timestamp);
    
    return ();
}

// Deactivate a provider
@external
func deactivate_provider(provider_id: felt252, reason: felt252) -> () {
    only_authorized();
    
    let (address, name, description, verification_level, status, kyc_status, kyc_expiry, lat, lng, email, phone, website, created_at, updated_at) = 
        providers::read(provider_id);
    
    assert(status == STATUS_ACTIVE, 'Provider must be active to deactivate');
    
    let timestamp = get_block_timestamp();
    
    // Update provider status
    providers::write(
        provider_id,
        address,
        name,
        description,
        verification_level,
        STATUS_INACTIVE,
        kyc_status,
        kyc_expiry,
        lat,
        lng,
        email,
        phone,
        website,
        created_at,
        timestamp
    );
    
    // Remove from active providers
    let active_count = active_provider_count::read();
    // Note: In a full implementation, you'd need to handle active provider removal
    
    // Deactivate all provider services
    let service_count = provider_service_count::read(provider_id);
    let mut i = 0;
    while i < service_count {
        let service_id = provider_services::read(provider_id, i);
        let (service_provider_id, title, desc, category, price_low, price_high, duration, service_status, service_created_at, service_updated_at) = 
            services::read(service_id);
        
        if service_status == SERVICE_STATUS_ACTIVE {
            services::write(
                service_id,
                service_provider_id,
                title,
                desc,
                category,
                price_low,
                price_high,
                duration,
                SERVICE_STATUS_INACTIVE,
                service_created_at,
                timestamp
            );
        }
        i = i + 1;
    }
    
    // Emit event
    ProviderDeactivated(provider_id, address, reason, timestamp);
    
    return ();
}

// Get provider services
@view
func get_provider_services(provider_id: felt252) -> (service_count: felt252, service_ids: Array<felt252>) {
    let service_count = provider_service_count::read(provider_id);
    let mut service_ids = ArrayTrait::new();
    
    let mut i = 0;
    while i < service_count {
        let service_id = provider_services::read(provider_id, i);
        service_ids.append(service_id);
        i = i + 1;
    }
    
    return (service_count, service_ids);
}

// Update provider verification level
@external
func update_verification_level(
    provider_id: felt252,
    verification_level: felt252,
    verifier: ContractAddress,
    notes: felt252
) -> () {
    only_authorized();
    
    assert(verification_level <= VERIFICATION_PREMIUM, 'Invalid verification level');
    
    let (address, name, description, old_verification_level, status, kyc_status, kyc_expiry, lat, lng, email, phone, website, created_at, updated_at) = 
        providers::read(provider_id);
    
    let timestamp = get_block_timestamp();
    
    // Update provider verification level
    providers::write(
        provider_id,
        address,
        name,
        description,
        verification_level,
        status,
        kyc_status,
        kyc_expiry,
        lat,
        lng,
        email,
        phone,
        website,
        created_at,
        timestamp
    );
    
    // Store verification record
    verification_records::write(
        provider_id,
        verifier,
        verification_level,
        timestamp,
        timestamp + 31536000, // 1 year expiry
        notes
    );
    
    // Update verified providers index
    let verified_count = verified_provider_count::read(verification_level);
    verified_providers::write(verification_level, verified_count, provider_id);
    verified_provider_count::write(verification_level, verified_count + 1);
    
    // Emit event
    VerificationUpdated(provider_id, verification_level, verifier, timestamp);
    
    return ();
}

// Update KYC status
@external
func update_kyc_status(
    provider_id: felt252,
    kyc_status: felt252,
    expiry_date: felt252
) -> () {
    only_authorized();
    
    assert(kyc_status <= KYC_STATUS_EXPIRED, 'Invalid KYC status');
    
    let (address, name, description, verification_level, status, old_kyc_status, old_kyc_expiry, lat, lng, email, phone, website, created_at, updated_at) = 
        providers::read(provider_id);
    
    let timestamp = get_block_timestamp();
    
    // Update KYC status
    providers::write(
        provider_id,
        address,
        name,
        description,
        verification_level,
        status,
        kyc_status,
        expiry_date,
        lat,
        lng,
        email,
        phone,
        website,
        created_at,
        timestamp
    );
    
    // Emit event
    KYCStatusChanged(provider_id, old_kyc_status, kyc_status, timestamp);
    
    return ();
}

// Create a new service category
@external
func create_category(
    name: felt252,
    description: felt252,
    parent_category: felt252
) -> (category_id: felt252) {
    only_authorized();
    
    assert(name != 0, 'Category name cannot be empty');
    
    let timestamp = get_block_timestamp();
    
    // Generate category ID
    let current_count = category_counter::read();
    let category_id = current_count + 1;
    category_counter::write(category_id);
    
    // Store category data
    categories::write(
        category_id,
        name,
        description,
        parent_category,
        1, // active
        timestamp
    );
    
    // Emit event
    CategoryCreated(category_id, name, parent_category, timestamp);
    
    return (category_id);
}

// Get provider details
@view
func get_provider_details(provider_id: felt252) -> (
    address: ContractAddress,
    name: felt252,
    description: felt252,
    verification_level: felt252,
    status: felt252,
    kyc_status: felt252,
    location_lat: felt252,
    location_lng: felt252,
    contact_email: felt252,
    contact_phone: felt252,
    website: felt252,
    created_at: felt252
) {
    let (addr, name, desc, verification_level, status, kyc_status, kyc_expiry, lat, lng, email, phone, website, created_at, updated_at) = 
        providers::read(provider_id);
    
    return (addr, name, desc, verification_level, status, kyc_status, lat, lng, email, phone, website, created_at);
}

// Get service details
@view
func get_service_details(service_id: felt252) -> (
    provider_id: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252,
    status: felt252,
    created_at: felt252
) {
    let (provider_id, title, description, category_id, price_low, price_high, duration, status, created_at, updated_at) = 
        services::read(service_id);
    
    return (provider_id, title, description, category_id, price_low, price_high, duration, status, created_at);
}

// Search providers by verification level
@view
func get_providers_by_verification_level(verification_level: felt252) -> (provider_count: felt252, provider_ids: Array<felt252>) {
    let provider_count = verified_provider_count::read(verification_level);
    let mut provider_ids = ArrayTrait::new();
    
    let mut i = 0;
    while i < provider_count {
        let provider_id = verified_providers::read(verification_level, i);
        provider_ids.append(provider_id);
        i = i + 1;
    }
    
    return (provider_count, provider_ids);
}

// Get active providers
@view
func get_active_providers() -> (provider_count: felt252, provider_ids: Array<felt252>) {
    let provider_count = active_provider_count::read();
    let mut provider_ids = ArrayTrait::new();
    
    let mut i = 0;
    while i < provider_count {
        let provider_id = active_providers::read(i);
        provider_ids.append(provider_id);
        i = i + 1;
    }
    
    return (provider_count, provider_ids);
}

// Get services by category
@view
func get_services_by_category(category_id: felt252) -> (service_count: felt252, service_ids: Array<felt252>) {
    let service_count = category_service_count::read(category_id);
    let mut service_ids = ArrayTrait::new();
    
    let mut i = 0;
    while i < service_count {
        let service_id = category_services::read(category_id, i);
        service_ids.append(service_id);
        i = i + 1;
    }
    
    return (service_count, service_ids);
}

// Get provider specializations
@view
func get_provider_specializations(provider_id: felt252) -> (specialization_count: felt252, specializations: Array<felt252>) {
    let specialization_count = provider_specialization_count::read(provider_id);
    let mut specializations = ArrayTrait::new();
    
    let mut i = 0;
    while i < specialization_count {
        let specialization = provider_specializations::read(provider_id, i);
        specializations.append(specialization);
        i = i + 1;
    }
    
    return (specialization_count, specializations);
}

// Get service tags
@view
func get_service_tags(service_id: felt252) -> (tag_count: felt252, tags: Array<felt252>) {
    let tag_count = service_tag_count::read(service_id);
    let mut tags = ArrayTrait::new();
    
    let mut i = 0;
    while i < tag_count {
        let tag = service_tags::read(service_id, i);
        tags.append(tag);
        i = i + 1;
    }
    
    return (tag_count, tags);
}

// Get verification record
@view
func get_verification_record(provider_id: felt252) -> (
    verifier: ContractAddress,
    verification_level: felt252,
    verification_date: felt252,
    expiry_date: felt252,
    notes: felt252
) {
    let (verifier, verification_level, verification_date, expiry_date, notes) = 
        verification_records::read(provider_id);
    
    return (verifier, verification_level, verification_date, expiry_date, notes);
}

// Get provider rating
@view
func get_provider_rating(provider_id: felt252) -> (
    average_rating: felt252,
    total_reviews: felt252,
    last_updated: felt252
) {
    let (average_rating, total_reviews, last_updated) = 
        provider_ratings::read(provider_id);
    
    return (average_rating, total_reviews, last_updated);
}

// Update provider rating (called by review system)
@external
func update_provider_rating(
    provider_id: felt252,
    new_rating: felt252,
    review_count: felt252
) -> () {
    only_authorized();
    
    let timestamp = get_block_timestamp();
    
    provider_ratings::write(
        provider_id,
        new_rating,
        review_count,
        timestamp
    );
    
    return ();
}

// Get total statistics
@view
func get_total_statistics() -> (
    total_providers: felt252,
    total_services: felt252,
    total_categories: felt252,
    active_providers: felt252
) {
    let total_providers = provider_counter::read();
    let total_services = service_counter::read();
    let total_categories = category_counter::read();
    let active_providers = active_provider_count::read();
    
    return (total_providers, total_services, total_categories, active_providers);
}

// Emergency functions for admin
@external
func emergency_suspend_provider(provider_id: felt252, reason: felt252) -> () {
    only_admin();
    
    let (address, name, description, verification_level, status, kyc_status, kyc_expiry, lat, lng, email, phone, website, created_at, updated_at) = 
        providers::read(provider_id);
    
    let timestamp = get_block_timestamp();
    
    // Suspend provider
    providers::write(
        provider_id,
        address,
        name,
        description,
        verification_level,
        STATUS_SUSPENDED,
        kyc_status,
        kyc_expiry,
        lat,
        lng,
        email,
        phone,
        website,
        created_at,
        timestamp
    );
    
    // Emit event
    ProviderDeactivated(provider_id, address, reason, timestamp);
    
    return ();
}

// Check if provider is registered
@view
func is_provider_registered(address: ContractAddress) -> (registered: felt252) {
    let provider_id = provider_by_address::read(address);
    return (provider_id > 0);
}

// Get provider ID by address
@view
func get_provider_id(address: ContractAddress) -> (provider_id: felt252) {
    let provider_id = provider_by_address::read(address);
    return (provider_id);
} 