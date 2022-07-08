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
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le, is_le
from starkware.cairo.common.math import assert_le, assert_not_zero, split_felt, assert_lt_felt
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.utils.game_structs import (
    ModuleIds,
    ExternalContractsIds,
    BuildingFixedData,
    SingleResource,
    MultipleResources,
    BuildingData,
)
from contracts.utils.game_constants import GOLD_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20FrensCoin, IERC1155
from contracts.utils.interfaces import IModuleController, IM01Worlds, IM02Resources
from contracts.utils.bArray import bArray
from contracts.library.library_module import Module
from contracts.library.library_data import Data

###########
# STORAGE #
###########

@storage_var
func can_initialize_() -> (address : felt):
end

# Fixed data of building
@storage_var
func building_global_data(type : felt, level : felt) -> (data : BuildingFixedData):
end

@storage_var
func building_count(token_id : Uint256) -> (count : felt):
end

# Manages building ids for each player
@storage_var
func building_index(token_id : Uint256) -> (index : felt):
end

# Dynamic data of building
@storage_var
func _building_data(token_id : Uint256, building_id : felt, storage_index : felt) -> (res : felt):
end
# storage_index = BuildingData.type_id, BuildingData.level, ...

##########
# EVENTS #
##########

@event
func Build(owner : felt, token_id : Uint256, type : felt):
end

@event
func DestroyBuilding(owner : felt, token_id : Uint256, type : felt):
end

###############
# CONSTRUCTOR #
###############

# Initialize fixed data
@constructor
func constructor{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type_len : felt,
    type : felt*,
    level : felt,
    building_cost_len : felt,
    building_cost : felt*,
    daily_cost_len : felt,
    daily_cost : felt*,
    daily_harvest_len : felt,
    daily_harvest : felt*,
    pop_len : felt,
    pop : felt*,
):
    let (caller) = get_caller_address()
    can_initialize_.write(caller)

    if type_len == 0:
        return ()
    end

    _initialize_global_data(type_len, type, 1, building_cost, daily_cost, daily_harvest, pop)
    _initialize_global_data(type_len, type, 2, building_cost, daily_cost, daily_harvest, pop)
    _initialize_global_data(type_len, type, 3, building_cost, daily_cost, daily_harvest, pop)

    return ()
end

# Initialize Controller Address
@external
func initializer{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    address_of_controller : felt
):
    Module.initialize_controller(address_of_controller)
    return ()
end

func _initialize_global_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type_len : felt,
    type : felt*,
    level : felt,
    building_cost : felt*,
    daily_cost : felt*,
    daily_harvest : felt*,
    pop : felt*,
):
    alloc_locals

    if type_len == 0:
        return ()
    end

    let c_upgrade = MultipleResources(
        nb_resources=building_cost[0],
        resources_qty=building_cost[1],
        gold_qty=building_cost[2],
        energy_qty=building_cost[3],
    )
    let c_daily = MultipleResources(
        nb_resources=daily_cost[0],
        resources_qty=daily_cost[1],
        gold_qty=daily_cost[2],
        energy_qty=daily_cost[3],
    )
    let h_daily = MultipleResources(
        nb_resources=daily_harvest[0],
        resources_qty=daily_harvest[1],
        gold_qty=daily_harvest[2],
        energy_qty=daily_harvest[3],
    )
    let d = BuildingFixedData(
        upgrade_cost=c_upgrade,
        daily_cost=c_daily,
        daily_harvest=h_daily,
        pop_max=pop[0],
        pop_min=pop[1],
    )

    building_global_data.write(type=type[0], level=level, value=d)

    return _initialize_global_data(
        type_len - 1, type + 1, level, building_cost + 4, daily_cost + 4, daily_harvest + 4, pop + 2
    )
end

######################
# EXTERNAL FUNCTIONS #
######################

