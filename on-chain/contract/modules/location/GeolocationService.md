# GeolocationService Contract Documentation

## Overview

The GeolocationService contract is a Cairo 1.0 implementation for StarkNet that provides location-based service discovery and provider mapping. It enables efficient radius-based searches, geographic service availability tracking, and privacy-preserving location storage mechanisms.

## Key Features

### 🔍 **Location-Based Service Discovery**
- Efficient radius-based provider searches
- Grid-based spatial indexing for fast queries
- Support for both point locations and service areas
- Geographic service availability tracking

### 🛡️ **Privacy-Preserving Mechanisms**
- Three privacy levels: Public, Approximate, Private
- Coordinate masking for privacy protection
- Location hashing for private providers
- Configurable privacy controls

### 📍 **Spatial Indexing & Performance**
- Grid-based spatial indexing (1km x 1km cells)
- Efficient radius searches with O(log n) complexity
- Optimized coordinate calculations
- Fast provider discovery within specified areas

### 🎯 **Service Area Management**
- Point-based service areas
- Circular service areas with configurable radius
- Polygon service areas (for complex boundaries)
- Dynamic service area updates

## Technical Implementation

### Coordinate System
- **Precision**: 6 decimal places (1 meter precision)
- **Storage**: Integer multiplication for efficiency
- **Validation**: Latitude (-90° to 90°), Longitude (-180° to 180°)

### Privacy Levels
1. **Public (0)**: Exact coordinates stored and visible
2. **Approximate (1)**: Coordinates rounded to nearest 100m
3. **Private (2)**: Coordinates rounded to nearest 1km + hashing

### Spatial Indexing
- **Grid Size**: 1km x 1km cells
- **Indexing**: Providers mapped to grid cells
- **Search**: Efficient radius-based queries
- **Updates**: Automatic grid updates on location changes

## Contract Interface

### Core Functions

#### `register_location(provider_id, latitude, longitude, privacy_level, service_area_type, service_radius)`
Registers a provider's location with privacy controls.

**Parameters:**
- `provider_id`: Unique provider identifier
- `latitude`: Latitude coordinate (integer * precision)
- `longitude`: Longitude coordinate (integer * precision)
- `privacy_level`: 0=public, 1=approximate, 2=private
- `service_area_type`: 0=point, 1=circle, 2=polygon
- `service_radius`: Service area radius in meters

**Returns:** `location_id` (unique location identifier)

#### `find_nearby_providers(center_latitude, center_longitude, radius, max_results)`
Finds providers within specified radius.

**Parameters:**
- `center_latitude`: Search center latitude
- `center_longitude`: Search center longitude
- `radius`: Search radius in meters (max 50km)
- `max_results`: Maximum number of results

**Returns:** `(provider_ids, distances)` - Arrays of provider IDs and distances

#### `update_location(provider_id, new_latitude, new_longitude, new_privacy_level)`
Updates a provider's location and privacy settings.

**Parameters:**
- `provider_id`: Provider identifier
- `new_latitude`: New latitude coordinate
- `new_longitude`: New longitude coordinate
- `new_privacy_level`: New privacy level

#### `update_service_area(provider_id, area_type, radius)`
Updates a provider's service area configuration.

**Parameters:**
- `provider_id`: Provider identifier
- `area_type`: New service area type
- `radius`: New service area radius

#### `calculate_distance(lat1, lng1, lat2, lng2)`
Calculates distance between two coordinates using Haversine formula.

**Parameters:**
- `lat1, lng1`: First coordinate pair
- `lat2, lng2`: Second coordinate pair

**Returns:** `distance` in meters

#### `get_providers_in_radius(center_lat, center_lng, radius)`
Gets count and total distance of providers within radius.

**Parameters:**
- `center_lat, center_lng`: Search center
- `radius`: Search radius

**Returns:** `(provider_count, total_distance)`

### Privacy Management

#### `update_privacy_level(provider_id, new_privacy_level)`
Updates privacy level for a provider.

**Parameters:**
- `provider_id`: Provider identifier
- `new_privacy_level`: New privacy level (0-2)

