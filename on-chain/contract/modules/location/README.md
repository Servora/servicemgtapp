# Location Module - GeolocationService

## Overview

The Location Module provides comprehensive geolocation services for the decentralized service marketplace. It enables location-based service discovery, privacy-preserving location storage, and efficient spatial indexing for fast radius-based searches.

## 🎯 **Key Features**

### 📍 **Location-Based Service Discovery**
- **Radius-based provider searches** with configurable search areas
- **Grid-based spatial indexing** for O(log n) search complexity
- **Geographic service availability tracking** for real-time updates
- **Support for both point locations and service areas**

### 🛡️ **Privacy-Preserving Mechanisms**
- **Three privacy levels**: Public, Approximate, Private
- **Coordinate masking** for privacy protection
- **Location hashing** for private providers
- **Configurable privacy controls** per provider

### ⚡ **Performance Optimizations**
- **1km x 1km grid cells** for optimal spatial indexing
- **Efficient coordinate storage** using integer multiplication
- **Fast radius searches** by querying relevant grid cells only
- **Gas-optimized operations** for cost-effective deployment

### 🎯 **Service Area Management**
- **Point-based service areas** for exact location services
- **Circular service areas** with configurable radius
- **Polygon service areas** for complex boundaries (future enhancement)
- **Dynamic service area updates** with real-time changes

## 📁 **File Structure**

```
location/
├── GeolocationService.cairo      # Main contract implementation
├── interfaces.cairo              # Interface definitions
├── GeolocationService.md         # Detailed documentation
├── README.md                     # This file
└── test_geolocation_service.cairo # Comprehensive test suite
```

## 🚀 **Quick Start**

### 1. **Deploy the Contract**

```cairo
// Deploy with required parameters
let (contract_address) = GeolocationService::constructor(
    admin_address,
    provider_registry_address,
    marketplace_address
);
```

### 2. **Register Provider Location**

```cairo
// Register a provider's location
let (location_id) = GeolocationService::register_location(
    provider_id,
    latitude * 1000000,  // Convert to contract format
    longitude * 1000000,
    privacy_level,       // 0=public, 1=approximate, 2=private
    area_type,          // 0=point, 1=circle, 2=polygon
    service_radius      // in meters
);
```

### 3. **Find Nearby Providers**

```cairo
// Search for providers within radius
let (provider_ids, distances) = GeolocationService::find_nearby_providers(
    center_latitude,
    center_longitude,
    radius,           // in meters (max 50km)
    max_results       // maximum number of results
);
```

## 🔧 **Core Functions**

### **Location Management**
- `register_location()` - Register a new provider location
- `update_location()` - Update provider location and privacy
- `update_service_area()` - Update service area configuration
- `emergency_remove_location()` - Admin function to remove location

### **Search & Discovery**
- `find_nearby_providers()` - Find providers within radius
- `get_providers_in_radius()` - Get count and total distance
- `calculate_distance()` - Calculate distance between coordinates

### **Privacy Management**
- `update_privacy_level()` - Update provider privacy settings
- `get_provider_location()` - Get location with privacy respect

### **Analytics & Stats**
- `get_search_stats()` - Get search statistics
- `get_total_locations()` - Get total registered locations

## 🛡️ **Privacy Levels**

| Level | Description | Coordinate Precision | Use Case |
|-------|-------------|---------------------|----------|
| **Public (0)** | Exact coordinates | 1 meter | Public services, delivery |
| **Approximate (1)** | Rounded to 100m | 100 meters | General services |
| **Private (2)** | Rounded to 1km + hash | 1 kilometer | Sensitive services |

## 📊 **Performance Metrics**

### **Search Performance**
- **Grid-based indexing**: O(log n) complexity
- **Radius searches**: Efficient within 50km
- **Max providers per search**: Configurable (default 1000)
- **Grid cell size**: 1km x 1km for optimal balance

### **Storage Optimization**
- **Coordinate precision**: 6 decimal places (1 meter)
- **Integer storage**: Reduces gas costs
- **Efficient indexing**: Minimal storage overhead
- **Privacy masking**: Reduces storage requirements

## 🔗 **Integration Points**

