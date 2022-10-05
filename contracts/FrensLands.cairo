%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.math import assert_not_zero, assert_le, assert_not_equal
from starkware.cairo.common.math import unsigned_div_rem

from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
    get_block_number,
)
from starkware.cairo.common.math_cmp import is_le

from contracts.utils.interfaces import IFrensLandsStorage, IModuleController, IResourcesSpawned, IBuildings
from contracts.utils.tokens_interfaces import IERC721Lands

from contracts.library.library_frenslands import FrensLands
from contracts.library.library_compute import Compute
from contracts.library.library_module import Module
from contracts.library.library_data import Data

from lib.openzeppelin.upgrades.library import Proxy
from contracts.utils.game_constants import NUMBER_OF_BLOCKS, MAP_Y_SIZE
from contracts.utils.game_structs import (
    ModuleIds,
    BiomeIds,
    ExternalContractsIds,
    ResourcesType,
    BuildingData,
    InfrastructureTypes,
)
from contracts.Resources.Resources_Data import ResourcesFixedData, RS_COUNTER
from contracts.Buildings.Buildings_Data import MultipleResources, BUILDINGS_COUNTER

// A modifier ensuite par mon storage dynamique
from contracts.FrensLands_Storage import (
    land_to_owner, 
    owner_to_land, 
    land_to_biome,
    balance,
    player_rs_idx,
    player_building_idx,
    player_building_counter,
    player_building,
    frens_available,
    frens_total
)

// ----------
// EVENTS 
// ----------

@event
func NewGame(
    owner: felt,
    land_id : felt,
    biome_id : felt,
    time: felt
) {
}

@event
func ResetGame(
    owner: felt, 
    time: felt,
    land_id: felt,
) {
}

@event
func HarvestResource(
    owner: felt,
    land_id: felt,
    time: felt,
    resource_type: felt,
    resource_uid: felt,
    block_comp: felt,
    pos_x: felt,
    pos_y: felt,
) {
}

@event
func Destroy(
    owner: felt,
    land_id: felt,
    timestamp: felt,
    building_type_id: felt,
    building_uid: felt,
    block_comp: felt,
    pos_x: felt,
    pos_y: felt,
) {
}

@event
func Build(
    owner: felt,
    land_id: felt,
    time: felt,
    building_type_id: felt,
    building_uid: felt,
    block_comp: felt,
    pos_x: felt,
    pos_y: felt,
) {
}

@event
func Repair(
    owner: felt,
    land_id: felt,
    time: felt,
    building_type_id: felt,
    building_uid: felt,
    pos_x: felt,
    pos_y: felt
) {
}

@event
func Move(
    owner: felt,
    land_id: felt,
    time: felt,
    infra_type: felt,
    infra_type_id: felt,
    infra_uid: felt,
    pos_x: felt,
    pos_y: felt,
    new_pos_x: felt, 
    new_pos_y: felt,
) {
}

@event
func FuelProduction(
    owner: felt,
    land_id: felt,
    time: felt,
    building_type_id: felt,
    building_uid: felt,
    pos_x: felt,
    pos_y: felt,
    nb_blocks: felt,
) {
}

@event
func Claim(
    owner: felt,
    land_id: felt,
    time: felt,
    block_number : felt,
    building_counter: felt,
) {
}


//##############
// CONSTRUCTOR #
//##############

// @notice: initialize Module Controller & proxy admin address
// @param address_of_controller : module controller contract address
// @param proxy_admin : proxy admin address
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address_of_controller: felt, proxy_admin: felt
) {
    Module.initialize_controller(address_of_controller);
    Proxy.initializer(proxy_admin);
    return ();
}

// @notice Set new proxy implementation
// @dev Can only be set by the arbiter
// @param new_implementation: New implementation contract address
@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}


