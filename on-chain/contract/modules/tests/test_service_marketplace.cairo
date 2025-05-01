# ServiceMarketplace Contract Tests (Cairo 1.0)
%lang starknet

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet
from starkware.cairo.common.uint256 import Uint256
from contracts.ServiceMarketplace import ServiceMarketplace

@contract_interface
namespace IERC20:
    func transferFrom(sender: felt252, recipient: felt252, amount: Uint256) -> ()
    func transfer(recipient: felt252, amount: Uint256) -> ()
end

@external
func test_service_creation() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let provider_registry_address = 0x456
    let payment_escrow_address = 0x789
    let analytics_registry_address = 0xabc
    
    let service_marketplace = await starknet.deploy(
        contract_class=ServiceMarketplace,
        constructor_calldata=[
            admin_address,
            provider_registry_address,
            payment_escrow_address,
            analytics_registry_address
        ]
    )
    
    # Test data
    let provider_address = 0x111
    let title = 123456789  # "Test Service" encoded as felt
    let description = 987654321  # "Description" encoded as felt
    let category_id = 1
    let price_low = 1000000000  # 10.00000000 (8 decimal places)
    let price_high = 0
    let duration = 3600  # 1 hour in seconds
    
    # Create a service
    let (service_id) = await service_marketplace.create_service(
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        caller_address=provider_address
    )
    
    # Verify service was created
    let (
        stored_provider,
        stored_title,
        stored_description,
        stored_category_id,
        stored_price_low,
        stored_price_high,
        stored_duration,
        stored_status,
        _,
        _
    ) = await service_marketplace.get_service(service_id)
    
    assert stored_provider == provider_address, 'Wrong provider'
    assert stored_title == title, 'Wrong title'
    assert stored_description == description, 'Wrong description'
    assert stored_category_id == category_id, 'Wrong category'
    assert stored_price_low == price_low, 'Wrong price low'
    assert stored_price_high == price_high, 'Wrong price high'
    assert stored_duration == duration, 'Wrong duration'
    assert stored_status == 1, 'Wrong status'
    
    return ()
end

@external
func test_service_booking() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let provider_registry_address = 0x456
    let payment_escrow_address = 0x789
    let analytics_registry_address = 0xabc
    
    let service_marketplace = await starknet.deploy(
        contract_class=ServiceMarketplace,
        constructor_calldata=[
            admin_address,
            provider_registry_address,
            payment_escrow_address,
            analytics_registry_address
        ]
    )
    
    # Test data
    let provider_address = 0x111
    let client_address = 0x222
    let token_address = 0x333
    let title = 123456789  # "Test Service" encoded as felt
    let description = 987654321  # "Description" encoded as felt
    let category_id = 1
    let price_low = 1000000000  # 10.00000000 (8 decimal places)
    let price_high = 0
    let duration = 3600  # 1 hour in seconds
    
    # Create a service
    let (service_id) = await service_marketplace.create_service(
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        caller_address=provider_address
    )
    
    # Set availability
    let start_time = 1672531200  # 2023-01-01 00:00:00 UTC
    await service_marketplace.set_availability(
        service_id,
        start_time,
        1,  # Available
        caller_address=provider_address
    )
    
    # Book the service
    let (booking_id) = await service_marketplace.book_service(
        service_id,
        start_time,
        token_address,
        caller_address=client_address
    )
    
    # Verify booking was created
    let (
        stored_service_id,
        stored_client,
        stored_provider,
        stored_start_time,
        stored_end_time,
        stored_price_low,
        stored_price_high,
        stored_payment_id,
        stored_status,
        _,
        _
    ) = await service_marketplace.get_booking(booking_id)
    
    assert stored_service_id == service_id, 'Wrong service ID'
    assert stored_client == client_address, 'Wrong client'
    assert stored_provider == provider_address, 'Wrong provider'
    assert stored_start_time == start_time, 'Wrong start time'
    assert stored_end_time == start_time + duration, 'Wrong end time'
    assert stored_price_low == price_low, 'Wrong price low'
    assert stored_price_high == price_high, 'Wrong price high'
    assert stored_status == 1, 'Wrong status'
    
    # Check availability is now marked as unavailable
    let (available) = await service_marketplace.check_availability(service_id, start_time)
    assert available == 0, 'Time slot should be unavailable'
    
    return ()
end

