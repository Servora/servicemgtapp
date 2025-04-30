// SPDX-License-Identifier: MIT
// Cairo 1.0 Payment & Escrow Contract for Service Marketplace

%lang starknet

from starkware::starknet::contract_address import ContractAddress
from starkware::starknet::storage import Storage
from starkware::starknet::event import Event
from starkware::starknet::syscalls import get_caller_address, get_block_timestamp
from starkware::starknet::erc20::IERC20 import IERC20
from starkware::starknet::math::uint256 import Uint256, add_uint256, sub_uint256, eq_uint256, lt_uint256, le_uint256
from starkware::starknet::array::ArrayTrait
from starkware::starknet::context import get_tx_info

@storage_var
func payment_count() -> (res: felt252) {}

@storage_var
func payments(payment_id: felt252) -> (
    client: ContractAddress,
    provider: ContractAddress,
    token: ContractAddress,
    amount: Uint256,
    released: Uint256,
    milestone_count: felt252,
    completed: felt252,
    disputed: felt252,
    timestamp: felt252
) {}

@storage_var
func milestones(payment_id: felt252, milestone_id: felt252) -> (
    amount: Uint256,
    released: felt252,
    completed: felt252,
    timestamp: felt252
) {}

@storage_var
func disputes(payment_id: felt252) -> (
    active: felt252,
    initiator: ContractAddress,
    timestamp: felt252
) {}

@event
func PaymentCreated(payment_id: felt252, client: ContractAddress, provider: ContractAddress, token: ContractAddress, amount: Uint256, timestamp: felt252) {}
@event
func MilestoneReleased(payment_id: felt252, milestone_id: felt252, amount: Uint256, timestamp: felt252) {}
@event
func DisputeInitiated(payment_id: felt252, initiator: ContractAddress, timestamp: felt252) {}
@event
func RefundProcessed(payment_id: felt252, to: ContractAddress, amount: Uint256, timestamp: felt252) {}

// Core contract implementation

@external
func create_payment{
    syscalls: SyscallPtr
}(
    provider: ContractAddress,
    token: ContractAddress,
    amount: Uint256,
    milestone_amounts: Array<Uint256>
) -> (payment_id: felt252):
    alloc_locals
    let (caller) = get_caller_address()
    let (current_count) = payment_count.read()
    let payment_id = current_count + 1
    let (timestamp) = get_block_timestamp()
    let milestone_count = milestone_amounts.len()
    payment_count.write(payment_id)
    payments.write(payment_id, (caller, provider, token, amount, Uint256(0,0), milestone_count, 0, 0, timestamp))
    // Store milestones
    let mut i = 0
    while i < milestone_count:
        let (milestone_amount) = milestone_amounts.at(i)
        milestones.write(payment_id, i, (milestone_amount, 0, 0, timestamp))
        let i = i + 1
    end
    PaymentCreated.emit(payment_id, caller, provider, token, amount, timestamp)
    return (payment_id,)
end

@external
func fund_payment{
    syscalls: SyscallPtr
}(
    payment_id: felt252
) -> ():
    alloc_locals
    let (caller) = get_caller_address()
    let (client, provider, token, amount, released, milestone_count, completed, disputed, timestamp) = payments.read(payment_id)
    assert client == caller, 'Only client can fund payment.'
    // Prevent double funding
    assert released.low == 0 && released.high == 0, 'Payment already funded.'
    // Transfer ERC-20 tokens from client to contract
    let (tx_info) = get_tx_info()
    IERC20(token).transferFrom(client, tx_info.contract_address, amount)
    // Mark as funded (released remains 0, but this prevents double funding)
    payments.write(payment_id, (client, provider, token, amount, released, milestone_count, completed, disputed, timestamp))
    return ()
end