@external
func upgrade{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    building_type_id : felt,
    level : felt,
    pos_start : felt,
    allocated_population : felt,
):
    alloc_locals

    # Check caller is owner of tokenId
    let (caller) = get_caller_address()
    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert bool = 1
    end

    # Check owner can build this level
    with_attr error_message("M03_Buildings: this level doesn't exist yet."):
        assert_le(level, 3)
    end

    # Fetch fixed building data
    let (building_data : BuildingFixedData) = building_global_data.read(building_type_id, level)

    # Fetch cost of upgrade. Formatted : [ID_RES1, QTY1, ID_RES2, QTY2, ...]
    let (costs_len : felt, costs : felt*) = _get_costs_from_chain(
        building_data.upgrade_cost.nb_resources, building_data.upgrade_cost.resources_qty
    )
    local upgrade_costs_struct : MultipleResources = building_data.upgrade_cost
    local upgrade_cost_gold = upgrade_costs_struct.gold_qty
    local upgrade_cost_energy = upgrade_costs_struct.energy_qty

    # Check enough FrensCoins
    let (controller) = Module.get_controller()
    let (frenscoins_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Gold
    )
    let (local balance_coins) = IERC20FrensCoin.balanceOf(frenscoins_addr, caller)
    let (felt_balance) = uint256_to_felt(balance_coins)
    let (enough_balance) = is_le(upgrade_cost_gold, felt_balance)
    with_attr error_message("M03_Buildings: caller has not enough FrensCoins."):
        assert enough_balance = 1
    end

    # Check enough resources
    let (erc1155_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Resources
    )
    let (has_resources) = _has_resources(caller, erc1155_addr, costs_len, costs)
    with_attr error_message("M03_Buildings: caller has not enough resources."):
        assert has_resources = 1
    end

    # Burn FrensCoins & resources needed
    let (uint_costs) = felt_to_uint256(upgrade_cost_gold)
    IERC20FrensCoin.burnFrom(frenscoins_addr, caller, uint_costs)
    _pay_resources(caller, erc1155_addr, costs_len, costs)

    # Increment building ID
    let (last_index) = building_index.read(tokenId)
    let (current_block) = get_block_number()

    # Check owner can build on this position on the map & check matType
    let (m01_addr) = IModuleController.get_module_address(controller, ModuleIds.M01_Worlds)
    IM01Worlds._check_can_build(m01_addr, tokenId, level, pos_start)

    # TODO : Write on the map the new data through M01

    # allocate population
    # TODO : cas où pas assez de population
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    IM02Resources.update_population(m02_addr, tokenId, 1, allocated_population)

    # Build data for building
    _building_data.write(tokenId, last_index + 1, BuildingData.type_id, building_type_id)
    _building_data.write(tokenId, last_index + 1, BuildingData.level, level)
    _building_data.write(tokenId, last_index + 1, BuildingData.pop, allocated_population)
    _building_data.write(tokenId, last_index + 1, BuildingData.time_created, current_block)
    _building_data.write(tokenId, last_index + 1, BuildingData.last_repair, current_block)

    building_index.write(tokenId, last_index + 1)

    # TODO : Calculer coûts et harvest en fonction de la population

    # Update Daily Costs in M02_Resources
    # Fetch the costs formatted : [ID_RES1, QTY1, ID_RES2, QTY2, ...]
    let (daily_costs_len : felt, daily_costs : felt*) = _get_costs_from_chain(
        building_data.daily_cost.nb_resources, building_data.daily_cost.resources_qty
    )
    IM02Resources.fill_ressources_cost(m02_addr, tokenId, daily_costs_len, daily_costs, 1)

    local daily_costs_struct : MultipleResources = building_data.daily_cost
    local daily_cost_gold = daily_costs_struct.gold_qty
    local daily_cost_energy = daily_costs_struct.energy_qty
    IM02Resources.fill_gold_energy_cost(m02_addr, tokenId, daily_cost_gold, daily_cost_energy, 1)

    # Update daily_cost storage_var res + gold + energy in M02 Module
    # Fetch harvesting quantities [ID_RES1, QTY1, ID_RES2, QTY2, ...]
    let (daily_harvests_len : felt, daily_harvests : felt*) = _get_costs_from_chain(
        building_data.daily_harvest.nb_resources, building_data.daily_harvest.resources_qty
    )
    IM02Resources.fill_ressources_harvest(m02_addr, tokenId, daily_harvests_len, daily_harvests, 1)

    local daily_harvests_struct : MultipleResources = building_data.daily_harvest
    local daily_harvest_gold = daily_harvests_struct.gold_qty
    local daily_harvest_energy = daily_harvests_struct.energy_qty
    IM02Resources.fill_gold_energy_harvest(
        m02_addr, tokenId, daily_harvest_gold, daily_harvest_energy, 1
    )

    let (id) = building_count.read(tokenId)
    building_count.write(tokenId, id + 1)

    Build.emit(caller, tokenId, building_type_id)

    return ()
