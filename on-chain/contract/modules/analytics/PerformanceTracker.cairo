// SPDX-License-Identifier: MIT
// Cairo 1.0 Performance Tracker Contract for Service Marketplace
// Collects and analyzes platform performance metrics, provider statistics, and market trends

%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::math::uint256 import Uint256, add_uint256, sub_uint256, mul_uint256, div_uint256
from starkware::starknet::array::ArrayTrait
from starkware::starknet::context import get_tx_info

// ============================================================================
// CONSTANTS
// ============================================================================

// Metric types for different performance indicators
const METRIC_TYPE_BOOKING_COUNT = 1
const METRIC_TYPE_PAYMENT_VOLUME = 2
const METRIC_TYPE_USER_ACTIVITY = 3
const METRIC_TYPE_SERVICE_VIEWS = 4
const METRIC_TYPE_COMPLETION_RATE = 5
const METRIC_TYPE_AVERAGE_RATING = 6
const METRIC_TYPE_RESPONSE_TIME = 7
const METRIC_TYPE_REVENUE_PER_PROVIDER = 8
const METRIC_TYPE_CATEGORY_POPULARITY = 9
const METRIC_TYPE_LOCATION_ACTIVITY = 10
const METRIC_TYPE_DISPUTE_RATE = 11
const METRIC_TYPE_PLATFORM_FEES = 12

// Time periods for aggregation
const PERIOD_TYPE_HOURLY = 1
const PERIOD_TYPE_DAILY = 2
const PERIOD_TYPE_WEEKLY = 3
const PERIOD_TYPE_MONTHLY = 4

// Privacy levels for data aggregation
const PRIVACY_LEVEL_PUBLIC = 1
const PRIVACY_LEVEL_AGGREGATED = 2
const PRIVACY_LEVEL_RESTRICTED = 3

// ============================================================================
// STORAGE VARIABLES
// ============================================================================

// Contract administration
@storage_var
func admin() -> (address: ContractAddress) {}

@storage_var
func authorized_contracts(contract_address: ContractAddress) -> (authorized: felt252) {}

// Transaction tracking
@storage_var
func transaction_count() -> (count: felt252) {}

@storage_var
func transactions(transaction_id: felt252) -> (
    transaction_type: felt252,
    user_address: ContractAddress,
    amount: Uint256,
    timestamp: felt252,
    metadata: felt252
) {}

// Platform metrics aggregation
@storage_var
func platform_metrics(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    total_value: Uint256,
    average_value: felt252,
    min_value: felt252,
    max_value: felt252,
    last_updated: felt252
) {}

// Provider-specific analytics
@storage_var
func provider_metrics(provider_address: ContractAddress, metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    total_value: Uint256,
    average_value: felt252,
    last_updated: felt252
) {}

// Market trends and analysis
@storage_var
func market_trends(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    rate_of_change: felt252,
    acceleration: felt252,
    volatility: felt252,
    trend_direction: felt252 // 1 = increasing, 0 = stable, -1 = decreasing
) {}

// Category and location analytics
@storage_var
func category_analytics(category_id: felt252, metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    total_value: Uint256,
    average_value: felt252
) {}

@storage_var
func location_analytics(location_hash: felt252, metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    count: felt252,
    total_value: Uint256,
    average_value: felt252
) {}

// Custom metric definitions
@storage_var
func custom_metrics(metric_id: felt252) -> (
    name: felt252,
    description: felt252,
    data_type: felt252,
    privacy_level: felt252,
    aggregation_method: felt252
) {}

@storage_var
func custom_metric_count() -> (count: felt252) {}

// Privacy-preserving analytics
@storage_var
func privacy_settings(metric_type: felt252) -> (
    min_aggregation_size: felt252,
    data_retention_period: felt252,
    anonymization_level: felt252
) {}

// Performance optimization - caching
@storage_var
func cached_reports(report_hash: felt252) -> (
    report_data: felt252,
    timestamp: felt252,
    expiry: felt252
) {}

// ============================================================================
// EVENTS
// ============================================================================

@event
func TransactionRecorded(transaction_id: felt252, transaction_type: felt252, user_address: ContractAddress, amount: Uint256, timestamp: felt252) {}

@event
func MetricUpdated(metric_type: felt252, period_type: felt252, period_id: felt252, value: Uint256, timestamp: felt252) {}

@event
func TrendCalculated(metric_type: felt252, period_type: felt252, rate_of_change: felt252, timestamp: felt252) {}

@event
func ReportGenerated(report_type: felt252, period_type: felt252, period_id: felt252, timestamp: felt252) {}

@event
func CustomMetricCreated(metric_id: felt252, name: felt252, privacy_level: felt252, timestamp: felt252) {}

// ============================================================================
// CONSTRUCTOR
// ============================================================================

@constructor
func constructor(admin_address: ContractAddress) {
    admin::write(admin_address);
    transaction_count::write(0);
    custom_metric_count::write(0);
    return ();
}

