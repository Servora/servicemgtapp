// SPDX-License-Identifier: MIT
// Core library for Service Management Application

use starknet::ContractAddress;
use array::ArrayTrait;
use option::OptionTrait;
use traits::Into;
use zeroable::Zeroable;

// Common error messages
mod errors {
    const UNAUTHORIZED: felt252 = 'Unauthorized caller';
    const INVALID_PARAMETER: felt252 = 'Invalid parameter';
    const NOT_FOUND: felt252 = 'Item not found';
    const ALREADY_EXISTS: felt252 = 'Item already exists';
    const EXPIRED: felt252 = 'Item expired';
    const REVOKED: felt252 = 'Item revoked';
    const INSUFFICIENT_FUNDS: felt252 = 'Insufficient funds';
}

// Common data structures
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Timestamp {
    created_at: u64,
    updated_at: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Rating {
    score: u8,
    count: u256,
    sum: u256,
}

// Common utility functions
fn calculate_average_rating(rating: Rating) -> u8 {
    if rating.count == 0.into() {
        return 0;
    }
    
    let avg: u256 = rating.sum / rating.count;
    avg.try_into().unwrap_or(5)
}

fn is_authorized(caller: ContractAddress, authorized_address: ContractAddress) -> bool {
    caller == authorized_address
}

fn is_valid_timestamp(expiry: u64, current: u64) -> bool {
    expiry > current
}

// Access control utilities
#[derive(Copy, Drop, Serde, starknet::Store)]
struct AccessControl {
    admin: ContractAddress,
    authorized_addresses: LegacyMap<ContractAddress, bool>,
}

trait AccessControlTrait {
    fn is_admin(self: @AccessControl, address: ContractAddress) -> bool;
    fn is_authorized(self: @AccessControl, address: ContractAddress) -> bool;
    fn add_authorized(ref self: AccessControl, address: ContractAddress);
    fn remove_authorized(ref self: AccessControl, address: ContractAddress);
}

impl AccessControlImpl of AccessControlTrait {
    fn is_admin(self: @AccessControl, address: ContractAddress) -> bool {
        *self.admin == address
    }
    
    fn is_authorized(self: @AccessControl, address: ContractAddress) -> bool {
        self.authorized_addresses.read(address) || self.is_admin(address)
    }
    
    fn add_authorized(ref self: AccessControl, address: ContractAddress) {
        self.authorized_addresses.write(address, true);
    }
    
    fn remove_authorized(ref self: AccessControl, address: ContractAddress) {
        self.authorized_addresses.write(address, false);
    }
}

// Pagination utilities
struct PaginationResult<T> {
    items: Array<T>,
    total: u32,
    page: u32,
    page_size: u32,
}

fn paginate<T, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(
    items: Array<T>, 
    page: u32, 
    page_size: u32
) -> PaginationResult<T> {
    let total = items.len();
    let start = (page - 1) * page_size;
    let end = if start + page_size > total {
        total
    } else {
        start + page_size
    };
    
    let mut result = ArrayTrait::new();
    let mut i = start;
    
    while i < end {
        if let Option::Some(item) = items.get(i) {
            result.append(*item);
        }
        i += 1;
    }
    
    PaginationResult {
        items: result,
        total: total,
        page: page,
        page_size: page_size
    }
}