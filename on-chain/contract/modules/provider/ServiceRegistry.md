# ServiceRegistry Contract Documentation

## Overview

The ServiceRegistry contract is a Cairo 1.0 implementation for StarkNet that serves as the foundation for the service marketplace. It manages provider registration with KYC verification, service catalog management, provider verification levels, and comprehensive metadata storage.

## Key Features

### 🔐 **Provider Registration & KYC Verification**
- **Secure provider registration** with comprehensive validation
- **KYC verification system** with multiple status levels
- **Provider verification levels**: Basic, Verified, Premium
- **Comprehensive metadata storage** including location and contact info

### 📋 **Service Catalog Management**
- **Service categorization** with hierarchical category system
- **Service tagging** for enhanced searchability
- **Dynamic service updates** with version control
- **Provider-service mapping** for efficient queries

### 🛡️ **Verification & Quality Control**
- **Multi-level verification system** for provider quality
- **KYC document management** with verification tracking
- **Provider rating system** integration
- **Suspension and deactivation** mechanisms

### 🔍 **Search & Discovery**
- **Verification level filtering** for quality-based search
- **Category-based service discovery**
- **Tag-based service filtering**
- **Integration with location-based search**

## Technical Implementation

### Verification Levels
1. **Basic (0)**: New providers with minimal verification
2. **Verified (1)**: Providers with completed KYC and basic verification
3. **Premium (2)**: Providers with enhanced verification and proven track record

### Provider Status
- **Inactive (0)**: Deactivated providers
- **Active (1)**: Active and operational providers
- **Suspended (2)**: Temporarily suspended providers
- **Pending Verification (3)**: Providers awaiting verification

### KYC Status
- **Pending (0)**: KYC verification in progress
- **Approved (1)**: KYC verification approved
- **Rejected (2)**: KYC verification rejected
- **Expired (3)**: KYC verification expired

## Contract Interface

### Core Provider Functions

#### `register_provider(name, description, contact_email, contact_phone, website, location_lat, location_lng, specializations)`
Registers a new service provider with comprehensive metadata.

**Parameters:**
- `name`: Provider name/company name
- `description`: Provider description
- `contact_email`: Contact email address
- `contact_phone`: Contact phone number
- `website`: Provider website URL
- `location_lat`: Location latitude
- `location_lng`: Location longitude
- `specializations`: Array of provider specializations/tags

**Returns:** `provider_id` (unique provider identifier)

#### `deactivate_provider(provider_id, reason)`
Deactivates a provider and all associated services.

**Parameters:**
- `provider_id`: Provider identifier
- `reason`: Reason for deactivation

### Service Management Functions

#### `add_service(provider_id, title, description, category_id, price_low, price_high, duration, tags)`
Adds a new service for a provider.

**Parameters:**
- `provider_id`: Provider identifier
- `title`: Service title
- `description`: Service description
- `category_id`: Service category ID
- `price_low`: Minimum price
- `price_high`: Maximum price
- `duration`: Service duration
- `tags`: Array of service tags

**Returns:** `service_id` (unique service identifier)

#### `update_service(service_id, title, description, category_id, price_low, price_high, duration)`
Updates an existing service.

**Parameters:**
- `service_id`: Service identifier
- `title`: Updated service title
- `description`: Updated service description
- `category_id`: Updated category ID
- `price_low`: Updated minimum price
- `price_high`: Updated maximum price
- `duration`: Updated service duration

#### `get_provider_services(provider_id)`
Retrieves all services for a specific provider.

**Parameters:**
- `provider_id`: Provider identifier

**Returns:** `(service_count, service_ids)` - Count and array of service IDs

### Verification Management

#### `update_verification_level(provider_id, verification_level, verifier, notes)`
Updates a provider's verification level.

**Parameters:**
- `provider_id`: Provider identifier
- `verification_level`: New verification level (0-2)
- `verifier`: Address of the verifier
- `notes`: Verification notes

#### `update_kyc_status(provider_id, kyc_status, expiry_date)`
Updates a provider's KYC verification status.

**Parameters:**
- `provider_id`: Provider identifier
- `kyc_status`: New KYC status (0-3)
- `expiry_date`: KYC expiry date

### Category Management

#### `create_category(name, description, parent_category)`
Creates a new service category.

**Parameters:**
- `name`: Category name
- `description`: Category description
- `parent_category`: Parent category ID (0 for root)

**Returns:** `category_id` (unique category identifier)

