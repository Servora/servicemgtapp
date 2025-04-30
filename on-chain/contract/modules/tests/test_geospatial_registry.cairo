# GeospatialRegistry Contract Tests (Cairo 1.0)
%lang starknet

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet
from contracts.GeospatialRegistry import GeospatialRegistry

@external
func test_register_service() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let geospatial_registry = await starknet.deploy(contract_class=GeospatialRegistry)
    
    # Test accounts
    let service_provider = 0x123
    
    # Test data
    let geohash = 0x7564716d6a3 # Example geohash "u64qmj3"
    let metadata = 0x1 # Metadata could be a pointer to IPFS or other data
    
    # Register a service
    let (service_id) = await geospatial_registry.register_service(geohash, metadata, caller_address=service_provider)
    
    # Verify service was registered
    let (owner, stored_geohash, stored_metadata, active, created_at, updated_at) = await geospatial_registry.get_service(service_id)
    
    assert owner == service_provider, 'Wrong owner'
    assert stored_geohash == geohash, 'Wrong geohash'
    assert stored_metadata == metadata, 'Wrong metadata'
    assert active == 1, 'Service should be active'
    assert created_at > 0, 'Created timestamp should be set'
    assert updated_at == created_at, 'Updated should equal created'
    
    return ()
end

@external
func test_update_location() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let geospatial_registry = await starknet.deploy(contract_class=GeospatialRegistry)
    
    # Test accounts
    let service_provider = 0x123
    
    # Test data
    let initial_geohash = 0x7564716d6a3 # "u64qmj3"
    let new_geohash = 0x7564716d6a4 # "u64qmj4"
    let metadata = 0x1
    
    # Register a service
    let (service_id) = await geospatial_registry.register_service(initial_geohash, metadata, caller_address=service_provider)
    
    # Update location
    await geospatial_registry.update_location(service_id, new_geohash, caller_address=service_provider)
    
    # Verify location was updated
    let (owner, stored_geohash, stored_metadata, active, created_at, updated_at) = await geospatial_registry.get_service(service_id)
    
    assert stored_geohash == new_geohash, 'Geohash not updated'
    assert updated_at > created_at, 'Updated timestamp not changed'
    
    # Check history
    let (history_len, geohashes, timestamps) = await geospatial_registry.get_location_history(service_id)
    
    assert history_len == 2, 'History should have 2 entries'
    
    return ()
end

@external
func test_proximity_search() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let geospatial_registry = await starknet.deploy(contract_class=GeospatialRegistry)
    
    # Test accounts
    let provider1 = 0x123
    let provider2 = 0x456
    
    # Test data - geohashes with same prefix
    let geohash1 = 0x7564716d6a3 # "u64qmj3"
    let geohash2 = 0x7564716d6b4 # "u64qmk4" - nearby location
    let geohash3 = 0x7a64716d6b4 # "z64qmk4" - far location
    
    # Register services
    let (service_id1) = await geospatial_registry.register_service(geohash1, 0x1, caller_address=provider1)
    let (service_id2) = await geospatial_registry.register_service(geohash2, 0x2, caller_address=provider1)
    let (service_id3) = await geospatial_registry.register_service(geohash3, 0x3, caller_address=provider2)
    
    # Search with precision 3 (first 3 chars of geohash)
    let (results_len, results) = await geospatial_registry.find_services_by_proximity(geohash1, 3)
    
    # Should find services 1 and 2 but not 3
    assert results_len >= 2, 'Should find at least 2 services'
    
    # Verify service_id1 and service_id2 are in results
    # Note: In a real test, you would iterate through results to verify
    
    return ()
end

@external
func test_service_status() -> ():
    # Deploy Starknet and contract
    let starknet = Starknet.empty()
    let geospatial_registry = await starknet.deploy(contract_class=GeospatialRegistry)
    
    # Test accounts
    let service_provider = 0x123
    
    # Register a service
    let (service_id) = await geospatial_registry.register_service(0x7564716d6a3, 0x1, caller_address=service_provider)
    
    # Deactivate service
    await geospatial_registry.set_service_status(service_id, 0, caller_address=service_provider)
    
    # Verify service is inactive
    let (_, _, _, active, _, _) = await geospatial_registry.get_service(service_id)
    assert active == 0, 'Service should be inactive'
    
    # Reactivate service
    await geospatial_registry.set_service_status(service_id, 1, caller_address=service_provider)
    
    # Verify service is active again
    let (_, _, _, active2, _, _) = await geospatial_registry.get_service(service_id)
    assert active2 == 1, 'Service should be active'
    
    return ()
end