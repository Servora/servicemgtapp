# Provider Module

The Provider Module is a comprehensive smart contract system that manages service provider registration, verification, and service catalog management within the decentralized service marketplace.

## Overview

The Provider Module consists of two main contracts:
- **ServiceRegistry**: Core provider and service management
- **ReputationSystem**: Provider reputation and rating tracking

## ServiceRegistry Contract

### Key Features

#### 1. Provider Registration & Management
- **Secure Registration**: Comprehensive provider registration with KYC requirements
- **Multi-level Verification**: Basic, Verified, and Premium verification levels
- **Metadata Storage**: Complete provider information including location, contact details, and specializations
- **Status Management**: Active, Inactive, Suspended, and Pending status tracking

#### 2. Service Catalog Management
- **Service Registration**: Dynamic service addition with pricing and duration
- **Category System**: Organized service categorization and tagging
- **Price Range Support**: Flexible pricing with low and high price points
- **Service Updates**: Real-time service information updates

#### 3. Verification & KYC System
- **KYC Integration**: Know Your Customer verification with expiry tracking
- **Verification Levels**: Progressive verification system (Basic → Verified → Premium)
- **Admin Controls**: Centralized verification management
- **Compliance Tracking**: KYC status and expiry monitoring

#### 4. Search & Discovery
- **Specialization-based Search**: Find providers by service specializations
- **Category Filtering**: Search services by category
- **Verification Filtering**: Filter by verification levels
- **Location Integration**: Location-based provider discovery

### Technical Implementation

#### Storage Structure
```cairo
// Provider storage
@storage_var
func providers(provider_id: felt252) -> (
    address: ContractAddress,
    name: felt252,
    description: felt252,
    verification_level: felt252,
    status: felt252,
    kyc_status: felt252,
    kyc_expiry: felt252,
    location_lat: felt252,
    location_lng: felt252,
    contact_email: felt252,
    contact_phone: felt252,
    website: felt252,
    created_at: felt252,
    updated_at: felt252
) {}

// Service storage
@storage_var
func services(service_id: felt252) -> (
    provider_id: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252,
    status: felt252,
    created_at: felt252,
    updated_at: felt252
) {}
```

#### Core Functions

**Provider Management:**
- `register_provider()`: Register new provider with complete metadata
- `update_provider_metadata()`: Update provider information
- `deactivate_provider()`: Deactivate provider account
- `verify_provider()`: Update verification and KYC status

**Service Management:**
- `add_service()`: Add new service to provider catalog
- `update_service()`: Update service information
- `get_provider_services()`: Retrieve all services for a provider

**Search & Discovery:**
- `search_providers()`: Advanced provider search with filters
- `get_providers_by_category()`: Category-based provider search
- `get_providers_by_verification_level()`: Verification-based filtering

### Integration Points

#### 1. Location Module Integration
```cairo
// Location data stored in provider records
location_lat: felt252,
location_lng: felt252
```

#### 2. Payment Module Integration
- Provider verification levels affect payment processing
- Service pricing integration with payment escrow
- Revenue sharing based on provider status

#### 3. Analytics Module Integration
- Provider registration analytics
- Service catalog usage tracking
- Verification level distribution metrics

#### 4. Governance Module Integration
- Provider verification proposal system
- Category management governance
- Platform policy updates

### Usage Examples

#### Register a Provider
```cairo
let (provider_id) = ServiceRegistry::register_provider(
    contract_address,
    'Tech Solutions Inc',
    'Professional IT services and consulting',
    'contact@techsolutions.com',
    '+1-555-0123',
    'https://techsolutions.com',
    40750000, // 40.75 degrees * 1,000,000
    -73980000, // -73.98 degrees * 1,000,000
    array![1, 2] // Web dev, Mobile dev specializations
);
```

#### Add a Service
```cairo
let (service_id) = ServiceRegistry::add_service(
    contract_address,
    provider_id,
    'Web Development',
    'Custom web development and design services',
    1, // Technology category
    5000, // $50.00 * 100
    25000, // $250.00 * 100
    14 // 14 days duration
);
```

#### Search Providers
```cairo
let (providers) = ServiceRegistry::search_providers(
    contract_address,
    1, // Web development specialization
    1, // Verified level
    0, // Active status
    1, // Approved KYC
    10 // Max 10 results
);
```

### Verification Levels

| Level | Description | Requirements |
|-------|-------------|--------------|
| Basic | Initial registration | Basic information |
| Verified | Enhanced trust | KYC approved, documents verified |
| Premium | Highest trust | Extensive verification, proven track record |

### Provider Statuses

| Status | Description | Permissions |
|--------|-------------|-------------|
| Active | Fully operational | All marketplace features |
| Inactive | Temporarily disabled | No new bookings |
| Suspended | Admin suspended | No marketplace access |
| Pending | Awaiting verification | Limited marketplace access |

### KYC Statuses

| Status | Description | Marketplace Access |
|--------|-------------|-------------------|
| Pending | Awaiting verification | Limited |
| Approved | Verification complete | Full access |
| Rejected | Verification failed | No access |
| Expired | KYC expired | Requires renewal |

### Performance Metrics

- **Gas Efficiency**: Optimized storage patterns for minimal gas usage
- **Query Speed**: Efficient indexing for fast provider searches
- **Scalability**: Support for thousands of providers and services
- **Data Integrity**: Comprehensive validation and error handling

### Security Features

- **Access Control**: Admin-only functions for critical operations
- **Data Validation**: Comprehensive input validation
- **Status Checks**: Proper authorization for all operations
- **Event Logging**: Complete audit trail for all actions

### Testing

The module includes comprehensive test coverage:
- Unit tests for all core functions
- Integration tests with other modules
- Error handling and edge case testing
- Performance and gas optimization tests

### Deployment

1. Deploy the ServiceRegistry contract
2. Set up initial categories and verification requirements
3. Configure integration with other modules
4. Deploy the ReputationSystem contract
5. Link contracts for full functionality

### Future Enhancements

- **Advanced Search**: AI-powered provider matching
- **Reputation Integration**: Enhanced reputation system
- **Multi-chain Support**: Cross-chain provider verification
- **Mobile Integration**: Mobile app provider management
- **API Gateway**: RESTful API for external integrations

## File Structure

```
modules/provider/
├── ServiceRegistry.cairo      # Main provider registry contract
├── ServiceRegistry.md         # Detailed documentation
├── interfaces.cairo           # StarkNet interface definitions
├── provider_registry.cairo    # Legacy provider registry
├── ReputationSystem.cairo     # Reputation tracking system
└── README.md                 # This documentation
```

## Contributing

When contributing to the Provider Module:

1. Follow Cairo 1.0 best practices
2. Maintain comprehensive test coverage
3. Update documentation for all changes
4. Ensure gas optimization
5. Validate integration with other modules

## License

This module is part of the Service Management Application and follows the same licensing terms as the main project. 