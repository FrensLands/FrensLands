%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
    get_block_number,
)
from starkware.cairo.common.uint256 import Uint256, uint256_sub
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.math import assert_not_zero, assert_le, split_felt, assert_lt_felt

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds, MapsPrice
from contracts.utils.game_constants import GOLD_START, NUMBER_OF_BLOCKS, MAP_X_SIZE, TEST_BLOCKS

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20FrensCoin
from contracts.utils.interfaces import IModuleController, IM02Resources
from contracts.library.library_module import Module
from contracts.library.library_data import Data
from contracts.utils.bArray import bArray

###########
# STORAGE #
###########

@storage_var
func can_initialize_() -> (address : felt):
end

# state = 0 = game paused, state = 1 = ongoing game
@storage_var
func game_state_(token_id : Uint256) -> (state : felt):
end

# Number of on-going games
# @storage_var
# func nb_games_() -> (amount : felt):
# end

# Map information
@storage_var
func map_info_(token_id : Uint256, index : felt) -> (data : felt):
end

##########
# EVENTS #
##########

@event
func NewGame(owner : felt, token_id : Uint256):
end

@event
func EndGame(owner : felt, token_id : Uint256):
end

###############
# CONSTRUCTOR #
###############

@constructor
func constructor{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}():
    let (caller) = get_caller_address()
    can_initialize_.write(caller)

    return ()
end

@external
func initializer{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    address_of_controller : felt
):
    Module.initialize_controller(address_of_controller)
    return ()
end

######################
# EXTERNAL FUNCTIONS #
######################

# @notice Initialize maps info
# @param data array of 640 blocks
# @param index starts at 1
@external
func _initialize_maps{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, data_len : felt, data : felt*, index : felt
):
    # let (caller) = get_caller_address()
    # let (can_initialize) = can_initialize_.read()
    # assert caller = can_initialize

    if data_len == 0:
        return ()
    end

    map_info_.write(tokenId, index, data[0])

    return _initialize_maps(tokenId, data_len - 1, data + 1, index + 1)
end

# @notice Transfer available map to player
@external
func get_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(tokenId : Uint256):
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()

    # Fetch external contracts addresses
    let (minter_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.MinterMaps
    )
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )

    # TODO : Check user does not already have a map
    let (balance : Uint256) = IERC721Maps.balanceOf(maps_erc721_addr, caller)
    with_attr error_message("M01_Worlds: caller has already minted a map."):
        assert balance = Uint256(0, 0)
    end

    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: this map is not available."):
        assert owner = minter_addr
    end

    IERC721Maps.transferFrom(maps_erc721_addr, minter_addr, caller, tokenId)

    return ()
end

@external
func start_game{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    let (m01_contract) = get_contract_address()

    # Add check que le game n'a pas déjà été commencé

    # Fetch external contracts addresses
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )
    let (gold_erc20_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Gold
    )
    # Check caller is owner of tokenId
    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert owner = caller
    end

    # TODO : update resources as buildings in M03_Buildings

    # Save block number of gameStart
    let (block_number) = get_block_number()
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    IM02Resources.update_block_number(m02_addr, tokenId, block_number)

    IM02Resources.update_population(m02_addr, tokenId, 3, 1)

    game_state_.write(tokenId, 1)

    # Emit NewGame event
    NewGame.emit(caller, tokenId)

    return ()
end

@external
func pause_game{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()

    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )
    # Check caller is owner of tokenId
    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert owner = caller
    end

    # TODO : check if you still need to pay or harvest resources

    # Update block_number
    let (block_number) = get_block_number()
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    IM02Resources.update_block_number(m02_addr, tokenId, block_number)

    # Pause game
    game_state_.write(tokenId, 0)

    return ()
end

# TODO: save map
func save_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    # Checks ?
    # Needs to setApproval before saving_map
    # Call _pause_game(tokenId)
    # Fetch data needed for MapsERC721 new mint
    # Mint new Map with new updated_data ?
    return ()
end

