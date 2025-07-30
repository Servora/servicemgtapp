%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.starknet.common.syscalls import emit_event

@storage_var
func role_admin(role: felt) -> felt:
end

@storage_var
func has_role(account: felt, role: felt) -> felt:
end

@storage_var
func security_policy(policy_id: felt) -> felt:
end

@storage_var
func is_paused() -> felt:
end

@storage_var
func last_call(account: felt, function_selector: felt) -> felt:
end

@event
func RoleGranted(role: felt, account: felt, sender: felt):
end

@event
func RoleRevoked(role: felt, account: felt, sender: felt):
end

@event
func EmergencyPaused(sender: felt):
end

@event
func SecurityPolicyUpdated(policy_id: felt, value: felt, sender: felt):
end

@external
func grant_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}(role: felt, account: felt):
    let (caller) = get_caller_address()
    let (admin) = role_admin.read(role)
    assert caller = admin

    has_role.write(account, role, 1)
    emit_event RoleGranted(role, account, caller)
    return ()
end

@external
func revoke_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}(role: felt, account: felt):
    let (caller) = get_caller_address()
    let (admin) = role_admin.read(role)
    assert caller = admin

    has_role.write(account, role, 0)
    emit_event RoleRevoked(role, account, caller)
    return ()
end

@view
func check_permission(account: felt, role: felt) -> (granted: felt):
    let (has) = has_role.read(account, role)
    return (granted=has)
end

@external
func update_security_policy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}(policy_id: felt, value: felt):
    let (caller) = get_caller_address()
    # Require ROLE_ADMIN or multisig approval in future upgrade
    security_policy.write(policy_id, value)
    emit_event SecurityPolicyUpdated(policy_id, value, caller)
    return ()
end

@external
func emergency_pause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}():
    let (caller) = get_caller_address()
    # Require multisig (for now, simulate single check)
    is_paused.write(1)
    emit_event EmergencyPaused(caller)
    return ()
end

@view
func is_authorized{syscall_ptr: felt*}(caller: felt, role: felt) -> (allowed: felt):
    let (has) = has_role.read(caller, role)
    return (allowed=has)
end

@external
func rate_limited_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}(function_selector: felt):
    let (caller) = get_caller_address()
    let (now) = get_block_timestamp()
    let (last) = last_call.read(caller, function_selector)

    if now - last < 60 {
        with_attr error:
            tempvar _ = 0
    }

    last_call.write(caller, function_selector, now)
    return ()
end
