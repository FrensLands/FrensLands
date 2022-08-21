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
from starkware.cairo.common.math import (
    assert_le,
    assert_not_zero,
    assert_not_equal,
)
from starkware.cairo.common.bool import TRUE, FALSE

from contracts.utils.game_structs import (
    ModuleIds,
    ExternalContractsIds,
    BuildingFixedData,
    MultipleResources,
    BuildingData,
)
from contracts.utils.game_constants import GOLD_START, NB_RECHARGES, RATIO_SECURITY

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20FrensCoin, IERC1155
from contracts.utils.interfaces import IModuleController, IM01Worlds, IM02Resources
from contracts.utils.bArray import bArray
from contracts.library.library_module import Module
from contracts.library.library_data import Data
from contracts.utils.general import felt_to_uint256, uint256_to_felt

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

# nb of police station
@storage_var
func security(token_id : Uint256) -> (res : felt):
end

@storage_var
func ratio_security() -> (res : felt):
end


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
    admin : felt,
):
    can_initialize_.write(admin)

    if type_len == 0:
        return ()
    end

    _initialize_global_data_iter(
        type_len, type, level, building_cost, daily_cost, daily_harvest, pop
    )

    ratio_security.write(RATIO_SECURITY)

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

@external
func initialize_global_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
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
    let (admin_addr) = can_initialize_.read()
    assert caller = admin_addr

    if type_len == 0:
        return ()
    end

    _initialize_global_data_iter(
        type_len, type, level, building_cost, daily_cost, daily_harvest, pop
    )

    return ()
end

func _initialize_global_data_iter{
    pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr
}(
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
        pop_min=pop[0],
        new_pop=pop[1]
    )

    building_global_data.write(type=type[0], level=level, value=d)

    return _initialize_global_data_iter(
        type_len - 1, type + 1, level, building_cost + 4, daily_cost + 4, daily_harvest + 4, pop + 2
    )
end

######################
# EXTERNAL FUNCTIONS #
######################

