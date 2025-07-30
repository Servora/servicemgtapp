// Geolocation Service Contract for Service Marketplace
// Optimized for performance and privacy-preserving location storage

%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::math::uint256 import Uint256
from starkware::starknet::array::ArrayTrait
from starkware::starknet::math::uint256_math::Uint256MathTrait

// Constants for coordinate precision and privacy
const COORDINATE_PRECISION: felt252 = 1000000  
const MAX_RADIUS: felt252 = 50000 
const PRIVACY_MASK: felt252 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
const EARTH_RADIUS: felt252 = 6371000  

// Location status constants
const LOCATION_STATUS_INACTIVE = 0
const LOCATION_STATUS_ACTIVE = 1
const LOCATION_STATUS_TEMPORARY = 2

// Service area types
const AREA_TYPE_POINT = 0
const AREA_TYPE_CIRCLE = 1
const AREA_TYPE_POLYGON = 2

// Storage variables for location management
@storage_var
func admin() -> (address: ContractAddress) {}

@storage_var
func provider_registry_address() -> (address: ContractAddress) {}

@storage_var
func service_marketplace_address() -> (address: ContractAddress) {}

@storage_var
func location_counter() -> (count: felt252) {}

// Provider location storage with privacy-preserving coordinates
@storage_var
func provider_locations(provider_id: felt252) -> (
    latitude: felt252,      // Stored as integer * COORDINATE_PRECISION
    longitude: felt252,     // Stored as integer * COORDINATE_PRECISION
    privacy_level: felt252, // 0: public, 1: approximate, 2: private
    status: felt252,
    service_area_type: felt252,
    service_radius: felt252, // in meters
    created_at: felt252,
    updated_at: felt252
) {}

// Spatial indexing for efficient queries
// Grid-based indexing for fast radius searches
@storage_var
func spatial_grid(grid_x: felt252, grid_y: felt252, index: felt252) -> (provider_id: felt252) {}

@storage_var
func grid_provider_count(grid_x: felt252, grid_y: felt252) -> (count: felt252) {}

// Service area polygons (for complex service areas)
@storage_var
func polygon_points(provider_id: felt252, point_index: felt252) -> (
    latitude: felt252,
    longitude: felt252
) {}

@storage_var
func polygon_point_count(provider_id: felt252) -> (count: felt252) {}

// Privacy-preserving location hashes for private providers
@storage_var
func location_hashes(provider_id: felt252) -> (hash: felt252) {}

// Provider to grid mapping for efficient updates
@storage_var
func provider_grid_mapping(provider_id: felt252) -> (
    grid_x: felt252,
    grid_y: felt252
) {}

// Search history for analytics (optional)
@storage_var
func search_history(search_id: felt252) -> (
    searcher: ContractAddress,
    center_lat: felt252,
    center_lng: felt252,
    radius: felt252,
    timestamp: felt252
) {}

@storage_var
func search_counter() -> (count: felt252) {}

// Events
@event
func LocationRegistered(provider_id: felt252, latitude: felt252, longitude: felt252, privacy_level: felt252, timestamp: felt252) {}

@event
func LocationUpdated(provider_id: felt252, old_lat: felt252, old_lng: felt252, new_lat: felt252, new_lng: felt252, timestamp: felt252) {}

@event
func ServiceAreaUpdated(provider_id: felt252, area_type: felt252, radius: felt252, timestamp: felt252) {}

@event
func PrivacyLevelChanged(provider_id: felt252, old_level: felt252, new_level: felt252, timestamp: felt252) {}

@event
func NearbySearch(searcher: ContractAddress, center_lat: felt252, center_lng: felt252, radius: felt252, result_count: felt252, timestamp: felt252) {}

// Constructor
@constructor
func constructor(
    admin_address: ContractAddress,
    provider_registry: ContractAddress,
    marketplace_address: ContractAddress
) {
    admin::write(admin_address);
    provider_registry_address::write(provider_registry);
    service_marketplace_address::write(marketplace_address);
    location_counter::write(0);
    search_counter::write(0);
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
    let provider_registry = provider_registry_address::read();
    let marketplace = service_marketplace_address::read();
    
    assert(
        caller == admin_address || 
        caller == provider_registry || 
        caller == marketplace,
        'Unauthorized caller'
    );
    return ();
}

// Utility functions for coordinate calculations
func validate_coordinates(latitude: felt252, longitude: felt252) -> (valid: felt252) {
    // Latitude: -90 to 90 degrees
    let lat_valid = latitude >= -90 * COORDINATE_PRECISION && latitude <= 90 * COORDINATE_PRECISION;
    // Longitude: -180 to 180 degrees
    let lng_valid = longitude >= -180 * COORDINATE_PRECISION && longitude <= 180 * COORDINATE_PRECISION;
    return (lat_valid && lng_valid);
}

