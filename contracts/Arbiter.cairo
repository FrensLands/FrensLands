%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

from lib.openzeppelin.access.ownable import Ownable

//##########
// STORAGE #
//##########

@storage_var
func controller_address() -> (address: felt) {
}

// 1=locked.
@storage_var
func lock() -> (bool: felt) {
}

//##############
// CONSTRUCTOR #
//##############

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner_address: felt
) {
    Ownable.initializer(owner_address);
    return ();
}

//#####################
// EXTERNAL FUNCTIONS #
//#####################

// Called to save the address of the Module Controller
@external
func set_address_of_controller{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    contract_address: felt
) {
    Ownable.assert_only_owner();
    let (locked) = lock.read();
    assert_not_zero(1 - locked);
    lock.write(1);

    controller_address.write(contract_address);

    return ();
}

// Called to replace the contract that controls the Arbiter
@external
func replace_self{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_arbiter_address: felt
) {
    Ownable.assert_only_owner();
    let (controller) = controller_address.read();
    // The ModuleController has a fixed address. The Arbiter
    // may be upgraded by calling the ModuleController and declaring
    // the new Arbiter.
    IModuleController.appoint_new_arbiter(
        contract_address=controller, new_arbiter=new_arbiter_address
    );

    return ();
}

// Called to appoint a new owner of Arbiter contract
@external
func appoint_new_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_owner_address: felt
) {
    Ownable.assert_only_owner();
    Ownable.transfer_ownership(new_owner_address);

    return ();
}

// Called to approve a deployed module as identified by ID
@external
func appoint_contract_as_module{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    module_address: felt, module_id: felt
) {
    Ownable.assert_only_owner();
    let (controller) = controller_address.read();

    IModuleController.set_address_for_module_id(
        contract_address=controller, module_id=module_id, module_address=module_address
    );

    return ();
}

// Called to authorize write access of one module to another
@external
func approve_module_to_module_write_access{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(module_id_doing_writing: felt, module_id_being_written_to: felt) {
    Ownable.assert_only_owner();
    let (controller) = controller_address.read();

    IModuleController.set_write_access(
        contract_address=controller,
        module_id_doing_writing=module_id_doing_writing,
        module_id_being_written_to=module_id_being_written_to,
    );

    return ();
}

@external
func batch_set_controller_addresses{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(frenslands_address: felt, storage_address: felt, resources_address: felt, buildings_address: felt) {
    Ownable.assert_only_owner();
    let (controller) = controller_address.read();

    IModuleController.set_initial_module_addresses(
        contract_address=controller,
        frenslands_address=frenslands_address,
        storage_address=storage_address,
        resources_address=resources_address,
        buildings_address=buildings_address,
    );

    return ();
}