// ============================================================================
// ACCESS CONTROL
// ============================================================================

func only_admin() {
    let caller = get_caller_address();
    let admin_address = admin::read();
    assert(caller == admin_address, 'Only admin can call this');
    return ();
}

func only_authorized() {
    let caller = get_caller_address();
    let admin_address = admin::read();
    let is_authorized = authorized_contracts::read(caller);
    assert(caller == admin_address or is_authorized == 1, 'Only authorized contracts can call this');
    return ();
}

// ============================================================================
// CORE FUNCTIONS
// ============================================================================

@external
func record_transaction{
    syscalls: SyscallPtr
}(
    transaction_type: felt252,
    user_address: ContractAddress,
    amount: Uint256,
    metadata: felt252
) -> (transaction_id: felt252):
    alloc_locals
    only_authorized();
    
    let (current_count) = transaction_count::read();
    let transaction_id = current_count + 1;
    let (timestamp) = get_block_timestamp();
    
    // Store transaction
    transaction_count::write(transaction_id);
    transactions::write(transaction_id, (transaction_type, user_address, amount, timestamp, metadata));
    
    // Update platform metrics
    update_platform_metrics(transaction_type, amount, timestamp);
    
    // Emit event
    TransactionRecorded(transaction_id, transaction_type, user_address, amount, timestamp);
    
    return (transaction_id,);
end

@external
func get_platform_metrics{
    syscalls: SyscallPtr
}(
    metric_type: felt252,
    period_type: felt252,
    period_id: felt252
) -> (count: felt252, total_value: Uint256, average_value: felt252, min_value: felt252, max_value: felt252, last_updated: felt252):
    alloc_locals
    let (count, total_value, average_value, min_value, max_value, last_updated) = platform_metrics::read(metric_type, period_type, period_id);
    return (count, total_value, average_value, min_value, max_value, last_updated);
end

@external
func get_provider_analytics{
    syscalls: SyscallPtr
}(
    provider_address: ContractAddress,
    metric_type: felt252,
    period_type: felt252,
    period_id: felt252
) -> (count: felt252, total_value: Uint256, average_value: felt252, last_updated: felt252):
    alloc_locals
    let (count, total_value, average_value, last_updated) = provider_metrics::read(provider_address, metric_type, period_type, period_id);
    return (count, total_value, average_value, last_updated);
end

@external
func calculate_trends{
    syscalls: SyscallPtr
}(
    metric_type: felt252,
    period_type: felt252,
    current_period_id: felt252,
    previous_period_id: felt252
) -> (rate_of_change: felt252, acceleration: felt252, trend_direction: felt252):
    alloc_locals
    only_admin();
    
    // Get current period metrics
    let (current_count, current_total, current_avg, _, _, _) = platform_metrics::read(metric_type, period_type, current_period_id);
    
    // Get previous period metrics
    let (previous_count, previous_total, previous_avg, _, _, _) = platform_metrics::read(metric_type, period_type, previous_period_id);
    
    // Calculate rate of change
    let rate_of_change = 0;
    if previous_avg != 0:
        let rate_of_change = ((current_avg - previous_avg) * 100) / previous_avg;
    end
    
    // Calculate acceleration (simplified)
    let acceleration = current_avg - previous_avg;
    
    // Determine trend direction
    let trend_direction = 0; // stable
    if current_avg > previous_avg:
        let trend_direction = 1; // increasing
    elif current_avg < previous_avg:
        let trend_direction = -1; // decreasing
    end
    
    // Store trend data
    let (timestamp) = get_block_timestamp();
    market_trends::write(metric_type, period_type, current_period_id, (rate_of_change, acceleration, 0, trend_direction));
    
    // Emit event
    TrendCalculated(metric_type, period_type, rate_of_change, timestamp);
    
    return (rate_of_change, acceleration, trend_direction);
end

@external
func generate_reports{
    syscalls: SyscallPtr
}(
    report_type: felt252,
    period_type: felt252,
    period_id: felt252,
    include_providers: felt252,
    include_categories: felt252
) -> (report_hash: felt252):
    alloc_locals
    only_admin();
    
    let (timestamp) = get_block_timestamp();
    
    // Generate comprehensive report
    let report_data = generate_comprehensive_report(report_type, period_type, period_id, include_providers, include_categories);
    
    // Create report hash (simplified)
    let report_hash = report_type + period_type + period_id + timestamp;
    
    // Cache report for 24 hours
    let expiry = timestamp + 86400; // 24 hours
    cached_reports::write(report_hash, (report_data, timestamp, expiry));
    
    // Emit event
    ReportGenerated(report_type, period_type, period_id, timestamp);
    
    return (report_hash,);
end

// ============================================================================
// PRIVACY-PRESERVING ANALYTICS
// ============================================================================

@external
func set_privacy_settings(
    metric_type: felt252,
    min_aggregation_size: felt252,
    data_retention_period: felt252,
    anonymization_level: felt252
) {
    only_admin();
    privacy_settings::write(metric_type, (min_aggregation_size, data_retention_period, anonymization_level));
    return ();
}