### View Functions

#### `get_provider_location(provider_id)`
Retrieves provider location with privacy respect.

**Returns:** `(latitude, longitude, privacy_level, status, area_type, radius)`

#### `get_search_stats()`
Gets search statistics for analytics.

**Returns:** `(total_searches, last_search_time)`

#### `get_total_locations()`
Gets total number of registered locations.

**Returns:** `count`

### Admin Functions

#### `emergency_remove_location(provider_id)`
Emergency function to remove a provider's location (admin only).

## Events

- `LocationRegistered(provider_id, latitude, longitude, privacy_level, timestamp)`
- `LocationUpdated(provider_id, old_lat, old_lng, new_lat, new_lng, timestamp)`
- `ServiceAreaUpdated(provider_id, area_type, radius, timestamp)`
- `PrivacyLevelChanged(provider_id, old_level, new_level, timestamp)`
- `NearbySearch(searcher, center_lat, center_lng, radius, result_count, timestamp)`

## Integration Examples

### Frontend Integration (React + starknet.js)

```jsx
import React, { useState, useEffect } from 'react';
import { Provider, Contract } from 'starknet';

const GeolocationService = () => {
  const [nearbyProviders, setNearbyProviders] = useState([]);
  const [userLocation, setUserLocation] = useState(null);
  const [searchRadius, setSearchRadius] = useState(5000); // 5km

  // Get user location
  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setUserLocation({
            lat: position.coords.latitude * 1000000, // Convert to contract format
            lng: position.coords.longitude * 1000000
          });
        },
        (error) => console.error('Error getting location:', error)
      );
    }
  }, []);

  // Search for nearby providers
  const searchNearbyProviders = async () => {
    if (!userLocation) return;

    try {
      const contract = new Contract(contractAbi, contractAddress, provider);
      
      const result = await contract.find_nearby_providers(
        userLocation.lat,
        userLocation.lng,
        searchRadius,
        20 // max results
      );

      const providers = [];
      for (let i = 0; i < result.provider_ids.length; i++) {
        providers.push({
          id: result.provider_ids[i],
          distance: result.distances[i]
        });
      }

      setNearbyProviders(providers);
    } catch (error) {
      console.error('Error searching providers:', error);
    }
  };

  // Register provider location
  const registerProviderLocation = async (providerId, lat, lng, privacyLevel) => {
    try {
      const contract = new Contract(contractAbi, contractAddress, provider);
      
      await contract.register_location(
        providerId,
        lat * 1000000, // Convert to contract format
        lng * 1000000,
        privacyLevel,
        1, // circle area type
        5000 // 5km service radius
      );

      console.log('Provider location registered successfully');
    } catch (error) {
      console.error('Error registering location:', error);
    }
  };

  return (
    <div>
      <h2>Geolocation Service</h2>
      
      <div className="search-section">
        <h3>Find Nearby Providers</h3>
        <input
          type="range"
          min="1000"
          max="50000"
          value={searchRadius}
          onChange={(e) => setSearchRadius(Number(e.target.value))}
        />
        <span>{searchRadius / 1000}km radius</span>
        <button onClick={searchNearbyProviders}>Search</button>
      </div>

      <div className="results">
        <h3>Nearby Providers ({nearbyProviders.length})</h3>
        {nearbyProviders.map((provider, index) => (
          <div key={index} className="provider-card">
            <p>Provider ID: {provider.id}</p>
            <p>Distance: {(provider.distance / 1000).toFixed(2)}km</p>
          </div>
        ))}
      </div>
    </div>
  );
};
```

### Backend Integration (Node.js)