// @notice : Start game and initialize land
// @param land_id : hash of account of player + random nb calculated in front 
// @param biome_id : id of biome to initialize 
// @param tokenId : id of land NFT owned by player
@external
func start_game{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(land_id: felt, biome_id : felt, tokenId : Uint256) -> () {
    alloc_locals;

    let (caller) = get_caller_address();
    let (controller) = Module.get_controller();
    let (lands_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Lands
    );

    // // Check caller is owner of tokenId
    // let (local owner : felt) = IERC721Maps.ownerOf(lands_erc721_addr, tokenId);
    // with_attr error_message("Start game: caller is not owner of this tokenId"){
    //     assert owner = caller;
    // }
    // // Update land owner 
    // // land_id == tokenId to felt 
    // owner_to_land.write(caller, land_id);

    // Check caller has not already a land
    let (has_land) = owner_to_land.read(caller);
    with_attr error_message("Start game: caller has already initialized a land.") {
        assert has_land = 0;
    }

    // Check caller is owner of land & update biomeId
    // let (local owner : felt) = IERC721Lands.ownerOf(lands_erc721_addr, tokenId);
    // %{ print (' owner', ids.owner) %}
    // // let biome : felt = BiomeIds.Grass;
    // if (owner != caller) {
    //     %{ print ('dans le if avant : ', ids.biome_id) %}
    //     biome_id = BiomeIds.Grass;
    // }
    land_to_biome.write(land_id, biome_id);

    // Storage_vars land_id to owner et inversement
    land_to_owner.write(land_id, caller);
    owner_to_land.write(caller, land_id);

    let (local resources_count) = FrensLands._initialize_maps(land_id, 1, 1, 1, 0, 0, 0, 0, 1);
    // sauvegarder le dernier unique_id de la ressource spawned
    _update_rs_idx(land_id, resources_count);

    // // Save cabin into array of buildings + update counter & idx
    _update_building_player(land_id, 1, 1, 2008, 1, 0, 100);

    _update_building_counter(land_id, 1);
    _update_building_idx(land_id, 1);

    _increase_resource(land_id, 3, 20);
    _increase_frens(land_id, 1);

    let (time) = get_block_timestamp();
    NewGame.emit(caller, land_id, biome_id, time);

    return ();
}

// @notice harvest resources spawned on map
// @param pos_x : position of resource on map block 
// @param pos_y
@external
func harvest{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    pos_x: felt,
    pos_y : felt
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local resources_addr) = IModuleController.get_module_address(
        controller, ModuleIds.ResourcesSpawned
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before harvesting.") {
        assert_not_zero(land_id);
    }

    // Get block information and check harvest is possible 
    let (local resource_type : felt, local resource_type_id : felt, local resource_uid : felt, local level : felt) = FrensLands._decompose_block_comp(
        land_id, pos_x, pos_y
    );
    with_attr error_message("Harvest: it's not possible to harvest this resource.") {
        assert resource_type = InfrastructureTypes.TSpawned;
        assert_le(resource_type_id, RS_COUNTER); 
        assert_not_zero(resource_uid);
    }

    // Fetch fixed data of resource to harvest
    let (resources_data: ResourcesFixedData) = IResourcesSpawned.read_rs_data(
        resources_addr, resource_type_id, 1
    );
    // Check sufficient population to harvest spawned resource : [total population, available population]
    let pop_required = resources_data.popFreeRequired;
    let (pop_len: felt, pop: felt*) = get_pop(land_id);
    let check_pop = is_le(pop_required, pop[1]);
    with_attr error_message("Harvest: you don't have enough available frens to harvest this resource.") {
        assert_not_zero(check_pop);
    }

    // Costs of harvesting
    let (costs_array_len : felt, costs_array : felt*) = FrensLands._decompose_resources_comp(resources_data.harvestingCost_qty);
    let (can_spend_resources) = _spend_resources(land_id, costs_array_len, costs_array, 1);
    with_attr error_message("Harvest: you don't have enough resources to harvest.") {
        assert can_spend_resources = 1;
    }
    // Get resources from harvesting
    let (gains_array_len : felt, gains_array : felt*) = FrensLands._decompose_resources_comp(resources_data.harvestingGain_qty);
    _increase_resources(land_id, gains_array_len, gains_array, 1);

    // Update resource level
    if (level == 3) {
        FrensLands._update_map_block(land_id, pos_x, pos_y, 0);
        let (local timestamp) = get_block_timestamp();
        HarvestResource.emit(caller, land_id, timestamp, resource_type_id, resource_uid, 0, pos_x, pos_y);
        tempvar pedersen_ptr = pedersen_ptr;
        return ();
    } else {
        let (local comp) = Data._compose_chain(resource_type, resource_type_id, resource_uid, level + 1);
        FrensLands._update_map_block(land_id, pos_x, pos_y, comp);
        let (local timestamp) = get_block_timestamp();
        HarvestResource.emit(caller, land_id, timestamp, resource_type_id, resource_uid, comp, pos_x, pos_y);
        tempvar pedersen_ptr = pedersen_ptr;
        return ();
    }
}

