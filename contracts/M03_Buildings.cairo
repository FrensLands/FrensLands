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

from contracts.utils.game_structs import (
    ModuleIds,
    ExternalContractsIds,
    BuildingFixedData,
    Cost,
    BuildingData,
    HarvestResourceBuilding,
)
from contracts.utils.game_constants import GOLD_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20Gold
from contracts.utils.interfaces import IModuleController
from contracts.library.library_module import Module

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

    let c_upgrade = Cost(
        resources_id=building_cost[0],
        resources_qty=building_cost[1],
        gold_qty=building_cost[2],
        energy_qty=building_cost[3],
    )
    let c_daily = Cost(
        resources_id=daily_cost[0],
        resources_qty=daily_cost[1],
        gold_qty=daily_cost[2],
        energy_qty=daily_cost[3],
    )
    let h_daily = Cost(
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
    building_id : felt,
    level : felt,
    position : felt,
    allocated_population : felt,
):
    alloc_locals

    let (caller) = get_caller_address()

    # TODO : Check caller is owner of token_id

    let (building_data : BuildingFixedData) = building_global_data.read(building_id, level)

    # TODO : Check owner can build (has enough resources)

    # TODO : Check owner can build this level

    # TODO : Check owner can build on this position on the map

    # Increment building ID
    let (last_index) = building_index.read(token_id)
    local new_index = last_index + 1
    let (current_block) = get_block_number()

    # TODO : In M02_Resources call :
    #   - Decrement population
    #   - Decrement all resources, gold, energy

    # Build data for building
    _building_data.write(token_id, building_id, BuildingData.type_id, building_id)
    _building_data.write(token_id, building_id, BuildingData.level, level)
    _building_data.write(token_id, building_id, BuildingData.pop, allocated_population)
    _building_data.write(token_id, building_id, BuildingData.time_created, current_block)
    _building_data.write(token_id, building_id, BuildingData.last_repair, current_block)

    # TODO : In M02_Resources
    #   - Calculate resources and update la storage_var du M02_Resources
    #     avec les daily costs et les daily recettes

    let (id) = building_count.read(token_id)
    building_count.write(token_id, id + 1)

    Build.emit(caller, token_id, building_id)

    return ()
end

@external
func destroy{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, building_id : felt
):
    alloc_locals

    let (caller) = get_caller_address()

    # TODO : Check caller is owner of token_id

    # Decrement number of buildings
    let (count) = building_count.read(token_id)
    building_count.write(token_id, count - 1)

    let (allocated_population) = _building_data.read(token_id, building_id, BuildingData.pop)
    let (level) = _building_data.read(token_id, building_id, BuildingData.level)
    let (building_data : BuildingFixedData) = building_global_data.read(building_id, level)

    # TODO : In M02_Resources
    #   - Decrement resources and update la storage_var du M02_Resources
    #     avec les daily costs et les daily recettes
    #   - increment available population

    # Destroy building
    _building_data.write(token_id, building_id, BuildingData.type_id, 0)
    _building_data.write(token_id, building_id, BuildingData.level, 0)
    _building_data.write(token_id, building_id, BuildingData.pop, 0)
    _building_data.write(token_id, building_id, BuildingData.time_created, 0)
    _building_data.write(token_id, building_id, BuildingData.last_repair, 0)

    # LATER : Potentially get back some of the resources ?

    DestroyBuilding.emit(caller, token_id, building_id)

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

# Get fixed data of buildings
@view
func view_fixed_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type : felt, level : felt
) -> (data : BuildingFixedData):
    let (data : BuildingFixedData) = building_global_data.read(type, level)
    return (data)
end

# Get dynamic data of building
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
    local counter = 0

    let (max_count) = building_count.read(token_id)

    _build_ids(token_id, counter, data, max_count)

    return (max_count, data)
end

func _build_ids{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, counter : felt, data : felt*, max_count : felt
):
    if counter == max_count:
        return ()
    end

    let (new_b) = _building_data.read(token_id, counter, BuildingData.type_id)

    if new_b != 0:
        data[0] = counter
        data[1] = new_b
        _build_ids(token_id, counter + 1, data + 2, max_count)
    else:
        _build_ids(token_id, counter + 1, data, max_count)
    end

    return ()
end

######################
# INTERNAL FUNCTIONS #
######################

# _can_build()
#   _has_enough_resources()
#   _
# _fetch_costs
