# PaymentEscrow Contract Interface Documentation

## Overview
This contract implements a secure, milestone-based payment and escrow system for a decentralized service marketplace on StarkNet, written in Cairo 1.0. It supports ERC-20 tokens, detailed payment history, dispute resolution, and refund processing.

---

## Contract Storage

```cairo
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
```

---

## External Functions

### 1. create_payment
Create a new escrow payment with milestone breakdown.
```cairo
@external
func create_payment(
    provider: ContractAddress,
    token: ContractAddress,
    amount: Uint256,
    milestone_amounts: Array<Uint256>
) -> (payment_id: felt252)
```
- **provider**: Service provider address
- **token**: ERC-20 token contract address
- **amount**: Total amount (Uint256, 18 decimals)
- **milestone_amounts**: Array of Uint256, each for a milestone
- **Returns**: `payment_id` (unique identifier)

---

### 2. fund_payment
Fund an escrow payment with ERC-20 tokens.
```cairo
@external
func fund_payment(payment_id: felt252)
```
- **payment_id**: The identifier of the payment to fund

---

### 3. release_milestone
Release funds for a specific milestone to the provider.
```cairo
@external
func release_milestone(payment_id: felt252, milestone_id: felt252)
```
- **payment_id**: Payment identifier
- **milestone_id**: Milestone index (starts at 0)

---

### 4. get_payment_history
Retrieve payment and milestone details for dashboards/history.
```cairo
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
)
```
- **payment_id**: Payment identifier
- **Returns**: Payment details

---

### 5. initiate_dispute
Start a dispute for a payment.
```cairo
@external
func initiate_dispute(payment_id: felt252)
```
- **payment_id**: Payment identifier

---

### 6. resolve_dispute
Resolve an active dispute and specify who receives funds.
```cairo
@external
func resolve_dispute(payment_id: felt252, winner: ContractAddress, refund_amount: Uint256)
```
- **payment_id**: Payment identifier
- **winner**: Address to receive funds
- **refund_amount**: Amount to transfer

---

### 7. process_refund
Provider refunds the client.
```cairo
@external
func process_refund(payment_id: felt252, refund_amount: Uint256)
```
- **payment_id**: Payment identifier
- **refund_amount**: Amount to refund to client

---

## Events
- `PaymentCreated(payment_id, client, provider, token, amount, timestamp)`
- `MilestoneReleased(payment_id, milestone_id, amount, timestamp)`
- `DisputeInitiated(payment_id, initiator, timestamp)`
- `RefundProcessed(payment_id, to, amount, timestamp)`

These events can be indexed and displayed in the frontend for real-time updates.

---

## Integration Notes
- **ERC-20 Support:** Client must approve the contract to spend tokens before calling `fund_payment`.
- **Milestones:** Managed as an array; frontend should track which milestones are released.
- **Security:** Only authorized parties can call sensitive functions.
- **Timestamps:** All actions are timestamped for audit/history.

---

## Example Usage (starknet.js)
```js
// Example: Create a payment
await contract.create_payment(provider, token, amount, milestone_amounts);

// Fund payment
await contract.fund_payment(payment_id);

// Release milestone
await contract.release_milestone(payment_id, milestone_id);

// Get payment history
const history = await contract.get_payment_history(payment_id);

// Initiate dispute
await contract.initiate_dispute(payment_id);

// Resolve dispute
await contract.resolve_dispute(payment_id, winner, refund_amount);

// Process refund
await contract.process_refund(payment_id, refund_amount);
```

---

For further integration help, see the contract and test files or reach out to the maintainers.