@external
func build{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    building_type_id : felt,
    pos_start : felt
):
    alloc_locals
    let (caller) = get_caller_address()
    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert bool = 1
    end

    let (controller) = Module.get_controller()

    let (m01_addr) = IModuleController.get_module_address(controller, ModuleIds.M01_Worlds)
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    let (erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    let (frenscoins_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)

    local _check = (building_type_id - 1) * (building_type_id - 2) * (building_type_id - 3) * (building_type_id - 20) * (building_type_id - 27)
    with_attr error_message("M01_Worlds: you cannot build this."):
        assert_not_zero(_check)
    end

    # Fetch fixed building data
    let (building_data : BuildingFixedData) = building_global_data.read(building_type_id, 1)
    with_attr error_message("M03_Buildings: this building does not exist."):
        assert_not_zero(building_data.upgrade_cost.nb_resources)
    end

    # Fetch cost of upgrade. Formatted : [ID_RES1, QTY1, ID_RES2, QTY2, ...]
    let (costs_len : felt, costs : felt*) = _get_costs_from_chain(
        building_data.upgrade_cost.nb_resources, building_data.upgrade_cost.resources_qty
    )
    local upgrade_costs_struct : MultipleResources = building_data.upgrade_cost
    local upgrade_cost_gold = upgrade_costs_struct.gold_qty
    local upgrade_cost_energy = upgrade_costs_struct.energy_qty

    # Population
    local pop_min = building_data.pop_min
    local new_pop = building_data.new_pop
    let (local pop_len : felt, local pop : felt*) = IM02Resources.get_population(m02_addr, tokenId)
    let (enough_pop) = is_le(pop_min, pop[0])
    with_attr error_message("M03_Buildings: not enough free population to build this building."):
        assert enough_pop = 1
    end
    # Update total population
    IM02Resources.update_population(m02_addr, tokenId, 3, new_pop)
    IM02Resources.update_population(m02_addr, tokenId, 1, pop_min)

    # Frenscoins
    let (local balance_coins) = IERC20FrensCoin.balanceOf(frenscoins_addr, caller)
    let (felt_balance) = uint256_to_felt(balance_coins)
    let (enough_balance) = is_le(upgrade_cost_gold, felt_balance)
    with_attr error_message("M03_Buildings: caller has not enough FrensCoins to build."):
        assert enough_balance = 1
    end
    let (uint_costs) = felt_to_uint256(upgrade_cost_gold)
    IM02Resources._pay_frens_coins(m02_addr, caller, uint_costs)

    # check has resources and pay
    let (has_resources) = IM02Resources.has_resources(m02_addr, caller, erc1155_addr, costs_len, costs, 1)
    with_attr error_message("M03_Buildings: caller has not enough resources to build."):
        assert has_resources = 1
    end

    # Check has energy and pay
    let (current_energy) = IM02Resources.get_energy_level(m02_addr, tokenId)
    let (has_energy) = is_le(upgrade_cost_energy, current_energy)
    with_attr error_message("M03_Buildings: caller has not enough energy to recharge building."):
        assert has_energy = 1
    end
    IM02Resources._update_energy(m02_addr, tokenId, 0, upgrade_cost_energy)

    # Check owner can build on this position on the map
    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, pos_start)
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)
    let check_build = decomp_array[7] * 100 + decomp_array[8] * 10 + decomp_array[9]
    with_attr error_message("M03_Buildings: there is already a building on this block."):
        assert check_build = 0
    end

    # Increment building ID
    let (last_index) = building_index.read(tokenId)
    building_index.write(tokenId, last_index + 1)

    let (counter) = building_count.read(tokenId)
    building_count.write(tokenId, counter + 1)

    # Security check
    let (current_security) = security.read(tokenId)
    if building_type_id == 22:
        security.write(tokenId, current_security + 1)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    else:
        let (local curr_ratio) = ratio_security.read()
        local security_check = (current_security + 1) * curr_ratio
        assert_le(counter + 1, security_check)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
    end

    # Build data for building
    let (current_block) = get_block_number()
    _building_data.write(tokenId, last_index + 1, BuildingData.type_id, building_type_id)
    _building_data.write(tokenId, last_index + 1, BuildingData.time_created, current_block)
    _building_data.write(tokenId, last_index + 1, BuildingData.pos, pos_start)
    _building_data.write(tokenId, last_index + 1, BuildingData.recharged, NB_RECHARGES)
    _building_data.write(tokenId, last_index + 1, BuildingData.last_claim, current_block)

    Build.emit(caller, tokenId, building_type_id)

    let (local comp) = Data._compose_chain_build(
        16, decomp_array, building_type_id, last_index + 1, pop_min, 1
    )
    IM01Worlds.update_map_block(m01_addr, tokenId, pos_start, comp)

    return ()
end