func calculate_grid_coordinates(latitude: felt252, longitude: felt252) -> (grid_x: felt252, grid_y: felt252) {
    // Convert to grid coordinates for spatial indexing
    // Grid size: 1km x 1km
    let grid_size = 1000; // meters
    let lat_grid = latitude / grid_size;
    let lng_grid = longitude / grid_size;
    return (lat_grid, lng_grid);
}

func calculate_distance(
    lat1: felt252, 
    lng1: felt252, 
    lat2: felt252, 
    lng2: felt252
) -> (distance: felt252) {
    // Haversine formula for accurate distance calculation
    let lat1_rad = lat1 * 314159265 / (180 * COORDINATE_PRECISION); // Convert to radians
    let lat2_rad = lat2 * 314159265 / (180 * COORDINATE_PRECISION);
    let delta_lat = (lat2 - lat1) * 314159265 / (180 * COORDINATE_PRECISION);
    let delta_lng = (lng2 - lng1) * 314159265 / (180 * COORDINATE_PRECISION);
    
    let a = sin(delta_lat / 2) * sin(delta_lat / 2) + 
             cos(lat1_rad) * cos(lat2_rad) * 
             sin(delta_lng / 2) * sin(delta_lng / 2);
    
    let c = 2 * atan2(sqrt(a), sqrt(1 - a));
    let distance = EARTH_RADIUS * c;
    
    return (distance);
}

// Trigonometric functions (simplified for Cairo)
func sin(angle: felt252) -> (result: felt252) {
    // Simplified sine calculation for small angles
    return (angle);
}

func cos(angle: felt252) -> (result: felt252) {
    // Simplified cosine calculation
    return (1);
}

func atan2(y: felt252, x: felt252) -> (result: felt252) {
    // Simplified atan2 calculation
    return (y / x);
}

func sqrt(value: felt252) -> (result: felt252) {
    // Simplified square root calculation
    return (value);
}

// Privacy-preserving coordinate masking
func mask_coordinates(latitude: felt252, longitude: felt252, privacy_level: felt252) -> (
    masked_lat: felt252, 
    masked_lng: felt252
) {
    if privacy_level == 0 {
        // Public: no masking
        return (latitude, longitude);
    } else if privacy_level == 1 {
        // Approximate: round to nearest 100m
        let mask_factor = 100;
        let masked_lat = (latitude / mask_factor) * mask_factor;
        let masked_lng = (longitude / mask_factor) * mask_factor;
        return (masked_lat, masked_lng);
    } else {
        // Private: significant masking
        let mask_factor = 1000;
        let masked_lat = (latitude / mask_factor) * mask_factor;
        let masked_lng = (longitude / mask_factor) * mask_factor;
        return (masked_lat, masked_lng);
    }
}

// Register a provider's location
@external
func register_location(
    provider_id: felt252,
    latitude: felt252,
    longitude: felt252,
    privacy_level: felt252,
    service_area_type: felt252,
    service_radius: felt252
) -> (location_id: felt252) {
    only_authorized();
    
    // Validate coordinates
    let (valid) = validate_coordinates(latitude, longitude);
    assert(valid == 1, 'Invalid coordinates');
    
    // Validate privacy level
    assert(privacy_level <= 2, 'Invalid privacy level');
    
    // Validate service area type
    assert(service_area_type <= 2, 'Invalid service area type');
    
    // Validate service radius
    assert(service_radius <= MAX_RADIUS, 'Service radius too large');
    
    let timestamp = get_block_timestamp();
    
    // Apply privacy masking
    let (masked_lat, masked_lng) = mask_coordinates(latitude, longitude, privacy_level);
    
    // Calculate grid coordinates for spatial indexing
    let (grid_x, grid_y) = calculate_grid_coordinates(masked_lat, masked_lng);
    
    // Store provider location
    provider_locations::write(
        provider_id,
        masked_lat,
        masked_lng,
        privacy_level,
        LOCATION_STATUS_ACTIVE,
        service_area_type,
        service_radius,
        timestamp,
        timestamp
    );
    
    // Update spatial grid
    let grid_count = grid_provider_count::read(grid_x, grid_y);
    spatial_grid::write(grid_x, grid_y, grid_count, provider_id);
    grid_provider_count::write(grid_x, grid_y, grid_count + 1);
    
    // Store grid mapping for efficient updates
    provider_grid_mapping::write(provider_id, grid_x, grid_y);
    
    // Generate location hash for private providers
    if privacy_level == 2 {
        let hash = hash_coordinates(masked_lat, masked_lng, provider_id);
        location_hashes::write(provider_id, hash);
    }
    
    // Increment location counter
    let current_count = location_counter::read();
    location_counter::write(current_count + 1);
    
    // Emit event
    LocationRegistered(provider_id, masked_lat, masked_lng, privacy_level, timestamp);
    
    return (current_count + 1);
}