// @notice build a building
// @param pos_x
// @param pos_y
// @param building_type_id : type of building being built
@external
func build{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    pos_x: felt, 
    pos_y : felt,
    building_type_id : felt,
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local buildings_addr) = IModuleController.get_module_address(
        controller, ModuleIds.Buildings
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before building.") {
        assert_not_zero(land_id);
    }

    // Get block information and check harvest is possible 
    let (local resource_type : felt, local resource_type_id : felt, local resource_uid : felt, local level : felt) = FrensLands._decompose_block_comp(
        land_id, pos_x, pos_y
    );
    with_attr error_message("Building: it's not possible to build here, block is not free.") {
        assert resource_type = 0;
        assert resource_type_id = 0;
        assert resource_uid = 0;
    }

    // Fetch fixed data building 
    let (build_data: MultipleResources) = IBuildings.read_build_data(buildings_addr, building_type_id, level);
    with_attr error_message("Building: it's not possible to build this building type.") {
        assert_not_zero(build_data.comp);
        assert_le(building_type_id, BUILDINGS_COUNTER);
    }

    // Update population
    _increase_frens(land_id, build_data.popAdd);
    _alloc_frens(land_id, build_data.popRequired);

    // Cost of building 
    let (costs_array_len : felt, costs_array : felt*) = FrensLands._decompose_resources_comp(build_data.comp);
    let (can_spend_resources) = _spend_resources(land_id, costs_array_len, costs_array, 1);
    with_attr error_message("Build: you don't have enough resources to build.") {
        assert can_spend_resources = 1;
    }

    // Increment counter & index buildings
    let (counter) = get_building_counter(land_id);
    _update_building_counter(land_id, counter + 1);
    let (building_uid) = get_building_idx(land_id);
    _update_building_idx(land_id, building_uid + 1);

    // Update map block 
    let (local comp) = Data._compose_chain(InfrastructureTypes.TBuilding, building_type_id, building_uid + 1, 1);
    FrensLands._update_map_block(land_id, pos_x, pos_y, comp);

    // Save player building state
    _update_building_player(land_id, building_uid + 1, building_type_id, pos_x * 100 + pos_y, 1, build_data.popRequired, 0);
    let (current_block) = get_block_number();
    _update_building_recharges(land_id, building_uid + 1, 3, current_block);

    // Emit build event 
    let (timestamp) = get_block_timestamp();
    Build.emit(caller, land_id, timestamp, building_type_id, building_uid + 1, comp, pos_x, pos_y);

    return();
}

// @notice build a building
// @param pos_start : land block number where building starts
// @param resource_type : type of building being built
@external
func destroy_building{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    pos_x: felt,
    pos_y: felt
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local buildings_addr) = IModuleController.get_module_address(
        controller, ModuleIds.Buildings
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before playing.") {
        assert_not_zero(land_id);
    }

    // Get block information and check destroy is possible
    let (local infrastructure_type : felt, local building_type_id : felt, local building_uid : felt, local level : felt) = FrensLands._decompose_block_comp(
        land_id, pos_x, pos_y
    );

    with_attr error_message("Destroy: there is no building to destroy on this block.") {
        assert infrastructure_type = InfrastructureTypes.TBuilding;
        assert_not_zero(building_type_id);
        assert_not_zero(building_uid);
        assert_not_equal(building_type_id, 1); // can't destroy a cabin
    }

    // Fetch fixed data building 
    let (build_data: MultipleResources) = IBuildings.read_build_data(buildings_addr, building_type_id, level);

    // Dealloc population 
    _dealloc_frens(land_id, build_data.popRequired);
    _decrease_frens(land_id, build_data.popAdd);
    
    // Get resources from destroying building (half of resources used to build)
    let (costs_array_len : felt, costs_array : felt*) = FrensLands._decompose_resources_comp(build_data.comp);
    _increase_resources_divided(land_id, costs_array_len, costs_array, 2);

    // Update counter buildings
    let (counter) = get_building_counter(land_id);
    _update_building_counter(land_id, counter - 1);

    // Update map block 
    FrensLands._update_map_block(land_id, pos_x, pos_y, 0);

    // Delete player building state
    _destroy_building_player(caller, building_uid);

    // Emit Destroy event 
    let (timestamp) = get_block_timestamp();
    Destroy.emit(caller, land_id, timestamp, building_type_id, building_uid, 0, pos_x, pos_y);

    return();
}