end

@external
func destroy{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, building_unique_id : felt
):
    alloc_locals

    let (controller) = Module.get_controller()

    # Check caller is owner of tokenId
    let (caller) = get_caller_address()
    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert bool = 1
    end

    # Fetch population information
    let (current_pop) = _building_data.read(tokenId, building_unique_id, BuildingData.pop)
    let (building_type_id) = _building_data.read(tokenId, building_unique_id, BuildingData.type_id)
    let (level) = _building_data.read(tokenId, building_unique_id, BuildingData.level)

    # Fetch fixed building data
    let (building_data : BuildingFixedData) = building_global_data.read(building_type_id, level)

    # Update Daily Costs in M02_Resources
    # TODO : calculate costs depending on allocated pop
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    let (daily_costs_len : felt, daily_costs : felt*) = _get_costs_from_chain(
        building_data.daily_cost.nb_resources, building_data.daily_cost.resources_qty
    )
    IM02Resources.fill_ressources_cost(m02_addr, tokenId, daily_costs_len, daily_costs, 0)

    local daily_costs_struct : MultipleResources = building_data.daily_cost
    local daily_cost_gold = daily_costs_struct.gold_qty
    local daily_cost_energy = daily_costs_struct.energy_qty
    IM02Resources.fill_gold_energy_cost(m02_addr, tokenId, daily_cost_gold, daily_cost_energy, 0)

    # Update daily_cost storage_var res + gold + energy in M02 Module. Fetch harvesting quantities [ID_RES1, QTY1, ID_RES2, QTY2, ...]
    let (daily_harvests_len : felt, daily_harvests : felt*) = _get_costs_from_chain(
        building_data.daily_harvest.nb_resources, building_data.daily_harvest.resources_qty
    )
    IM02Resources.fill_ressources_harvest(m02_addr, tokenId, daily_harvests_len, daily_harvests, 0)

    local daily_harvests_struct : MultipleResources = building_data.daily_harvest
    local daily_harvest_gold = daily_harvests_struct.gold_qty
    local daily_harvest_energy = daily_harvests_struct.energy_qty
    IM02Resources.fill_gold_energy_harvest(
        m02_addr, tokenId, daily_harvest_gold, daily_harvest_energy, 0
    )

    # Update population
    IM02Resources.update_population(m02_addr, tokenId, 0, current_pop)

    # Destroy building
    _building_data.write(tokenId, building_unique_id, BuildingData.type_id, 0)
    _building_data.write(tokenId, building_unique_id, BuildingData.level, 0)
    _building_data.write(tokenId, building_unique_id, BuildingData.pop, 0)
    _building_data.write(tokenId, building_unique_id, BuildingData.time_created, 0)
    _building_data.write(tokenId, building_unique_id, BuildingData.last_repair, 0)

    # Decrement number of buildings
    let (count) = building_count.read(tokenId)
    building_count.write(tokenId, count - 1)

    DestroyBuilding.emit(caller, tokenId, building_unique_id)

    return ()