@external
func upgrade{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    pos_start : felt
):
    alloc_locals
    let (caller) = get_caller_address()
    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert bool = 1
    end

    let (controller) = Module.get_controller()
    let (m01_addr) = IModuleController.get_module_address(controller, ModuleIds.M01_Worlds)
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    let (erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    let (frenscoins_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)

    # Check block info at this position
    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, pos_start)
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)

    let building_type_id = decomp_array[5] * 10 + decomp_array[6]
    let current_level = decomp_array[14]
    let building_unique_id = decomp_array[7] * 100 + decomp_array[8] * 10 + decomp_array[9]

    with_attr error_message("M03_Buildings: there are no buildings to upgrade on this block."):
        assert_not_zero(building_unique_id)
    end

    local _check = (building_type_id - 2) * (building_type_id - 3) * (building_type_id - 20) * (building_type_id - 27)
    with_attr error_message("M01_Worlds: you cannot upgrade this resource."):
        assert_not_zero(_check)
    end

    # Fetch fixed building data
    let (building_data : BuildingFixedData) = building_global_data.read(building_type_id, current_level + 1)
    with_attr error_message("M03_Buildings: there are no upgrades for this building."):
        assert_not_zero(building_data.upgrade_cost.nb_resources)
    end

    # Fetch cost of upgrade. Formatted : [ID_RES1, QTY1, ID_RES2, QTY2, ...]
    let (costs_len : felt, costs : felt*) = _get_costs_from_chain(
        building_data.upgrade_cost.nb_resources, building_data.upgrade_cost.resources_qty
    )
    local upgrade_costs_struct : MultipleResources = building_data.upgrade_cost
    local upgrade_cost_gold = upgrade_costs_struct.gold_qty * 2
    local upgrade_cost_energy = upgrade_costs_struct.energy_qty * 2

    # Check enough free population
    local pop_min = building_data.pop_min
    local new_pop = building_data.new_pop
    IM02Resources.update_population(m02_addr, tokenId, 3, new_pop)
    IM02Resources.update_population(m02_addr, tokenId, 1, pop_min)

    # Check enough frens coins
    let (local balance_coins) = IERC20FrensCoin.balanceOf(frenscoins_addr, caller)
    let (felt_balance) = uint256_to_felt(balance_coins)
    let (enough_balance) = is_le(upgrade_cost_gold, felt_balance)
    with_attr error_message("M03_Buildings: caller has not enough FrensCoins to build."):
        assert enough_balance = 1
    end
    let (uint_costs) = felt_to_uint256(upgrade_cost_gold)
    IM02Resources._pay_frens_coins(m02_addr, caller, uint_costs)

    # check has resources
    let (has_resources) = IM02Resources.has_resources(m02_addr, caller, erc1155_addr, costs_len, costs, 1)
    with_attr error_message("M03_Buildings: caller has not enough resources to build."):
        assert has_resources = 1
    end

    # Check has energy
    let (current_energy) = IM02Resources.get_energy_level(m02_addr, tokenId)
    let (has_energy) = is_le(upgrade_cost_energy, current_energy)
    with_attr error_message("M03_Buildings: caller has not enough energy to recharge building."):
        assert has_energy = 1
    end
    IM02Resources._update_energy(m02_addr, tokenId, 0, upgrade_cost_energy)

    let (local comp) = Data._compose_chain_build(
        16, decomp_array, building_type_id, building_unique_id, pop_min, current_level + 1
    )
    IM01Worlds.update_map_block(m01_addr, tokenId, pos_start, comp)

    return ()
end

@external
func recharge_building{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, pos_start: felt, nb_days : felt
):
    alloc_locals
    let (caller) = get_caller_address()

    if nb_days == 0:
        return ()
    end

    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert bool = 1
    end

    let (controller) = Module.get_controller()
    let (m01_addr) = IModuleController.get_module_address(controller, ModuleIds.M01_Worlds)
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)
    let (erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    let (frenscoins_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)

    # Get unique id from block pos
    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, pos_start)
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)

    let building_unique_id = decomp_array[7] * 100 + decomp_array[8] * 10 + decomp_array[9]
    with_attr error_message("M03_Buildings: there are no building on this block"):
        assert_not_zero(building_unique_id)
    end

    let type_id = decomp_array[5] * 10 + decomp_array[6]
    let level = decomp_array[14]

    local _check = (type_id - 1) * (type_id - 2) * (type_id - 3) * (type_id - 20) * (type_id - 27)
    with_attr error_message("M01_Worlds: you cannot recharge this."):
        assert_not_zero(_check)
    end

    let (building_data : BuildingFixedData) = building_global_data.read(type_id, level)

    # Get daily costs
    let (costs_len : felt, costs : felt*) = _get_costs_from_chain(
        building_data.daily_cost.nb_resources, building_data.daily_cost.resources_qty
    )
    local daily_costs_struct : MultipleResources = building_data.daily_cost
    local daily_cost_gold = daily_costs_struct.gold_qty
    local daily_cost_energy = daily_costs_struct.energy_qty

    # Check can recharge building
    let (local balance_coins) = IERC20FrensCoin.balanceOf(frenscoins_addr, caller)
    let (felt_balance) = uint256_to_felt(balance_coins)
    let (enough_balance) = is_le(daily_cost_gold * nb_days, felt_balance)
    with_attr error_message(
            "M03_Buildings: caller has not enough FrensCoins to recharge building."):
        assert enough_balance = 1
    end
    let (uint_costs) = felt_to_uint256(daily_cost_gold * nb_days)
    IM02Resources._pay_frens_coins(m02_addr, caller, uint_costs)

    # Resources
    let (has_resources) = IM02Resources.has_resources(m02_addr, caller, erc1155_addr, costs_len, costs, nb_days)
    with_attr error_message("M03_Buildings: caller has not enough resources to recharge building."):
        assert has_resources = 1
    end

    # Energy
    let (current_energy) = IM02Resources.get_energy_level(m02_addr, tokenId)
    let (has_energy) = is_le(daily_cost_energy * nb_days, current_energy)
    with_attr error_message("M03_Buildings: caller has not enough energy to recharge building."):
        assert has_energy = 1
    end
    IM02Resources._update_energy(m02_addr, tokenId, 0, daily_cost_energy * nb_days)

    # Update recharges
    let (recharged) = _building_data.read(tokenId, building_unique_id, BuildingData.recharged)
    _building_data.write(tokenId, building_unique_id, BuildingData.recharged, recharged + nb_days)

    return ()
