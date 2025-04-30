# AnalyticsRegistry Contract Documentation

## Overview

The AnalyticsRegistry contract is a Cairo 1.0 implementation for StarkNet that enables efficient tracking of service metrics, performance indicators, and market trends. It provides a decentralized analytics system for storing aggregated metrics on-chain with timestamps, calculating trends, and maintaining historical performance data.

## Key Features

- **Decentralized Analytics System**: Store service metrics on-chain with proper timestamps
- **Metrics Aggregation**: Efficiently aggregate metrics by different time periods (daily, weekly, monthly)
- **Trend Calculation**: Calculate and track rate of change and acceleration for various metrics
- **Historical Data**: Maintain comprehensive history of metrics for services and categories
- **Access Control**: Protect sensitive metrics with proper access controls
- **Category Analysis**: Track and analyze metrics by service category

## Technical Implementation

### Metric Types

The contract supports various metric types:

1. Service views
2. Service bookings
3. Service completions
4. Revenue
5. Average rating
6. Category popularity
7. Location popularity
8. Custom metrics

### Storage Structure

The contract uses several storage variables:

- `metrics`: Maps service IDs, metric types, and timestamps to metric values
- `aggregated_metrics`: Stores aggregated metrics (count, sum, avg, min, max) by period
- `metric_trends`: Tracks rate of change and acceleration for metrics over time
- `category_metrics`: Maps category IDs, metric types, and timestamps to metric values
- `metric_access_control`: Controls access to sensitive metrics

### Time Period Aggregation

Metrics can be aggregated by different time periods:

1. Daily (period_type = 1)
2. Weekly (period_type = 2)
3. Monthly (period_type = 3)

The contract provides a helper function to calculate period IDs from timestamps.

## Contract Interface

### External Functions

#### `record_metric(service_id: felt252, metric_type: felt252, value: felt252)`

Records a new metric for a service.

Parameters:

- `service_id`: The ID of the service
- `metric_type`: The type of metric (1-8)
- `value`: The metric value

#### `record_category_metric(category_id: felt252, metric_type: felt252, value: felt252)`

Records a new metric for a service category.

Parameters:

- `category_id`: The ID of the category
- `metric_type`: The type of metric
- `value`: The metric value

#### `aggregate_metrics(metric_type: felt252, period_type: felt252, period_id: felt252)`

Aggregates metrics for a specific period.

Parameters:

- `metric_type`: The type of metric to aggregate
- `period_type`: The type of period (1=daily, 2=weekly, 3=monthly)
- `period_id`: The ID of the period

#### `calculate_trends(metric_type: felt252, period_type: felt252, period_id: felt252, previous_period_id: felt252)`

Calculates trends based on aggregated metrics.

Parameters:

- `metric_type`: The type of metric
- `period_type`: The type of period
- `period_id`: The current period ID
- `previous_period_id`: The previous period ID for comparison

#### `set_metric_access_control(metric_type: felt252, restricted: felt252)`

Sets access control for sensitive metrics.

Parameters:

- `metric_type`: The type of metric
- `restricted`: 1 for restricted, 0 for unrestricted

### View Functions

#### `get_metric(service_id: felt252, metric_type: felt252, timestamp: felt252) -> (value: felt252)`

Retrieves a specific metric value.

#### `get_aggregated_metrics(metric_type: felt252, period_type: felt252, period_id: felt252) -> (count, sum, avg, min, max)`

Retrieves aggregated metrics for a specific period.

#### `get_trend(metric_type: felt252, period_type: felt252, period_id: felt252) -> (rate_of_change, acceleration)`

Retrieves trend data for a specific period.

#### `get_category_metric(category_id: felt252, metric_type: felt252, timestamp: felt252) -> (value: felt252)`

Retrieves a specific category metric value.

#### `get_metric_history_count(service_id: felt252, metric_type: felt252) -> (count: felt252)`

Retrieves the count of historical metrics for a service and metric type.

#### `calculate_period_id(timestamp: felt252, period_type: felt252) -> (period_id: felt252)`

Calculates a period ID from a timestamp and period type.

## Events

- `MetricRecorded(service_id, metric_type, value, timestamp)`: Emitted when a new metric is recorded
- `AggregationCompleted(metric_type, period_type, period_id, timestamp)`: Emitted when metrics aggregation is completed
- `TrendCalculated(metric_type, period_type, rate_of_change, timestamp)`: Emitted when trend calculation is completed

## Integration with Frontend

To integrate this contract with your frontend, you'll need to:

1. Deploy the contract to StarkNet
2. Use starknet.js to interact with the contract
3. Create analytics dashboards that visualize the metrics and trends

Example frontend integration (React + starknet.js):

