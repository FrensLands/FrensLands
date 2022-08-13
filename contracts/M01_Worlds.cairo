%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
    get_block_number,
)
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.math import assert_not_zero, assert_le, split_felt, assert_lt_felt

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds, MapsPrice
from contracts.utils.game_constants import GOLD_START, NUMBER_OF_BLOCKS, MAP_X_SIZE

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20FrensCoin
from contracts.utils.interfaces import IModuleController, IM02Resources, IM03Buildings
from contracts.library.library_module import Module
from contracts.library.library_data import Data
from contracts.MapSeeder import MapSeeder
from contracts.utils.bArray import bArray

###########
# STORAGE #
###########

@storage_var
func can_initialize_() -> (address : felt):
end

@storage_var
func supply_index() -> (last_id : Uint256):
end

# state = 0 = game paused, state = 1 = ongoing game
@storage_var
func game_state_(token_id : Uint256) -> (state : felt):
end

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

# @notice Transfer available map to player
@external
func get_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}():
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    # Fetch external contracts addresses
    let (minter_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.MinterMaps
    )
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )

    # Check user does not already have a map
    let (balance : Uint256) = IERC721Maps.balanceOf(maps_erc721_addr, caller)
    with_attr error_message("M01_Worlds: caller has already minted a map."):
        assert balance = Uint256(0, 0)
    end

    let (local last_tokenId : Uint256) = supply_index.read()
    let (tokenId, _) = uint256_add(last_tokenId, Uint256(1, 0))
    supply_index.write(tokenId)

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
    alloc_locals
    
    let (m01_contract) = get_contract_address()
    let (controller) = Module.get_controller()
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )

    let (game_status) = game_state_.read(tokenId)
    assert game_status = 0

    # Check caller is owner of tokenId
    let (local caller) = get_caller_address()
    let (local owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert owner = caller
    end

    let (local unique_id_count) = _initialize_maps(tokenId, 1, 1, 1, 0, 0, 0, 2)

    let (local block_number) = get_block_number()
    let (local m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    let (local m03_addr) = IModuleController.get_module_address(controller, ModuleIds.M03_Buildings)

    IM03Buildings.initialize_resources(m03_addr, tokenId, block_number, unique_id_count)
    IM02Resources.update_block_number(m02_addr, tokenId, block_number)
    IM02Resources.update_population(m02_addr, tokenId, 3, 1)
    IM02Resources._receive_resources_start(m02_addr, tokenId, caller)
    # Ajouter des conditions dans cette boucle ? pour reinitialize + start game ?

    game_state_.write(tokenId, 1)

    # Emit NewGame event
    NewGame.emit(caller, tokenId)

    return ()
end

# index : 1 à 640
# _x : 1 à 40
# -y : 1 à 16
# counter trees
# position cabin
func _initialize_maps{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    _x : felt,
    _y : felt,
    index : felt,
    counter_tree : felt,
    counter_rocks : felt,
    counter_mines : felt,
    building_unique_id : felt,
) -> (building_unique_id : felt):
    alloc_locals
    if index == NUMBER_OF_BLOCKS + 1:
        return (building_unique_id)
    end

    if index == 300:
        local building_type_id = 1
        local comp = (100000000000000 * _x) + (1000000000000 * _y) + (100000000000 * 1) + (1000000000 * building_type_id) + (1000000 * 1) + (100000 * 8) + (10000 * 8) + (100 * 0) + (10 * 1) + 1
        map_info_.write(tokenId, index, comp)
        # Write dans buildings
        if _x == MAP_X_SIZE:
            return _initialize_maps(
                tokenId,
                1,
                _y + 1,
                index + 1,
                counter_tree,
                counter_rocks,
                counter_mines,
                building_unique_id + 1,
            )
        else:
            return _initialize_maps(
                tokenId,
                _x + 1,
                _y,
                index + 1,
                counter_tree,
                counter_rocks,
                counter_mines,
                building_unique_id + 1,
            )
        end
    end

    let (is_tree) = MapSeeder.get_tree(counter_tree)
    if is_tree == index:
        local building_type_id = 3
        local comp = (100000000000000 * _x) + (1000000000000 * _y) + (100000000000 * 1) + (1000000000 * building_type_id) + (1000000 * building_unique_id) + (100000 * 8) + (10000 * 8) + (100 * 0) + (10 * 1) + 1
        map_info_.write(tokenId, index, comp)
        if _x == MAP_X_SIZE:
            return _initialize_maps(
                tokenId,
                1,
                _y + 1,
                index + 1,
                counter_tree + 1,
                counter_rocks,
                counter_mines,
                building_unique_id + 1,
            )
        else:
            return _initialize_maps(
                tokenId,
                _x + 1,
                _y,
                index + 1,
                counter_tree + 1,
                counter_rocks,
                counter_mines,
                building_unique_id + 1,
            )
        end
    end

    let (is_rocks) = MapSeeder.get_rocks(counter_rocks)
    if is_rocks == index:
        local building_type_id = 2
        local comp = (100000000000000 * _x) + (1000000000000 * _y) + (100000000000 * 1) + (1000000000 * building_type_id) + (1000000 * building_unique_id) + (100000 * 8) + (10000 * 8) + (100 * 0) + (10 * 1) + 1
        map_info_.write(tokenId, index, comp)
        if _x == MAP_X_SIZE:
            return _initialize_maps(
                tokenId,
                1,
                _y + 1,
                index + 1,
                counter_tree,
                counter_rocks + 1,
                counter_mines,
                building_unique_id + 1,
            )
        else:
            return _initialize_maps(
                tokenId,
                _x + 1,
                _y,
                index + 1,
                counter_tree,
                counter_rocks + 1,
                counter_mines,
                building_unique_id + 1,
            )
        end
    end

    let (is_mine) = MapSeeder.get_mines(counter_mines)
    if is_mine == index:
        local building_type_id = 20
        local comp = (100000000000000 * _x) + (1000000000000 * _y) + (100000000000 * 1) + (1000000000 * building_type_id) + (1000000 * building_unique_id) + (100000 * 8) + (10000 * 8) + (100 * 0) + (10 * 1) + 1
        map_info_.write(tokenId, index, comp)
        if _x == MAP_X_SIZE:
            return _initialize_maps(
                tokenId,
                1,
                _y + 1,
                index + 1,
                counter_tree,
                counter_rocks,
                counter_mines + 1,
                building_unique_id + 1,
            )
        else:
            return _initialize_maps(
                tokenId,
                _x + 1,
                _y,
                index + 1,
                counter_tree,
                counter_rocks,
                counter_mines + 1,
                building_unique_id + 1,
            )
        end
    end

    local comp = (100000000000000 * _x) + (1000000000000 * _y) + (100000000000 * 1) + (1000000000 * 0) + (1000000 * 0) + (100000 * 8) + (10000 * 8) + (100 * 0) + (10 * 1) + 1
    map_info_.write(tokenId, index, comp)
    if _x == MAP_X_SIZE:
        return _initialize_maps(
            tokenId,
            1,
            _y + 1,
            index + 1,
            counter_tree,
            counter_rocks,
            counter_mines,
            building_unique_id,
        )
    else:
        return _initialize_maps(
            tokenId,
            _x + 1,
            _y,
            index + 1,
            counter_tree,
            counter_rocks,
            counter_mines,
            building_unique_id,
        )
    end
end

@external
func reinitialize_game{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    alloc_locals
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    let (m01_contract) = get_contract_address()
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )

    # Check caller is owner of tokenId
    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert owner = caller
    end
    
    # Save block number of reinitialize
    let (block_number) = get_block_number()
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    IM02Resources.update_block_number(m02_addr, tokenId, block_number)
    IM02Resources.update_population(m02_addr, tokenId, 5, 1)
    IM02Resources._reinitialize_resources(m02_addr, tokenId, caller)

    let (m03_addr) = IModuleController.get_module_address(controller, ModuleIds.M03_Buildings)
    IM03Buildings._reinitialize_buildings(m03_addr, tokenId, caller)

    let (local unique_id_count) = _initialize_maps(tokenId, 1, 1, 1, 0, 0, 0, 2)
    IM03Buildings.initialize_resources(m03_addr, tokenId, block_number, unique_id_count)
    game_state_.write(tokenId, 0)

    # Emit NewGame event
    NewGame.emit(caller, tokenId)

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

@external
func update_map_block{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, index : felt, data : felt
) -> ():
    alloc_locals
    Module.only_approved()
    map_info_.write(tokenId, index, data)
    return ()
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

@view
func get_map_block{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, index : felt
) -> (data : felt):
    let (data) = map_info_.read(tokenId, index)
    return (data)
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
