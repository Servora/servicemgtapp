// Interface definitions for GeolocationService

use starknet::ContractAddress;

#[starknet::interface]
trait IGeolocationService<TContractState> {
    // Core location management
    fn register_location(
        ref self: TContractState,
        provider_id: felt252,
        latitude: felt252,
        longitude: felt252,
        privacy_level: felt252,
        service_area_type: felt252,
        service_radius: felt252
    ) -> felt252;
    
    fn update_location(
        ref self: TContractState,
        provider_id: felt252,
        new_latitude: felt252,
        new_longitude: felt252,
        new_privacy_level: felt252
    );
    
    fn update_service_area(
        ref self: TContractState,
        provider_id: felt252,
        area_type: felt252,
        radius: felt252
    );
    
    // Search and discovery
    fn find_nearby_providers(
        self: @TContractState,
        center_latitude: felt252,
        center_longitude: felt252,
        radius: felt252,
        max_results: felt252
    ) -> (Array<felt252>, Array<felt252>);
    
    fn get_providers_in_radius(
        self: @TContractState,
        center_lat: felt252,
        center_lng: felt252,
        radius: felt252
    ) -> (felt252, felt252);
    
    // Distance calculations
    fn calculate_distance(
        self: @TContractState,
        lat1: felt252,
        lng1: felt252,
        lat2: felt252,
        lng2: felt252
    ) -> felt252;
    
    // Privacy management
    fn update_privacy_level(
        ref self: TContractState,
        provider_id: felt252,
        new_privacy_level: felt252
    );
    
    // View functions
    fn get_provider_location(
        self: @TContractState,
        provider_id: felt252
    ) -> (felt252, felt252, felt252, felt252, felt252, felt252);
    
    fn get_search_stats(self: @TContractState) -> (felt252, felt252);
    
    fn get_total_locations(self: @TContractState) -> felt252;
    
    // Admin functions
    fn emergency_remove_location(
        ref self: TContractState,
        provider_id: felt252
    );
}

// Data structures for location information
#[derive(Copy, Drop, Serde, starknet::Store)]
struct LocationInfo {
    provider_id: felt252,
    latitude: felt252,
    longitude: felt252,
    privacy_level: felt252,
    status: felt252,
    service_area_type: felt252,
    service_radius: felt252,
    created_at: felt252,
    updated_at: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct SearchResult {
    provider_id: felt252,
    distance: felt252,
    latitude: felt252,
    longitude: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct ServiceArea {
    area_type: felt252,
    radius: felt252,
    center_lat: felt252,
    center_lng: felt252,
}

// Events interface
#[starknet::interface]
trait IGeolocationEvents<TContractState> {
    fn location_registered(
        self: @TContractState,
        provider_id: felt252,
        latitude: felt252,
        longitude: felt252,
        privacy_level: felt252,
        timestamp: felt252
    );
    
    fn location_updated(
        self: @TContractState,
        provider_id: felt252,
        old_lat: felt252,
        old_lng: felt252,
        new_lat: felt252,
        new_lng: felt252,
        timestamp: felt252
    );
    
    fn service_area_updated(
        self: @TContractState,
        provider_id: felt252,
        area_type: felt252,
        radius: felt252,
        timestamp: felt252
    );
    
    fn privacy_level_changed(
        self: @TContractState,
        provider_id: felt252,
        old_level: felt252,
        new_level: felt252,
        timestamp: felt252
    );
    
    fn nearby_search(
        self: @TContractState,
        searcher: ContractAddress,
        center_lat: felt252,
        center_lng: felt252,
        radius: felt252,
        result_count: felt252,
        timestamp: felt252
    );
}

// Integration interfaces for other contracts
#[starknet::interface]
trait IGeolocationIntegration<TContractState> {
    // Provider Registry Integration
    fn is_provider_registered(
        self: @TContractState,
        provider_id: felt252
    ) -> bool;
    
    fn get_provider_address(
        self: @TContractState,
        provider_id: felt252
    ) -> ContractAddress;
    
    // Service Marketplace Integration
    fn get_provider_services(
        self: @TContractState,
        provider_id: felt252
    ) -> Array<felt252>;
    
    fn is_service_active(
        self: @TContractState,
        service_id: felt252
    ) -> bool;
    
    // Analytics Integration
    fn record_location_search(
        ref self: TContractState,
        searcher: ContractAddress,
        center_lat: felt252,
        center_lng: felt252,
        radius: felt252,
        result_count: felt252
    );
    
    fn record_location_update(
        ref self: TContractState,
        provider_id: felt252,
        old_lat: felt252,
        old_lng: felt252,
        new_lat: felt252,
        new_lng: felt252
    );
}

// Constants for integration
const GEOLOCATION_MODULE_ID: felt252 = 'geolocation_service';
const LOCATION_EVENT_TOPIC: felt252 = 'location_event';
const SEARCH_EVENT_TOPIC: felt252 = 'search_event';
const PRIVACY_EVENT_TOPIC: felt252 = 'privacy_event';

// Error codes
const ERROR_INVALID_COORDINATES: felt252 = 'Invalid coordinates';
const ERROR_INVALID_RADIUS: felt252 = 'Invalid radius';
const ERROR_INVALID_PRIVACY_LEVEL: felt252 = 'Invalid privacy level';
const ERROR_INVALID_AREA_TYPE: felt252 = 'Invalid area type';
const ERROR_PROVIDER_NOT_FOUND: felt252 = 'Provider not found';
const ERROR_UNAUTHORIZED_CALLER: felt252 = 'Unauthorized caller';
const ERROR_LOCATION_NOT_ACTIVE: felt252 = 'Location not active';
const ERROR_SEARCH_RADIUS_TOO_LARGE: felt252 = 'Search radius too large';
const ERROR_MAX_RESULTS_EXCEEDED: felt252 = 'Max results exceeded';

// Success codes
const SUCCESS_LOCATION_REGISTERED: felt252 = 'Location registered successfully';
const SUCCESS_LOCATION_UPDATED: felt252 = 'Location updated successfully';
const SUCCESS_SERVICE_AREA_UPDATED: felt252 = 'Service area updated successfully';
const SUCCESS_PRIVACY_LEVEL_UPDATED: felt252 = 'Privacy level updated successfully';
const SUCCESS_PROVIDERS_FOUND: felt252 = 'Providers found successfully';
const SUCCESS_DISTANCE_CALCULATED: felt252 = 'Distance calculated successfully'; 