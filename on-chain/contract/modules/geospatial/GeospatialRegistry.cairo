// SPDX-License-Identifier: MIT
// Cairo 1.0 Geospatial Registry Contract for Service Marketplace

%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::math::uint256 import Uint256
from starkware::starknet::array::ArrayTrait

// Storage variables
@storage_var
func service_count() -> (res: felt252) {}

// Geohash is stored as a felt252 for efficiency
// We'll use a precision of 8 characters which gives ~20m precision
@storage_var
func service_locations(service_id: felt252) -> (
    owner: ContractAddress,
    geohash: felt252,
    metadata: felt252,
    active: felt252,
    created_at: felt252,
    updated_at: felt252
) {}

// Index for efficient proximity search
// We store the first 5 characters of geohash (neighborhood level) as key
// and an array of service_ids as value
@storage_var
func geohash_index(geohash_prefix: felt252, index: felt252) -> (service_id: felt252) {}

@storage_var
func geohash_index_size(geohash_prefix: felt252) -> (size: felt252) {}

// Service history for tracking location updates
@storage_var
func location_history(service_id: felt252, update_index: felt252) -> (
    geohash: felt252,
    timestamp: felt252
) {}

@storage_var
func location_history_count(service_id: felt252) -> (count: felt252) {}

// Events
@event
func ServiceRegistered(service_id: felt252, owner: ContractAddress, geohash: felt252, timestamp: felt252) {}

@event
func LocationUpdated(service_id: felt252, old_geohash: felt252, new_geohash: felt252, timestamp: felt252) {}

@event
func ServiceStatusChanged(service_id: felt252, active: felt252, timestamp: felt252) {}

// Constructor
@constructor
func constructor() {
    service_count::write(0);
    return ();
}

// Register a new service location
@external
func register_service(geohash: felt252, metadata: felt252) -> (service_id: felt252) {
    // Validate geohash format and length
    assert(is_valid_geohash(geohash), 'Invalid geohash format');
    
    let caller = get_caller_address();
    let timestamp = get_block_timestamp();
    
    // Get and increment service count
    let current_count = service_count::read();
    let service_id = current_count + 1;
    service_count::write(service_id);
    
    // Store service location data
    service_locations::write(
        service_id,
        caller,
        geohash,
        metadata,
        1, // active by default
        timestamp,
        timestamp
    );
    
    // Update geohash index for proximity search
    let geohash_prefix = extract_prefix(geohash, 5);
    let index_size = geohash_index_size::read(geohash_prefix);
    geohash_index::write(geohash_prefix, index_size, service_id);
    geohash_index_size::write(geohash_prefix, index_size + 1);
    
    // Initialize location history
    location_history::write(service_id, 0, geohash, timestamp);
    location_history_count::write(service_id, 1);
    
    // Emit event
    ServiceRegistered(service_id, caller, geohash, timestamp);
    
    return (service_id);
}

// Update service location
@external
func update_location(service_id: felt252, geohash: felt252) {
    // Validate geohash
    assert(is_valid_geohash(geohash), 'Invalid geohash format');
    
    let caller = get_caller_address();
    let timestamp = get_block_timestamp();
    
    // Get current service data
    let (owner, old_geohash, metadata, active, created_at, _) = service_locations::read(service_id);
    
    // Verify ownership
    assert(caller == owner, 'Not the service owner');
    
    // Update service location
    service_locations::write(
        service_id,
        owner,
        geohash,
        metadata,
        active,
        created_at,
        timestamp
    );
    
    // Update geohash index
    // Remove from old index
    let old_prefix = extract_prefix(old_geohash, 5);
    remove_from_index(old_prefix, service_id);
    
    // Add to new index
    let new_prefix = extract_prefix(geohash, 5);
    let index_size = geohash_index_size::read(new_prefix);
    geohash_index::write(new_prefix, index_size, service_id);
    geohash_index_size::write(new_prefix, index_size + 1);
    
    // Update location history
    let history_count = location_history_count::read(service_id);
    location_history::write(service_id, history_count, geohash, timestamp);
    location_history_count::write(service_id, history_count + 1);
    
    // Emit event
    LocationUpdated(service_id, old_geohash, geohash, timestamp);
    
    return ();
}