// @notice repair a building
// @param pos_x : land block number where building starts
// @param pos_y
@external
func repair_building{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    pos_x: felt,
    pos_y: felt,
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local buildings_addr) = IModuleController.get_module_address(
        controller, ModuleIds.Buildings
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before playing.") {
        assert_not_zero(land_id);
    }

    // Get block information and check repair is possible
    let (local infrastructure_type : felt, local building_type_id : felt, local building_uid : felt, local level : felt) = FrensLands._decompose_block_comp(
        land_id, pos_x, pos_y
    );
    with_attr error_message("Repair: there is no building to repair on this block.") {
        assert infrastructure_type = InfrastructureTypes.TBuilding;
        assert_not_zero(building_type_id);
        assert_not_zero(building_uid);
    }

    let (decay_level) = get_building_decay(land_id, building_uid);
    if (decay_level == 0) {
        return ();
    }

    // Fetch repair data 
    let (repair_data: MultipleResources) = IBuildings.read_repair_data(buildings_addr, building_type_id);
    let (costs_array_len : felt, costs_array : felt*) = FrensLands._decompose_resources_comp(repair_data.comp);

    // TODO : divide resources to spend to repair depending on decay level
    let (can_spend_resources) = _spend_resources(land_id, costs_array_len, costs_array, 1);
    with_attr error_message("Repair: you don't have enough resources to repair this building.") {
        assert can_spend_resources = 1;
    }

    // Update population
    _increase_frens(land_id, repair_data.popAdd);
    // _alloc_frens(land_id, build_data.popRequired);

    // Update decay level in player building
    _update_building_decay(land_id, building_uid, 0);

    // Emit Repair event 
    let (timestamp) = get_block_timestamp();
    Repair.emit(caller, land_id, timestamp, building_type_id, building_uid, pos_x, pos_y);

    return();
}

// @notice repair a building
// @param pos_x : land block number where building starts
// @param pos_y
@external
func move_infrastructure{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    pos_x: felt,
    pos_y: felt,
    new_pos_x: felt,
    new_pos_y: felt,
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local buildings_addr) = IModuleController.get_module_address(
        controller, ModuleIds.Buildings
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before playing.") {
        assert_not_zero(land_id);
    }

    // Get block information and check if move possible 
    let (local infra_type : felt, local infra_type_id : felt, local infra_uid : felt, local level : felt) = FrensLands._decompose_block_comp(
        land_id, pos_x, pos_y
    );
    with_attr error_message("Move: there is nothing to move.") {
        assert_not_zero(infra_type);
        assert_not_zero(infra_type_id);
        assert_not_zero(infra_uid);
    }
    with_attr error_message("Move: it's not possible to move this kind of resource.") {
        assert_not_equal(infra_type, InfrastructureTypes.TSpawned);
    }

    // Check destination block is empty 
    let (local dest_infra_type : felt, local dest_infra_type_id : felt, local dest_infra_uid : felt, local dest_level : felt) = FrensLands._decompose_block_comp(
        land_id, new_pos_x, new_pos_y
    );
    with_attr error_message("Move: the destination block is not free.") {
        assert dest_infra_type = 0;
        assert dest_infra_type_id = 0;
        assert dest_infra_uid = 0;
    }

    // Move block
    let (local comp) = Data._compose_chain(infra_type, infra_type_id, infra_uid, level);
    FrensLands._update_map_block(land_id, new_pos_x, new_pos_y, comp);
    FrensLands._update_map_block(land_id, pos_x, pos_y, 0);

    if (infra_type == InfrastructureTypes.TBuilding) {
        _update_building_player_pos(land_id, infra_uid, (new_pos_x * 100) + new_pos_y);
        return ();
    }

    // Emit Move event 
    let (timestamp) = get_block_timestamp();
    Move.emit(caller, land_id, timestamp, infra_type, infra_type_id, infra_uid, pos_x, pos_y, new_pos_x, new_pos_y);

    return ();
}

// @notice fuel production of a building
// @param pos_x : land block number where building starts
// @param pos_y
// @param nb_days : nb of blocks to fuel production
@external
func fuel_building_production{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    pos_x: felt,
    pos_y: felt,
    nb_days: felt,
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local buildings_addr) = IModuleController.get_module_address(
        controller, ModuleIds.Buildings
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before playing.") {
        assert_not_zero(land_id);
    }

    if (nb_days == 0) {
        return ();
    }

    // Get block information and check destroy is possible
    let (local infrastructure_type : felt, local building_type_id : felt, local building_uid : felt, local level : felt) = FrensLands._decompose_block_comp(
        land_id, pos_x, pos_y
    );
    with_attr error_message("Recharge: there is no building to recharge on this block.") {
        assert infrastructure_type = InfrastructureTypes.TBuilding;
        assert_not_zero(building_type_id);
        assert_not_zero(building_uid);
    }

    // fetch daily costs 
    let (costs_array_len: felt, costs_array: felt*) = IBuildings.read_maintenance_cost_data(buildings_addr, building_type_id, level);
    with_attr error_message("Recharge: it's not possible to recharge this building type.") {
        assert_not_zero(costs_array_len);
        assert_le(building_type_id, BUILDINGS_COUNTER);
    }

    // Cost of building 
    let (can_spend_resources) = _spend_resources(land_id, costs_array_len, costs_array, nb_days);
    with_attr error_message("Recharge: you don't have enough resources to recharge this building.") {
        assert can_spend_resources = 1;
    }

    // Update la partie recharge de l'array building du player 
    let (current_block) = get_block_number();
    _update_building_recharges(land_id, building_uid, nb_days, current_block);

    // Emit FuelProduction event 
    let (timestamp) = get_block_timestamp();
    FuelProduction.emit(caller, land_id, timestamp, building_type_id, building_uid, pos_x, pos_y, nb_days);

    return ();

}