# Function to reinitialize map ?
func reinitialize_world{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    # Regen maps resources by blocks
    # Burn resources, and tokens left and restart from scratch
    # Need setApprovalForAll before
    return ()
end

# @notice checks if player can build a building
# @param building_size : 1, 2 or 4 blocks
# @param pos_start first block on the bottom left
# @param building_type_id
# @param building_unique_id
@external
func _check_can_build{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, building_size : felt, pos_start : felt
) -> (bool : felt):
    alloc_locals

    # Decompose first position
    let (local too_big_1) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_1 == 0:
        return (0)
    end
    let (local first_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info_.read(tokenId, pos_start)
    Data._decompose(bArr, 16, comp, first_block, 0, 0, 0)

    local index_1 = (first_block[5] * 10) + first_block[6]

    let (local available) = is_not_zero(index_1)
    if available == 1:
        return (0)
    end

    if building_size == 1:
        return (1)
    end

    # Decompose 2nd position
    let (local too_big_2) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_2 == 0:
        return (0)
    end

    # Check que ce n'est pas hors map sur Axe X ?

    let (local second_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info_.read(tokenId, pos_start + 1)
    Data._decompose(bArr, 16, comp, second_block, 0, 0, 0)

    local index_2 = (second_block[5] * 10) + second_block[6]

    let (local available) = is_not_zero(index_2)
    if available == 1:
        return (0)
    end

    if building_size == 2:
        # TODO : write sur le block
        # second_block
        return (1)
    end

    # Decompose 3nd and 4th position
    let (local too_big_3) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_3 == 0:
        return (0)
    end

    let (local too_big_4) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_4 == 0:
        return (0)
    end

    let (local third_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info_.read(tokenId, pos_start + MAP_X_SIZE)
    Data._decompose(bArr, 16, comp, third_block, 0, 0, 0)

    local index_3 = (third_block[5] * 10) + third_block[6]

    let (local available) = is_not_zero(index_3)
    if available == 1:
        return (0)
    end

    let (local fourth_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info_.read(tokenId, pos_start + MAP_X_SIZE + 1)
    Data._decompose(bArr, 16, comp, fourth_block, 0, 0, 0)

    local index_4 = (fourth_block[5] * 10) + fourth_block[6]

    let (local available) = is_not_zero(index_4)
    if available == 1:
        return (0)
    end

    return (1)
end

##################
# VIEW FUNCTIONS #
##################

# @notice get game status
# @dev Returns 0 if game paused, 1 if ongoing game
@view
func get_game_status{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (state : felt):
    let (state) = game_state_.read(tokenId)
    return (state)
end

# @notice get map array will the blocks data
@view
func get_map_array{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (data_len : felt, data : felt*):
    alloc_locals
    let (local data : felt*) = alloc()

    _get_map_array_iter(tokenId, data, 1)

    return (NUMBER_OF_BLOCKS, data)
end

func _get_map_array_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, data : felt*, index : felt
):
    alloc_locals
    let (local value) = map_info_.read(tokenId, index)
    data[0] = value

    if index == NUMBER_OF_BLOCKS:
        return ()
    end

    return _get_map_array_iter(tokenId, data + 1, index + 1)
end

######################
# INTERNAL FUNCTIONS #
######################

# TODO: Add function to update maps blocks

# @notice fill map array
# @param index need to start at index at 1
func _fill_map_array{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, data_len : felt, data : felt*, index : felt
) -> ():
    if data_len == 0:
        return ()
    end

    map_info_.write(tokenId, index, data[0])

    _fill_map_array(tokenId, data_len - 1, data + 1, index + 1)

    return ()
end

func felt_to_uint256{range_check_ptr}(x) -> (uint_x : Uint256):
    let (high, low) = split_felt(x)
    return (Uint256(low=low, high=high))
end

func uint256_to_felt{range_check_ptr}(value : Uint256) -> (value : felt):
    assert_lt_felt(value.high, 2 ** 123)
    return (value.high * (2 ** 128) + value.low)
end

# @notice Checks write-permission of the calling contract.
func _only_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    # Get the address of the module trying to write to this contract.
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    let (bool) = IModuleController.has_write_access(
        contract_address=controller, address_attempting_to_write=caller
    )
    assert_not_zero(bool)
    return ()
end