// Set service active status
@external
func set_service_status(service_id: felt252, active: felt252) {
    let caller = get_caller_address();
    let timestamp = get_block_timestamp();
    
    // Get current service data
    let (owner, geohash, metadata, current_active, created_at, updated_at) = service_locations::read(service_id);
    
    // Verify ownership
    assert(caller == owner, 'Not the service owner');
    
    // Update service status
    service_locations::write(
        service_id,
        owner,
        geohash,
        metadata,
        active,
        created_at,
        timestamp
    );
    
    // Emit event
    ServiceStatusChanged(service_id, active, timestamp);
    
    return ();
}

// Get service details
@view
func get_service(service_id: felt252) -> (
    owner: ContractAddress,
    geohash: felt252,
    metadata: felt252,
    active: felt252,
    created_at: felt252,
    updated_at: felt252
) {
    let (owner, geohash, metadata, active, created_at, updated_at) = service_locations::read(service_id);
    return (owner, geohash, metadata, active, created_at, updated_at);
}

// Get services by proximity (using geohash prefix matching)
@view
func find_services_by_proximity(center_geohash: felt252, precision: felt252) -> (service_ids_len: felt252, service_ids: felt252*) {
    assert(precision >= 1 && precision <= 8, 'Invalid precision');
    assert(is_valid_geohash(center_geohash), 'Invalid geohash format');
    
    // Extract prefix based on desired precision
    let prefix = extract_prefix(center_geohash, precision);
    
    // Get all services in this geohash prefix
    let count = geohash_index_size::read(prefix);
    let service_ids = ArrayTrait::new();
    
    // Collect all service IDs in this prefix
    let mut i = 0;
    while i < count {
        let service_id = geohash_index::read(prefix, i);
        // Only include active services
        let (_, _, _, active, _, _) = service_locations::read(service_id);
        if active == 1 {
            service_ids.append(service_id);
        }
        i += 1;
    }
    
    return (service_ids.len(), service_ids.span());
}

// Get location history for a service
@view
func get_location_history(service_id: felt252) -> (history_len: felt252, geohashes: felt252*, timestamps: felt252*) {
    let count = location_history_count::read(service_id);
    let geohashes = ArrayTrait::new();
    let timestamps = ArrayTrait::new();
    
    let mut i = 0;
    while i < count {
        let (geohash, timestamp) = location_history::read(service_id, i);
        geohashes.append(geohash);
        timestamps.append(timestamp);
        i += 1;
    }
    
    return (count, geohashes.span(), timestamps.span());
}

// Helper function to validate geohash format
@view
func is_valid_geohash(geohash: felt252) -> felt252 {
    // Basic validation - in a real implementation, you would check:
    // 1. Length (typically 1-12 characters)
    // 2. Character set (base32: 0-9, b-h, j-n, p-z, excluding a, i, l, o)
    
    // For simplicity, we'll just check if it's non-zero
    // In a production contract, implement proper validation
    return geohash != 0;
}

// Helper to extract prefix from geohash
@view
func extract_prefix(geohash: felt252, length: felt252) -> felt252 {
    // In a real implementation, you would extract the first 'length' characters
    // For simplicity in this example, we'll use a placeholder
    // This would need proper bit manipulation in a production contract
    
    // Placeholder implementation
    return geohash;
}

// Helper to remove a service from a geohash index
func remove_from_index(prefix: felt252, service_id: felt252) {
    let size = geohash_index_size::read(prefix);
    let mut found = 0;
    let mut i = 0;
    
    // Find the service in the index
    while i < size {
        let current_id = geohash_index::read(prefix, i);
        if current_id == service_id {
            found = 1;
            break;
        }
        i += 1;
    }
    
    // If found, replace with the last element and decrease size
    if found == 1 {
        if i < size - 1 {
            let last_id = geohash_index::read(prefix, size - 1);
            geohash_index::write(prefix, i, last_id);
        }
        geohash_index_size::write(prefix, size - 1);
    }
    
    return ();
}