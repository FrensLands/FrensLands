%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_nn_le, assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_add

from contracts.utils.interfaces import IModuleController
from contracts.tokens.tokens_interfaces import IERC721Maps

###########
# STORAGE #
###########

# Stores the address of the Maps_ERC721 contract
@storage_var
func maps_erc721_address() -> (address : felt):
end

@storage_var
func maps_erc721_admin() -> (address : felt):
end

###############
# CONSTRUCTOR #
###############

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(admin : felt):
    maps_erc721_admin.write(admin)

    return ()
end

######################
# EXTERNAL FUNCTIONS #
######################

@external
func set_maps_erc721_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    contract_address : felt
):
    let (admin) = maps_erc721_admin.read()
    let (caller) = get_caller_address()
    assert admin = caller

    maps_erc721_address.write(contract_address)

    return ()
end

@external
func set_maps_erc721_approval{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    operator : felt, approved : felt
):
    let (admin) = maps_erc721_admin.read()
    let (caller) = get_caller_address()
    assert admin = caller

    let (maps_erc721_contract_addr) = maps_erc721_address.read()

    IERC721Maps.setApprovalForAll(maps_erc721_contract_addr, operator, approved)

    return ()
end

@external
func mint_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    nb : felt, token_id : Uint256
):
    let (admin) = maps_erc721_admin.read()
    let (caller) = get_caller_address()
    assert admin = caller

    if nb == 0:
        return ()
    end

    let (maps_erc721_contract_addr) = maps_erc721_address.read()
    let (minter_address) = get_contract_address()

    IERC721Maps.mint(maps_erc721_contract_addr, minter_address, token_id)

    let (next_id, _) = uint256_add(token_id, Uint256(1, 0))
    mint_all(nb - 1, next_id)
    return ()
end

# @external
# func set_token_uri_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     token_uri_len : felt, token_uri : felt*
# ):
#     let (admin) = maps_erc721_admin.read()
#     let (caller) = get_caller_address()
#     assert admin = caller

# _set_token_uri(token_uri_len, token_uri, Uint256(1, 0))

# return ()
# end

# func _set_token_uri{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     token_uri_len : felt, token_uri : felt*, id : Uint256
# ):
#     if token_uri_len == 0:
#         return ()
#     end

# let (maps_erc721_contract_addr) = maps_erc721_address.read()

# IERC721Maps.setTokenURI(maps_erc721_contract_addr, id, [token_uri])

# let (next_id, _) = uint256_add(id, Uint256(1, 0))

# _set_token_uri(token_uri_len - 1, token_uri - 1, next_id)

# return ()
# end

##################
# VIEW FUNCTIONS #
##################

@view
func get_maps_erc721_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (contract_address : felt):
    let (contract_address) = maps_erc721_address.read()

    return (contract_address)
end
