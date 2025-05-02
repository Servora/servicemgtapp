%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp

# Service status constants
const SERVICE_STATUS_INACTIVE = 0
const SERVICE_STATUS_ACTIVE = 1
const SERVICE_STATUS_PAUSED = 2

# Booking status constants
const BOOKING_STATUS_PENDING = 1
const BOOKING_STATUS_CONFIRMED = 2
const BOOKING_STATUS_COMPLETED = 3
const BOOKING_STATUS_CANCELLED = 4
const BOOKING_STATUS_DISPUTED = 5

# Availability constants
const AVAILABILITY_UNAVAILABLE = 0
const AVAILABILITY_AVAILABLE = 1

# Storage variables
@storage_var
func admin() -> (address: felt252) {}

@storage_var
func provider_registry_address() -> (address: felt252) {}

@storage_var
func payment_escrow_address() -> (address: felt252) {}

@storage_var
func analytics_registry_address() -> (address: felt252) {}

@storage_var
func next_service_id() -> (id: felt252) {}

@storage_var
func next_booking_id() -> (id: felt252) {}

# Service storage
@storage_var
func services(service_id: felt252) -> (
    provider: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252,
    status: felt252,
    created_at: felt252,
    updated_at: felt252
) {}

@storage_var
func service_availability(service_id: felt252, start_time: felt252) -> (available: felt252) {}

@storage_var
func category_services(category_id: felt252, index: felt252) -> (service_id: felt252) {}

@storage_var
func category_service_count(category_id: felt252) -> (count: felt252) {}

@storage_var
func provider_services(provider: felt252, index: felt252) -> (service_id: felt252) {}

@storage_var
func provider_service_count(provider: felt252) -> (count: felt252) {}

# Booking storage
@storage_var
func bookings(booking_id: felt252) -> (
    service_id: felt252,
    client: felt252,
    provider: felt252,
    start_time: felt252,
    end_time: felt252,
    price_low: felt252,
    price_high: felt252,
    payment_id: felt252,
    status: felt252,
    created_at: felt252,
    updated_at: felt252
) {}

@storage_var
func client_bookings(client: felt252, index: felt252) -> (booking_id: felt252) {}

@storage_var
func client_booking_count(client: felt252) -> (count: felt252) {}

@storage_var
func provider_bookings(provider: felt252, index: felt252) -> (booking_id: felt252) {}

@storage_var
func provider_booking_count(provider: felt252) -> (count: felt252) {}

@storage_var
func service_bookings(service_id: felt252, index: felt252) -> (booking_id: felt252) {}

@storage_var
func service_booking_count(service_id: felt252) -> (count: felt252) {}

# Constructor
@constructor
func constructor{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    admin_address: felt252,
    provider_registry: felt252,
    payment_escrow: felt252,
    analytics_registry: felt252
) {
    admin.write(admin_address);
    provider_registry_address.write(provider_registry);
    payment_escrow_address.write(payment_escrow);
    analytics_registry_address.write(analytics_registry);
    next_service_id.write(1);
    next_booking_id.write(1);
    return ();
}

# Access control
func _only_admin{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller) = get_caller_address();
    let (admin_address) = admin.read();
    assert caller = admin_address;
    return ();
}