// @notice fuel production of a building
// @param pos_x : land block number where building starts
// @param pos_y
// @param nb_days : nb of blocks to fuel production
@external
func claim_production{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local buildings_addr) = IModuleController.get_module_address(
        controller, ModuleIds.Buildings
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before playing.") {
        assert_not_zero(land_id);
    }

    let (current_counter) = get_building_counter(land_id);
    let (current_block) = get_block_number();
    _claim_production_iter(buildings_addr, land_id, current_counter, 1, current_block);

    // Emit Claim event 
    let (timestamp) = get_block_timestamp();
    Claim.emit(caller, land_id, timestamp, current_block, current_counter);

    return ();

}

func _claim_production_iter{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    buildings_addr: felt,
    land_id: felt,
    counter: felt,
    index: felt,
    current_block: felt,
) {
    alloc_locals;

    // On a loupé à travers tous les buildings 
    if (counter == 0) {
        return ();
    }

    let (building_type_id: felt, nb_recharges: felt, last_claim: felt)= get_building_claimable(land_id, index);

    if (building_type_id == 0) {
        // Means building was destroyed
        return _claim_production_iter(buildings_addr, land_id, counter - 1, index + 1, current_block);
    }

    if (nb_recharges == 0) {
        // Building is not claimable because not recharged
        return _claim_production_iter(buildings_addr, land_id, counter - 1, index + 1, current_block);
    }

    // Check if recharges, how many recharges can be claimed 
    let is_ready = is_le(last_claim + 1, current_block);
    if (is_ready == 0) {
        // Building production not ready
        return _claim_production_iter(buildings_addr, land_id, counter - 1, index + 1, current_block);
    }

    let (gains_len: felt, gains: felt*) = IBuildings.read_production_daily_data(buildings_addr, building_type_id, 1);
    // Get nb of blocks claimable 
    local nb_blocks = current_block - last_claim;
    local is_inf = is_le(nb_blocks, nb_recharges);
    if (is_inf == 1) {
        // On donne nb_blocks fois le gains
        _increase_resources(land_id, gains_len, gains, nb_blocks);
        _update_building_recharges(land_id, index, nb_recharges - nb_blocks, current_block);
        return _claim_production_iter(buildings_addr, land_id, counter - 1, index + 1, current_block);
    } else {
        // On donne nb_recharges fois le gains
        _increase_resources(land_id, gains_len, gains, nb_recharges);
        _update_building_recharges(land_id, index, 0, current_block);
        return _claim_production_iter(buildings_addr, land_id, counter - 1, index + 1, current_block);
    }
}

// @notice reinit game
@external
func reinit_game{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
) {
    alloc_locals;

    let (controller) = Module.get_controller();
    let (caller) = get_caller_address();
    let (local buildings_addr) = IModuleController.get_module_address(
        controller, ModuleIds.Buildings
    );

    // Check caller has a land 
    let (land_id) = owner_to_land.read(caller);
    with_attr error_message("Caller has no land. You need to initialize a land before playing.") {
        assert_not_zero(land_id);
    }

    let (counter) = get_building_counter(land_id);
    // destroy all buildings
    _destroy_building_player_all(land_id, 1, counter);

    // Reinit map
    let (local resources_count) = FrensLands._initialize_maps(land_id, 1, 1, 1, 0, 0, 0, 0, 1);
    
    // Reinit counters & idx buildings 
    _update_rs_idx(land_id, resources_count);
    _update_building_counter(land_id, 1);

    // Reset balances 
    balance.write(land_id, ResourcesType.Wood, 0);
    balance.write(land_id, ResourcesType.Rock, 0);
    balance.write(land_id, ResourcesType.Food, 20);
    balance.write(land_id, ResourcesType.Metal, 0);
    balance.write(land_id, ResourcesType.Coal, 0);
    balance.write(land_id, ResourcesType.Energy, 0);
    balance.write(land_id, ResourcesType.Coins, 0);

    // Reset frens
    frens_available.write(land_id, 1);
    frens_total.write(land_id, 1);

    // Emit ResetGame event 
    let (timestamp) = get_block_timestamp();
    ResetGame.emit(caller, timestamp, land_id);

    return ();
}