```jsx
import React, { useState, useEffect } from 'react';
import { Provider, Contract } from 'starknet';
import { Line } from 'react-chartjs-2';

const provider = new Provider({ network: 'goerli-alpha' });
const contractAddress = '0xYOUR_DEPLOYED_CONTRACT_ADDRESS';
const contractAbi = [...]; // Your contract ABI

function AnalyticsDashboard() {
  const [serviceMetrics, setServiceMetrics] = useState([]);
  const [trends, setTrends] = useState([]);
  const [selectedMetricType, setSelectedMetricType] = useState(1);
  const [selectedPeriodType, setSelectedPeriodType] = useState(1);

  useEffect(() => {
    fetchMetrics();
    fetchTrends();
  }, [selectedMetricType, selectedPeriodType]);

  async function fetchMetrics() {
    try {
      const contract = new Contract(contractAbi, contractAddress, provider);

      // Get current period ID
      const now = Math.floor(Date.now() / 1000);
      const result = await contract.calculate_period_id(now, selectedPeriodType);
      const currentPeriodId = result.period_id;

      // Fetch metrics for the last 7 periods
      const metricsData = [];
      for (let i = 0; i < 7; i++) {
        const periodId = currentPeriodId - i;
        const aggregatedMetrics = await contract.get_aggregated_metrics(
          selectedMetricType,
          selectedPeriodType,
          periodId
        );

        metricsData.push({
          periodId,
          count: aggregatedMetrics.count,
          sum: aggregatedMetrics.sum,
          avg: aggregatedMetrics.avg,
          min: aggregatedMetrics.min,
          max: aggregatedMetrics.max
        });
      }

      setServiceMetrics(metricsData.reverse());
    } catch (error) {
      console.error('Error fetching metrics:', error);
    }
  }

  async function fetchTrends() {
    try {
      const contract = new Contract(contractAbi, contractAddress, provider);

      // Get current period ID
      const now = Math.floor(Date.now() / 1000);
      const result = await contract.calculate_period_id(now, selectedPeriodType);
      const currentPeriodId = result.period_id;

      // Fetch trends for the last 7 periods
      const trendsData = [];
      for (let i = 0; i < 7; i++) {
        const periodId = currentPeriodId - i;
        const trend = await contract.get_trend(
          selectedMetricType,
          selectedPeriodType,
          periodId
        );

        trendsData.push({
          periodId,
          rateOfChange: trend.rate_of_change,
          acceleration: trend.acceleration
        });
      }

      setTrends(trendsData.reverse());
    } catch (error) {
      console.error('Error fetching trends:', error);
    }
  }

  // Convert period IDs to readable dates
  function periodIdToDate(periodId, periodType) {
    const secondsPerDay = 86400;
    let timestamp;

    if (periodType === 1) {
      // Daily
      timestamp = periodId * secondsPerDay;
    } else if (periodType === 2) {
      // Weekly
      timestamp = periodId * 7 * secondsPerDay;
    } else {
      // Monthly
      timestamp = periodId * 30 * secondsPerDay;
    }

    return new Date(timestamp * 1000).toLocaleDateString();
  }

  // Chart data for metrics
  const metricsChartData = {
    labels: serviceMetrics.map(m => periodIdToDate(m.periodId, selectedPeriodType)),
    datasets: [
      {
        label: 'Average',
        data: serviceMetrics.map(m => m.avg),
        borderColor: 'rgb(75, 192, 192)',
        tension: 0.1
      },
      {
        label: 'Maximum',
        data: serviceMetrics.map(m => m.max),
        borderColor: 'rgb(255, 99, 132)',
        tension: 0.1
      }
    ]
  };

  // Chart data for trends
  const trendsChartData = {
    labels: trends.map(t => periodIdToDate(t.periodId, selectedPeriodType)),
    datasets: [
      {
        label: 'Rate of Change (%)',
        data: trends.map(t => t.rateOfChange),
        borderColor: 'rgb(54, 162, 235)',
        tension: 0.1
      }
    ]
  };

  return (
    <div>
      <h2>Service Analytics Dashboard</h2>

      <div className="controls">
        <div>
          <label>Metric Type:</label>
          <select
            value={selectedMetricType}
            onChange={e => setSelectedMetricType(Number(e.target.value))}
          >
            <option value={1}>Service Views</option>
            <option value={2}>Service Bookings</option>
            <option value={3}>Service Completions</option>
            <option value={4}>Revenue</option>
            <option value={5}>Average Rating</option>
          </select>
        </div>

        <div>
          <label>Period:</label>
          <select
            value={selectedPeriodType}
            onChange={e => setSelectedPeriodType(Number(e.target.value))}
          >
            <option value={1}>Daily</option>
            <option value={2}>Weekly</option>
            <option value={3}>Monthly</option>
          </select>
        </div>
      </div>

      <div className="charts">
        <div className="chart">
          <h3>Metrics Over Time</h3>
          <Line data={metricsChartData} />
        </div>

        <div className="chart">
          <h3>Trend Analysis</h3>
          <Line data={trendsChartData} />
        </div>
      </div>
    </div>
  );
}
```
