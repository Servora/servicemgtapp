%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::array::ArrayTrait

// Storage variables
@storage_var
func dispute_count() -> (count: felt252) {}

@storage_var
func disputes(dispute_id: felt252) -> (
    payment_id: felt252,
    initiator: ContractAddress,
    respondent: ContractAddress,
    status: felt252,  // 0: Pending, 1: In Progress, 2: Resolved, 3: Appealed
    resolution: felt252,  // 0: None, 1: Client Favor, 2: Provider Favor, 3: Split
    timestamp: felt252
) {}

@storage_var
func evidence_count(dispute_id: felt252) -> (count: felt252) {}

@storage_var
func evidence(dispute_id: felt252, evidence_id: felt252) -> (
    submitter: ContractAddress,
    evidence_hash: felt252,  // IPFS or other content hash
    timestamp: felt252,
    verified: felt252
) {}

@storage_var
func arbitrators(dispute_id: felt252) -> (
    arbitrator: ContractAddress,
    assigned_at: felt252,
    status: felt252  // 0: Pending, 1: Accepted, 2: Declined
) {}

// Events
@event
func DisputeCreated(
    dispute_id: felt252,
    payment_id: felt252,
    initiator: ContractAddress,
    respondent: ContractAddress,
    timestamp: felt252
) {}

@event
func EvidenceSubmitted(
    dispute_id: felt252,
    evidence_id: felt252,
    submitter: ContractAddress,
    evidence_hash: felt252,
    timestamp: felt252
) {}

@event
func ArbitratorAssigned(
    dispute_id: felt252,
    arbitrator: ContractAddress,
    timestamp: felt252
) {}

@event
func DisputeResolved(
    dispute_id: felt252,
    resolution: felt252,
    arbitrator: ContractAddress,
    timestamp: felt252
) {}

// Core functions
@external
func create_dispute{syscalls: SyscallPtr}(
    payment_id: felt252,
    respondent: ContractAddress,
    initial_evidence_hash: felt252
) -> (dispute_id: felt252):
    alloc_locals
    let (caller) = get_caller_address()
    let (current_count) = dispute_count.read()
    let dispute_id = current_count + 1
    let (timestamp) = get_block_timestamp()
    
    // Create dispute
    disputes.write(dispute_id, (payment_id, caller, respondent, 0, 0, timestamp))
    dispute_count.write(dispute_id)
    
    // Store initial evidence
    evidence_count.write(dispute_id, 1)
    evidence.write(dispute_id, 0, (caller, initial_evidence_hash, timestamp, 0))
    
    DisputeCreated.emit(dispute_id, payment_id, caller, respondent, timestamp)
    EvidenceSubmitted.emit(dispute_id, 0, caller, initial_evidence_hash, timestamp)
    
    return (dispute_id)
end

@external
func submit_evidence{syscalls: SyscallPtr}(
    dispute_id: felt252,
    evidence_hash: felt252
) -> (evidence_id: felt252):
    alloc_locals
    let (caller) = get_caller_address()
    let (current_count) = evidence_count.read(dispute_id)
    let evidence_id = current_count + 1
    let (timestamp) = get_block_timestamp()
    
    evidence.write(dispute_id, evidence_id, (caller, evidence_hash, timestamp, 0))
    evidence_count.write(dispute_id, evidence_id)
    
    EvidenceSubmitted.emit(dispute_id, evidence_id, caller, evidence_hash, timestamp)
    return (evidence_id)
end

@external
func assign_arbitrator{syscalls: SyscallPtr}(
    dispute_id: felt252,
    arbitrator: ContractAddress
) -> ():
    alloc_locals
    let (timestamp) = get_block_timestamp()
    arbitrators.write(dispute_id, (arbitrator, timestamp, 0))
    ArbitratorAssigned.emit(dispute_id, arbitrator, timestamp)
    return ()
end

@external
func resolve_dispute{syscalls: SyscallPtr}(
    dispute_id: felt252,
    resolution: felt252
) -> ():
    alloc_locals
    let (caller) = get_caller_address()
    let (arbitrator, _, status) = arbitrators.read(dispute_id)
    assert caller == arbitrator, 'Only assigned arbitrator'
    assert status == 1, 'Arbitrator must be active'
    
    let (payment_id, initiator, respondent, dispute_status, _, timestamp) = disputes.read(dispute_id)
    assert dispute_status == 1, 'Dispute must be in progress'
    
    let (current_timestamp) = get_block_timestamp()
    disputes.write(dispute_id, (payment_id, initiator, respondent, 2, resolution, current_timestamp))
    
    DisputeResolved.emit(dispute_id, resolution, caller, current_timestamp)
    return ()
end

// View functions
@view
func get_dispute_details(dispute_id: felt252) -> (
    payment_id: felt252,
    initiator: ContractAddress,
    respondent: ContractAddress,
    status: felt252,
    resolution: felt252,
    timestamp: felt252
):
    return disputes.read(dispute_id)
end

@view
func get_evidence_details(dispute_id: felt252, evidence_id: felt252) -> (
    submitter: ContractAddress,
    evidence_hash: felt252,
    timestamp: felt252,
    verified: felt252
):
    return evidence.read(dispute_id, evidence_id)
end