// ---------------------------------------------------- GENERAL ----------------------------------------------------

// @notice get id of land from account address
// @param owner : account address owning land_id
// @return land_id
@view
func get_land_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner : felt
) -> (land_id : felt) {

    let (land_id) = owner_to_land.read(owner);

    return (land_id,);
}

// @notice get account address playing land_id
// @param land_id
// @return owner: account address
@view
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt
) -> (owner : felt) {
    let (owner) = land_to_owner.read(land_id);

    return (owner,);
}

// @notice get account address playing land_id
// @return owner: account address
@view
func get_biome_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt
) -> (biome_id : felt) {
    let (biome_id) = land_to_biome.read(land_id);

    return (biome_id,);
}

// @notice get land information for all 640 blocks 
// @param land_id
// @return array of comp
@view
func get_map_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt
) -> (data_len : felt, data: felt*) {
    alloc_locals;
    
    let (local data : felt*) = alloc();

    _get_map_array_iter(land_id, data, 1, 1, 1);

    return (NUMBER_OF_BLOCKS, data,);
}

func _get_map_array_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    land_id: felt, 
    data: felt*, 
    index: felt,
    pos_x: felt, 
    pos_y: felt,
) {
    alloc_locals;
    let (local value) = FrensLands._read_map_block(land_id, pos_x, pos_y);
    data[0] = value;

    if (pos_y == MAP_Y_SIZE) {
        return _get_map_array_iter(land_id, data + 1, index + 1, pos_x + 1, 1);
    }

    if (index == NUMBER_OF_BLOCKS) {
        return ();
    }

    return _get_map_array_iter(land_id, data + 1, index + 1, pos_x, pos_y + 1);
}

@view
func read_map_block{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, pos_x: felt, pos_y: felt,
) -> (data: felt) {
    let (data : felt) = FrensLands._read_map_block(land_id, pos_x, pos_y);

    return (data,);
}


// ---------------------------------------------------- RESOURCES MANAGEMENT ----------------------------------------------------

// @notice Spend resource
// @param land_id
// @param resource_id : id of resource to update
// @param amount : amount to substract to current balance
func _spend_resource{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt, resource_id: felt, amount: felt
) -> (success: felt) {
    alloc_locals;

    let (local current_balance) = balance.read(land_id, resource_id);
    local can_spend = is_le(amount, current_balance);
    if (can_spend == 0) {
        return (FALSE,);
    }

    let new_balance = current_balance - amount;
    balance.write(land_id, resource_id, new_balance);

    return (TRUE,);
}

// @notice Spend multiple resources
// @param land_id
// @param resources_len : length of array of resources 
// @param resources : array with 
func _spend_resources{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt, 
    resources_len: felt, 
    resources: felt*, 
    multiplier: felt
) -> (success: felt) {
    alloc_locals;

    if (resources_len == 0) {
        return (TRUE,);
    }

    let (is_spent) = _spend_resource(land_id, resources[0], resources[1] * multiplier);
    if (is_spent == FALSE) {
        return (FALSE,);
    }

    return _spend_resources(land_id, resources_len - 2, resources + 2, multiplier);
}

// @notice Increase player balance of a resource
// @param land_id : token id of erc721 land
// @param resource_id : id of resource to update
// @param amount : amount to add or substract
func _increase_resource{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt, 
    resource_id: felt, 
    amount: felt
) {
    let (current_balance) = balance.read(land_id, resource_id);
    let new_balance = current_balance + amount;
    balance.write(land_id, resource_id, new_balance);

    return ();
}

// @notice Increase player balance for multiple resource
// @param land_id
// @param resources_len : length of array of resources 
// @param resources : array with 
// @param multiplier : multiplier
func _increase_resources{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt, resources_len: felt, resources: felt*, multiplier: felt
) {
    if (resources_len == 0) {
        return ();
    }

    _increase_resource(land_id, resources[0], resources[1] * multiplier);

    return _increase_resources(land_id, resources_len - 2, resources + 2, multiplier);
}