### View Functions

#### `get_provider_details(provider_id)`
Retrieves comprehensive provider details.

**Returns:** `(address, name, description, verification_level, status, kyc_status, location_lat, location_lng, contact_email, contact_phone, website, created_at)`

#### `get_service_details(service_id)`
Retrieves comprehensive service details.

**Returns:** `(provider_id, title, description, category_id, price_low, price_high, duration, status, created_at)`

#### `get_providers_by_verification_level(verification_level)`
Retrieves providers by verification level.

**Returns:** `(provider_count, provider_ids)` - Count and array of provider IDs

#### `get_active_providers()`
Retrieves all active providers.

**Returns:** `(provider_count, provider_ids)` - Count and array of provider IDs

#### `get_services_by_category(category_id)`
Retrieves services by category.

**Returns:** `(service_count, service_ids)` - Count and array of service IDs

#### `get_provider_specializations(provider_id)`
Retrieves provider specializations.

**Returns:** `(specialization_count, specializations)` - Count and array of specializations

#### `get_service_tags(service_id)`
Retrieves service tags.

**Returns:** `(tag_count, tags)` - Count and array of tags

#### `get_verification_record(provider_id)`
Retrieves verification record for a provider.

**Returns:** `(verifier, verification_level, verification_date, expiry_date, notes)`

#### `get_provider_rating(provider_id)`
Retrieves provider rating information.

**Returns:** `(average_rating, total_reviews, last_updated)`

#### `get_total_statistics()`
Retrieves overall system statistics.

**Returns:** `(total_providers, total_services, total_categories, active_providers)`

### Utility Functions

#### `is_provider_registered(address)`
Checks if an address is registered as a provider.

**Returns:** `registered` (1 if registered, 0 if not)

#### `get_provider_id(address)`
Gets provider ID by address.

**Returns:** `provider_id`

### Admin Functions

#### `emergency_suspend_provider(provider_id, reason)`
Emergency suspension of a provider (admin only).

## Events

- `ProviderRegistered(provider_id, address, name, verification_level, timestamp)`
- `ProviderUpdated(provider_id, address, name, timestamp)`
- `ProviderDeactivated(provider_id, address, reason, timestamp)`
- `ServiceAdded(service_id, provider_id, title, category_id, timestamp)`
- `ServiceUpdated(service_id, provider_id, title, timestamp)`
- `VerificationUpdated(provider_id, verification_level, verifier, timestamp)`
- `KYCStatusChanged(provider_id, old_status, new_status, timestamp)`
- `CategoryCreated(category_id, name, parent_category, timestamp)`

## Integration Examples

### Frontend Integration (React + starknet.js)

