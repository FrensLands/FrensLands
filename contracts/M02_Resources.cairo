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
from starkware.cairo.common.math import assert_not_zero, split_felt, assert_lt_felt, assert_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le, is_le, is_in_range

from contracts.utils.game_structs import (
    ModuleIds,
    ExternalContractsIds,
    BuildingFixedData,
    MapsPrice,
    MultipleResources,
    ResourcesType
)
from contracts.utils.game_constants import GOLD_START, RESOURCES_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20FrensCoin, IERC1155
from contracts.utils.interfaces import IModuleController, IM03Buildings, IM01Worlds
from contracts.library.library_module import Module
from openzeppelin.access.ownable import Ownable
from contracts.utils.bArray import bArray
from contracts.library.library_data import Data
from contracts.utils.general import felt_to_uint256, uint256_to_felt


###########
# STORAGE #
###########

# Time is calculated using blocks. Stores the first blocks the world was generated
@storage_var
func start_block_(token_id : Uint256) -> (block : felt):
end

# Stores the last block
@storage_var
func block_number_(token_id : Uint256) -> (block : felt):
end

# Stores allocated population
# busy = 0, means available to work & harvest
# busy = 1, means already allocated to building
@storage_var
func population_(token_id : Uint256, busy : felt) -> (number : felt):
end

@storage_var
func energy_level(token_id : Uint256) -> (number : felt):
end

@storage_var
func initialized_(token_id : Uint256) -> (value : felt):
end

##########
# EVENTS #
##########

@event
func StartPayTaxes(owner : felt, token_id : Uint256):
end

@event
func EndPayTaxes(owner : felt, data : BuildingFixedData):
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

@external
func claim{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256
):
    alloc_locals
    let (controller) = Module.get_controller()
    let (m03_addr) = IModuleController.get_module_address(controller, ModuleIds.M03_Buildings)
    let (caller) = get_caller_address()

    let (data_len : felt, data : felt*) = IM03Buildings.get_all_buildings_data(m03_addr, tokenId)

    let (current_block) = get_block_number()
    _claim_resources_iter(tokenId, caller, data_len, data, current_block)

    return ()
end