func _increase_resources_divided{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt, 
    resources_len: felt, 
    resources: felt*, 
    divider: felt
) {
    if (resources_len == 0) {
        return ();
    }

    let (q, r) = unsigned_div_rem(resources[1], divider);
    _increase_resource(land_id, resources[0], q);

    return _increase_resources_divided(land_id, resources_len - 2, resources + 2, divider);
}

// @notice Get balance of player's resources
// @param land_id
// @param resource_id : id of resource to update
// @return balance : balance of resource_id for owner of tokenId
@view
func get_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt, resource_id: felt
) -> (current_balance: felt) {
    let (current_balance) = balance.read(land_id, resource_id);
    return (current_balance,);
}

// @notice Get balance of all player's resources
// @param tokenId : token id of erc721 land
// @return balance : array of balance for each resource_id for owner of tokenId
@view
func get_balance_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt
) -> (balance_len: felt, balance: felt*) {
    alloc_locals;
    let (local balances: felt*) = alloc();
    local index = 1;
    local resources_count = ResourcesType.count;

    _get_balance_all_iter(land_id, resources_count, balances, index);

    return (ResourcesType.count, balances);
}

// @notice function to interate and get all balances of player
func _get_balance_all_iter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt, 
    resources_count: felt, 
    balances: felt*, 
    index: felt
) {
    if (index == resources_count + 1) {
        return ();
    }

    let (current_balance) = balance.read(land_id, index);
    balances[0] = current_balance;

    return _get_balance_all_iter(land_id, resources_count, balances + 1, index + 1);
}


// -------------------- PLAYER Resources spwaned index --------------------

func _update_rs_idx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt,
    idx : felt
) {
    player_rs_idx.write(land_id, idx);
    return();
}

// -------------------- BUILDING INDEX && COUNTERS --------------------

// @notice get building last index for a given land_id
@view
func get_building_idx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt
) -> (index: felt) {
    let (index) = player_building_idx.read(land_id);
    return (index,);
}

// @notice get building current number for a given land_id
@view
func get_building_counter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt
) -> (counter: felt) {
    let (counter) = player_building_counter.read(land_id);
    return (counter,);
}

// @notice update building index of a land_id
func _update_building_idx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt,
    idx : felt
) {
    player_building_idx.write(land_id, idx);
    return();
}

// @notice update building counter of a land_id
func _update_building_counter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt,
    counter : felt
) {
    player_building_counter.write(land_id, counter);
    return();
}

// -------------------- BUILDING PLAYER ARRAY --------------------

// @notice fill player building array when building built
// @param land_id
// @param building_uid
// @param building_type_id
// @param pos_start : comp formatted > pos_x * 100 + pos_y
// @param level_value : level of the building built
// @param frens_working : nb of frens allocated to building
// @param decay value : value of decay of building
func _update_building_player{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt,
    building_type_id : felt, 
    pos_start : felt, 
    level_value : felt,
    frens_working : felt,
    decay_value: felt,
) {
    player_building.write(land_id, building_uid, BuildingData.typeId, building_type_id);
    player_building.write(land_id, building_uid, BuildingData.posStart, pos_start);
    player_building.write(land_id, building_uid, BuildingData.frensWorking, frens_working);
    player_building.write(land_id, building_uid, BuildingData.decay, decay_value);
    player_building.write(land_id, building_uid, BuildingData.level, level_value);

    return();
}

func _update_building_recharges{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt,
    nb_recharges: felt,
    current_block: felt,
) {
    player_building.write(land_id, building_uid, BuildingData.recharges, nb_recharges);
    player_building.write(land_id, building_uid, BuildingData.lastClaim, current_block);

    return();
}

func _update_building_player_pos{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt,
    pos_start : felt
) {
    player_building.write(land_id, building_uid, BuildingData.posStart, pos_start);

    return();
}

// @notice get building recharges & block number 
// @param land_id
// @param building_uid : uid of building to destroy
@view
func get_building_recharges{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt
) -> (nb_recharges : felt, last_claim: felt) {
    let (nb_recharges) = player_building.read(land_id, building_uid, BuildingData.recharges);
    let (last_claim) = player_building.read(land_id, building_uid, BuildingData.lastClaim);

    return (nb_recharges, last_claim,);
}

// @notice get building recharges & block number 
// @param land_id
// @param building_uid : uid of building to destroy
@view
func get_building_claimable{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt
) -> (building_type_id: felt, nb_recharges : felt, last_claim: felt) {
    let (building_type_id) = player_building.read(land_id, building_uid, BuildingData.typeId);
    let (nb_recharges) = player_building.read(land_id, building_uid, BuildingData.recharges);
    let (last_claim) = player_building.read(land_id, building_uid, BuildingData.lastClaim);

    return (building_type_id, nb_recharges, last_claim,);
}