end

@external
func destroy{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, pos_start : felt
):
    alloc_locals

    # Check caller is owner of tokenId
    let (caller) = get_caller_address()
    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert bool = 1
    end

    let (controller) = Module.get_controller()
    let (m01_addr) = IModuleController.get_module_address(controller, ModuleIds.M01_Worlds)
    let (m02_addr) = IModuleController.get_module_address(controller, ModuleIds.M02_Resources)

    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, pos_start)
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)

    let building_type_id = decomp_array[5] * 10 + decomp_array[6]
    let level = decomp_array[14]

    # Assert building exists
    let building_unique_id = decomp_array[7] * 100 + decomp_array[8] * 10 + decomp_array[9]
    with_attr error_message("M03_Buildings: no building to destroy here"):
        assert_not_zero(building_unique_id)
    end

    # Fetch upgrade costs pour pouvoir repayer de la moitié du montant utilisé pour build 
    let (building_data : BuildingFixedData) = building_global_data.read(building_type_id, level)
    with_attr error_message("M03_Buildings: this building does not exist."):
        assert_not_zero(building_data.upgrade_cost.nb_resources)
    end
    let (costs_len : felt, costs : felt*) = _get_costs_from_chain(
        building_data.upgrade_cost.nb_resources, building_data.upgrade_cost.resources_qty
    )
    IM02Resources._get_resources_destroyed(m02_addr, tokenId, caller, costs_len, costs, 1)

    let allocated_population = building_data.pop_min
    IM02Resources.update_population(m02_addr, tokenId, 0, allocated_population)

    let _new_pop = building_data.new_pop
    IM02Resources.update_population(m02_addr, tokenId, 4, _new_pop)

    # Delete building dynamic data
    _building_data.write(tokenId, building_unique_id, BuildingData.type_id, 0)

    # Update block in map array 
    let (local comp) = Data._compose_chain_destroyed(16, decomp_array)
    IM01Worlds.update_map_block(m01_addr, tokenId, pos_start, comp)

    # Decrement number of buildings
    let (count) = building_count.read(tokenId)
    building_count.write(tokenId, count - 1)

    DestroyBuilding.emit(caller, tokenId, building_unique_id)

    return ()
end

@external
func initialize_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, block_number : felt, unique_id_count : felt
):
    Module.only_approved()

    _building_data.write(tokenId, 1, BuildingData.type_id, 1)
    _building_data.write(tokenId, 1, BuildingData.pos, 300)
    _building_data.write(tokenId, 1, BuildingData.level, 1)
    _building_data.write(tokenId, 1, BuildingData.time_created, block_number)

    building_index.write(tokenId, unique_id_count)
    building_count.write(tokenId, 1)

    return ()
end

@external
func update_ratio_security{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    new_ratio: felt
):
    let (caller) = get_caller_address()
    let (admin_addr) = can_initialize_.read()
    assert caller = admin_addr

    ratio_security.write(new_ratio)

    return ()
end

##################
# VIEW FUNCTIONS #
##################

# Get fixed data of buildings by type and level
@view
func view_fixed_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type : felt, level : felt
) -> (building_data : BuildingFixedData):
    let (building_data : BuildingFixedData) = building_global_data.read(type, level)
    return (building_data)
end

@view
func view_fixed_data_claim{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type : felt, level : felt
) -> (building_data_len : felt, building_data : felt*):
    alloc_locals

    let (building_data : BuildingFixedData) = building_global_data.read(type, level)
    local daily_harvests_struct : MultipleResources = building_data.daily_harvest

    let (local res : felt*) = alloc()
    res[0] = daily_harvests_struct.nb_resources
    res[1] = daily_harvests_struct.resources_qty
    res[2] = daily_harvests_struct.gold_qty
    res[3] = daily_harvests_struct.energy_qty

    return (4, res)
