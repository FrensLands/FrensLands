%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import storage_read, storage_write
from contracts.library.library_module import Module
from lib.openzeppelin.upgrades.library import Proxy

// Storage vars 

@storage_var
func land_to_owner(land_id : felt) -> (owner : felt){
}

@storage_var
func owner_to_land(owner : felt) -> (land_id : felt){
}


@storage_var
func land_to_biome(land_id : felt) -> (biome_id : felt){
}

// Player balance of resources 
@storage_var
func balance(land_id: felt, resource_id: felt) -> (res: felt) {
}

// Land resources spawned 
@storage_var
func player_rs_idx(land_id: felt) -> (res: felt) {
}

// Building players
@storage_var
func player_building_idx(land_id: felt) -> (res: felt) {
}

@storage_var
func player_building_counter(land_id: felt) -> (res: felt) {
}

@storage_var
func player_building(land_id: felt, building_uid: felt, data_type: felt) -> (res: felt) {
}

@storage_var
func frens_total(land_id: felt) -> (res: felt) {
}

@storage_var
func frens_available(land_id: felt) -> (res: felt) {
}

@storage_var
func map_info(land_id: felt, pos_x: felt, pos_y: felt) -> (res: felt) {
}



// -------------
// CONSTRUCTOR 
// -------------

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

@external
func set_value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: felt,
    y: felt
) {
    Module.only_approved();
    storage_write(x, y);
    return ();
}

@view
func read_value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: felt
) -> (y: felt) {
    let (y) = storage_read(x);
    return (y,);
}