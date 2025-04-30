use starknet::ContractAddress;
use array::Array;

#[starknet::interface]
trait IProviderRegistry {
    fn get_provider(self: @ContractState, provider_id: u256) -> Provider;
    fn is_verified_provider(self: @ContractState, provider_address: ContractAddress) -> bool;
    fn update_verification_status(ref self: ContractState, provider_address: ContractAddress, status: bool);
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Provider {
    id: u256,
    address: ContractAddress,
    name: felt252,
    verified: bool,
    active: bool,
    registration_date: u64,
}

#[starknet::interface]
trait IVerificationIntegration {
    fn verify_provider_credentials(
        ref self: ContractState, 
        provider_address: ContractAddress, 
        required_credential_types: Array<u8>
    ) -> bool;
    
    fn get_provider_verification_status(
        self: @ContractState,
        provider_address: ContractAddress
    ) -> bool;
}