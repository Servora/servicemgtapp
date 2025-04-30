use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;
use array::ArrayTrait;
use option::OptionTrait;
use traits::Into;
use zeroable::Zeroable;

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Credential {
    id: u256,
    provider_address: ContractAddress,
    credential_type: u8,
    issuer: ContractAddress,
    issue_date: u64,
    expiry_date: u64,
    revoked: bool,
    hash: felt252, // Hash of the credential data
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct VerificationRecord {
    credential_id: u256,
    verifier: ContractAddress,
    timestamp: u64,
    status: bool,
}

#[starknet::interface]
trait IVerification {
    fn register_credential(
        ref self: ContractState,
        provider_address: ContractAddress,
        credential_type: u8,
        issuer: ContractAddress,
        expiry_date: u64,
        hash: felt252
    ) -> u256;
    
    fn verify_credential(ref self: ContractState, credential_id: u256) -> bool;
    
    fn revoke_credential(ref self: ContractState, credential_id: u256);
    
    fn get_credential(self: @ContractState, credential_id: u256) -> Credential;
    
    fn get_provider_credentials(self: @ContractState, provider_address: ContractAddress) -> Array<u256>;
    
    fn is_credential_valid(self: @ContractState, credential_id: u256) -> bool;
    
    fn get_verification_history(self: @ContractState, credential_id: u256) -> Array<VerificationRecord>;
}

#[starknet::contract]
mod VerificationContract {
    use super::{ContractAddress, Credential, VerificationRecord, ArrayTrait, get_caller_address, get_block_timestamp};
    use starknet::{get_contract_address, contract_address_const};
    use traits::{Into, TryInto};
    use option::OptionTrait;
    use zeroable::Zeroable;
    use array::SpanTrait;
    use dict::Felt252DictTrait;
    
    #[storage]
    struct Storage {
        admin: ContractAddress,
        authorized_verifiers: LegacyMap<ContractAddress, bool>,
        credentials: LegacyMap<u256, Credential>,
        credential_counter: u256,
        provider_to_credentials: LegacyMap<(ContractAddress, u32), u256>,
        provider_credential_count: LegacyMap<ContractAddress, u32>,
        verification_records: LegacyMap<(u256, u32), VerificationRecord>,
        credential_verification_count: LegacyMap<u256, u32>,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CredentialRegistered: CredentialRegistered,
        CredentialVerified: CredentialVerified,
        CredentialRevoked: CredentialRevoked,
    }
    
    #[derive(Drop, starknet::Event)]
    struct CredentialRegistered {
        credential_id: u256,
        provider_address: ContractAddress,
        credential_type: u8,
        issuer: ContractAddress,
    }
    
    #[derive(Drop, starknet::Event)]
    struct CredentialVerified {
        credential_id: u256,
        verifier: ContractAddress,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct CredentialRevoked {
        credential_id: u256,
        revoker: ContractAddress,
        timestamp: u64,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        self.admin.write(admin_address);
        self.authorized_verifiers.write(admin_address, true);
    }
    
    #[external(v0)]
    impl VerificationImpl of super::IVerification {
        fn register_credential(
            ref self: ContractState,
            provider_address: ContractAddress,
            credential_type: u8,
            issuer: ContractAddress,
            expiry_date: u64,
            hash: felt252
        ) -> u256 {
            // Only authorized verifiers can register credentials
            let caller = get_caller_address();
            assert(self.authorized_verifiers.read(caller), 'Not authorized');
            
            // Get current timestamp
            let current_time = get_block_timestamp();
            
            // Ensure expiry date is in the future
            assert(expiry_date > current_time, 'Invalid expiry date');
            
            // Increment credential counter
            let credential_id = self.credential_counter.read() + 1.into();
            self.credential_counter.write(credential_id);
            
            // Create and store the credential
            let credential = Credential {
                id: credential_id,
                provider_address: provider_address,
                credential_type: credential_type,
                issuer: issuer,
                issue_date: current_time,
                expiry_date: expiry_date,
                revoked: false,
                hash: hash,
            };
            
            self.credentials.write(credential_id, credential);
            
            // Add to provider's credentials
            let provider_count = self.provider_credential_count.read(provider_address);
            self.provider_to_credentials.write((provider_address, provider_count), credential_id);
            self.provider_credential_count.write(provider_address, provider_count + 1);
            
            // Emit event
            self.emit(CredentialRegistered {
                credential_id: credential_id,
                provider_address: provider_address,
                credential_type: credential_type,
                issuer: issuer,
            });
            
            credential_id
        }
        
        fn verify_credential(ref self: ContractState, credential_id: u256) -> bool {
            // Only authorized verifiers can verify credentials
            let caller = get_caller_address();
            assert(self.authorized_verifiers.read(caller), 'Not authorized');
            
            // Check if credential exists and is valid
            let credential = self.credentials.read(credential_id);
            assert(credential.id == credential_id, 'Credential not found');
            
            let is_valid = self.is_credential_valid(credential_id);
            
            // Record verification
            let current_time = get_block_timestamp();
            let verification_count = self.credential_verification_count.read(credential_id);
            
            let record = VerificationRecord {
                credential_id: credential_id,
                verifier: caller,
                timestamp: current_time,
                status: is_valid,
            };
            
            self.verification_records.write((credential_id, verification_count), record);
            self.credential_verification_count.write(credential_id, verification_count + 1);
            
            // Emit event
            self.emit(CredentialVerified {
                credential_id: credential_id,
                verifier: caller,
                timestamp: current_time,
            });
            
            is_valid
        }
        
        fn revoke_credential(ref self: ContractState, credential_id: u256) {
            // Only admin or the issuer can revoke credentials
            let caller = get_caller_address();
            let credential = self.credentials.read(credential_id);
            
            assert(credential.id == credential_id, 'Credential not found');
            assert(
                caller == self.admin.read() || caller == credential.issuer,
                'Not authorized to revoke'
            );
            
            // Update credential to revoked status
            let mut updated_credential = credential;
            updated_credential.revoked = true;
            self.credentials.write(credential_id, updated_credential);
            
            // Emit event
            self.emit(CredentialRevoked {
                credential_id: credential_id,
                revoker: caller,
                timestamp: get_block_timestamp(),
            });
        }
        
        fn get_credential(self: @ContractState, credential_id: u256) -> Credential {
            let credential = self.credentials.read(credential_id);
            assert(credential.id == credential_id, 'Credential not found');
            credential
        }
        
        fn get_provider_credentials(self: @ContractState, provider_address: ContractAddress) -> Array<u256> {
            let count = self.provider_credential_count.read(provider_address);
            let mut credentials = ArrayTrait::new();
            
            let mut i: u32 = 0;
            while i < count {
                let credential_id = self.provider_to_credentials.read((provider_address, i));
                credentials.append(credential_id);
                i += 1;
            }
            
            credentials
        }
        
        fn is_credential_valid(self: @ContractState, credential_id: u256) -> bool {
            let credential = self.credentials.read(credential_id);
            assert(credential.id == credential_id, 'Credential not found');
            
            // Check if credential is not revoked and not expired
            let current_time = get_block_timestamp();
            !credential.revoked && current_time <= credential.expiry_date
        }
        
        fn get_verification_history(self: @ContractState, credential_id: u256) -> Array<VerificationRecord> {
            let count = self.credential_verification_count.read(credential_id);
            let mut records = ArrayTrait::new();
            
            let mut i: u32 = 0;
            while i < count {
                let record = self.verification_records.read((credential_id, i));
                records.append(record);
                i += 1;
            }
            
            records
        }
    }
    
    #[external(v0)]
    fn add_verifier(ref self: ContractState, verifier_address: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can add verifiers');
        self.authorized_verifiers.write(verifier_address, true);
    }
    
    #[external(v0)]
    fn remove_verifier(ref self: ContractState, verifier_address: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can remove verifiers');
        self.authorized_verifiers.write(verifier_address, false);
    }
    
    #[external(v0)]
    fn is_verifier(self: @ContractState, address: ContractAddress) -> bool {
        self.authorized_verifiers.read(address)
    }
    
    #[external(v0)]
    fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Only admin can transfer admin');
        assert(!new_admin.is_zero(), 'Invalid admin address');
        self.admin.write(new_admin);
    }
}