```jsx
import React, { useState, useEffect } from 'react';
import { Provider, Contract } from 'starknet';

const ServiceRegistry = () => {
  const [providers, setProviders] = useState([]);
  const [services, setServices] = useState([]);
  const [selectedVerificationLevel, setSelectedVerificationLevel] = useState(1);

  // Register a new provider
  const registerProvider = async (providerData) => {
    try {
      const contract = new Contract(contractAbi, contractAddress, provider);
      
      const result = await contract.register_provider(
        providerData.name,
        providerData.description,
        providerData.email,
        providerData.phone,
        providerData.website,
        providerData.lat * 1000000,
        providerData.lng * 1000000,
        providerData.specializations
      );

      console.log('Provider registered with ID:', result.provider_id);
    } catch (error) {
      console.error('Error registering provider:', error);
    }
  };

  // Add a new service
  const addService = async (serviceData) => {
    try {
      const contract = new Contract(contractAbi, contractAddress, provider);
      
      const result = await contract.add_service(
        serviceData.providerId,
        serviceData.title,
        serviceData.description,
        serviceData.categoryId,
        serviceData.priceLow,
        serviceData.priceHigh,
        serviceData.duration,
        serviceData.tags
      );

      console.log('Service added with ID:', result.service_id);
    } catch (error) {
      console.error('Error adding service:', error);
    }
  };

  // Get providers by verification level
  const getVerifiedProviders = async (verificationLevel) => {
    try {
      const contract = new Contract(contractAbi, contractAddress, provider);
      
      const result = await contract.get_providers_by_verification_level(verificationLevel);
      
      const providerDetails = [];
      for (let i = 0; i < result.provider_ids.length; i++) {
        const providerId = result.provider_ids[i];
        const details = await contract.get_provider_details(providerId);
        providerDetails.push({
          id: providerId,
          address: details.address,
          name: details.name,
          verificationLevel: details.verification_level,
          status: details.status
        });
      }
      
      setProviders(providerDetails);
    } catch (error) {
      console.error('Error fetching providers:', error);
    }
  };

  // Get provider services
  const getProviderServices = async (providerId) => {
    try {
      const contract = new Contract(contractAbi, contractAddress, provider);
      
      const result = await contract.get_provider_services(providerId);
      
      const serviceDetails = [];
      for (let i = 0; i < result.service_ids.length; i++) {
        const serviceId = result.service_ids[i];
        const details = await contract.get_service_details(serviceId);
        serviceDetails.push({
          id: serviceId,
          title: details.title,
          description: details.description,
          categoryId: details.category_id,
          priceLow: details.price_low,
          priceHigh: details.price_high
        });
      }
      
      setServices(serviceDetails);
    } catch (error) {
      console.error('Error fetching services:', error);
    }
  };

  return (
    <div>
      <h2>Service Registry</h2>
      
      <div className="provider-registration">
        <h3>Register Provider</h3>
        <button onClick={() => registerProvider({
          name: 'Tech Solutions Inc',
          description: 'Professional IT services',
          email: 'contact@techsolutions.com',
          phone: '+1234567890',
          website: 'https://techsolutions.com',
          lat: 40.7128,
          lng: -74.0060,
          specializations: ['web_development', 'mobile_apps', 'cloud_services']
        })}>
          Register Provider
        </button>
      </div>

      <div className="verification-filter">
        <h3>Filter by Verification Level</h3>
        <select 
          value={selectedVerificationLevel} 
          onChange={(e) => setSelectedVerificationLevel(Number(e.target.value))}
        >
          <option value={0}>Basic</option>
          <option value={1}>Verified</option>
          <option value={2}>Premium</option>
        </select>
        <button onClick={() => getVerifiedProviders(selectedVerificationLevel)}>
          Get Providers
        </button>
      </div>

      <div className="providers-list">
        <h3>Providers ({providers.length})</h3>
        {providers.map(provider => (
          <div key={provider.id} className="provider-card">
            <h4>{provider.name}</h4>
            <p>Verification Level: {provider.verificationLevel}</p>
            <p>Status: {provider.status}</p>
            <button onClick={() => getProviderServices(provider.id)}>
              View Services
            </button>
          </div>
        ))}
      </div>

      <div className="services-list">
        <h3>Services ({services.length})</h3>
        {services.map(service => (
          <div key={service.id} className="service-card">
            <h4>{service.title}</h4>
            <p>{service.description}</p>
            <p>Price: ${service.priceLow} - ${service.priceHigh}</p>
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

class ServiceRegistry {
  constructor(contractAddress, contractAbi, provider) {
    this.contract = new Contract(contractAbi, contractAddress, provider);
  }

  // Register a new provider
  async registerProvider(providerData) {
    try {
      const result = await this.contract.register_provider(
        providerData.name,
        providerData.description,
        providerData.email,
        providerData.phone,
        providerData.website,
        Math.floor(providerData.lat * 1000000),
        Math.floor(providerData.lng * 1000000),
        providerData.specializations
      );
      
      return result.provider_id;
    } catch (error) {
      throw new Error(`Failed to register provider: ${error.message}`);
    }
  }

  // Add a new service
  async addService(serviceData) {
    try {
      const result = await this.contract.add_service(
        serviceData.providerId,
        serviceData.title,
        serviceData.description,
        serviceData.categoryId,
        serviceData.priceLow,
        serviceData.priceHigh,
        serviceData.duration,
        serviceData.tags
      );
      
      return result.service_id;
    } catch (error) {
      throw new Error(`Failed to add service: ${error.message}`);
    }
  }

  // Get provider details
  async getProviderDetails(providerId) {
    try {
      const result = await this.contract.get_provider_details(providerId);
      
      return {
        address: result.address,
        name: result.name,
        description: result.description,
        verificationLevel: result.verification_level,
        status: result.status,
        kycStatus: result.kyc_status,
        locationLat: result.location_lat / 1000000,
        locationLng: result.location_lng / 1000000,
        contactEmail: result.contact_email,
        contactPhone: result.contact_phone,
        website: result.website,
        createdAt: result.created_at
      };
    } catch (error) {
      throw new Error(`Failed to get provider details: ${error.message}`);
    }
  }

  // Get provider services
  async getProviderServices(providerId) {
    try {
      const result = await this.contract.get_provider_services(providerId);
      
      const services = [];
      for (let i = 0; i < result.service_ids.length; i++) {
        const serviceId = result.service_ids[i];
        const serviceDetails = await this.contract.get_service_details(serviceId);
        
        services.push({
          id: serviceId,
          title: serviceDetails.title,
          description: serviceDetails.description,
          categoryId: serviceDetails.category_id,
          priceLow: serviceDetails.price_low,
          priceHigh: serviceDetails.price_high,
          duration: serviceDetails.duration,
          status: serviceDetails.status,
          createdAt: serviceDetails.created_at
        });
      }
      
      return services;
    } catch (error) {
      throw new Error(`Failed to get provider services: ${error.message}`);
    }
  }

  // Get providers by verification level
  async getProvidersByVerificationLevel(verificationLevel) {
    try {
      const result = await this.contract.get_providers_by_verification_level(verificationLevel);
      
      const providers = [];
      for (let i = 0; i < result.provider_ids.length; i++) {
        const providerId = result.provider_ids[i];
        const providerDetails = await this.getProviderDetails(providerId);
        providers.push({
          id: providerId,
          ...providerDetails
        });
      }
      
      return providers;
    } catch (error) {
      throw new Error(`Failed to get providers by verification level: ${error.message}`);
    }
  }

  // Update verification level
  async updateVerificationLevel(providerId, verificationLevel, verifier, notes) {
    try {
      await this.contract.update_verification_level(
        providerId,
        verificationLevel,
        verifier,
        notes
      );
      
      return true;
    } catch (error) {
      throw new Error(`Failed to update verification level: ${error.message}`);
    }
  }

  // Get total statistics
  async getTotalStatistics() {
    try {
      const result = await this.contract.get_total_statistics();
      
      return {
        totalProviders: result.total_providers,
        totalServices: result.total_services,
        totalCategories: result.total_categories,
        activeProviders: result.active_providers
      };
    } catch (error) {
      throw new Error(`Failed to get statistics: ${error.message}`);
    }
  }
}

module.exports = ServiceRegistry;
```