@external
func release_milestone{
    syscalls: SyscallPtr
}(
    payment_id: felt252,
    milestone_id: felt252
) -> ():
    alloc_locals
    let (caller) = get_caller_address()
    let (client, provider, token, amount, released, milestone_count, completed, disputed, timestamp) = payments.read(payment_id)
    assert caller == client, 'Only client can release milestone.'
    let (milestone_amount, milestone_released, milestone_completed, milestone_timestamp) = milestones.read(payment_id, milestone_id)
    assert milestone_completed == 0, 'Milestone already completed.'
    // Prevent over-release (released + milestone_amount <= amount)
    let (potential_released, overflow) = add_uint256(released, milestone_amount)
    assert overflow == 0, 'Uint256 overflow.'
    let (exceeds, _) = lt_uint256(amount, potential_released)
    assert exceeds == 0, 'Cannot release more than funded.'
    // Transfer ERC-20 tokens to provider
    IERC20(token).transfer(provider, milestone_amount)
    // Update released amount
    milestones.write(payment_id, milestone_id, (milestone_amount, 1, 1, get_block_timestamp()))
    // Mark as completed if last milestone
    let new_completed = if milestone_id + 1 == milestone_count { 1 } else { completed };
    payments.write(payment_id, (client, provider, token, amount, potential_released, milestone_count, new_completed, disputed, timestamp))
    MilestoneReleased.emit(payment_id, milestone_id, milestone_amount, get_block_timestamp())
    return ()
end

@view
func get_payment_history(payment_id: felt252) -> (
    client: ContractAddress,
    provider: ContractAddress,
    token: ContractAddress,
    amount: Uint256,
    released: Uint256,
    milestone_count: felt252,
    completed: felt252,
    disputed: felt252,
    timestamp: felt252
):
    return payments.read(payment_id)
end

@external
func initiate_dispute{
    syscalls: SyscallPtr
}(
    payment_id: felt252
) -> ():
    alloc_locals
    let (caller) = get_caller_address()
    let (active, initiator, dispute_timestamp) = disputes.read(payment_id)
    assert active == 0, 'Dispute already active.'
    disputes.write(payment_id, (1, caller, get_block_timestamp()))
    DisputeInitiated.emit(payment_id, caller, get_block_timestamp())
    return ()
end

@external
func resolve_dispute{
    syscalls: SyscallPtr
}(
    payment_id: felt252,
    winner: ContractAddress,
    refund_amount: Uint256
) -> ():
    alloc_locals
    let (active, initiator, dispute_timestamp) = disputes.read(payment_id)
    assert active == 1, 'No active dispute.'
    let (client, provider, token, amount, released, milestone_count, completed, disputed, timestamp) = payments.read(payment_id)
    // Only admin/arbitrator can resolve (for demo: client)
    let (caller) = get_caller_address()
    assert caller == client, 'Only client (admin) can resolve.'
    // Prevent resolving with more than unreleased funds
    let (unreleased, _) = sub_uint256(amount, released)
    let (exceeds, _) = lt_uint256(unreleased, refund_amount)
    assert exceeds == 0, 'Cannot resolve for more than unreleased funds.'
    // Refund or payout
    IERC20(token).transfer(winner, refund_amount)
    disputes.write(payment_id, (0, initiator, dispute_timestamp))
    RefundProcessed.emit(payment_id, winner, refund_amount, get_block_timestamp())
    return ()
end

@external
func process_refund{
    syscalls: SyscallPtr
}(
    payment_id: felt252,
    refund_amount: Uint256
) -> ():
    alloc_locals
    let (client, provider, token, amount, released, milestone_count, completed, disputed, timestamp) = payments.read(payment_id)
    let (caller) = get_caller_address()
    assert caller == provider, 'Only provider can process refund.'
    // Prevent refunding more than unreleased funds
    let (unreleased, _) = sub_uint256(amount, released)
    let (exceeds, _) = lt_uint256(unreleased, refund_amount)
    assert exceeds == 0, 'Cannot refund more than unreleased funds.'
    // Refund tokens to client
    IERC20(token).transfer(client, refund_amount)
    RefundProcessed.emit(payment_id, client, refund_amount, get_block_timestamp())
    return ()
end

// Additional validation and security checks can be added as needed.