@external
func test_booking_lifecycle() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let provider_registry_address = 0x456
    let payment_escrow_address = 0x789
    let analytics_registry_address = 0xabc
    
    let service_marketplace = await starknet.deploy(
        contract_class=ServiceMarketplace,
        constructor_calldata=[
            admin_address,
            provider_registry_address,
            payment_escrow_address,
            analytics_registry_address
        ]
    )
    
    # Test data
    let provider_address = 0x111
    let client_address = 0x222
    let token_address = 0x333
    let title = 123456789  # "Test Service" encoded as felt
    let description = 987654321  # "Description" encoded as felt
    let category_id = 1
    let price_low = 1000000000  # 10.00000000 (8 decimal places)
    let price_high = 0
    let duration = 3600  # 1 hour in seconds
    
    # Create a service
    let (service_id) = await service_marketplace.create_service(
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        caller_address=provider_address
    )
    
    # Set availability
    let start_time = 1672531200  # 2023-01-01 00:00:00 UTC
    await service_marketplace.set_availability(
        service_id,
        start_time,
        1,  # Available
        caller_address=provider_address
    )
    
    # Book the service
    let (booking_id) = await service_marketplace.book_service(
        service_id,
        start_time,
        token_address,
        caller_address=client_address
    )
    
    # Confirm the booking
    await service_marketplace.confirm_booking(
        booking_id,
        caller_address=provider_address
    )
    
    # Verify booking status is confirmed
    let (_, _, _, _, _, _, _, _, status, _, _) = await service_marketplace.get_booking(booking_id)
    assert status == 2, 'Booking should be confirmed'
    
    # Complete the booking
    await service_marketplace.complete_booking(
        booking_id,
        caller_address=provider_address
    )
    
    # Verify booking status is completed
    let (_, _, _, _, _, _, _, _, status2, _, _) = await service_marketplace.get_booking(booking_id)
    assert status2 == 3, 'Booking should be completed'
    
    return ()
end

@external
func test_booking_cancellation() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let provider_registry_address = 0x456
    let payment_escrow_address = 0x789
    let analytics_registry_address = 0xabc
    
    let service_marketplace = await starknet.deploy(
        contract_class=ServiceMarketplace,
        constructor_calldata=[
            admin_address,
            provider_registry_address,
            payment_escrow_address,
            analytics_registry_address
        ]
    )
    
    # Test data
    let provider_address = 0x111
    let client_address = 0x222
    let token_address = 0x333
    let title = 123456789  # "Test Service" encoded as felt
    let description = 987654321  # "Description" encoded as felt
    let category_id = 1
    let price_low = 1000000000  # 10.00000000 (8 decimal places)
    let price_high = 0
    let duration = 3600  # 1 hour in seconds
    
    # Create a service
    let (service_id) = await service_marketplace.create_service(
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        caller_address=provider_address
    )
    
    # Set availability
    let start_time = 1672531200  # 2023-01-01 00:00:00 UTC
    await service_marketplace.set_availability(
        service_id,
        start_time,
        1,  # Available
        caller_address=provider_address
    )
    
    # Book the service
    let (booking_id) = await service_marketplace.book_service(
        service_id,
        start_time,
        token_address,
        caller_address=client_address
    )
    
    # Cancel the booking by client
    await service_marketplace.cancel_booking(
        booking_id,
        caller_address=client_address
    )
    
    # Verify booking status is cancelled
    let (_, _, _, _, _, _, _, _, status, _, _) = await service_marketplace.get_booking(booking_id)
    assert status == 4, 'Booking should be cancelled'
    
    # Check availability is now marked as available again
    let (available) = await service_marketplace.check_availability(service_id, start_time)
    assert available == 1, 'Time slot should be available again'
    
    return ()
end

@external
func test_bulk_service_retrieval() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let provider_registry_address = 0x456
    let payment_escrow_address = 0x789
    let analytics_registry_address = 0xabc
    
    let service_marketplace = await starknet.deploy(
        contract_class=ServiceMarketplace,
        constructor_calldata=[
            admin_address,
            provider_registry_address,
            payment_escrow_address,
            analytics_registry_address
        ]
    )
    
    # Test data for multiple services
    let provider_address = 0x111
    let category_id = 1
    
    # Create multiple services
    let (service_id1) = await service_marketplace.create_service(
        111111,  # Title 1
        222222,  # Description 1
        category_id,
        1000000000,  # 10.00000000
        0,
        3600,
        caller_address=provider_address
    )
    
    let (service_id2) = await service_marketplace.create_service(
        333333,  # Title 2
        444444,  # Description 2
        category_id,
        2000000000,  # 20.00000000
        0,
        7200,
        caller_address=provider_address
    )
    
    let (service_id3) = await service_marketplace.create_service(
        555555,  # Title 3
        666666,  # Description 3
        category_id,
        3000000000,  # 30.00000000
        0,
        10800,
        caller_address=provider_address
    )
    
    # Get services by category
    let (service_count, service_ids) = await service_marketplace.get_services_by_category(category_id, 0, 10)
    
    # Verify we got all services
    assert service_count == 3, 'Wrong service count'
    assert service_ids[0] == service_id1, 'Wrong service ID 1'
    assert service_ids[1] == service_id2, 'Wrong service ID 2'
    assert service_ids[2] == service_id3, 'Wrong service ID 3'
    
    # Get services by provider
    let (provider_service_count, provider_service_ids) = await service_marketplace.get_services_by_provider(provider_address, 0, 10)
    
    # Verify we got all services
    assert provider_service_count == 3, 'Wrong provider service count'
    assert provider_service_ids[0] == service_id1, 'Wrong provider service ID 1'
    assert provider_service_ids[1] == service_id2, 'Wrong provider service ID 2'
    assert provider_service_ids[2] == service_id3, 'Wrong provider service ID 3'
    
    return ()