end

@external
func repair{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, building_id : felt, level : felt
):
    alloc_locals

    let (caller) = get_caller_address()

    # TODO : Check caller is owner of token_id

    # TODO : Check user has resources

    # TODO : Decrement resources

    let (current_block) = get_block_number()
    _building_data.write(token_id, building_id, BuildingData.last_repair, current_block)

    return ()
end

# Move a building on the map
@external
func move{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, building_id : felt, level : felt
):
    # Check caller is owner of token_id
    # Fetch resources needed to build
    # Check owner can build (has enough resources)
    return ()
end

# TODO : Function callable only by Arbiter to add additional levels and data
# @external
# func add_additional_fixed_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
#     token_id : Uint256, building_id : felt, level : felt
# ):
#     _only_approved()

# return ()
# end

@external
func initialize_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    building_type_id_len : felt,
    building_type_id : felt*,
    level_len : felt,
    level : felt*,
):
    let (caller) = get_caller_address()
    let (can_initialize) = can_initialize_.read()
    assert caller = can_initialize

    _initialize_resources_iter(tokenId, building_type_id, level_len, level)

    building_count.write(tokenId, 1)

    return ()
end

func _initialize_resources_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, building_type_id : felt*, level_len : felt, level : felt*
):
    if level_len == 0:
        return ()
    end

    # Increment building ID
    let (last_index) = building_index.read(tokenId)
    let (current_block) = get_block_number()

    _building_data.write(tokenId, last_index + 1, BuildingData.type_id, building_type_id[0])
    _building_data.write(tokenId, last_index + 1, BuildingData.level, level[0])
    _building_data.write(tokenId, last_index + 1, BuildingData.time_created, current_block)

    building_index.write(tokenId, last_index + 1)

    return _initialize_resources_iter(tokenId, building_type_id + 1, level_len - 1, level + 1)
end

##################
# VIEW FUNCTIONS #
##################

# Get fixed data of buildings by type and level
@view
func view_fixed_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type : felt, level : felt
) -> (data : BuildingFixedData):
    let (data : BuildingFixedData) = building_global_data.read(type, level)
    return (data)
end

# Get current number of buildings built by a user
@view
func get_building_count{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256
) -> (count : felt):
    let (count) = building_count.read(token_id)
    return (count)
end

# Returns an array of building ids with type
@view
func get_all_building_ids{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256
) -> (data_len : felt, data : felt*):
    alloc_locals
    let (local data : felt*) = alloc()
    local data_size = 0

    let (max_count) = building_count.read(token_id)

    _get_all_building_ids_iter(token_id, 0, data_size, data, max_count * 2)

    return (max_count * 2, data)
end

# Get dynamic data of building from unique building_id
@view
func get_building_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, building_id
) -> (data_len : felt, data : felt*):
    alloc_locals
    let (data : felt*) = alloc()

    let (data_1) = _building_data.read(token_id, building_id, BuildingData.type_id)
    let (data_2) = _building_data.read(token_id, building_id, BuildingData.level)
    let (data_3) = _building_data.read(token_id, building_id, BuildingData.pop)
    let (data_4) = _building_data.read(token_id, building_id, BuildingData.time_created)
    let (data_5) = _building_data.read(token_id, building_id, BuildingData.last_repair)

    # TODO : Add asserts here
    data[0] = data_1
    data[1] = data_2
    data[2] = data_3
    data[3] = data_4
    data[4] = data_5

    return (5, data)
end