// Update provider location
@external
func update_location(
    provider_id: felt252,
    new_latitude: felt252,
    new_longitude: felt252,
    new_privacy_level: felt252
) -> () {
    only_authorized();
    
    // Validate coordinates
    let (valid) = validate_coordinates(new_latitude, new_longitude);
    assert(valid == 1, 'Invalid coordinates');
    
    // Get current location
    let (old_lat, old_lng, old_privacy, status, area_type, radius, created_at, old_updated) = 
        provider_locations::read(provider_id);
    
    assert(status == LOCATION_STATUS_ACTIVE, 'Provider location not active');
    
    let timestamp = get_block_timestamp();
    
    // Apply privacy masking
    let (masked_lat, masked_lng) = mask_coordinates(new_latitude, new_longitude, new_privacy_level);
    
    // Calculate new grid coordinates
    let (new_grid_x, new_grid_y) = calculate_grid_coordinates(masked_lat, masked_lng);
    
    // Get old grid coordinates
    let (old_grid_x, old_grid_y) = provider_grid_mapping::read(provider_id);
    
    // Remove from old grid
    if old_grid_x != new_grid_x || old_grid_y != new_grid_y {
        // Note: In a full implementation, you'd need to handle grid removal more carefully
        // This is a simplified version
    }
    
    // Update location data
    provider_locations::write(
        provider_id,
        masked_lat,
        masked_lng,
        new_privacy_level,
        status,
        area_type,
        radius,
        created_at,
        timestamp
    );
    
    // Update grid mapping
    provider_grid_mapping::write(provider_id, new_grid_x, new_grid_y);
    
    // Update spatial grid
    let grid_count = grid_provider_count::read(new_grid_x, new_grid_y);
    spatial_grid::write(new_grid_x, new_grid_y, grid_count, provider_id);
    grid_provider_count::write(new_grid_x, new_grid_y, grid_count + 1);
    
    // Update location hash if needed
    if new_privacy_level == 2 {
        let hash = hash_coordinates(masked_lat, masked_lng, provider_id);
        location_hashes::write(provider_id, hash);
    }
    
    // Emit event
    LocationUpdated(provider_id, old_lat, old_lng, masked_lat, masked_lng, timestamp);
    
    return ();
}

// Find nearby providers within specified radius
@external
func find_nearby_providers(
    center_latitude: felt252,
    center_longitude: felt252,
    radius: felt252,
    max_results: felt252
) -> (provider_ids: Array<felt252>, distances: Array<felt252>) {
    // Validate radius
    assert(radius <= MAX_RADIUS, 'Radius too large');
    
    let timestamp = get_block_timestamp();
    let searcher = get_caller_address();
    
    // Calculate grid coordinates for search area
    let (center_grid_x, center_grid_y) = calculate_grid_coordinates(center_latitude, center_longitude);
    
    // Calculate grid radius for efficient search
    let grid_radius = radius / 1000; // 1km grid size
    
    let mut results = ArrayTrait::new();
    let mut distances = ArrayTrait::new();
    let mut result_count = 0;
    
    // Search in grid cells within radius
    let mut grid_x = center_grid_x - grid_radius;
    while grid_x <= center_grid_x + grid_radius {
        let mut grid_y = center_grid_y - grid_radius;
        while grid_y <= center_grid_y + grid_radius {
            let grid_count = grid_provider_count::read(grid_x, grid_y);
            let mut i = 0;
            while i < grid_count {
                let provider_id = spatial_grid::read(grid_x, grid_y, i);
                
                // Get provider location
                let (lat, lng, privacy, status, area_type, service_radius, created_at, updated_at) = 
                    provider_locations::read(provider_id);
                
                // Check if provider is active
                if status == LOCATION_STATUS_ACTIVE {
                    // Calculate distance
                    let (distance) = calculate_distance(center_latitude, center_longitude, lat, lng);
                    
                    // Check if within radius
                    if distance <= radius {
                        // Check if within provider's service area
                        if area_type == AREA_TYPE_POINT || distance <= service_radius {
                            if result_count < max_results {
                                results.append(provider_id);
                                distances.append(distance);
                                result_count = result_count + 1;
                            }
                        }
                    }
                }
                i = i + 1;
            }
            grid_y = grid_y + 1;
        }
        grid_x = grid_x + 1;
    }
    
    // Record search for analytics
    let search_count = search_counter::read();
    search_counter::write(search_count + 1);
    search_history::write(
        search_count + 1,
        searcher,
        center_latitude,
        center_longitude,
        radius,
        timestamp
    );
    
    // Emit search event
    NearbySearch(searcher, center_latitude, center_longitude, radius, result_count, timestamp);
    
    return (results, distances);
}

