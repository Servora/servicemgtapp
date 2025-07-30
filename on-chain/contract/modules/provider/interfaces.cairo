use starknet::ContractAddress;

// Data structures for ServiceRegistry
#[derive(Drop, Serde)]
struct Provider {
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
}

#[derive(Drop, Serde)]
struct Service {
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
}

#[derive(Drop, Serde)]
struct ServiceCategory {
    name: felt252,
    description: felt252,
    status: felt252,
    created_at: felt252
}

#[derive(Drop, Serde)]
struct ProviderStatistics {
    total_services: felt252,
    total_specializations: felt252,
    verification_level: felt252,
    status: felt252,
    kyc_status: felt252
}

// Events
#[derive(Drop, starknet::Event)]
enum Event {
    #[starknet(event)]
    ProviderRegistered {
        provider_id: felt252,
        address: ContractAddress,
        name: felt252,
        verification_level: felt252
    },
    #[starknet(event)]
    ServiceAdded {
        service_id: felt252,
        provider_id: felt252,
        title: felt252,
        category_id: felt252
    },
    #[starknet(event)]
    ServiceUpdated {
        service_id: felt252,
        provider_id: felt252,
        title: felt252
    },
    #[starknet(event)]
    ProviderVerified {
        provider_id: felt252,
        verification_level: felt252,
        kyc_status: felt252
    },
    #[starknet(event)]
    ProviderDeactivated {
        provider_id: felt252,
        status: felt252
    },
    #[starknet(event)]
    CategoryAdded {
        category_id: felt252,
        name: felt252
    },
    #[starknet(event)]
    MetadataUpdated {
        provider_id: felt252,
        field: felt252
    }
}

#[starknet::interface]
trait IServiceRegistry<TContractState> {
    // Core provider management
    fn register_provider(
        ref self: TContractState,
        name: felt252,
        description: felt252,
        contact_email: felt252,
        contact_phone: felt252,
        website: felt252,
        location_lat: felt252,
        location_lng: felt252,
        specializations: Array<felt252>
    ) -> felt252;
    
    fn update_provider_metadata(
        ref self: TContractState,
        provider_id: felt252,
        name: felt252,
        description: felt252,
        contact_email: felt252,
        contact_phone: felt252,
        website: felt252
    );
    
    fn deactivate_provider(
        ref self: TContractState,
        provider_id: felt252
    );
    
    // Service management
    fn add_service(
        ref self: TContractState,
        provider_id: felt252,
        title: felt252,
        description: felt252,
        category_id: felt252,
        price_low: felt252,
        price_high: felt252,
        duration: felt252
    ) -> felt252;
    
    fn update_service(
        ref self: TContractState,
        service_id: felt252,
        title: felt252,
        description: felt252,
        category_id: felt252,
        price_low: felt252,
        price_high: felt252,
        duration: felt252
    );
    
    // Verification and KYC
    fn verify_provider(
        ref self: TContractState,
        provider_id: felt252,
        verification_level: felt252,
        kyc_status: felt252,
        kyc_expiry: felt252
    );
    
    // Category management
    fn add_service_category(
        ref self: TContractState,
        name: felt252,
        description: felt252
    ) -> felt252;
    
    // Search and query functions
    fn search_providers(
        self: @TContractState,
        specialization: felt252,
        verification_level: felt252,
        status: felt252,
        kyc_status: felt252,
        max_results: felt252
    ) -> Array<felt252>;
    
    fn get_provider_services(
        self: @TContractState,
        provider_id: felt252
    ) -> Array<felt252>;
    
    fn get_provider_by_address(
        self: @TContractState,
        address: ContractAddress
    ) -> felt252;
    
    fn get_provider_statistics(
        self: @TContractState,
        provider_id: felt252
    ) -> ProviderStatistics;
    
    // Admin functions
    fn set_verification_requirement(
        ref self: TContractState,
        requires_verification: bool
    );
    
    fn update_kyc_expiry(
        ref self: TContractState,
        provider_id: felt252,
        new_expiry: felt252
    );
    
    // View functions
    fn get_provider(
        self: @TContractState,
        provider_id: felt252
    ) -> Provider;
    
    fn get_service(
        self: @TContractState,
        service_id: felt252
    ) -> Service;
    
    fn get_service_category(
        self: @TContractState,
        category_id: felt252
    ) -> ServiceCategory;
    
    fn get_total_providers(
        self: @TContractState
    ) -> felt252;
    
    fn get_total_services(
        self: @TContractState
    ) -> felt252;
    
    fn get_total_categories(
        self: @TContractState
    ) -> felt252;
    
    fn get_verification_requirement(
        self: @TContractState
    ) -> bool;
    
    fn get_provider_specializations(
        self: @TContractState,
        provider_id: felt252
    ) -> Array<felt252>;
    
    fn get_providers_by_category(
        self: @TContractState,
        category_id: felt252,
        max_results: felt252
    ) -> Array<felt252>;
    
    fn get_services_by_category(
        self: @TContractState,
        category_id: felt252,
        max_results: felt252
    ) -> Array<felt252>;
    
    fn get_providers_by_verification_level(
        self: @TContractState,
        verification_level: felt252,
        max_results: felt252
    ) -> Array<felt252>;
    
    fn get_active_providers(
        self: @TContractState,
        max_results: felt252
    ) -> Array<felt252>;
    
    fn get_provider_services_count(
        self: @TContractState,
        provider_id: felt252
    ) -> felt252;
    
    fn get_category_services_count(
        self: @TContractState,
        category_id: felt252
    ) -> felt252;
    
    fn is_provider_active(
        self: @TContractState,
        provider_id: felt252
    ) -> bool;
    
    fn is_service_active(
        self: @TContractState,
        service_id: felt252
    ) -> bool;
    
    fn get_provider_verification_level(
        self: @TContractState,
        provider_id: felt252
    ) -> felt252;
    
    fn get_provider_kyc_status(
        self: @TContractState,
        provider_id: felt252
    ) -> felt252;
    
    fn get_provider_location(
        self: @TContractState,
        provider_id: felt252
    ) -> (felt252, felt252); // (latitude, longitude)
    
    fn get_service_price_range(
        self: @TContractState,
        service_id: felt252
    ) -> (felt252, felt252); // (price_low, price_high)
    
    fn get_provider_contact_info(
        self: @TContractState,
        provider_id: felt252
    ) -> (felt252, felt252, felt252); // (email, phone, website)
    
    fn get_service_duration(
        self: @TContractState,
        service_id: felt252
    ) -> felt252;
    
    fn get_category_name(
        self: @TContractState,
        category_id: felt252
    ) -> felt252;
    
    fn get_provider_name(
        self: @TContractState,
        provider_id: felt252
    ) -> felt252;
    
    fn get_service_title(
        self: @TContractState,
        service_id: felt252
    ) -> felt252;
    
    fn get_provider_creation_date(
        self: @TContractState,
        provider_id: felt252
    ) -> felt252;
    
    fn get_service_creation_date(
        self: @TContractState,
        service_id: felt252
    ) -> felt252;
    
    fn get_provider_last_update(
        self: @TContractState,
        provider_id: felt252
    ) -> felt252;
    
    fn get_service_last_update(
        self: @TContractState,
        service_id: felt252
    ) -> felt252;
} 