func _only_service_provider{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(service_id: felt252) {
    let (caller) = get_caller_address();
    let (provider, _, _, _, _, _, _, _, _, _) = services.read(service_id);
    assert caller = provider;
    return ();
}

func _only_booking_provider{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(booking_id: felt252) {
    let (caller) = get_caller_address();
    let (_, _, provider, _, _, _, _, _, _, _, _) = bookings.read(booking_id);
    assert caller = provider;
    return ();
}

func _only_booking_client{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(booking_id: felt252) {
    let (caller) = get_caller_address();
    let (_, client, _, _, _, _, _, _, _, _, _) = bookings.read(booking_id);
    assert caller = client;
    return ();
}

# Service management functions
@external
func create_service{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252
) -> (service_id: felt252) {
    let (caller) = get_caller_address();
    let (current_time) = get_block_timestamp();
    let (service_id) = next_service_id.read();
    
    # Store service details
    services.write(
        service_id,
        caller,
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        SERVICE_STATUS_ACTIVE,
        current_time,
        current_time
    );
    
    # Update category services
    let (category_count) = category_service_count.read(category_id);
    category_services.write(category_id, category_count, service_id);
    category_service_count.write(category_id, category_count + 1);
    
    # Update provider services
    let (provider_count) = provider_service_count.read(caller);
    provider_services.write(caller, provider_count, service_id);
    provider_service_count.write(caller, provider_count + 1);
    
    # Increment service ID
    next_service_id.write(service_id + 1);
    
    return (service_id);
}

@external
func update_service{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    service_id: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252
) {
    _only_service_provider(service_id);
    
    let (provider, _, _, old_category_id, _, _, _, status, created_at, _) = services.read(service_id);
    let (current_time) = get_block_timestamp();
    
    # Update service details
    services.write(
        service_id,
        provider,
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        status,
        created_at,
        current_time
    );
    
    # If category changed, update category mappings
    if (old_category_id != category_id) {
        # This is a simplified implementation
        # In a real contract, we would need to remove from old category and add to new
    }
    
    return ();
}

@external
func set_service_status{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    service_id: felt252,
    status: felt252
) {
    _only_service_provider(service_id);
    
    let (provider, title, description, category_id, price_low, price_high, duration, _, created_at, _) = services.read(service_id);
    let (current_time) = get_block_timestamp();
    
    # Update service status
    services.write(
        service_id,
        provider,
        title,
        description,
        category_id,
        price_low,
        price_high,
        duration,
        status,
        created_at,
        current_time
    );
    
    return ();
}

@external
func set_availability{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    service_id: felt252,
    start_time: felt252,
    available: felt252
) {
    _only_service_provider(service_id);
    
    # Set availability for the time slot
    service_availability.write(service_id, start_time, available);
    
    return ();
}

@external
func check_availability{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    service_id: felt252,
    start_time: felt252
) -> (available: felt252) {
    let (available) = service_availability.read(service_id, start_time);
    return (available);
}

# Booking functions
@external
func book_service{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    service_id: felt252,
    start_time: felt252,
    token_address: felt252
) -> (booking_id: felt252) {
    let (caller) = get_caller_address();
    let (current_time) = get_block_timestamp();
    
    # Check service exists and is active
    let (provider, _, _, _, price_low, price_high, duration, status, _, _) = services.read(service_id);
    assert status = SERVICE_STATUS_ACTIVE;
    
    # Check availability
    let (available) = service_availability.read(service_id, start_time);
    assert available = AVAILABILITY_AVAILABLE;
    
    # Create booking
    let (booking_id) = next_booking_id.read();
    let end_time = start_time + duration;
    
    # For simplicity, payment_id is set to 0 here
    # In a real implementation, we would integrate with the payment contract
    let payment_id = 0;
    
    bookings.write(
        booking_id,
        service_id,
        caller,
        provider,
        start_time,
        end_time,
        price_low,
        price_high,
        payment_id,
        BOOKING_STATUS_PENDING,
        current_time,
        current_time
    );
    
    # Update client bookings
    let (client_count) = client_booking_count.read(caller);
    client_bookings.write(caller, client_count, booking_id);
    client_booking_count.write(caller, client_count + 1);
    
    # Update provider bookings
    let (provider_count) = provider_booking_count.read(provider);
    provider_bookings.write(provider, provider_count, booking_id);
    provider_booking_count.write(provider, provider_count + 1);
    
    # Update service bookings
    let (service_count) = service_booking_count.read(service_id);
    service_bookings.write(service_id, service_count, booking_id);
    service_booking_count.write(service_id, service_count + 1);
    
    # Mark time slot as unavailable
    service_availability.write(service_id, start_time, AVAILABILITY_UNAVAILABLE);
    
    # Increment booking ID
    next_booking_id.write(booking_id + 1);
    
    return (booking_id);
}

@external
func confirm_booking{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    booking_id: felt252
) {
    _only_booking_provider(booking_id);
    
    let (service_id, client, provider, start_time, end_time, price_low, price_high, payment_id, status, created_at, _) = bookings.read(booking_id);
    assert status = BOOKING_STATUS_PENDING;
    
    let (current_time) = get_block_timestamp();
    
    # Update booking status
    bookings.write(
        booking_id,
        service_id,
        client,
        provider,
        start_time,
        end_time,
        price_low,
        price_high,
        payment_id,
        BOOKING_STATUS_CONFIRMED,
        created_at,
        current_time
    );
    
    return ();
}

@external
func complete_booking{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    booking_id: felt252
) {
    _only_booking_provider(booking_id);
    
    let (service_id, client, provider, start_time, end_time, price_low, price_high, payment_id, status, created_at, _) = bookings.read(booking_id);
    assert status = BOOKING_STATUS_CONFIRMED;
    
    let (current_time) = get_block_timestamp();
    
    # Update booking status
    bookings.write(
        booking_id,
        service_id,
        client,
        provider,
        start_time,
        end_time,
        price_low,
        price_high,
        payment_id,
        BOOKING_STATUS_COMPLETED,
        created_at,
        current_time
    );
    
    # In a real implementation, we would release payment to provider here
    
    return ();
}

@external
func cancel_booking{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    booking_id: felt252
) {
    # Allow either client or provider to cancel
    let (caller) = get_caller_address();
    let (service_id, client, provider, start_time, end_time, price_low, price_high, payment_id, status, created_at, _) = bookings.read(booking_id);
    
    # Only pending or confirmed bookings can be cancelled
    assert (status = BOOKING_STATUS_PENDING) | (status = BOOKING_STATUS_CONFIRMED);
    
    # Verify caller is either client or provider
    assert (caller = client) | (caller = provider);
    
    let (current_time) = get_block_timestamp();
    
    # Update booking status
    bookings.write(
        booking_id,
        service_id,
        client,
        provider,
        start_time,
        end_time,
        price_low,
        price_high,
        payment_id,
        BOOKING_STATUS_CANCELLED,
        created_at,
        current_time
    );
    
    # Make time slot available again
    service_availability.write(service_id, start_time, AVAILABILITY_AVAILABLE);
    
    # In a real implementation, we would handle refunds here
    
    return ();
}

# Query functions
@view
func get_service{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    service_id: felt252
) -> (
    provider: felt252,
    title: felt252,
    description: felt252,
    category_id: felt252,
    price_low: felt252,
    price_high: felt252,
    duration: felt252,
    status: felt252,
    created_at: felt252,
    updated_at: felt252
) {
    let (provider, title, description, category_id, price_low, price_high, duration, status, created_at, updated_at) = services.read(service_id);
    return (provider, title, description, category_id, price_low, price_high, duration, status, created_at, updated_at);
}

@view
func get_booking{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    booking_id: felt252
) -> (
    service_id: felt252,
    client: felt252,
    provider: felt252,
    start_time: felt252,
    end_time: felt252,
    price_low: felt252,
    price_high: felt252,
    payment_id: felt252,
    status: felt252,
    created_at: felt252,
    updated_at: felt252
) {
    let (service_id, client, provider, start_time, end_time, price_low, price_high, payment_id, status, created_at, updated_at) = bookings.read(booking_id);
    return (service_id, client, provider, start_time, end_time, price_low, price_high, payment_id, status, created_at, updated_at);
}

@view
func get_services_by_category{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    category_id: felt252,
    offset: felt252,
    limit: felt252
) -> (count: felt252, service_ids_len: felt252, service_ids: felt252*) {
    alloc_locals;
    
    let (total_count) = category_service_count.read(category_id);
    
    # Calculate actual count to return based on offset, limit and total count
    let end = offset + limit;
    let actual_end = min(end, total_count);
    let actual_count = actual_end - offset;
    
    # Allocate array for service IDs
    let (local service_ids: felt252*) = alloc();
    
    # Fill array with service IDs
    _get_services_by_category_recursive(category_id, offset, actual_count, 0, service_ids);
    
    return (total_count, actual_count, service_ids);
}

func _get_services_by_category_recursive{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    category_id: felt252,
    offset: felt252,
    count: felt252,
    index: felt252,
    service_ids: felt252*
) {
    if (index == count) {
        return ();
    }
    
    let (service_id) = category_services.read(category_id, offset + index);
    assert service_ids[index] = service_id;
    
    _get_services_by_category_recursive(category_id, offset, count, index + 1, service_ids);
    return ();
}

@view
func get_services_by_provider{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    provider: felt252,
    offset: felt252,
    limit: felt252
) -> (count: felt252, service_ids_len: felt252, service_ids: felt252*) {
    alloc_locals;
    
    let (total_count) = provider_service_count.read(provider);
    
    # Calculate actual count to return based on offset, limit and total count
    let end = offset + limit;
    let actual_end = min(end, total_count);
    let actual_count = actual_end - offset;
    
    # Allocate array for service IDs
    let (local service_ids: felt252*) = alloc();
    
    # Fill array with service IDs
    _get_services_by_provider_recursive(provider, offset, actual_count, 0, service_ids);
    
    return (total_count, actual_count, service_ids);
}

func _get_services_by_provider_recursive{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    provider: felt252,
    offset: felt252,
    count: felt252,
    index: felt252,
    service_ids: felt252*
) {
    if (index == count) {
        return ();
    }
    
    let (service_id) = provider_services.read(provider, offset + index);
    assert service_ids[index] = service_id;
    
    _get_services_by_provider_recursive(provider, offset, count, index + 1, service_ids);
    return ();
}

@view
func get_client_bookings{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    client: felt252,
    offset: felt252,
    limit: felt252
) -> (count: felt252, booking_ids_len: felt252, booking_ids: felt252*) {
    alloc_locals;
    
    let (total_count) = client_booking_count.read(client);
    
    # Calculate actual count to return based on offset, limit and total count
    let end = offset + limit;
    let actual_end = min(end, total_count);
    let actual_count = actual_end - offset;
    
    # Allocate array for booking IDs
    let (local booking_ids: felt252*) = alloc();
    
    # Fill array with booking IDs
    _get_client_bookings_recursive(client, offset, actual_count, 0, booking_ids);
    
    return (total_count, actual_count, booking_ids);
}

func _get_client_bookings_recursive{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    client: felt252,
    offset: felt252,
    count: felt252,
    index: felt252,
    booking_ids: felt252*
) {
    if (index == count) {
        return ();
    }
    
    let (booking_id) = client_bookings.read(client, offset + index);
    assert booking_ids[index] = booking_id;
    
    _get_client_bookings_recursive(client, offset, count, index + 1, booking_ids);
    return ();
}

@view
func get_provider_bookings{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    provider: felt252,
    offset: felt252,
    limit: felt252
) -> (count: felt252, booking_ids_len: felt252, booking_ids: felt252*) {
    alloc_locals;
    
    let (total_count) = provider_booking_count.read(provider);
    
    # Calculate actual count to return based on offset, limit and total count
    let end = offset + limit;
    let actual_end = min(end, total_count);
    let actual_count = actual_end - offset;
    
    # Allocate array for booking IDs
    let (local booking_ids: felt252*) = alloc();
    
    # Fill array with booking IDs
    _get_provider_bookings_recursive(provider, offset, actual_count, 0, booking_ids);
    
    return (total_count, actual_count, booking_ids);
}

func _get_provider_bookings_recursive{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    provider: felt252,
    offset: felt252,
    count: felt252,
    index: felt252,
    booking_ids: felt252*
) {
    if (index == count) {
        return ();
    }
    
    let (booking_id) = provider_bookings.read(provider, offset + index);
    assert booking_ids[index] = booking_id;
    
    _get_provider_bookings_recursive(provider, offset, count, index + 1, booking_ids);
    return ();
}

# Helper functions
func min{syscall_ptr: felt252*, pedersen_ptr: HashBuiltin*, range_check_ptr}(a: felt252, b: felt252) -> felt252 {
    if (a <= b) {
        return a;
    } else {
        return b;
    }
}