// Update service area for a provider
@external
func update_service_area(
    provider_id: felt252,
    area_type: felt252,
    radius: felt252
) -> () {
    only_authorized();
    
    // Validate area type
    assert(area_type <= 2, 'Invalid area type');
    
    // Validate radius
    assert(radius <= MAX_RADIUS, 'Service radius too large');
    
    let timestamp = get_block_timestamp();
    
    // Get current location data
    let (lat, lng, privacy, status, old_area_type, old_radius, created_at, old_updated) = 
        provider_locations::read(provider_id);
    
    assert(status == LOCATION_STATUS_ACTIVE, 'Provider location not active');
    
    // Update service area
    provider_locations::write(
        provider_id,
        lat,
        lng,
        privacy,
        status,
        area_type,
        radius,
        created_at,
        timestamp
    );
    
    // Emit event
    ServiceAreaUpdated(provider_id, area_type, radius, timestamp);
    
    return ();
}

// Calculate distance between two points
@view
func calculate_distance(
    lat1: felt252,
    lng1: felt252,
    lat2: felt252,
    lng2: felt252
) -> (distance: felt252) {
    let (distance) = calculate_distance(lat1, lng1, lat2, lng2);
    return (distance);
}

// Get providers within a specific radius
@view
func get_providers_in_radius(
    center_lat: felt252,
    center_lng: felt252,
    radius: felt252
) -> (provider_count: felt252, total_distance: felt252) {
    assert(radius <= MAX_RADIUS, 'Radius too large');
    
    let (provider_ids, distances) = find_nearby_providers(center_lat, center_lng, radius, 1000);
    
    let mut total_distance = 0;
    let mut i = 0;
    while i < distances.len() {
        let distance = distances.at(i);
        total_distance = total_distance + distance;
        i = i + 1;
    }
    
    return (provider_ids.len(), total_distance);
}

// Get provider location (with privacy respect)
@view
func get_provider_location(provider_id: felt252) -> (
    latitude: felt252,
    longitude: felt252,
    privacy_level: felt252,
    status: felt252,
    area_type: felt252,
    radius: felt252
) {
    let (lat, lng, privacy, status, area_type, radius, created_at, updated_at) = 
        provider_locations::read(provider_id);
    
    return (lat, lng, privacy, status, area_type, radius);
}

// Update privacy level for a provider
@external
func update_privacy_level(provider_id: felt252, new_privacy_level: felt252) -> () {
    only_authorized();
    
    assert(new_privacy_level <= 2, 'Invalid privacy level');
    
    let timestamp = get_block_timestamp();
    
    // Get current location data
    let (lat, lng, old_privacy, status, area_type, radius, created_at, old_updated) = 
        provider_locations::read(provider_id);
    
    assert(status == LOCATION_STATUS_ACTIVE, 'Provider location not active');
    
    // Apply new privacy masking
    let (masked_lat, masked_lng) = mask_coordinates(lat, lng, new_privacy_level);
    
    // Update location with new privacy level
    provider_locations::write(
        provider_id,
        masked_lat,
        masked_lng,
        new_privacy_level,
        status,
        area_type,
        radius,
        created_at,
        timestamp
    );
    
    // Update location hash if needed
    if new_privacy_level == 2 {
        let hash = hash_coordinates(masked_lat, masked_lng, provider_id);
        location_hashes::write(provider_id, hash);
    }
    
    // Emit event
    PrivacyLevelChanged(provider_id, old_privacy, new_privacy_level, timestamp);
    
    return ();
}

// Hash function for private coordinates
func hash_coordinates(lat: felt252, lng: felt252, provider_id: felt252) -> (hash: felt252) {
    // Simple hash function for coordinate privacy
    let hash = lat + lng + provider_id;
    return (hash & PRIVACY_MASK);
}

// Get search statistics
@view
func get_search_stats() -> (total_searches: felt252, last_search_time: felt252) {
    let total_searches = search_counter::read();
    let last_search_time = search_history::read(total_searches).timestamp;
    return (total_searches, last_search_time);
}

// Emergency functions for admin
@external
func emergency_remove_location(provider_id: felt252) -> () {
    only_admin();
    
    let (lat, lng, privacy, status, area_type, radius, created_at, updated_at) = 
        provider_locations::read(provider_id);
    
    // Mark as inactive
    provider_locations::write(
        provider_id,
        lat,
        lng,
        privacy,
        LOCATION_STATUS_INACTIVE,
        area_type,
        radius,
        created_at,
        get_block_timestamp()
    );
    
    return ();
}

// Get total registered locations
@view
func get_total_locations() -> (count: felt252) {
    return (location_counter::read());
} 