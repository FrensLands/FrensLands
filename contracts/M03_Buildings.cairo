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
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.utils.game_structs import (
    ModuleIds,
    ExternalContractsIds,
    BuildingFixedData,
    UpgradeCost,
    DailyCost,
    BuildingData,
)
from contracts.utils.game_constants import GOLD_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20Gold
from contracts.utils.interfaces import IModuleController
from contracts.utils.bArray import bArray
from contracts.library.library_module import Module
from contracts.library.library_data import Data

###########
# STORAGE #
###########

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

# TODO : Add initialize Controller Address

# Initialize fixed data
# TODO : can be done only once
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
    if type_len == 0:
        return ()
    end

    _initialize_global_data(type_len, type, level, building_cost, daily_cost, daily_harvest, pop)

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

    let c_upgrade = UpgradeCost(
        nb_resources=building_cost[0],
        resources_qty=building_cost[1],
        gold_qty=building_cost[2],
        energy_qty=building_cost[3],
    )
    let c_daily = DailyCost(
        resources_id=daily_cost[0],
        resources_qty=daily_cost[1],
        gold_qty=daily_cost[2],
        energy_qty=daily_cost[3],
    )
    let h_daily = DailyCost(
        resources_id=daily_harvest[0],
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
    token_id : Uint256,
    building_type_id : felt,
    level : felt,
    position : felt,
    allocated_population : felt,
):
    alloc_locals

    let (caller) = get_caller_address()

    # TODO : Check caller is owner of token_id

    let (building_data : BuildingFixedData) = building_global_data.read(building_type_id, level)

    # Fetch cost of upgrade
    let (costs_len : felt, costs : felt*) = _get_costs_from_chain(
        building_data.upgrade_cost.nb_resources, building_data.upgrade_cost.resources_qty
    )
    # TODO : Check owner has enough resources to build
    let (has_resources) = _has_resources(costs_len, costs)
    with_attr error_message("M03_Buildings: caller has not enough resources."):
        assert has_resources = 1
    end

    # Check owner can build this level
    with_attr error_message("M03_Buildings: this level doesn't exist yet."):
        assert_le(level, 3)
    end

    # TODO : Check owner can build on this position on the map
    # _can_build
    # Call une view function dans map qui récupère les données et regarde si c'est dispo

    # Increment building ID
    let (last_index) = building_index.read(token_id)
    let (current_block) = get_block_number()

    # TODO : In M02_Resources call :
    #   - Decrement all resources : en passant (costs_len : felt, costs : felt*)
    # == tableau de couts [ID, QTY1, ID2, QTY2]
    # , gold, energy
    #   - Decrement population

    # Build data for building
    _building_data.write(token_id, last_index + 1, BuildingData.type_id, building_type_id)
    _building_data.write(token_id, last_index + 1, BuildingData.level, level)
    _building_data.write(token_id, last_index + 1, BuildingData.pop, allocated_population)
    _building_data.write(token_id, last_index + 1, BuildingData.time_created, current_block)
    _building_data.write(token_id, last_index + 1, BuildingData.last_repair, current_block)

    building_index.write(token_id, last_index + 1)

    # TODO : In M02_Resources
    #   - Calculate resources and update la storage_var du M02_Resources
    #     avec les daily costs et les daily recettes
    #  @storage_var
    # func daily_cost(index: felt, ressource_id : felt) -> (cost : Cost):
    # end
    # Idem pour daily_harvest : owner, index de la ressources -> qty

    let (id) = building_count.read(token_id)
    building_count.write(token_id, id + 1)

    Build.emit(caller, token_id, building_type_id)

    return ()
end

@external
func destroy{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, building_unique_id : felt
):
    alloc_locals

    let (caller) = get_caller_address()

    # TODO : Check caller is owner of token_id

    # Decrement number of buildings
    let (count) = building_count.read(token_id)
    building_count.write(token_id, count - 1)

    let (allocated_population) = _building_data.read(token_id, building_unique_id, BuildingData.pop)
    let (level) = _building_data.read(token_id, building_unique_id, BuildingData.level)

    # TODO : In M02_Resources
    #   - Decrement resources and update la storage_var du M02_Resources
    #     avec les daily costs et les daily recettes
    #   - increment available population

    # Destroy building
    _building_data.write(token_id, building_unique_id, BuildingData.type_id, 0)
    _building_data.write(token_id, building_unique_id, BuildingData.level, 0)
    _building_data.write(token_id, building_unique_id, BuildingData.pop, 0)
    _building_data.write(token_id, building_unique_id, BuildingData.time_created, 0)
    _building_data.write(token_id, building_unique_id, BuildingData.last_repair, 0)

    # LATER : Potentially get back some of the resources ?

    DestroyBuilding.emit(caller, token_id, building_unique_id)

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

##################
# VIEW FUNCTIONS #
##################

# Get current number of buildings built by a user
@view
func get_building_count{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256
) -> (count : felt):
    let (count) = building_count.read(token_id)
    return (count)
end

# Get fixed data of buildings by type and level
@view
func view_fixed_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type : felt, level : felt
) -> (data : BuildingFixedData):
    let (data : BuildingFixedData) = building_global_data.read(type, level)
    return (data)
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

# Returns an array of building ids with type
@view
func get_all_building_ids{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256
) -> (data_len : felt, data : felt*):
    alloc_locals
    let (local data : felt*) = alloc()
    local data_size = 0

    let (max_count) = building_count.read(token_id)

    _build_ids(token_id, 0, data_size, data, max_count * 2)

    return (max_count * 2, data)
end

func _build_ids{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, counter : felt, data_size : felt, data : felt*, max_count : felt
):
    # On return si le tab de result == nb de buildings construits
    if data_size == max_count:
        return ()
    end

    # Pour chaque index entre 1 et last id of building on check type_id
    let (new_b) = _building_data.read(
        token_id=token_id, building_id=counter, storage_index=BuildingData.type_id
    )
    # Si 0 alors vide, si 1 alors exists
    let (exists) = is_not_zero(new_b)

    %{ print ('max_count : ', ids.max_count) %}
    %{ print ('counter : ', ids.counter) %}
    %{ print ('Building exists : ', ids.exists) %}
    %{ print ('Building type_id : ', ids.new_b) %}

    if exists == 1:
        assert data[0] = counter
        assert data[1] = new_b
        _build_ids(token_id, counter + 1, data_size + 2, data + 2, max_count)
        # tempvar range_check_ptr = range_check_ptr
    else:
        _build_ids(token_id, counter + 1, data_size, data, max_count)
        # tempvar range_check_ptr = range_check_ptr
    end

    return ()
end

######################
# INTERNAL FUNCTIONS #
######################

# @notice decompose the costs of building to build
# @dev takes a chain of number formatted [resource_id_0][qty_0][qty_0][resource_id_1][qty_1][qty_1]...
# @param resources_qty : the chain of numbers
# @param nb_resources : nb of resources
func _has_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    costs_len : felt, costs : felt
) -> (bool : felt):
    if costs_len == 0:
        return (TRUE)
    end

    # GET ERC1155
    # Check

    return _can_build(costs_len - 2, costs + 2)
end

# @notice decompose the costs of building to build
# @dev takes a chain of number formatted [resource_id_0][qty_0][qty_0][resource_id_1][qty_1][qty_1]...
# @param resources_qty : the chain of numbers
# @param nb_resources : nb of resources
@view
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

# _can_build()
#   _has_enough_resources()
#   _
# _fetch_costs
