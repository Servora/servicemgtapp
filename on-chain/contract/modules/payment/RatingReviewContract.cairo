// SPDX-License-Identifier: MIT
// Cairo 1.0 Rating and Review Contract for Service Marketplace

%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::math::uint256 import Uint256
from starkware::starknet::array::ArrayTrait

// Storage variables
@storage_var
func admin() -> (address: ContractAddress) {}

@storage_var
func service_marketplace_contract() -> (address: ContractAddress) {}

@storage_var
func provider_registry_contract() -> (address: ContractAddress) {}

// Review count for a provider
@storage_var
func provider_review_count(provider_id: felt252) -> (count: felt252) {}

// Total ratings sum for a provider (for calculating average)
@storage_var
func provider_rating_sum(provider_id: felt252) -> (sum: felt252) {}

// Provider's average rating (stored with 1 decimal place precision - 45 means 4.5/5)
@storage_var
func provider_rating_avg(provider_id: felt252) -> (avg: felt252) {}

// Store a specific review
@storage_var
func reviews(provider_id: felt252, review_id: felt252) -> (
    reviewer: ContractAddress,
    service_id: felt252,
    rating: felt252,
    timestamp: felt252,
    verified: felt252
) {}

// Store review content separately to optimize storage
@storage_var
func review_content(provider_id: felt252, review_id: felt252) -> (content: felt252) {}

// Mapping to track if a user has reviewed a specific service
@storage_var
func has_reviewed(reviewer: ContractAddress, service_id: felt252) -> (has_reviewed: felt252) {}

// Events
@event
func ReviewSubmitted(
    provider_id: felt252,
    review_id: felt252,
    reviewer: ContractAddress,
    service_id: felt252,
    rating: felt252,
    verified: felt252,
    timestamp: felt252
) {}

@event
func RatingUpdated(
    provider_id: felt252,
    new_avg_rating: felt252,
    review_count: felt252,
    timestamp: felt252
) {}

@event
func ReviewVerified(
    provider_id: felt252,
    review_id: felt252,
    timestamp: felt252
) {}

// Constructor
@constructor
func constructor{
    syscalls: SyscallPtr
}(
    admin_address: ContractAddress,
    marketplace_address: ContractAddress,
    registry_address: ContractAddress
) {
    admin.write(admin_address);
    service_marketplace_contract.write(marketplace_address);
    provider_registry_contract.write(registry_address);
    return ();
}

// Modifiers
func only_admin{
    syscalls: SyscallPtr
}() {
    let (caller) = get_caller_address();
    let (admin_address) = admin.read();
    assert caller == admin_address, 'Only admin can call this';
    return ();
}

// Submit a review for a provider
@external
func submit_review{
    syscalls: SyscallPtr
}(
    provider_id: felt252,
    service_id: felt252,
    rating: felt252,
    content: felt252
) -> (review_id: felt252) {
    alloc_locals
    let (caller) = get_caller_address();
    let (timestamp) = get_block_timestamp();
    
    // Validate rating is between 1-5
    assert rating >= 1 && rating <= 5, 'Rating must be between 1-5';
    
    // Check if the user has already reviewed this service
    let (already_reviewed) = has_reviewed.read(caller, service_id);
    assert already_reviewed == 0, 'Already reviewed this service';
    
    // Mark as reviewed
    has_reviewed.write(caller, service_id, 1);
    
    // Get current review count and increment
    let (current_count) = provider_review_count.read(provider_id);
    let new_count = current_count + 1;
    provider_review_count.write(provider_id, new_count);
    
    // Determine if review is verified (initially set to 0, will be verified later)
    let verified = 0;
    
    // Store the review
    reviews.write(provider_id, current_count, (caller, service_id, rating, timestamp, verified));
    review_content.write(provider_id, current_count, content);
    
    // Update provider rating
    let (current_sum) = provider_rating_sum.read(provider_id);
    let new_sum = current_sum + rating;
    provider_rating_sum.write(provider_id, new_sum);
    
    // Calculate new average rating with 1 decimal precision
    // Formula: (sum * 10) / count - This gives us 1 decimal place
    let new_avg = (new_sum * 10) / new_count;
    provider_rating_avg.write(provider_id, new_avg);
    
    // Emit events
    ReviewSubmitted(provider_id, current_count, caller, service_id, rating, verified, timestamp);
    RatingUpdated(provider_id, new_avg, new_count, timestamp);
    
    return (current_count);
}

