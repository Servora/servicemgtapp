use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::{set_caller_address, set_contract_address, set_block_timestamp};
use array::ArrayTrait;
use traits::Into;
use option::OptionTrait;

use verification::verification::{
    VerificationContract, IVerificationDispatcher, IVerificationDispatcherTrait, Credential, VerificationRecord
};

// Test constants
const ADMIN: felt252 = 0x123;
const VERIFIER: felt252 = 0x456;
const PROVIDER: felt252 = 0x789;
const ISSUER: felt252 = 0xabc;
const CREDENTIAL_TYPE_1: u8 = 1; // License
const CREDENTIAL_TYPE_2: u8 = 2; // Certification
const CREDENTIAL_HASH: felt252 = 0xdef123;
const CURRENT_TIME: u64 = 1000;
const EXPIRY_TIME: u64 = 2000;

#[test]
fn test_register_credential() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = VerificationContract::contract_state_for_testing();
    VerificationContract::constructor(ref state, admin_address);
    
    // Set caller as admin
    set_caller_address(admin_address);
    set_block_timestamp(CURRENT_TIME);
    
    // Register a credential
    let provider_address = contract_address_const::<PROVIDER>();
    let issuer_address = contract_address_const::<ISSUER>();
    
    let credential_id = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .register_credential(
            ref state,
            provider_address,
            CREDENTIAL_TYPE_1,
            issuer_address,
            EXPIRY_TIME,
            CREDENTIAL_HASH
        );
    
    // Verify credential was registered
    assert(credential_id == 1.into(), 'Wrong credential ID');
    
    let credential = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .get_credential(@state, credential_id);
    
    assert(credential.provider_address == provider_address, 'Wrong provider');
    assert(credential.credential_type == CREDENTIAL_TYPE_1, 'Wrong credential type');
    assert(credential.issuer == issuer_address, 'Wrong issuer');
    assert(credential.issue_date == CURRENT_TIME, 'Wrong issue date');
    assert(credential.expiry_date == EXPIRY_TIME, 'Wrong expiry date');
    assert(!credential.revoked, 'Should not be revoked');
    assert(credential.hash == CREDENTIAL_HASH, 'Wrong hash');
}

#[test]
fn test_verify_credential() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = VerificationContract::contract_state_for_testing();
    VerificationContract::constructor(ref state, admin_address);
    
    // Set caller as admin
    set_caller_address(admin_address);
    set_block_timestamp(CURRENT_TIME);
    
    // Register a credential
    let provider_address = contract_address_const::<PROVIDER>();
    let issuer_address = contract_address_const::<ISSUER>();
    
    let credential_id = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .register_credential(
            ref state,
            provider_address,
            CREDENTIAL_TYPE_1,
            issuer_address,
            EXPIRY_TIME,
            CREDENTIAL_HASH
        );
    
    // Verify the credential
    let is_valid = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .verify_credential(ref state, credential_id);
    
    assert(is_valid, 'Credential should be valid');
    
    // Check verification history
    let history = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .get_verification_history(@state, credential_id);
    
    assert(history.len() == 1, 'Should have 1 verification');
    let record = *history.at(0);
    assert(record.credential_id == credential_id, 'Wrong credential ID');
    assert(record.verifier == admin_address, 'Wrong verifier');
    assert(record.timestamp == CURRENT_TIME, 'Wrong timestamp');
    assert(record.status == true, 'Wrong status');
}

#[test]
fn test_revoke_credential() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = VerificationContract::contract_state_for_testing();
    VerificationContract::constructor(ref state, admin_address);
    
    // Set caller as admin
    set_caller_address(admin_address);
    set_block_timestamp(CURRENT_TIME);
    
    // Register a credential
    let provider_address = contract_address_const::<PROVIDER>();
    let issuer_address = contract_address_const::<ISSUER>();
    
    let credential_id = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .register_credential(
            ref state,
            provider_address,
            CREDENTIAL_TYPE_1,
            issuer_address,
            EXPIRY_TIME,
            CREDENTIAL_HASH
        );
    
    // Revoke the credential
    IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .revoke_credential(ref state, credential_id);
    
    // Check if credential is revoked
    let credential = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .get_credential(@state, credential_id);
    
    assert(credential.revoked, 'Credential should be revoked');
    
    // Verify the credential should now be invalid
    let is_valid = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .is_credential_valid(@state, credential_id);
    
    assert(!is_valid, 'Credential should be invalid');
}

#[test]
fn test_expired_credential() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = VerificationContract::contract_state_for_testing();
    VerificationContract::constructor(ref state, admin_address);
    
    // Set caller as admin
    set_caller_address(admin_address);
    set_block_timestamp(CURRENT_TIME);
    
    // Register a credential
    let provider_address = contract_address_const::<PROVIDER>();
    let issuer_address = contract_address_const::<ISSUER>();
    
    let credential_id = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .register_credential(
            ref state,
            provider_address,
            CREDENTIAL_TYPE_1,
            issuer_address,
            EXPIRY_TIME,
            CREDENTIAL_HASH
        );
    
    // Set time to after expiry
    set_block_timestamp(EXPIRY_TIME + 1);
    
    // Verify the credential should now be invalid due to expiration
    let is_valid = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .is_credential_valid(@state, credential_id);
    
    assert(!is_valid, 'Credential should be expired');
}

#[test]
fn test_get_provider_credentials() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = VerificationContract::contract_state_for_testing();
    VerificationContract::constructor(ref state, admin_address);
    
    // Set caller as admin
    set_caller_address(admin_address);
    set_block_timestamp(CURRENT_TIME);
    
    // Register multiple credentials for the same provider
    let provider_address = contract_address_const::<PROVIDER>();
    let issuer_address = contract_address_const::<ISSUER>();
    
    let credential_id1 = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .register_credential(
            ref state,
            provider_address,
            CREDENTIAL_TYPE_1,
            issuer_address,
            EXPIRY_TIME,
            CREDENTIAL_HASH
        );
    
    let credential_id2 = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .register_credential(
            ref state,
            provider_address,
            CREDENTIAL_TYPE_2,
            issuer_address,
            EXPIRY_TIME,
            CREDENTIAL_HASH
        );
    
    // Get provider credentials
    let credentials = IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .get_provider_credentials(@state, provider_address);
    
    assert(credentials.len() == 2, 'Should have 2 credentials');
    assert(*credentials.at(0) == credential_id1, 'Wrong first credential');
    assert(*credentials.at(1) == credential_id2, 'Wrong second credential');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_unauthorized_register() {
    // Setup
    let admin_address = contract_address_const::<ADMIN>();
    let mut state = VerificationContract::contract_state_for_testing();
    VerificationContract::constructor(ref state, admin_address);
    
    // Set caller as non-admin
    let unauthorized = contract_address_const::<VERIFIER>();
    set_caller_address(unauthorized);
    set_block_timestamp(CURRENT_TIME);
    
    // Try to register a credential (should fail)
    let provider_address = contract_address_const::<PROVIDER>();
    let issuer_address = contract_address_const::<ISSUER>();
    
    IVerificationDispatcher { contract_address: contract_address_const::<0>() }
        .register_credential(
            ref state,
            provider_address,
            CREDENTIAL_TYPE_1,
            issuer_address,
            EXPIRY_TIME,
            CREDENTIAL_HASH
        );
}