// @notice destroy building in building player array
// @param land_id
// @param building_uid : uid of building to destroy
// @dev only pass the value BuildingData.typeId to 0 
func _destroy_building_player{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt
) {
    player_building.write(land_id, building_uid, BuildingData.typeId, 0);

    return ();
}

// @notice destroy all buildings
// @param land_id
// @param building_uid : uid of building to destroy
// @dev only pass the value BuildingData.typeId to 0 
func _destroy_building_player_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt,
    idx : felt,
    counter : felt,
) {
    alloc_locals;

    if (counter == 0) {
        return ();
    }

    let (is_building) = player_building.read(land_id, idx, BuildingData.typeId);

    if (is_building == 0) {
        return _destroy_building_player_all(land_id, idx + 1, counter);
    } else {
        let (pos) = player_building.read(land_id, idx, BuildingData.posStart);
        player_building.write(land_id, idx, BuildingData.typeId, 0);
        let (_x,_y) = unsigned_div_rem(pos, 100);
        FrensLands._update_map_block(land_id, _x, _y, 0);
        return _destroy_building_player_all(land_id, idx + 1, counter - 1);
    }
}

// @notice get building decay level
// @param land_id
// @param building_uid : uid of building to destroy
@view
func get_building_decay{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt
) -> (decay_level : felt) {

    let (decay_level) = player_building.read(land_id, building_uid, BuildingData.decay);

    return (decay_level,);
}

// @notice update level of decay of a building on a given land_id
func _update_building_decay{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt, 
    building_uid : felt,
    decay_level: felt,
) {
    player_building.write(land_id, building_uid, BuildingData.decay, decay_level);

    return ();
}


// ----------------------- FRENS MANAGEMENT -----------------------

// @notice view total population of community && total population available to work at the current time
// @param land_id
// @return array with [total population, available population]
@view
func get_pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(land_id: felt) -> (
    pop_len: felt, pop: felt*
) {
    alloc_locals;

    let (local total_pop) = frens_total.read(land_id);
    let (local free_pop) = frens_available.read(land_id);

    let (local pop: felt*) = alloc();
    pop[0] = total_pop;
    pop[1] = free_pop;

    return (2, pop);
}

// @notice allocate frens to work in a building. Called whenever a player build a building producing
// @param land_id
// @param val : number of frens starting work
func _alloc_frens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt,
    nb_frens : felt
) {
    alloc_locals;

    if (nb_frens == 0) {
        return ();
    }

    let (local free_frens) = frens_available.read(land_id);
    with_attr error_message("Not enough available frens to work here.") {
        assert_le(nb_frens, free_frens);
    }

    frens_available.write(land_id, free_frens - nb_frens);

    return();
}

// @notice deallocate frens to work in a building. Called whenever a player destroys a building producing
// @param land_id 
// @param val : number of frens starting work
// @dev called whenever a player build a building producing
func _dealloc_frens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id : felt,
    nb_frens : felt
) -> () {
    alloc_locals;

    if (nb_frens == 0) {
        return ();
    }

    let (local free_frens) = frens_available.read(land_id);
    frens_available.write(land_id, free_frens + nb_frens);

    return();
}


// @notice Increase frens population (total number of frens & frens available)
// @param land_id
// @param new_frens : number of new frens
// @dev called whenever a player build a building which increases its total population of frens
func _increase_frens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt,
    new_frens : felt
) {
    alloc_locals;

    if (new_frens == 0) {
        return ();
    }

    let (total) = frens_total.read(land_id);
    frens_total.write(land_id, total + new_frens);

    let (free_frens) = frens_available.read(land_id);
    frens_available.write(land_id, free_frens + new_frens);

    return ();
}

// @notice Descrease frens population (total number of frens + frens available)
// @param land_id
// @param new_frens : number of new frens
// @dev player needs to have enough free frens to decrease overall frens population
// @dev called whenever a player destroys a house, appartment or hotel
func _decrease_frens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    land_id: felt,
    frens_leaving : felt
) {
    alloc_locals;

    if (frens_leaving == 0) {
        return ();
    }

    let (free_frens) = frens_available.read(land_id);
    with_attr error_message("You don't have enough population available") {
        assert_le(frens_leaving, free_frens);
    }
    frens_available.write(land_id, free_frens - frens_leaving);

    let (total) = frens_total.read(land_id);
    frens_total.write(land_id, total - frens_leaving);

    return ();
}

