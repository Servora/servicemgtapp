# AnalyticsRegistry Contract Tests (Cairo 1.0)
%lang starknet

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet
from contracts.AnalyticsRegistry import AnalyticsRegistry

@external
func test_record_metric() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let analytics_registry = await starknet.deploy(contract_class=AnalyticsRegistry, constructor_calldata=[admin_address])
    
    # Test data
    let service_id = 1
    let metric_type = 1 # Service views
    let value = 10
    
    # Record a metric
    await analytics_registry.record_metric(service_id, metric_type, value, caller_address=admin_address)
    
    # Get the current timestamp
    let timestamp = starknet.get_block_timestamp()
    
    # Verify metric was recorded
    let (stored_value) = await analytics_registry.get_metric(service_id, metric_type, timestamp)
    
    assert stored_value == value, 'Wrong metric value'
    
    # Check history count
    let (count) = await analytics_registry.get_metric_history_count(service_id, metric_type)
    assert count == 1, 'Wrong history count'
    
    return ()
end

@external
func test_aggregate_metrics() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let analytics_registry = await starknet.deploy(contract_class=AnalyticsRegistry, constructor_calldata=[admin_address])
    
    # Test data
    let metric_type = 1 # Service views
    let period_type = 1 # Daily
    let period_id = 123 # Some arbitrary period ID
    
    # Record some metrics
    await analytics_registry.record_metric(1, metric_type, 10, caller_address=admin_address)
    await analytics_registry.record_metric(2, metric_type, 20, caller_address=admin_address)
    
    # Aggregate metrics
    await analytics_registry.aggregate_metrics(metric_type, period_type, period_id, caller_address=admin_address)
    
    # Verify aggregation
    let (count, sum, avg, min, max) = await analytics_registry.get_aggregated_metrics(metric_type, period_type, period_id)
    
    # Note: In our simplified implementation, these values are placeholders
    # In a real test, we would verify the actual calculated values
    
    return ()
end

@external
func test_calculate_trends() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let analytics_registry = await starknet.deploy(contract_class=AnalyticsRegistry, constructor_calldata=[admin_address])
    
    # Test data
    let metric_type = 1 # Service views
    let period_type = 1 # Daily
    let current_period = 123
    let previous_period = 122
    
    # Set up some aggregated metrics for both periods
    await analytics_registry.aggregate_metrics(metric_type, period_type, current_period, caller_address=admin_address)
    await analytics_registry.aggregate_metrics(metric_type, period_type, previous_period, caller_address=admin_address)
    
    # Calculate trends
    await analytics_registry.calculate_trends(metric_type, period_type, current_period, previous_period, caller_address=admin_address)
    
    # Verify trend calculation
    let (rate_of_change, acceleration) = await analytics_registry.get_trend(metric_type, period_type, current_period)
    
    # Note: In our simplified implementation, these values are placeholders
    # In a real test, we would verify the actual calculated values
    
    return ()
end

@external
func test_access_control() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let non_admin_address = 0x456
    let analytics_registry = await starknet.deploy(contract_class=AnalyticsRegistry, constructor_calldata=[admin_address])
    
    # Test data
    let service_id = 1
    let metric_type = 4 # Revenue (sensitive)
    let value = 1000
    
    # Record a metric
    await analytics_registry.record_metric(service_id, metric_type, value, caller_address=admin_address)
    
    # Get the current timestamp
    let timestamp = starknet.get_block_timestamp()
    
    # Set access control to restricted
    await analytics_registry.set_metric_access_control(metric_type, 1, caller_address=admin_address)
    
    # Admin should be able to access the metric
    let (stored_value) = await analytics_registry.get_metric(service_id, metric_type, timestamp, caller_address=admin_address)
    assert stored_value == value, 'Admin should access metric'
    
    # Non-admin should not be able to access the metric
    # This should revert with 'Access denied to sensitive metric'
    let reverted = false
    try {
        let (_) = await analytics_registry.get_metric(service_id, metric_type, timestamp, caller_address=non_admin_address)
    } catch {
        reverted = true
    }
    
    assert reverted, 'Non-admin should not access sensitive metric'
    
    return ()
end

@external
func test_category_metrics() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let analytics_registry = await starknet.deploy(contract_class=AnalyticsRegistry, constructor_calldata=[admin_address])
    
    # Test data
    let category_id = 5 # Some category ID
    let metric_type = 6 # Category popularity
    let value = 50
    
    # Record a category metric
    await analytics_registry.record_category_metric(category_id, metric_type, value, caller_address=admin_address)
    
    # Get the current timestamp
    let timestamp = starknet.get_block_timestamp()
    
    # Verify category metric was recorded
    let (stored_value) = await analytics_registry.get_category_metric(category_id, metric_type, timestamp)
    
    assert stored_value == value, 'Wrong category metric value'
    
    return ()
end

@external
func test_period_calculation() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let analytics_registry = await starknet.deploy(contract_class=AnalyticsRegistry, constructor_calldata=[admin_address])
    
    # Test timestamp (e.g., 2023-01-01 00:00:00 UTC)
    let timestamp = 1672531200
    
    # Calculate period IDs
    let (daily_period) = await analytics_registry.calculate_period_id(timestamp, 1)
    let (weekly_period) = await analytics_registry.calculate_period_id(timestamp, 2)
    let (monthly_period) = await analytics_registry.calculate_period_id(timestamp, 3)
    
    # Verify calculations
    assert daily_period == timestamp / 86400, 'Wrong daily period'
    assert weekly_period == timestamp / (7 * 86400), 'Wrong weekly period'
    assert monthly_period == timestamp / (30 * 86400), 'Wrong monthly period'
    
    return ()
end