// Verify a review (only admin or marketplace contract can call)
@external
func verify_review{
    syscalls: SyscallPtr
}(
    provider_id: felt252,
    review_id: felt252
) -> () {
    alloc_locals
    let (caller) = get_caller_address();
    let (admin_address) = admin.read();
    let (marketplace_address) = service_marketplace_contract.read();
    
    // Only admin or marketplace contract can verify reviews
    assert caller == admin_address || caller == marketplace_address, 'Unauthorized verification';
    
    // Get the review
    let (reviewer, service_id, rating, timestamp, verified) = reviews.read(provider_id, review_id);
    
    // Ensure review exists and is not already verified
    assert reviewer != ContractAddress(0), 'Review does not exist';
    assert verified == 0, 'Review already verified';
    
    // Update the review to verified status
    reviews.write(provider_id, review_id, (reviewer, service_id, rating, timestamp, 1));
    
    // Emit verification event
    let (current_timestamp) = get_block_timestamp();
    ReviewVerified(provider_id, review_id, current_timestamp);
    
    return ();
}

// Get provider's average rating
@view
func get_provider_rating(provider_id: felt252) -> (avg_rating: felt252, review_count: felt252) {
    let (avg) = provider_rating_avg.read(provider_id);
    let (count) = provider_review_count.read(provider_id);
    return (avg, count);
}

// Get a specific review
@view
func get_review(provider_id: felt252, review_id: felt252) -> (
    reviewer: ContractAddress,
    service_id: felt252,
    rating: felt252,
    timestamp: felt252,
    verified: felt252,
    content: felt252
) {
    let (reviewer, service_id, rating, timestamp, verified) = reviews.read(provider_id, review_id);
    let (content) = review_content.read(provider_id, review_id);
    return (reviewer, service_id, rating, timestamp, verified, content);
}

// Get all reviews for a provider (with pagination)
@view
func get_provider_reviews(provider_id: felt252, offset: felt252, limit: felt252) -> (
    review_ids_len: felt252,
    review_ids: felt252*
) {
    alloc_locals
    let (total_reviews) = provider_review_count.read(provider_id);
    
    // Calculate actual number of reviews to return
    let end_idx = if offset + limit > total_reviews {
        total_reviews
    } else {
        offset + limit
    };
    
    let actual_count = end_idx - offset;
    
    // Create an array of review IDs
    local review_ids: felt252[100]; // Assume max 100 reviews per request
    let mut i = 0;
    
    // Fill the array with review IDs
    while i < actual_count {
        let review_id = offset + i;
        review_ids[i] = review_id;
        i = i + 1;
    }
    
    return (actual_count, review_ids);
}

// Check if a user has reviewed a specific service
@view
func check_has_reviewed(reviewer: ContractAddress, service_id: felt252) -> (has_reviewed: felt252) {
    return has_reviewed.read(reviewer, service_id);
}

// Set the marketplace contract address
@external
func set_marketplace_contract{
    syscalls: SyscallPtr
}(marketplace_address: ContractAddress) -> () {
    only_admin();
    service_marketplace_contract.write(marketplace_address);
    return ();
}

// Set the provider registry contract address
@external
func set_provider_registry_contract{
    syscalls: SyscallPtr
}(registry_address: ContractAddress) -> () {
    only_admin();
    provider_registry_contract.write(registry_address);
    return ();
}

// Filter reviews by rating (with pagination)
@view
func filter_reviews_by_rating(provider_id: felt252, min_rating: felt252, max_rating: felt252, offset: felt252, limit: felt252) -> (
    review_ids_len: felt252,
    review_ids: felt252*
) {
    alloc_locals
    let (total_reviews) = provider_review_count.read(provider_id);
    
    // Create an array of matching review IDs
    local matching_review_ids: felt252[100]; // Assume max 100 reviews per request
    let mut matching_count = 0;
    let mut i = 0;
    
    // Scan through all reviews to find matches
    while i < total_reviews && matching_count < limit {
        let (reviewer, service_id, rating, timestamp, verified) = reviews.read(provider_id, i);
        
        // Check if rating is within range
        if rating >= min_rating && rating <= max_rating && i >= offset {
            matching_review_ids[matching_count] = i;
            matching_count = matching_count + 1;
        }
        
        i = i + 1;
    }
    
    return (matching_count, matching_review_ids);
}

// Calculate weighted rating for a provider (considering review verification)
@view
func get_weighted_rating(provider_id: felt252) -> (weighted_rating: felt252) {
    alloc_locals
    let (total_reviews) = provider_review_count.read(provider_id);
    
    if total_reviews == 0 {
        return (0);
    }
    
    let mut weighted_sum = 0;
    let mut weight_sum = 0;
    let mut i = 0;
    
    // Iterate through all reviews
    while i < total_reviews {
        let (reviewer, service_id, rating, timestamp, verified) = reviews.read(provider_id, i);
        
        // Verified reviews get weight 2, unverified get weight 1
        let weight = if verified == 1 { 2 } else { 1 };
        
        weighted_sum = weighted_sum + (rating * weight);
        weight_sum = weight_sum + weight;
        
        i = i + 1;
    }
    
    // Calculate weighted average with 1 decimal precision
    let weighted_avg = (weighted_sum * 10) / weight_sum;
    
    return (weighted_avg);
} 