# @notice iteration through all buildings
func _claim_resources_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, caller: felt, building_list_len : felt, building_list : felt*, current_block: felt
):
    alloc_locals

    if building_list_len == 0:
        return ()
    end

    local building_type_id = building_list[1]

    # If buildings are Cabin, Tree, Rock or Mine - nothing to claim
    if building_type_id == 1:
        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    end
    if building_type_id == 2:
        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    end
    if building_type_id == 3:
        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    end
    if building_type_id == 20:
        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    end

    let (controller) = Module.get_controller()
    let (m03_addr) = IModuleController.get_module_address(controller, ModuleIds.M03_Buildings)
    let (erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    let (gold_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)

    local nb_recharges = building_list[3]
    local last_claim = building_list[4]

    # Check if this building is ready to harvest
    let (is_ready) = is_le(last_claim + 1, current_block)

    if is_ready == 0:
        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    end

    # Si pas rechargé alors on passe à la prochaine ressource
    if nb_recharges == 0:
        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    end

    # TODO remplacer par le level 1
    # Get les fixed data de ce building
    # Get array with 0 = nb resources, 1 = resources_qty, 
    let (local building_fixed_len : felt, local building_fixed : felt*) = IM03Buildings.view_fixed_data_claim(m03_addr, building_list[1], 1)
    # Update daily_cost storage_var res + gold + energy in M02 Module
    # Fetch harvesting quantities [ID_RES1, QTY1, ID_RES2, QTY2, ...]
    let (daily_harvests_len : felt, daily_harvests : felt*) = _get_costs_from_chain(
        building_fixed[0], building_fixed[1]
    )
    local daily_harvest_gold = building_fixed[2]
    local daily_harvest_energy = building_fixed[3]

    # Get the max number of blocks possible
    local nb_blocks = current_block - last_claim
    # Le nombre de block est inférieur ou égal au nb de recharge dispo
    let (local is_inf) = is_le(nb_blocks, nb_recharges)

    if is_inf == 1:
        _get_resources(tokenId, caller, daily_harvests_len, daily_harvests, nb_blocks)
        
        # let (local erc20_addr) = gold_address_.read()
        let (local erc20_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)
        local amount = daily_harvest_gold * nb_blocks
        let (local amount_uint) = felt_to_uint256(amount)
        IERC20FrensCoin.mint(contract_address=erc20_addr, to=caller, amount=amount_uint)
        let (local curr_energy) = energy_level.read(tokenId)
        energy_level.write(tokenId, curr_energy + (daily_harvest_energy * nb_blocks))
        IM03Buildings.update_building_claimed_data(m03_addr, tokenId, building_list[0], nb_recharges - nb_blocks, current_block)

        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    else:
        # let (local erc1155_addr) = erc1155_address_.read()
        let (local erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
        _get_resources(tokenId, caller, daily_harvests_len, daily_harvests, nb_recharges)
        # let (local erc20_addr) = gold_address_.read()
        let (local erc20_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)
        local amount = daily_harvest_gold * nb_recharges
        let (local amount_uint) = felt_to_uint256(amount)
        IERC20FrensCoin.mint(contract_address=erc20_addr, to=caller, amount=amount_uint)

        # Pay energy
        let (local curr_energy) = energy_level.read(tokenId)
        energy_level.write(tokenId, curr_energy + (daily_harvest_energy * nb_recharges))
        IM03Buildings.update_building_claimed_data(m03_addr, tokenId, building_list[0], 0, current_block)

        return _claim_resources_iter(tokenId, caller, building_list_len - 5, building_list + 5, current_block)
    end
end

# Harvest resources (trees, rocks, mines) based on resource block position
@external
func harvest{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, 
    pos_start: felt
):
    alloc_locals

    let (controller) = Module.get_controller()
    let (m03_addr) = IModuleController.get_module_address(controller, ModuleIds.M03_Buildings)
    let (m01_addr) = IModuleController.get_module_address(controller, ModuleIds.M01_Worlds)
    let (erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    let (erc20_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)
    let (caller) = get_caller_address()

    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M02_Resources: caller is not owner of this tokenId"):
        assert bool = 1
    end

    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, pos_start)
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)

    # Get current id et assert qu'elles sont identiques 
    let building_unique_id = decomp_array[7] * 100 + decomp_array[8] * 10 + decomp_array[9]
    with_attr error_message("M02_Resources: there is not resources on this block"):
        assert_not_zero(building_unique_id)
    end

    let res_type = decomp_array[5] * 10 + decomp_array[6]
    let level = decomp_array[14]

    # Check resource of type 2 or 3 or 20
    # TODO : add 26
    local check = 0
    if res_type == 20:
        local check = 1
        tempvar range_check_ptr = range_check_ptr
    else:
        let (local check) = is_in_range(res_type, 1, 4)
        tempvar range_check_ptr = range_check_ptr
        with_attr error_message("M02_Resources: it's not possible to harvest this resource."):
            assert check = 1
        end
        tempvar range_check_ptr = range_check_ptr
    end

    # Fetch fixed data
    let (building_data : BuildingFixedData) = IM03Buildings.view_fixed_data(m03_addr, res_type, level)

    # Population
    let pop_required = building_data.pop_min
    let (pop_free) = population_.read(tokenId, 0)
    let (check_pop) = is_le(pop_required, pop_free)
    with_attr error_message("M02_Resources: not enough free population to harvest this resource."):
        assert check_pop = 1
    end
    
    # Costs of harvesting
    local daily_cost_struct : MultipleResources = building_data.daily_cost
    let daily_cost_gold = daily_cost_struct.gold_qty
    let daily_cost_energy = daily_cost_struct.energy_qty
    let (costs_len : felt, costs : felt*) = _get_costs_from_chain(
        building_data.daily_cost.nb_resources, building_data.daily_cost.resources_qty
    )

    # Resources
    let (check_resources) = _has_resources(caller, erc1155_addr, costs_len, costs, 1)
    with_attr error_message("M02_Resources: you don't have enough resources to harvest."):
        assert check_resources = 1
    end
    let (amount) = felt_to_uint256(daily_cost_gold)
    IERC20FrensCoin.burn(erc20_addr, caller, amount)

    # Energy
    let (current_energy) =  energy_level.read(tokenId)
    let (has_energy) = is_le(daily_cost_energy, current_energy)
    with_attr error_message("M03_Buildings: caller has not enough energy to recharge building."):
        assert has_energy = 1
    end
    energy_level.write(tokenId, current_energy - daily_cost_energy)

    # Get resources from harvesting
    let (gains_len : felt, gains : felt*) = Data._get_costs_from_chain(
        building_data.daily_harvest.nb_resources, building_data.daily_harvest.resources_qty
    )
    _get_resources(tokenId, caller, gains_len, gains, 1)

    if level  == 3:
        let (local comp) = Data._compose_chain_destroyed(16, decomp_array)
        IM01Worlds.update_map_block(m01_addr, tokenId, pos_start, comp)
        tempvar pedersen_ptr = pedersen_ptr
        return ()
    else:
        let (local comp) = Data._compose_chain_harvest(16, decomp_array, level + 1)
        IM01Worlds.update_map_block(m01_addr, tokenId, pos_start, comp)
        tempvar pedersen_ptr = pedersen_ptr
        return()
    end
end

# @notice checks player has the resources
# @param player address
# @param costs [ID_RES1, QTY1, ID_RES2, QTY2, ...]
@external
func has_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    player : felt, erc1155_addr : felt, costs_len : felt, costs : felt*, multiplier
) -> (bool : felt):

    let (caller) = get_caller_address()
    Module.only_approved()

    return _has_resources(player, erc1155_addr, costs_len, costs, multiplier)

