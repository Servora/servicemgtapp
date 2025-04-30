# Edge and Negative Tests for PaymentEscrow (Cairo 1.0)
%lang starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet
from starkware.cairo.common.uint256 import Uint256
from contracts.PaymentEscrow import PaymentEscrow

@external
func test_double_funding_should_fail() -> ():
    let starknet = Starknet.empty()
    let erc20 = await starknet.deploy(contract_class=IERC20)
    let payment_escrow = await starknet.deploy(contract_class=PaymentEscrow)
    let client = 0x111
    let provider = 0x222
    let token = erc20.contract_address
    let amount = Uint256(1000, 0)
    let milestone_amounts = [Uint256(1000, 0)]
    let (payment_id) = await payment_escrow.create_payment(provider, token, amount, milestone_amounts)
    await payment_escrow.fund_payment(payment_id, caller_address=client)
    // Second funding attempt should fail
    let failed = 0
    try:
        await payment_escrow.fund_payment(payment_id, caller_address=client)
    except:
        failed = 1
    assert failed == 1, 'Double funding should fail'
    return ()
end

@external
func test_over_release_should_fail() -> ():
    let starknet = Starknet.empty()
    let erc20 = await starknet.deploy(contract_class=IERC20)
    let payment_escrow = await starknet.deploy(contract_class=PaymentEscrow)
    let client = 0x111
    let provider = 0x222
    let token = erc20.contract_address
    let amount = Uint256(1000, 0)
    let milestone_amounts = [Uint256(1000, 0)]
    let (payment_id) = await payment_escrow.create_payment(provider, token, amount, milestone_amounts)
    await payment_escrow.fund_payment(payment_id, caller_address=client)
    await payment_escrow.release_milestone(payment_id, 0, caller_address=client)
    // Attempt to release again should fail
    let failed = 0
    try:
        await payment_escrow.release_milestone(payment_id, 0, caller_address=client)
    except:
        failed = 1
    assert failed == 1, 'Over-release should fail'
    return ()
end

@external
func test_unauthorized_access_should_fail() -> ():
    let starknet = Starknet.empty()
    let erc20 = await starknet.deploy(contract_class=IERC20)
    let payment_escrow = await starknet.deploy(contract_class=PaymentEscrow)
    let client = 0x111
    let provider = 0x222
    let token = erc20.contract_address
    let amount = Uint256(1000, 0)
    let milestone_amounts = [Uint256(1000, 0)]
    let (payment_id) = await payment_escrow.create_payment(provider, token, amount, milestone_amounts)
    await payment_escrow.fund_payment(payment_id, caller_address=client)
    // Provider tries to release milestone (should fail)
    let failed = 0
    try:
        await payment_escrow.release_milestone(payment_id, 0, caller_address=provider)
    except:
        failed = 1
    assert failed == 1, 'Unauthorized access should fail'
    return ()
end

# Add more edge/negative tests as needed
