%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from lib.openzeppelin.upgrades.library import Proxy
from contracts.library.library_module import Module
from contracts.Resources.Resources_Data import (
    RS_COUNTER, 
    RS_DATA, 
    ResourcesFixedData,
    rs_data_start
)

// -------------
// CONSTRUCTOR 
// -------------

// @notice: initialize Module Controller
// @param address_of_controller : module controller contract address
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address_of_controller: felt, proxy_admin : felt
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

//#################
// VIEW FUNCTIONS #
//#################

// @notice get number of resources spawned type
@view
func read_rs_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    rs_count: felt
) {
    return (RS_COUNTER,);
}

// @notice Get resources spawned fixed data 
// @param type_id : type of resource
// @param level : level of resource
// @return data : ResourcesFixedData struct
@view
func read_rs_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    type_id: felt, level: felt
) -> (data: ResourcesFixedData) {
    alloc_locals;

    let (rs_data_start_label) = get_label_location(rs_data_start);
    let arr = cast(rs_data_start_label, felt*);

    let data = ResourcesFixedData(
        harvestingCost_qty=arr[(type_id - 1) * RS_DATA],
        harvestingGain_qty=arr[(type_id - 1) * RS_DATA + 1],
        popFreeRequired=arr[(type_id - 1) * RS_DATA + 2],
        timeRequired=arr[(type_id - 1) * RS_DATA + 3],
    );

    return (data,);
}
