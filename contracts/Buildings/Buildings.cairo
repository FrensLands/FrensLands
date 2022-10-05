%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from lib.openzeppelin.upgrades.library import Proxy
from contracts.library.library_module import Module
from contracts.library.library_data import Data

from contracts.Buildings.Buildings_Data import (
    BUILDINGS_COUNTER,
    BUILD_DATA_NB,
    UPGRADE_DATA_NB,
    REPAIR_DATA_NB,
    MultipleResources,
    build_data_start,
    maintenance_cost_start,
    production_daily_start,
    repair_data_start,
)


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

//##########
// GETTERS #
//##########

// @notice get number of resources spawned type
// @return building_counter 
@view
func read_building_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    building_count: felt
) {
    return (BUILDINGS_COUNTER,);
}

// @notice Get build fixed data 
// @param type_id : building type id 
// @param level : level of building 
// @return data : struct of type Multiple resources with nb of resources needed, composition of resources, pop needed to build, additional pop
@view
func read_build_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    type_id: felt, level: felt
) -> (data: MultipleResources) {
    alloc_locals;
    let (build_data_start_label) = get_label_location(build_data_start);
    let arr = cast(build_data_start_label, felt*);

    let data = MultipleResources(
        comp=arr[(type_id - 1) * BUILD_DATA_NB],
        popRequired=arr[(type_id - 1) * BUILD_DATA_NB + 1],
        popAdd=arr[(type_id - 1) * BUILD_DATA_NB + 2],
    );

    return (data,);
}

// @notice Get maintenance cost building fixed data 
// @param type_id : building type id 
// @param level : level of building 
// @return data : struct of type Multiple resources with nb of resources needed, composition of resources, pop needed to build
@view
func read_maintenance_cost_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    type_id: felt, level: felt
) -> (costs_len: felt, costs: felt*) {
    alloc_locals;

    let (maintenance_cost_start_label) = get_label_location(maintenance_cost_start);
    let arr = cast(maintenance_cost_start_label, felt*);

    // Decompose resources needed
    let (costs : felt*) = alloc();
    let (costs_len : felt) = Data._decompose_resources(arr[type_id - 1], costs, 0);

    return (costs_len, costs);
}

// @notice Get daily gains of building running fixed data 
// @param type_id : building type id 
// @param level : level of building 
// @return data : struct of type Multiple resources with nb of resources needed, composition of resources, pop needed to build
@view
func read_production_daily_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    type_id: felt, level: felt
) -> (gains_len: felt, gains: felt*) {
    alloc_locals;

    let (production_daily_start_label) = get_label_location(production_daily_start);
    let arr = cast(production_daily_start_label, felt*);

    // Decompose resources needed
    let (gains : felt*) = alloc();
    let (gains_len : felt) = Data._decompose_resources(arr[type_id - 1], gains, 0);

    return (gains_len, gains);
}

// @notice Get repair fixed data 
// @param type_id : building type id 
// @param level : level of building 
// @return data : struct of type Multiple resources with nb of resources needed, composition of resources, pop needed to build
@view
func read_repair_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    type_id: felt
) -> (data: MultipleResources) {
    alloc_locals;

    let (repair_data_start_label) = get_label_location(repair_data_start);
    let arr = cast(repair_data_start_label, felt*);

    let data = MultipleResources(
        comp=arr[(type_id - 1) * UPGRADE_DATA_NB],
        popRequired=arr[(type_id - 1) * UPGRADE_DATA_NB + 1],
        popAdd=arr[(type_id - 1) * UPGRADE_DATA_NB + 2],
    );

    return (data,);
}

// @notice Get population added when building
// @param type_id : building type id 
// @param level : level of building 
// @return data : felt 
@view
func read_pop_add_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    type_id: felt, level: felt
) -> (data: felt) {
    let (build_data_start_label) = get_label_location(build_data_start);
    let arr = cast(build_data_start_label, felt*);

    return (arr[(type_id - 1) * BUILD_DATA_NB + 2],);
}

// @notice Get population required to work in building
// @param type_id : building type id 
// @param level : level of building 
// @return data : felt 
@view
func read_pop_required_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    type_id: felt, level: felt
) -> (data: felt) {
    let (build_data_start_label) = get_label_location(build_data_start);
    let arr = cast(build_data_start_label, felt*);

    return (arr[(type_id - 1) * BUILD_DATA_NB + 1],);
}
