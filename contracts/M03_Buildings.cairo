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

# DYNAMIC DATA OF BUILDING
# @storage_var
# func _building_global_data(type : felt, storage_index : felt) -> (res : felt):
# end
# storage_index = BuildingFixedData.upgrade_cost, BuildingFixedData.daily_cost, BuildingFixedData.daily_harvest, BuildingFixedData.pop_max, BuildingFixedData.pop_min

@storage_var
func building_global_data(type : felt) -> (data : BuildingFixedData):
end

# DYNAMIC DATA OF BUILDING

# Nb of building for a user
@storage_var
func building_index(token_id : Uint256) -> (index : felt):
end

@storage_var
func _building_data(token_id : Uint256, building_id : felt, storage_index : felt) -> (res : felt):
end
# # storage_index = BuildingData.type_id, BuildingData.level, BuildingData.pop_min, BuildingData.pop_max, BuildingData.time_created

##########
# EVENTS #
##########

# Build a building
# Destroy a building

###############
# CONSTRUCTOR #
###############

# TODO : Add initialize Controller Address

# Initialize fixed data (can be done only once)
@external
func initialize_global_data{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    type_len : felt, type : felt*, level : felt, building_cost_len : felt, building_cost : felt
):
    alloc_locals

    # array de buildingsIds to add [1 ... 22]
    # nb de levels possible pour tous les buildings
    #

    # Add checks
    # Add initialized_building storage_var ? so it's initialized only once

    if building_id_len == 0:
        return ()
    end

    local h : HarvestResourceBuilding
    h.resource_id = resource_id[0]
    h.resource_qty = resource_qty[0]

    %{ print ('resource_id : ',  ids.resource_id[0]) %}
    %{ print ('resource_qty : ',  ids.resource_qty[0]) %}

    building_res_harvest.write(building_id[0], level, h)

    return initialize_building_harvest(
        building_id_len - 1,
        building_id + 1,
        level,
        resource_id_len - 1,
        resource_id + 1,
        resource_qty_len - 1,
        resource_qty + 1,
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
    # Check caller is owner of token_id

    # Fetch resources needed to build building_id

    # Check owner can build (has enough resources)

    # Check owner can build on this position on the map

    # build :
    #   increment building_by_user_storage var
    #   decrement resources total
    #   allocate population

    # Calculate resources and update la storage_var du M02_Resources avec les daily costs et les daily recettes
    return ()
end

@external
func destroy{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, building_id : felt, level : felt
):
    # Check caller is owner of token_id
    # destroy building : decrement Cost et Recettes dans storage_var resources + storage_var
    # Potentially get back some of the resources ?

    return ()
end

@external
func repair{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    token_id : Uint256, building_id : felt, level : felt
):
    # Check caller is owner of token_id
    # Fetch resources needed to build
    # Check owner can build (has enough resources)
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

######################
# INTERNAL FUNCTIONS #
######################

# _can_build()
#   _has_enough_resources()
#   _
# _fetch_costs

# @view
# func get_res_harvest{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
#     building_id : felt, level : felt
# ) -> (harvest : HarvestResourceBuilding):
#     let (res : HarvestResourceBuilding) = building_res_harvest.read(building_id, level)
#     return (res)
# end

# # OLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLDOLD
# @storage_var
# func buildings_upgrades(building_id : felt, level : felt) -> (cost : Cost):
# end

# @storage_var
# func buildings_daily_costs(building_id : felt, level : felt) -> (cost : Cost):
# end

# @storage_var
# func building_population(building_id : felt, level : felt) -> (max_pop : felt):
# end

# @storage_var
# func building_res_harvest(building_id : felt, level : felt) -> (harvest : HarvestResourceBuilding):
# end

# @storage_var
# func building_gold_harvest(building_id : felt, level : felt) -> (amount : felt):
# end

# @storage_var
# func total_daily_cost(token_id : Uint256) -> (daily_cost : ResourcesData):
# end

# @external
# func initialize_building_harvest{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
#     building_id_len : felt,
#     building_id : felt*,
#     level : felt,
#     resource_id_len : felt,
#     resource_id : felt*,
#     resource_qty_len : felt,
#     resource_qty : felt*,
# ):
#     alloc_locals

# # array de buildingsIds to add [1 ... 22]
#     # nb de levels possible pour tous les buildings
#     #

# # Add checks
#     # Add initialized_building storage_var ? so it's initialized only once

# if building_id_len == 0:
#         return ()
#     end

# local h : HarvestResourceBuilding
#     h.resource_id = resource_id[0]
#     h.resource_qty = resource_qty[0]

# %{ print ('resource_id : ',  ids.resource_id[0]) %}
#     %{ print ('resource_qty : ',  ids.resource_qty[0]) %}

# building_res_harvest.write(building_id[0], level, h)

# return initialize_building_harvest(
#         building_id_len - 1,
#         building_id + 1,
#         level,
#         resource_id_len - 1,
#         resource_id + 1,
#         resource_qty_len - 1,
#         resource_qty + 1,
#     )
# end