### **Provider Registry**
```cairo
// Verify provider exists before location registration
let is_registered = ProviderRegistry::is_provider_registered(provider_id);
assert(is_registered, 'Provider not registered');
```

### **Service Marketplace**
```cairo
// Get provider services for location-based filtering
let services = ServiceMarketplace::get_provider_services(provider_id);
```

### **Analytics Registry**
```cairo
// Record location searches for analytics
AnalyticsRegistry::record_metric(
    service_id,
    LOCATION_SEARCH_METRIC,
    result_count
);
```

## 🧪 **Testing**

### **Run Comprehensive Tests**
```bash
# Run all tests
cairo-test test_geolocation_service.cairo

# Run specific test
cairo-test test_geolocation_service.cairo::test_find_nearby_providers
```

### **Test Coverage**
- ✅ Location registration and updates
- ✅ Privacy level management
- ✅ Radius-based searches
- ✅ Distance calculations
- ✅ Service area updates
- ✅ Spatial indexing
- ✅ Error handling
- ✅ Performance optimizations

## 📈 **Usage Examples**

### **Frontend Integration (React)**

```jsx
import { useGeolocation } from './hooks/useGeolocation';

const LocationSearch = () => {
  const [nearbyProviders, setNearbyProviders] = useState([]);
  const { location } = useGeolocation();

  const searchNearbyProviders = async (radius = 5000) => {
    const result = await contract.find_nearby_providers(
      location.lat * 1000000,
      location.lng * 1000000,
      radius,
      20
    );
    setNearbyProviders(result.provider_ids);
  };

  return (
    <div>
      <button onClick={() => searchNearbyProviders(5000)}>
        Find Providers (5km)
      </button>
      {nearbyProviders.map(provider => (
        <ProviderCard key={provider.id} provider={provider} />
      ))}
    </div>
  );
};
```

### **Backend Integration (Node.js)**

```javascript
class GeolocationService {
  async registerProviderLocation(providerId, lat, lng, privacyLevel = 1) {
    const result = await this.contract.register_location(
      providerId,
      Math.floor(lat * 1000000),
      Math.floor(lng * 1000000),
      privacyLevel,
      1, // circle area type
      5000 // 5km radius
    );
    return result.location_id;
  }

  async findNearbyProviders(lat, lng, radius = 5000) {
    const result = await this.contract.find_nearby_providers(
      Math.floor(lat * 1000000),
      Math.floor(lng * 1000000),
      radius,
      20
    );
    return {
      providerIds: result.provider_ids,
      distances: result.distances
    };
  }
}
```

## 🔒 **Security Considerations**

### **Access Control**
- **Authorized caller validation** for sensitive operations
- **Admin-only emergency functions**
- **Provider registry integration** for verification

### **Privacy Protection**
- **Coordinate masking** prevents exact location tracking
- **Location hashing** for private providers
- **Configurable privacy levels** give providers control

### **Data Validation**
- **Coordinate validation** prevents invalid locations
- **Radius limits** prevent excessive search areas
- **Privacy level validation** ensures proper settings

## 🚀 **Deployment**

### **Constructor Parameters**
```cairo
constructor(
    admin_address: ContractAddress,
    provider_registry: ContractAddress,
    marketplace_address: ContractAddress
)
```

### **Environment Variables**
```bash
GEOLOCATION_ADMIN_ADDRESS=0x...
PROVIDER_REGISTRY_ADDRESS=0x...
MARKETPLACE_ADDRESS=0x...
```

## 📚 **Documentation**

- **[GeolocationService.md](./GeolocationService.md)** - Detailed contract documentation
- **[interfaces.cairo](./interfaces.cairo)** - Interface definitions
- **[test_geolocation_service.cairo](./test_geolocation_service.cairo)** - Test suite

## 🤝 **Contributing**

1. **Fork the repository**
2. **Create a feature branch**
3. **Add tests for new functionality**
4. **Ensure all tests pass**
5. **Submit a pull request**

## 📄 **License**

MIT License - see [LICENSE](../../../LICENSE) for details.

---

**Built with ❤️ for the decentralized service marketplace ecosystem** 