end

func _has_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    player : felt, erc1155_addr : felt, costs_len : felt, costs : felt*, multiplier
) -> (bool : felt):
    alloc_locals 

    if costs_len == 0:
        return (1)
    end

    let (uint_id) = felt_to_uint256(costs[0])
    let (balance : Uint256) = IERC1155.balanceOf(erc1155_addr, player, uint_id)
    let (felt_balance) = uint256_to_felt(balance)

    let (local check) = is_le(costs[1] * multiplier, felt_balance)

    if check == 0:            
        return (0)
    end

    let (uint_qty) = felt_to_uint256(costs[1] * multiplier)
    IERC1155.burn(erc1155_addr, player, uint_id, uint_qty)

    return _has_resources(player, erc1155_addr, costs_len - 2, costs + 2, multiplier)
end


@external
func _reinitialize_resources_erc20{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    account : felt
):
    let (m01_addr) = m01_address.read()
    let (caller) = get_caller_address()
    assert m01_addr = caller


    let (gold_erc20_addr) = gold_address_.read()

    # Mint some Gold (minus the price of the map)
    let (amount : Uint256) = uint256_sub(Uint256(GOLD_START, 0), Uint256(MapsPrice.Map_1, 0))
    IERC20FrensCoin.burn(gold_erc20_addr, account, amount)

    return ()
end

# IERC20FrensCoin.mint(gold_erc20_addr, caller, amount)

##################
# VIEW FUNCTIONS #
##################

