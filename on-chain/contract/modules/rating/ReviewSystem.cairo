%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from starkware.starknet.common.syscalls import emit_event

struct Review {
  user: felt,
  rating: felt,
  timestamp: felt,
  comment_hash: felt, // hash of the review text
  service_type: felt,
  verified: felt,
  flagged: felt,
}

@storage_var
func review(provider: felt, index: felt) -> Review:
end

@storage_var
func review_count(provider: felt) -> felt:
end

@storage_var
func rating_sum(provider: felt) -> felt:
end

@storage_var
func review_verified(user: felt, provider: felt) -> felt:
end

@storage_var
func review_window(user: felt, service_id: felt) -> felt:
end

@event
func ReviewSubmitted(provider: felt, user: felt, rating: felt, comment_hash: felt):
end

@event
func ReviewFlagged(provider: felt, user: felt, reason: felt):
end

@external
func submit_review{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}(
    provider: felt, rating: felt, comment_hash: felt, service_type: felt
):
    let (caller) = get_caller_address()
    let (now) = get_block_timestamp()

    let (window) = review_window.read(caller, service_type)
    assert now <= window

    let (verified) = review_verified.read(caller, provider)
    assert verified = 1

    assert rating >= 1
    assert rating <= 5

    let (index) = review_count.read(provider)
    review.write(provider, index, Review(caller, rating, now, comment_hash, service_type, 1, 0))

    let (current_sum) = rating_sum.read(provider)
    rating_sum.write(provider, current_sum + rating)

    review_count.write(provider, index + 1)

    emit_event ReviewSubmitted(provider, caller, rating, comment_hash)
    return ()
end

@view
func get_provider_reviews(provider: felt) -> (count: felt):
    let (count) = review_count.read(provider)
    return (count,)
end

@view
func get_average_rating(provider: felt) -> (average: felt):
    let (total) = rating_sum.read(provider)
    let (count) = review_count.read(provider)

    if count == 0 {
        return (average=0)
    }

    let avg = total / count
    return (average=avg)
end

@external
func flag_review{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*}(
    provider: felt, index: felt, reason: felt
):
    let (caller) = get_caller_address()
    let (review_struct) = review.read(provider, index)

    // Only admin or platform service can flag (in production)
    review.write(provider, index, Review(
        review_struct.user,
        review_struct.rating,
        review_struct.timestamp,
        review_struct.comment_hash,
        review_struct.service_type,
        review_struct.verified,
        1 // flagged
    ))

    emit_event ReviewFlagged(provider, review_struct.user, reason)
    return ()
end

@view
func verify_review_authenticity(user: felt, provider: felt) -> (auth: felt):
    let (auth) = review_verified.read(user, provider)
    return (auth,)
end