end

@external
func test_booking_history() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let provider_registry_address = 0x456
    let payment_escrow_address = 0x789
    let analytics_registry_address = 0xabc
    
    let service_marketplace = await starknet.deploy(
        contract_class=ServiceMarketplace,
        constructor_calldata=[
            admin_address,
            provider_registry_address,
            payment_escrow_address,
            analytics_registry_address
        ]
    )
    
    # Test data
    let provider_address = 0x111
    let client_address = 0x222
    let token_address = 0x333
    let title = 123456789  # "Test Service" encoded as felt
    let description = 987654321  # "Description" encoded as felt
    let category_id = 1
    let price_low = 1000000000  # 10.00000000 (8 decimal places)
    let price_high = 0
    let duration = 3600  # 1 hour in seconds
    
    # Create a service
    let (service_id) = await service_marketplace.create_service(
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        caller_address=provider_address
    )
    
    # Set availability for multiple time slots
    let start_time1 = 1672531200  # 2023-01-01 00:00:00 UTC
    let start_time2 = 1672534800  # 2023-01-01 01:00:00 UTC
    let start_time3 = 1672538400  # 2023-01-01 02:00:00 UTC
    
    await service_marketplace.set_availability(service_id, start_time1, 1, caller_address=provider_address)
    await service_marketplace.set_availability(service_id, start_time2, 1, caller_address=provider_address)
    await service_marketplace.set_availability(service_id, start_time3, 1, caller_address=provider_address)
    
    # Book multiple services
    let (booking_id1) = await service_marketplace.book_service(
        service_id,
        start_time1,
        token_address,
        caller_address=client_address
    )
    
    let (booking_id2) = await service_marketplace.book_service(
        service_id,
        start_time2,
        token_address,
        caller_address=client_address
    )
    
    let (booking_id3) = await service_marketplace.book_service(
        service_id,
        start_time3,
        token_address,
        caller_address=client_address
    )
    
    # Get client booking history
    let (client_booking_count, client_booking_ids) = await service_marketplace.get_client_bookings(client_address, 0, 10)
    
    # Verify client booking history
    assert client_booking_count == 3, 'Wrong client booking count'
    assert client_booking_ids[0] == booking_id1, 'Wrong client booking ID 1'
    assert client_booking_ids[1] == booking_id2, 'Wrong client booking ID 2'
    assert client_booking_ids[2] == booking_id3, 'Wrong client booking ID 3'
    
    # Get provider booking history
    let (provider_booking_count, provider_booking_ids) = await service_marketplace.get_provider_bookings(provider_address, 0, 10)
    
    # Verify provider booking history
    assert provider_booking_count == 3, 'Wrong provider booking count'
    assert provider_booking_ids[0] == booking_id1, 'Wrong provider booking ID 1'
    assert provider_booking_ids[1] == booking_id2, 'Wrong provider booking ID 2'
    assert provider_booking_ids[2] == booking_id3, 'Wrong provider booking ID 3'
    
    return ()
end

@external
func test_double_booking_prevention() -> ():
    # Deploy Starknet and contracts
    let starknet = Starknet.empty()
    let admin_address = 0x123
    let provider_registry_address = 0x456
    let payment_escrow_address = 0x789
    let analytics_registry_address = 0xabc
    
    let service_marketplace = await starknet.deploy(
        contract_class=ServiceMarketplace,
        constructor_calldata=[
            admin_address,
            provider_registry_address,
            payment_escrow_address,
            analytics_registry_address
        ]
    )
    
    # Test data
    let provider_address = 0x111
    let client_address1 = 0x222
    let client_address2 = 0x333
    let token_address = 0x444
    let title = 123456789  # "Test Service" encoded as felt
    let description = 987654321  # "Description" encoded as felt
    let category_id = 1
    let price_low = 1000000000  # 10.00000000 (8 decimal places)
    let price_high = 0
    let duration = 3600  # 1 hour in seconds
    
    # Create a service
    let (service_id) = await service_marketplace.create_service(
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        caller_address=provider_address
    )
    
    # Set availability
    let start_time = 1672531200  # 2023-01-01 00:00:00 UTC
    await service_marketplace.set_availability(
        service_id,
        start_time,
        1,  # Available
        caller_address=provider_address
    )
    
    # First client books the service
    let (booking_id1) = await service_marketplace.book_service(
        service_id,
        start_time,
        token_address,
        caller_address=client_address1
    )
    
    # Check availability is now marked as unavailable
    let (available) = await service_marketplace.check_availability(service_id, start_time)
    assert available == 0, 'Time slot should be unavailable'
    
    # Second client tries to book the same service at the same time
    # This should revert with 'Service not available at this time'
    let reverted = false
    try {
        let (_) = await service_marketplace.book_service(
            service_id,
            start_time,
            token_address,
            caller_address=client_address2
        )
    } catch {
        reverted = true
    }
    
    assert reverted, 'Double booking should be prevented'
    
    return ()
end