end

# Get current number of buildings built by a user
@view
func get_building_count{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256
) -> (count : felt):
    let (count) = building_count.read(token_id)
    return (count)
end

# Returns an array of building ids with their types 
# 0 : unique ID of the building
# 1 : type_id of the building 
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

    if exists == 1:
        assert data[0] = counter
        assert data[1] = new_b
        _get_all_building_ids_iter(token_id, counter + 1, data_size + 2, data + 2, max_count)
    else:
        _get_all_building_ids_iter(token_id, counter + 1, data_size, data, max_count)
    end

    return ()
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
    let (data_3) = _building_data.read(token_id, building_id, BuildingData.time_created)
    let (data_4) = _building_data.read(token_id, building_id, BuildingData.recharged)
    let (data_5) = _building_data.read(token_id, building_id, BuildingData.last_claim)

    assert data[0] = data_1
    assert data[1] = data_2
    assert data[2] = data_3
    assert data[3] = data_4
    assert data[4] = data_5

    return (5, data)
end

# Get all buildings data : uniqueID, typeID, pos_start, nb_recharges, last_claims
@view
func get_all_buildings_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256
) -> (data_len : felt, data : felt*):
    alloc_locals
    let (local data : felt*) = alloc()
    local data_size = 0

    let (max_count) = building_count.read(token_id)

    _get_all_building_data_iter(token_id, 0, data_size, data, max_count * 5)

    return (max_count * 5, data)
end

func _get_all_building_data_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, counter : felt, data_size : felt, data : felt*, max_count : felt
):
    if data_size == max_count:
        return ()
    end

    let (type_id) = _building_data.read(token_id=token_id, building_id=counter, storage_index=BuildingData.type_id)
    let (exists) = is_not_zero(type_id)

    if exists == 0:
        return _get_all_building_data_iter(token_id, counter + 1, data_size, data, max_count)
    end 

    let (pos_start) = _building_data.read(token_id=token_id, building_id=counter, storage_index=BuildingData.pos)
    let (last_claim) = _building_data.read(token_id=token_id, building_id=counter, storage_index=BuildingData.last_claim)
    let (recharges) = _building_data.read(token_id=token_id, building_id=counter, storage_index=BuildingData.recharged)

    assert data[0] = counter
    assert data[1] = type_id
    assert data[2] = pos_start
    assert data[3] = recharges
    assert data[4] = last_claim

    return _get_all_building_data_iter(token_id, counter + 1, data_size + 5, data + 5, max_count)

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

@view
func get_ratio_security{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
) -> (ratio: felt):
    let (ratio) = ratio_security.read()

    return (ratio)
end

######################
# INTERNAL FUNCTIONS #
######################

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

@external
func _destroy_building{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, building_unique_id : felt
) -> ():
    Module.only_approved()
    _building_data.write(tokenId, building_unique_id, BuildingData.type_id, 0)

    return ()
end

@external
func update_building_claimed_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, building_unique_id: felt, recharge: felt, last_claim: felt
):
    Module.only_approved()

    _building_data.write(tokenId, building_unique_id, BuildingData.last_claim, last_claim)
    _building_data.write(tokenId, building_unique_id, BuildingData.recharged, recharge)

    return ()
end


@external
func _reinitialize_buildings{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, caller: felt
):
    Module.only_approved()

    let (index) = building_index.read(tokenId)
    _reinitialize_building_iter(tokenId, index)

    building_count.write(tokenId, 0)

    return ()
end

func _reinitialize_building_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    index : felt,
):
    if index == 0:
        building_index.write(tokenId, 0)
        return ()
    end

    let (current_block) = get_block_number()

    let (_data) = _building_data.read(tokenId, index, BuildingData.type_id)
    if _data != 0:
        _building_data.write(tokenId, index, BuildingData.type_id, 0)
        return _reinitialize_building_iter(tokenId, index - 1)
    end

    return _reinitialize_building_iter(tokenId, index - 1)
end