```javascript
const { Provider, Contract } = require('starknet');

class GeolocationService {
  constructor(contractAddress, contractAbi, provider) {
    this.contract = new Contract(contractAbi, contractAddress, provider);
  }

  // Register a new provider location
  async registerProviderLocation(providerId, latitude, longitude, privacyLevel = 1) {
    try {
      const lat = Math.floor(latitude * 1000000);
      const lng = Math.floor(longitude * 1000000);
      
      const result = await this.contract.register_location(
        providerId,
        lat,
        lng,
        privacyLevel,
        1, // circle area type
        5000 // 5km default radius
      );
      
      return result.location_id;
    } catch (error) {
      throw new Error(`Failed to register location: ${error.message}`);
    }
  }

  // Find nearby providers
  async findNearbyProviders(latitude, longitude, radius = 5000, maxResults = 20) {
    try {
      const lat = Math.floor(latitude * 1000000);
      const lng = Math.floor(longitude * 1000000);
      
      const result = await this.contract.find_nearby_providers(
        lat,
        lng,
        radius,
        maxResults
      );
      
      return {
        providerIds: result.provider_ids,
        distances: result.distances
      };
    } catch (error) {
      throw new Error(`Failed to find nearby providers: ${error.message}`);
    }
  }

  // Update provider location
  async updateProviderLocation(providerId, latitude, longitude, privacyLevel) {
    try {
      const lat = Math.floor(latitude * 1000000);
      const lng = Math.floor(longitude * 1000000);
      
      await this.contract.update_location(
        providerId,
        lat,
        lng,
        privacyLevel
      );
      
      return true;
    } catch (error) {
      throw new Error(`Failed to update location: ${error.message}`);
    }
  }

  // Get provider location
  async getProviderLocation(providerId) {
    try {
      const result = await this.contract.get_provider_location(providerId);
      
      return {
        latitude: result.latitude / 1000000,
        longitude: result.longitude / 1000000,
        privacyLevel: result.privacy_level,
        status: result.status,
        areaType: result.area_type,
        radius: result.radius
      };
    } catch (error) {
      throw new Error(`Failed to get provider location: ${error.message}`);
    }
  }

  // Calculate distance between two points
  async calculateDistance(lat1, lng1, lat2, lng2) {
    try {
      const result = await this.contract.calculate_distance(
        Math.floor(lat1 * 1000000),
        Math.floor(lng1 * 1000000),
        Math.floor(lat2 * 1000000),
        Math.floor(lng2 * 1000000)
      );
      
      return result.distance;
    } catch (error) {
      throw new Error(`Failed to calculate distance: ${error.message}`);
    }
  }
}

module.exports = GeolocationService;
```

## Performance Optimizations

### Spatial Indexing
- **Grid-based indexing** for O(log n) search complexity
- **1km x 1km grid cells** for optimal balance of precision and performance
- **Efficient radius searches** by querying relevant grid cells only

### Privacy Optimizations
- **Coordinate masking** reduces storage requirements
- **Location hashing** for private providers
- **Configurable privacy levels** balance privacy and functionality

### Gas Optimizations
- **Integer coordinate storage** reduces gas costs
- **Efficient grid updates** minimize storage operations
- **Batch operations** for multiple location updates

## Security Considerations

### Access Control
- **Authorized caller validation** for sensitive operations
- **Admin-only emergency functions**
- **Provider registry integration** for verification

### Privacy Protection
- **Coordinate masking** prevents exact location tracking
- **Location hashing** for private providers
- **Configurable privacy levels** give providers control

### Data Validation
- **Coordinate validation** prevents invalid locations
- **Radius limits** prevent excessive search areas
- **Privacy level validation** ensures proper settings

## Deployment Configuration

### Constructor Parameters
```cairo
constructor(
    admin_address: ContractAddress,
    provider_registry: ContractAddress,
    marketplace_address: ContractAddress
)
```

### Integration Points
- **Provider Registry**: For provider verification
- **Service Marketplace**: For service discovery integration
- **Analytics Registry**: For search analytics (optional)

## Testing

The contract includes comprehensive test coverage for:
- Location registration and updates
- Privacy level management
- Radius-based searches
- Distance calculations
- Service area updates
- Emergency functions

## Future Enhancements

1. **Advanced Polygon Support**: Complex service area boundaries
2. **Real-time Location Updates**: Dynamic location tracking
3. **Geofencing**: Automatic service area notifications
4. **Location Analytics**: Advanced search pattern analysis
5. **Multi-chain Support**: Cross-chain location data

---

For integration help or questions, refer to the contract source code or contact the development team. 