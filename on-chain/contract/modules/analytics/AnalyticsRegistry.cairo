// SPDX-License-Identifier: MIT
// Cairo 1.0 Analytics Registry Contract for Service Marketplace

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

// Metric types
// 1: Service views
// 2: Service bookings
// 3: Service completions
// 4: Revenue
// 5: Average rating
// 6: Category popularity
// 7: Location popularity
// 8: Custom metric

// Metric data structure
@storage_var
func metrics(service_id: felt252, metric_type: felt252, timestamp: felt252) -> (value: felt252) {}

// Aggregated metrics by time period (daily, weekly, monthly)
// period_type: 1 = daily, 2 = weekly, 3 = monthly
@storage_var
func aggregated_metrics(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    sum: felt252,
    avg: felt252,
    min: felt252,
    max: felt252
) {}

// Track metric history count for each service and metric type
@storage_var
func metric_history_count(service_id: felt252, metric_type: felt252) -> (count: felt252) {}

// Market trends - store the rate of change for metrics
@storage_var
func metric_trends(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    rate_of_change: felt252,
    acceleration: felt252
) {}

// Category metrics for market analysis
@storage_var
func category_metrics(category_id: felt252, metric_type: felt252, timestamp: felt252) -> (value: felt252) {}

// Access control for sensitive metrics
@storage_var
func metric_access_control(metric_type: felt252) -> (restricted: felt252) {}

// Events
@event
func MetricRecorded(service_id: felt252, metric_type: felt252, value: felt252, timestamp: felt252) {}

@event
func AggregationCompleted(metric_type: felt252, period_type: felt252, period_id: felt252, timestamp: felt252) {}

@event
func TrendCalculated(metric_type: felt252, period_type: felt252, rate_of_change: felt252, timestamp: felt252) {}

// Constructor
@constructor
func constructor(admin_address: ContractAddress) {
    admin::write(admin_address);
    return ();
}

// Modifiers
func only_admin() {
    let caller = get_caller_address();
    let admin_address = admin::read();
    assert(caller == admin_address, 'Only admin can call this');
    return ();
}

// Record a new metric
@external
func record_metric(service_id: felt252, metric_type: felt252, value: felt252) {
    let timestamp = get_block_timestamp();
    
    // Store the metric
    metrics::write(service_id, metric_type, timestamp, value);
    
    // Update metric history count
    let count = metric_history_count::read(service_id, metric_type);
    metric_history_count::write(service_id, metric_type, count + 1);
    
    // Emit event
    MetricRecorded(service_id, metric_type, value, timestamp);
    
    return ();
}

// Record a category metric
@external
func record_category_metric(category_id: felt252, metric_type: felt252, value: felt252) {
    let timestamp = get_block_timestamp();
    
    // Store the category metric
    category_metrics::write(category_id, metric_type, timestamp, value);
    
    // Emit event
    MetricRecorded(category_id, metric_type, value, timestamp);
    
    return ();
}

// Aggregate metrics for a specific period
@external
func aggregate_metrics(metric_type: felt252, period_type: felt252, period_id: felt252) {
    let timestamp = get_block_timestamp();
    
    // In a real implementation, this would iterate through all metrics of the given type
    // within the specified period and calculate aggregations
    // For simplicity, we'll use placeholder values
    
    // Placeholder implementation
    aggregated_metrics::write(
        metric_type,
        period_type,
        period_id,
        0, // count
        0, // sum
        0, // avg
        0, // min
        0  // max
    );
    
    // Emit event
    AggregationCompleted(metric_type, period_type, period_id, timestamp);
    
    return ();
}

// Calculate trends based on aggregated metrics
@external
func calculate_trends(metric_type: felt252, period_type: felt252, period_id: felt252, previous_period_id: felt252) {
    let timestamp = get_block_timestamp();
    
    // Get current and previous period metrics
    let (current_count, current_sum, current_avg, _, _) = aggregated_metrics::read(metric_type, period_type, period_id);
    let (previous_count, previous_sum, previous_avg, _, _) = aggregated_metrics::read(metric_type, period_type, previous_period_id);
    
    // Calculate rate of change (percentage)
    // In a real implementation, handle division by zero and use proper fixed-point math
    let rate_of_change = 0;
    if previous_avg != 0 {
        rate_of_change = ((current_avg - previous_avg) * 100) / previous_avg;
    }
    
    // Store trend data
    metric_trends::write(
        metric_type,
        period_type,
        period_id,
        rate_of_change,
        0 // acceleration (would require more historical data)
    );
    
    // Emit event
    TrendCalculated(metric_type, period_type, rate_of_change, timestamp);
    
    return ();
}

// Set access control for sensitive metrics
@external
func set_metric_access_control(metric_type: felt252, restricted: felt252) {
    only_admin();
    
    metric_access_control::write(metric_type, restricted);
    
    return ();
}

// Get a specific metric
@view
func get_metric(service_id: felt252, metric_type: felt252, timestamp: felt252) -> (value: felt252) {
    // Check access control for sensitive metrics
    let restricted = metric_access_control::read(metric_type);
    if restricted == 1 {
        let caller = get_caller_address();
        let admin_address = admin::read();
        assert(caller == admin_address, 'Access denied to sensitive metric');
    }
    
    let value = metrics::read(service_id, metric_type, timestamp);
    return (value);
}

// Get aggregated metrics
@view
func get_aggregated_metrics(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    sum: felt252,
    avg: felt252,
    min: felt252,
    max: felt252
) {
    let (count, sum, avg, min, max) = aggregated_metrics::read(metric_type, period_type, period_id);
    return (count, sum, avg, min, max);
}

// Get trend data
@view
func get_trend(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    rate_of_change: felt252,
    acceleration: felt252
) {
    let (rate_of_change, acceleration) = metric_trends::read(metric_type, period_type, period_id);
    return (rate_of_change, acceleration);
}

// Get category metrics
@view
func get_category_metric(category_id: felt252, metric_type: felt252, timestamp: felt252) -> (value: felt252) {
    let value = category_metrics::read(category_id, metric_type, timestamp);
    return (value);
}

// Get metric history count
@view
func get_metric_history_count(service_id: felt252, metric_type: felt252) -> (count: felt252) {
    let count = metric_history_count::read(service_id, metric_type);
    return (count);
}

// Helper function to calculate period ID from timestamp
// period_type: 1 = daily, 2 = weekly, 3 = monthly
@view
func calculate_period_id(timestamp: felt252, period_type: felt252) -> (period_id: felt252) {
    // Daily: timestamp / (24 * 60 * 60)
    // Weekly: timestamp / (7 * 24 * 60 * 60)
    // Monthly: approximate using timestamp / (30 * 24 * 60 * 60)
    
    let seconds_per_day = 86400;
    let period_id = 0;
    
    if period_type == 1 {
        // Daily
        period_id = timestamp / seconds_per_day;
    } else if period_type == 2 {
        // Weekly
        period_id = timestamp / (7 * seconds_per_day);
    } else if period_type == 3 {
        // Monthly (approximate)
        period_id = timestamp / (30 * seconds_per_day);
    }
    
    return (period_id);
}