@view
func get_block_start{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (block_number : felt):
    let (block_number) = start_block_.read(tokenId)
    return (block_number)
end

@view
func get_latest_block{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (block_number : felt):
    let (block_number) = block_number_.read(tokenId)
    return (block_number)
end

# @notice gets population allocated and available
# @dev returns array [pop_available, pop_busy]
@view
func get_population{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (pop_len : felt, pop : felt*):
    alloc_locals
    let (local pop : felt*) = alloc()
    let (pop_available) = population_.read(tokenId, 0)
    let (pop_busy) = population_.read(tokenId, 1)
    pop[0] = pop_available
    pop[1] = pop_busy
    return (2, pop)
end

@view
func get_energy_level{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (energy : felt):
    let (energy) = energy_level.read(tokenId)
    return (energy)
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

    if nb_resources == 0:
        return (0, ret_array)
    end

    local b_index = 16 - (nb_resources * 3)
    let (local bArr) = bArray(b_index)

    Data._decompose(bArr, nb_resources * 3, resources_qty, ret_array, 0, 0, 0)

    let (local costs : felt*) = alloc()
    Data._compose_costs(nb_resources, ret_array, costs)

    return (nb_resources * 2, costs)
end

# @notice Update storage var population
# @param allocated : 1 means allocated to building, 0 means available, 3 to add new pop to land, 4 : delete pop from land, 5: reinitialize pop
@external
func update_population{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, allocate : felt, number : felt
):
    alloc_locals
    Module.only_approved()

    let (available_pop) = population_.read(tokenId, 0)
    let (busy_pop) = population_.read(tokenId, 1)

    if allocate == 1:
        with_attr error_message("M01_Resources: not enough population to allocate."):
            assert_le(number, available_pop)
        end
        population_.write(tokenId, 1, busy_pop + number)
        population_.write(tokenId, 0, available_pop - number)
        tempvar syscall_ptr = syscall_ptr
        return ()
    end

    if allocate == 0:
        population_.write(tokenId, 1, busy_pop - number)
        population_.write(tokenId, 0, available_pop + number)
        tempvar syscall_ptr = syscall_ptr
        return ()
    end

    if allocate == 3:
        population_.write(tokenId, 0, available_pop + number)
        tempvar syscall_ptr = syscall_ptr
        return ()
    end

    if allocate == 4:
        with_attr error_message("M01_Resources: not enough population to allocate."):
            assert_le(number, available_pop)
        end
        population_.write(tokenId, 0, available_pop - number)
        return ()
    end

    if allocate == 5:
        population_.write(tokenId, 0, number)
        population_.write(tokenId, 1, 0)
        return ()
    end

    return ()
end

# @notice updates start_block_ number on initialization
# @notice updates last block_number_ needed to calculate costs
@external
func update_block_number{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, _block_nb : felt
):
    alloc_locals
    Module.only_approved()

    block_number_.write(tokenId, _block_nb)

    let (local start) = start_block_.read(tokenId)
    if start == 0:
        start_block_.write(tokenId, _block_nb)
        return ()
    end

    return ()
end

@external
func _receive_resources_start{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    account : felt
):
    alloc_locals
    Module.only_approved()

    let (_initialized) = initialized_.read(tokenId)
    assert _initialized = 0

    let (controller) = Module.get_controller()
    let (erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)

    let (local amount_resources) = felt_to_uint256(RESOURCES_START)
    let (local _food) = felt_to_uint256(ResourcesType.Meat)
    IERC1155.mint(contract_address=erc1155_addr, to=account, id=_food, amount=amount_resources)

    initialized_.write(tokenId, 1)

    return ()
end

@external
func _pay_frens_coins{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    account : felt,
    amount: Uint256
):
    Module.only_approved()
    let (controller) = Module.get_controller()
    let (gold_erc20_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)

    # Mint some Gold (minus the price of the map)
    IERC20FrensCoin.burn(gold_erc20_addr, account, amount)

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

func _get_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, caller : felt, res_len : felt, res : felt*, multiplier : felt
):
    alloc_locals
    if res_len == 0:
        return ()
    end

    # Mint Resources
    let (controller) = Module.get_controller()
    let (local erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    local amount_felt = res[1] * multiplier
    local id_felt = res[0]
    let (local amount) = felt_to_uint256(amount_felt)
    let (local res_id) = felt_to_uint256(id_felt)
    IERC1155.mint(contract_address=erc1155_addr, to=caller, id=res_id, amount=amount)

    return _get_resources(tokenId, caller, res_len - 2, res + 2, multiplier)
end

@external
func _get_resources_destroyed{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, account : felt, res_len : felt, res : felt*, multiplier : felt
):
    alloc_locals
    Module.only_approved()

    if res_len == 0:
        return ()
    end

    # Mint Resources
    let (controller) = Module.get_controller()
    let (local erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    local amount_felt = res[1] * multiplier
    local id_felt = res[0]
    let (local amount) = felt_to_uint256(amount_felt)
    let (local res_id) = felt_to_uint256(id_felt)
    IERC1155.mint(contract_address=erc1155_addr, to=account, id=res_id, amount=amount)

    return _get_resources(tokenId, account, res_len - 2, res + 2, multiplier)
end

func _destroy_resources_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, index_len : felt, index: felt*, building_unique_id: felt
):
    alloc_locals

    let (controller) = Module.get_controller()
    let (m01_addr) = IModuleController.get_module_address(controller, ModuleIds.M01_Worlds)

    # Get block info
    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, index[0])
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)

    let current = decomp_array[7] * 100 + decomp_array[8] * 100 + decomp_array[9]

    if current != building_unique_id :
        return ()
    end 
    
    # Recompose with resources destroyed
    let (comp) = Data._compose_chain_destroyed(16, decomp_array)

    # Update map Array
    IM01Worlds.update_map_block(m01_addr, tokenId, index[0], comp)

    return _destroy_resources_map(tokenId, index_len - 1, index + 1, building_unique_id)
end

# Operation : 1 == addition, 0 == soustraction
@external
func _update_energy{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, operation: felt, val : felt
):
    alloc_locals
    Module.only_approved()

    let (local is_ok) = is_le(operation, 1)
    with_attr error_message("M02_Resources: wrong operation."):
        assert is_ok = 1
    end

    let (local current_energy) = energy_level.read(tokenId)
    if operation == 1:
        energy_level.write(tokenId, current_energy + val)
        tempvar syscall_ptr = syscall_ptr
        return ()
    else:
        energy_level.write(tokenId, current_energy - val)
        tempvar syscall_ptr = syscall_ptr
        return ()
    end
end

# Réinitialize functions
@external
func _reinitialize_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, caller: felt
):
    alloc_locals
    Module.only_approved()

    # burn frensCoins
    let (controller) = Module.get_controller()
    let (erc20_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Gold)
    let (_balance) = IERC20FrensCoin.balanceOf(erc20_addr, caller)
    IERC20FrensCoin.burn(erc20_addr, caller, _balance)

    # burn all resources 
    let (erc1155_addr) = IModuleController.get_external_contract_address(controller, ExternalContractsIds.Resources)
    _burn_resources(caller, erc1155_addr, 1)

    return ()
end

func _burn_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    player : felt, erc1155_addr : felt, index: felt
):
    alloc_locals 

    if index == ResourcesType.count:
        return ()
    end

    let (local uint_id) = felt_to_uint256(index)
    let (local balance : Uint256) = IERC1155.balanceOf(erc1155_addr, player, uint_id)

    if index != 3:
        IERC1155.burn(erc1155_addr, player, uint_id, balance)
        return _burn_resources(player, erc1155_addr, index + 1)
    end 

    let (local felt_balance) = uint256_to_felt(balance)
    let (local check) = is_le(felt_balance, RESOURCES_START)

    if check == 0:   
        local _amount = felt_balance - RESOURCES_START
        let (local _amount_uint) = felt_to_uint256(_amount)
        IERC1155.burn(erc1155_addr, player, uint_id, _amount_uint)
        return _burn_resources(player, erc1155_addr, index + 1)
    else:
        local _amount = RESOURCES_START - felt_balance
        let (local _amount_uint) = felt_to_uint256(_amount)
        IERC1155.burn(erc1155_addr, player, uint_id, _amount_uint)
        return _burn_resources(player, erc1155_addr, index + 1)
    end
end