## Performance Optimizations

### Storage Efficiency
- **Efficient indexing** for fast provider and service lookups
- **Optimized data structures** for minimal storage overhead
- **Batch operations** for multiple updates
- **Lazy loading** for large datasets

### Search Performance
- **Verification level indexing** for quality-based filtering
- **Category-based indexing** for service discovery
- **Tag-based indexing** for enhanced searchability
- **Provider-service mapping** for efficient queries

### Gas Optimization
- **Efficient data validation** reduces failed transactions
- **Optimized event emission** for cost-effective logging
- **Batch operations** minimize transaction costs
- **Smart contract integration** reduces external calls

## Security Considerations

### Access Control
- **Admin-only functions** for critical operations
- **Provider ownership verification** for service management
- **Authorized caller validation** for verification updates
- **Emergency suspension** mechanisms

### Data Validation
- **Comprehensive input validation** prevents invalid data
- **Provider existence checks** ensure data integrity
- **Service ownership verification** prevents unauthorized updates
- **Category validation** ensures proper categorization

### KYC Integration
- **Document hash verification** for KYC documents
- **Verification status tracking** for compliance
- **Expiry date management** for KYC renewals
- **Multi-level verification** for quality assurance

## Deployment Configuration

### Constructor Parameters
```cairo
constructor(
    admin_address: ContractAddress,
    verification_contract: ContractAddress,
    geolocation_service: ContractAddress
)
```

### Integration Points
- **Verification Contract**: For KYC and verification processes
- **Geolocation Service**: For location-based provider discovery
- **Analytics Registry**: For provider and service analytics
- **Payment System**: For service pricing and payments

## Testing

The contract includes comprehensive test coverage for:
- Provider registration and updates
- Service management and categorization
- Verification level management
- KYC status updates
- Category management
- Search and filtering
- Emergency functions
- Integration testing

## Future Enhancements

1. **Advanced Search**: Full-text search capabilities
2. **Provider Analytics**: Performance metrics and insights
3. **Automated Verification**: AI-powered verification processes
4. **Multi-chain Support**: Cross-chain provider data
5. **Advanced Categorization**: Machine learning-based categorization

---

For integration help or questions, refer to the contract source code or contact the development team. 