%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_nn_le, assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_add

from contracts.utils.interfaces import IModuleController
from contracts.utils.tokens_interfaces import IERC721Maps
from contracts.utils.general import felt_to_uint256

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
    with_attr error_message("Maps ERC721: caller is not the admin."):
        assert admin = caller
    end

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

@external
func transfer_batch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    nb : felt, token_id_len : felt, token_id : felt*, player_len : felt, player: felt*
):
    let (admin) = maps_erc721_admin.read()
    let (caller) = get_caller_address()
    with_attr error_message("Maps ERC721: caller is not the admin."):
        assert admin = caller
    end

    if nb == 0:
        return ()
    end

    let (maps_erc721_contract_addr) = maps_erc721_address.read()
    let (minter_address) = get_contract_address()

    let (token_id_uint) = felt_to_uint256(token_id[0])
    IERC721Maps.transferFrom(maps_erc721_contract_addr, minter_address, player[0], token_id_uint)

    transfer_batch(nb - 1, token_id_len - 1, token_id + 1, player_len - 1, player + 1)
    return ()
end

##################
# VIEW FUNCTIONS #
##################

@view
func get_maps_erc721_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (contract_address : felt):
    let (contract_address) = maps_erc721_address.read()

    return (contract_address)
end
