%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address
from contracts.utils.game_structs import ModuleIds, ExternalContractsIds

//##########
// STORAGE #
//##########

// Stores the address of the Arbiter contract
@storage_var
func arbiter() -> (address: felt) {
}

// Stores contract address for each module id
@storage_var
func address_of_module_id(module_id: felt) -> (address: felt) {
}

// Stores modules_id for each address
@storage_var
func module_id_of_address(address: felt) -> (module_id: felt) {
}

// Maps write access between modules. 1 means module can write
@storage_var
func can_write_to(doing_writing: felt, being_written_to: felt) -> (bool: felt) {
}

// Maps external module ids with their addresses
@storage_var
func external_contracts(external_contract_id: felt) -> (address: felt) {
}

//##############
// CONSTRUCTOR #
//##############

// @notice Constructor function
// @param arbiter_address : Arbiter contract address
// @param _lands_address : Lands erc721 contract address
// @param _minter_lands_address : Minter lands erc721 contract address
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arbiter_address: felt, _lands_address: felt, _minter_lands_address: felt
) {
    arbiter.write(arbiter_address);

    // FrensLands can write to Storage, Buildings
    can_write_to.write(
       doing_writing=ModuleIds.FrensLands, being_written_to=ModuleIds.FrensLands_Storage, value=1
    );
    can_write_to.write(
       doing_writing=ModuleIds.ResourcesSpawned, being_written_to=ModuleIds.FrensLands_Storage, value=1
    );
    can_write_to.write(
       doing_writing=ModuleIds.Buildings, being_written_to=ModuleIds.FrensLands_Storage, value=1
    );

    external_contracts.write(ExternalContractsIds.Lands, _lands_address);
    external_contracts.write(ExternalContractsIds.MinterLands, _minter_lands_address);

    return ();
}

//#####################
// EXTERNAL FUNCTIONS #
//#####################

// @notice Called by the current arbiter to replace itself
// @param new_arbiter: new arbiter contract address
@external
func appoint_new_arbiter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_arbiter: felt
) {
    only_arbiter();
    arbiter.write(new_arbiter);

    return ();
}

// @notice Called by current arbiter to set new address mappings
// @param module_id : ID of module
// @param module_address : new module contract address
@external
func set_address_for_module_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    module_id: felt, module_address: felt
) {
    only_arbiter();
    module_id_of_address.write(module_address, module_id);
    address_of_module_id.write(module_id, module_address);

    return ();
}

// @notice Called by current arbiter to set new address mappings in batch
@external
func set_initial_module_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    frenslands_address: felt, storage_address: felt, resources_address: felt, buildings_address: felt
) {
    only_arbiter();

    // for each module update the storage_vars module_id_of_address & address_of_module_id
    module_id_of_address.write(address=frenslands_address, value=ModuleIds.FrensLands);
    address_of_module_id.write(module_id=ModuleIds.FrensLands, value=frenslands_address);

    module_id_of_address.write(address=storage_address, value=ModuleIds.FrensLands_Storage);
    address_of_module_id.write(module_id=ModuleIds.FrensLands_Storage, value=storage_address);

    module_id_of_address.write(address=resources_address, value=ModuleIds.ResourcesSpawned);
    address_of_module_id.write(module_id=ModuleIds.ResourcesSpawned, value=resources_address);

    module_id_of_address.write(address=buildings_address, value=ModuleIds.Buildings);
    address_of_module_id.write(module_id=ModuleIds.Buildings, value=buildings_address);

    return ();
}

// @notice Called by arbiter to authorise write access between two modules
// @param module_id_doing_writing : module contract address that can write
// @param module_id_being_written_to : module contract address being written to
@external
func set_write_access{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    module_id_doing_writing: felt, module_id_being_written_to: felt
) {
    only_arbiter();
    can_write_to.write(module_id_doing_writing, module_id_being_written_to, 1);

    return ();
}

// @notice Update list of external contracts address
// @param external_contract_id : ID of external contract
// @param external_contract_address : external contract address
@external
func update_external_contracts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    external_contract_id: felt, external_contract_address: felt
) {
    only_arbiter();
    external_contracts.write(external_contract_id, external_contract_address);

    return ();
}

//#################
// VIEW FUNCTIONS #
//#################

// @notice view module contract address
// @param module_id : ID of module
// @return address: Module contract address
@view
func get_module_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    module_id: felt
) -> (address: felt) {
    let (address) = address_of_module_id.read(module_id);
    return (address,);
}

// @notice Get Arbiter address
// @return arbiter_addr: Arbiter contract address
@view
func get_arbiter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    arbiter_addr: felt
) {
    let (arbiter_addr) = arbiter.read();
    return (arbiter_addr,);
}

// @notice View external contract address
// @param external_contract_id : ID of external contract
// @return address: External contract address
@view
func get_external_contract_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    external_contract_id: felt
) -> (address: felt) {
    let (address) = external_contracts.read(external_contract_id);
    return (address,);
}

//#####################
// INTERNAL FUNCTIONS #
//#####################

// @notice Check has write access
// @param address_attempting_to_write
// @return success : 1 is successful, 0 failed
@view
func has_write_access{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address_attempting_to_write: felt
) -> (success: felt) {
    alloc_locals;

    // Get address of module calling (being written to) & make sure it hasn't been replaced
    let (caller) = get_caller_address();
    let (module_id_being_written_to) = module_id_of_address.read(caller);

    let (local current_module_address) = address_of_module_id.read(module_id_being_written_to);

    if (current_module_address != caller) {
        return (0,);
    }

    // Get module id of contract trying to write & make sure it hasn't been replaced
    let (module_id_attempting_to_write) = module_id_of_address.read(address_attempting_to_write);
    let (local active_address) = address_of_module_id.read(module_id_attempting_to_write);

    if (active_address != address_attempting_to_write) {
        return (0,);
    }

    let (bool) = can_write_to.read(module_id_attempting_to_write, module_id_being_written_to);

    if (bool == 0) {
        return (0,);
    }

    return (1,);
}

//####################
// PRIVATE FUNCTIONS #
//####################

// @notice checks person calling is arbiter
func only_arbiter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local caller) = get_caller_address();
    let (current_arbiter) = arbiter.read();
    assert caller = current_arbiter;

    return ();
}
