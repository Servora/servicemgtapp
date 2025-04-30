# PaymentEscrow Contract Tests (Cairo 1.0)
# Run with: pytest

%lang starknet

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet
from starkware.cairo.common.uint256 import Uint256
from contracts.PaymentEscrow import PaymentEscrow

@contract_interface
namespace IERC20:
    func transferFrom(sender: felt252, recipient: felt252, amount: Uint256) -> ()
    func transfer(recipient: felt252, amount: Uint256) -> ()
end

@external
func test_payment_flow() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let erc20 = await starknet.deploy(contract_class=IERC20)
    let payment_escrow = await starknet.deploy(contract_class=PaymentEscrow)

    # Set up test accounts
    let client = 0x111
    let provider = 0x222
    let token = erc20.contract_address
    let amount = Uint256(1000, 0)
    let milestone_amounts = [Uint256(500, 0), Uint256(500, 0)]

    # Client creates payment
    let (payment_id) = await payment_escrow.create_payment(provider, token, amount, milestone_amounts)

    # Client funds payment (mock ERC-20 transfer)
    await payment_escrow.fund_payment(payment_id, caller_address=client)

    # Client releases first milestone
    await payment_escrow.release_milestone(payment_id, 0, caller_address=client)

    # Retrieve payment history
    let (history) = await payment_escrow.get_payment_history(payment_id)
    assert history.client == client, 'Client address mismatch'
    assert history.provider == provider, 'Provider address mismatch'

    # Initiate and resolve dispute
    await payment_escrow.initiate_dispute(payment_id, caller_address=client)
    await payment_escrow.resolve_dispute(payment_id, provider, Uint256(500, 0), caller_address=client)

    # Provider processes refund
    await payment_escrow.process_refund(payment_id, Uint256(500, 0), caller_address=provider)
    return ()
end

# Additional tests for security, invalid access, and edge cases can be added below.