func _get_all_building_ids_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, counter : felt, data_size : felt, data : felt*, max_count : felt
):
    if data_size == max_count:
        return ()
    end

    let (new_b) = _building_data.read(
        token_id=token_id, building_id=counter, storage_index=BuildingData.type_id
    )
    let (exists) = is_not_zero(new_b)

    # %{ print ('max_count : ', ids.max_count) %}
    # %{ print ('counter : ', ids.counter) %}
    # %{ print ('Building exists : ', ids.exists) %}
    # %{ print ('Building type_id : ', ids.new_b) %}

    if exists == 1:
        assert data[0] = counter
        assert data[1] = new_b
        _get_all_building_ids_iter(token_id, counter + 1, data_size + 2, data + 2, max_count)
    else:
        _get_all_building_ids_iter(token_id, counter + 1, data_size, data, max_count)
    end

    return ()
end

@view
func get_upgrade_cost{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    building_type : felt, level : felt
) -> (res : felt):
    alloc_locals
    let (local data : BuildingFixedData) = building_global_data.read(building_type, level)
    local all_costs : MultipleResources = data.upgrade_cost
    let res = all_costs.resources_qty
    return (res)
end

######################
# INTERNAL FUNCTIONS #
######################

# @notice checks player has the resources
# @param player address
# @param costs [ID_RES1, QTY1, ID_RES2, QTY2, ...]
func _has_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    player : felt, erc1155_addr : felt, costs_len : felt, costs : felt*
) -> (bool : felt):
    alloc_locals
    if costs_len == 0:
        return (TRUE)
    end

    let (uint_id) = felt_to_uint256(costs[0])
    let (balance : Uint256) = IERC1155.balanceOf(erc1155_addr, player, uint_id)
    let (felt_balance) = uint256_to_felt(balance)

    let (local check) = is_le(costs[1], felt_balance)
    if check == 0:
        return (FALSE)
    end

    return _has_resources(player, erc1155_addr, costs_len - 2, costs + 2)
end

# @notice pays resources of upgrade
# @param player address
# @param costs [ID_RES1, QTY1, ID_RES2, QTY2, ...]
func _pay_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    player : felt, erc1155_addr : felt, costs_len : felt, costs : felt*
) -> (bool : felt):
    alloc_locals
    if costs_len == 0:
        return (TRUE)
    end

    let (uint_id) = felt_to_uint256(costs[0])
    let (uint_qty) = felt_to_uint256(costs[1])
    IERC1155.burn(erc1155_addr, player, uint_id, uint_qty)

    return _has_resources(player, erc1155_addr, costs_len - 2, costs + 2)
end

# @notice decompose the costs of building to build
# @dev takes a chain of number formatted [resource_id_0][qty_0][qty_0][resource_id_1][qty_1][qty_1]...
# @param resources_qty : the chain of numbers
# @param nb_resources : nb of resources
func _get_costs_from_chain{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    nb_resources : felt, resources_qty : felt
) -> (ret_array_len : felt, ret_array : felt*):
    alloc_locals

    let (local ret_array : felt*) = alloc()

    local b_index = 16 - (nb_resources * 3)
    let (local bArr) = bArray(b_index)

    Data._decompose(bArr, nb_resources * 3, resources_qty, ret_array, 0, 0, 0)

    let (local costs : felt*) = alloc()
    Data._compose_costs(nb_resources, ret_array, costs)

    return (nb_resources * 2, costs)
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

func _is_owner_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    caller : felt, tokenId : Uint256
) -> (success : felt):
    let (controller) = Module.get_controller()
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )
    # Check caller is owner of tokenId
    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    if owner == caller:
        return (1)
    end
    return (0)
end

func felt_to_uint256{range_check_ptr}(x) -> (uint_x : Uint256):
    let (high, low) = split_felt(x)
    return (Uint256(low=low, high=high))
end

func uint256_to_felt{range_check_ptr}(value : Uint256) -> (value : felt):
    assert_lt_felt(value.high, 2 ** 123)
    return (value.high * (2 ** 128) + value.low)
end

# Add new data to global fixed data
# Pour ajouter des levels, ou bien de nouveaux buildings
# Only par arbiter
