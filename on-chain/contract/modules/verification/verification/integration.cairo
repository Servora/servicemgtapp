use starknet::ContractAddress;
use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use traits::Into;
use zeroable::Zeroable;

use verification::interfaces::{IProviderRegistry, IVerificationIntegration, Provider};
use verification::verification::{IVerification, Credential, VerificationRecord};

#[starknet::contract]
mod VerificationIntegration {
    use super::{ContractAddress, ArrayTrait, IProviderRegistry, IVerification, Credential};
    use starknet::{get_caller_address, get_contract_address};
    use array::SpanTrait;
    use option::OptionTrait;
    use traits::Into;
    use zeroable::Zeroable;
    
    #[storage]
    struct Storage {
        admin: ContractAddress,
        verification_contract: ContractAddress,
        provider_registry_contract: ContractAddress,
        required_credentials: LegacyMap<u8, bool>,
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin_address: ContractAddress,
        verification_contract: ContractAddress,
        provider_registry_contract: ContractAddress
    ) {
        self.admin.write(admin_address);
        self.verification_contract.write(verification_contract);
        self.provider_registry_contract.write(provider_registry_contract);
    }
    
    #[external(v0)]
    impl VerificationIntegrationImpl of super::IVerificationIntegration {
        fn verify_provider_credentials(
            ref self: ContractState, 
            provider_address: ContractAddress, 
            required_credential_types: Array<u8>
        ) -> bool {
            // Get verification contract
            let verification_contract = self.verification_contract.read();
            let verification_dispatcher = IVerificationDispatcher { contract_address: verification_contract };
            
            // Get all credentials for the provider
            let credential_ids = verification_dispatcher.get_provider_credentials(provider_address);
            
            // Check if provider has all required credential types
            let mut required_types_span = required_credential_types.span();
            let mut has_all_required = true;
            
            loop {
                match required_types_span.pop_front() {
                    Option::Some(required_type) => {
                        let mut found = false;
                        let mut credential_ids_span = credential_ids.span();
                        
                        loop {
                            match credential_ids_span.pop_front() {
                                Option::Some(credential_id) => {
                                    let credential = verification_dispatcher.get_credential(*credential_id);
                                    if credential.credential_type == *required_type && 
                                       verification_dispatcher.is_credential_valid(*credential_id) {
                                        found = true;
                                        break;
                                    }
                                },
                                Option::None => { break; }
                            };
                        };
                        
                        if !found {
                            has_all_required = false;
                            break;
                        }
                    },
                    Option::None => { break; }
                };
            };
            
            // Update provider verification status in the registry
            if has_all_required {
                let provider_registry = self.provider_registry_contract.read();
                let provider_registry_dispatcher = IProviderRegistryDispatcher { contract_address: provider_registry };
                provider_registry_dispatcher.update_verification_status(provider_address, true);
            }
            
            has_all_required
        }
        
        fn get_provider_verification_status(
            self: @ContractState,
            provider_address: ContractAddress
        ) -> bool {
            let provider_registry = self.provider_registry_contract.read();
            let provider_registry_dispatcher = IProviderRegistryDispatcher { contract_address: provider_registry };
            provider_registry_dispatcher.is_verified_provider(provider_address)
        }
    }
    
    #[external(v0)]
    fn set_required_credential(ref self: ContractState, credential_type: u8, required: bool) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can set requirements');
        self.required_credentials.write(credential_type, required);
    }
    
    #[external(v0)]
    fn is_credential_required(self: @ContractState, credential_type: u8) -> bool {
        self.required_credentials.read(credential_type)
    }
    
    #[external(v0)]
    fn update_verification_contract(ref self: ContractState, new_contract: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can update contract');
        assert(!new_contract.is_zero(), 'Invalid contract address');
        self.verification_contract.write(new_contract);
    }
    
    #[external(v0)]
    fn update_provider_registry_contract(ref self: ContractState, new_contract: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can update contract');
        assert(!new_contract.is_zero(), 'Invalid contract address');
        self.provider_registry_contract.write(new_contract);
    }
}