@external
func get_aggregated_metrics{
    syscalls: SyscallPtr
}(
    metric_type: felt252,
    period_type: felt252,
    period_id: felt252
) -> (aggregated_value: Uint256, participant_count: felt252):
    alloc_locals
    let (min_aggregation_size, _, _) = privacy_settings::read(metric_type);
    let (count, total_value, _, _, _, _) = platform_metrics::read(metric_type, period_type, period_id);
    
    // Only return aggregated data if minimum aggregation size is met
    if count >= min_aggregation_size:
        return (total_value, count);
    else:
        return (Uint256(0, 0), 0);
    end
end

// ============================================================================
// CUSTOM METRIC SUPPORT
// ============================================================================

@external
func create_custom_metric(
    name: felt252,
    description: felt252,
    data_type: felt252,
    privacy_level: felt252,
    aggregation_method: felt252
) -> (metric_id: felt252):
    only_admin();
    
    let (current_count) = custom_metric_count::read();
    let metric_id = current_count + 1;
    
    custom_metrics::write(metric_id, (name, description, data_type, privacy_level, aggregation_method));
    custom_metric_count::write(metric_id);
    
    let (timestamp) = get_block_timestamp();
    CustomMetricCreated(metric_id, name, privacy_level, timestamp);
    
    return (metric_id,);
end

@external
func record_custom_metric(
    metric_id: felt252,
    value: Uint256,
    metadata: felt252
) {
    only_authorized();
    
    let (name, description, data_type, privacy_level, aggregation_method) = custom_metrics::read(metric_id);
    let (timestamp) = get_block_timestamp();
    
    // Store custom metric data (simplified storage)
    // In a real implementation, this would use a more sophisticated storage mechanism
    
    return ();
}

// ============================================================================
// INTERNAL FUNCTIONS
// ============================================================================

func update_platform_metrics(
    transaction_type: felt252,
    amount: Uint256,
    timestamp: felt252
) {
    // Determine metric type based on transaction type
    let metric_type = transaction_type;
    let period_type = PERIOD_TYPE_DAILY;
    let period_id = timestamp / 86400; // Daily period
    
    // Get current metrics
    let (current_count, current_total, current_avg, current_min, current_max, last_updated) = platform_metrics::read(metric_type, period_type, period_id);
    
    // Update metrics
    let new_count = current_count + 1;
    let new_total = add_uint256(current_total, amount);
    let new_avg = div_uint256(new_total, Uint256(new_count, 0)).low;
    
    let new_min = current_min;
    if amount.low < current_min or current_min == 0:
        let new_min = amount.low;
    end
    
    let new_max = current_max;
    if amount.low > current_max:
        let new_max = amount.low;
    end
    
    // Store updated metrics
    platform_metrics::write(metric_type, period_type, period_id, (new_count, new_total, new_avg, new_min, new_max, timestamp));
    
    return ();
}

func generate_comprehensive_report(
    report_type: felt252,
    period_type: felt252,
    period_id: felt252,
    include_providers: felt252,
    include_categories: felt252
) -> (report_data: felt252):
    // This is a simplified implementation
    // In a real contract, this would aggregate data from multiple sources
    let report_data = report_type + period_type + period_id;
    return (report_data,);
end

// ============================================================================
// ADMINISTRATIVE FUNCTIONS
// ============================================================================

@external
func authorize_contract(contract_address: ContractAddress) {
    only_admin();
    authorized_contracts::write(contract_address, 1);
    return ();
}

@external
func revoke_authorization(contract_address: ContractAddress) {
    only_admin();
    authorized_contracts::write(contract_address, 0);
    return ();
}

@external
func update_admin(new_admin: ContractAddress) {
    only_admin();
    admin::write(new_admin);
    return ();
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

@external
func get_transaction_details(transaction_id: felt252) -> (
    transaction_type: felt252,
    user_address: ContractAddress,
    amount: Uint256,
    timestamp: felt252,
    metadata: felt252
):
    let (transaction_type, user_address, amount, timestamp, metadata) = transactions::read(transaction_id);
    return (transaction_type, user_address, amount, timestamp, metadata);
end

@external
func get_custom_metric_details(metric_id: felt252) -> (
    name: felt252,
    description: felt252,
    data_type: felt252,
    privacy_level: felt252,
    aggregation_method: felt252
):
    let (name, description, data_type, privacy_level, aggregation_method) = custom_metrics::read(metric_id);
    return (name, description, data_type, privacy_level, aggregation_method);
end

@external
func get_trend_data(metric_type: felt252, period_type: felt252, period_id: felt252) -> (
    rate_of_change: felt252,
    acceleration: felt252,
    volatility: felt252,
    trend_direction: felt252
):
    let (rate_of_change, acceleration, volatility, trend_direction) = market_trends::read(metric_type, period_type, period_id);
    return (rate_of_change, acceleration, volatility, trend_direction);
end 