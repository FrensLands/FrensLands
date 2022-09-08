%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address, deploy
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.uint256 import Uint256
from contracts.utils.tokens_interfaces import IERC721Maps
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

// Stores map for game contract
@storage_var
func map_id_by_game(game_address: felt) -> (map_tokenId: Uint256) {
}

// Stores game contract by user address
@storage_var
func game_contracts(user_address: felt) -> (game_address: felt) {
}

@storage_var
func game_contracts_class_hash() -> (game_class_hash: felt) {
}

@storage_var
func salt() -> (value: felt) {
}

//##############
// EVENT #
//##############

@event
func GameContractDeployed(game_contract_address: felt) {
}

//##############
// CONSTRUCTOR #
//##############

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arbiter_address: felt,
    _maps_address: felt,
    _minter_maps_address: felt,
    _gold_address: felt,
    _resources_address: felt,
    _game_class_hash: felt,
) {
    game_contracts_class_hash.write(_game_class_hash);

    arbiter.write(arbiter_address);

    // Writings logics between contracts
    // M03_Buildings can write to M02_Resources
    can_write_to.write(
        doing_writing=ModuleIds.M03_Buildings, being_written_to=ModuleIds.M02_Resources, value=1
    );
    // M01_Worlds can write to M02_Resources
    can_write_to.write(
        doing_writing=ModuleIds.M01_Worlds, being_written_to=ModuleIds.M02_Resources, value=1
    );
    // M01_Worlds can write to M03_Buildings
    can_write_to.write(
        doing_writing=ModuleIds.M01_Worlds, being_written_to=ModuleIds.M03_Buildings, value=1
    );
    // M03_Buildings can write to M01_Worlds
    can_write_to.write(
        doing_writing=ModuleIds.M03_Buildings, being_written_to=ModuleIds.M01_Worlds, value=1
    );
    // M02_Resources can write to M03_Worlds
    can_write_to.write(
        doing_writing=ModuleIds.M02_Resources, being_written_to=ModuleIds.M03_Buildings, value=1
    );
    can_write_to.write(
        doing_writing=ModuleIds.M02_Resources, being_written_to=ModuleIds.M01_Worlds, value=1
    );

    external_contracts.write(ExternalContractsIds.Maps, _maps_address);
    external_contracts.write(ExternalContractsIds.MinterMaps, _minter_maps_address);
    external_contracts.write(ExternalContractsIds.Gold, _gold_address);
    external_contracts.write(ExternalContractsIds.Resources, _resources_address);

    return ();
}

//#####################
// EXTERNAL FUNCTIONS #
//#####################

// Called by the current arbiter to replace itself
@external
func appoint_new_arbiter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_arbiter: felt
) {
    only_arbiter();
    arbiter.write(new_arbiter);

    return ();
}

// Called by current arbiter to set new address mappings
@external
func set_address_for_module_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    module_id: felt, module_address: felt
) {
    only_arbiter();
    module_id_of_address.write(module_address, module_id);
    address_of_module_id.write(module_id, module_address);

    return ();
}

// Called by current arbiter to new address mappings in batch
@external
func set_initial_module_addresses{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    m01_addr: felt, m02_addr: felt, m03_addr: felt
) {
    only_arbiter();

    // for each module update the storage_vars module_id_of_address & address_of_module_id
    module_id_of_address.write(address=m01_addr, value=ModuleIds.M01_Worlds);
    address_of_module_id.write(module_id=ModuleIds.M01_Worlds, value=m01_addr);

    module_id_of_address.write(address=m02_addr, value=ModuleIds.M02_Resources);
    address_of_module_id.write(module_id=ModuleIds.M02_Resources, value=m02_addr);

    module_id_of_address.write(address=m03_addr, value=ModuleIds.M03_Buildings);
    address_of_module_id.write(module_id=ModuleIds.M03_Buildings, value=m03_addr);

    return ();
}

// Called by arbiter to authorise write access between two modules
@external
func set_write_access{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    module_id_doing_writing: felt, module_id_being_written_to: felt
) {
    only_arbiter();
    can_write_to.write(module_id_doing_writing, module_id_being_written_to, 1);

    return ();
}

@external
func update_external_contracts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    external_contract_id: felt, external_contract_address: felt
) {
    only_arbiter();
    external_contracts.write(external_contract_id, external_contract_address);

    return ();
}

// Deploy game contract
@external
func deploy_game_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    map_tokenId: Uint256
) {
    let (caller) = get_caller_address();
    let (current_salt) = salt.read();
    let (class_hash) = game_contracts_class_hash.read();
    let (contract_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=1,
        constructor_calldata=cast(new (caller,), felt*),
        deploy_from_zero=FALSE,
    );
    salt.write(value=current_salt + 1);

    game_contracts.write(caller, contract_address);

    GameContractDeployed.emit(game_contract_address=contract_address);

    set_map_to_game(map_tokenId, contract_address);

    return ();
}

//#################
// VIEW FUNCTIONS #
//#################

@view
func get_module_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    module_id: felt
) -> (address: felt) {
    let (address) = address_of_module_id.read(module_id);
    return (address,);
}

@view
func get_arbiter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    arbiter_addr: felt
) {
    let (arbiter_addr) = arbiter.read();
    return (arbiter_addr,);
}

@view
func get_external_contract_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    external_contract_id: felt
) -> (address: felt) {
    let (address) = external_contracts.read(external_contract_id);
    return (address,);
}

@view
func get_game_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    game_contract_addr: felt
) {
    let (caller) = get_caller_address();
    let (game_contract_addr) = game_contracts.read(caller);
    return (game_contract_addr,);
}

//#####################
// INTERNAL FUNCTIONS #
//#####################

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

@view
func  get_map_tokenId_by_game{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    game_contract: felt
) -> (tokenId: Uint256) {
    let (tokenId) = map_id_by_game.read(game_contract);
    return (tokenId,);
}

//####################
// PRIVATE FUNCTIONS #
//####################

// checks person calling is arbiter
func only_arbiter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local caller) = get_caller_address();
    let (current_arbiter) = arbiter.read();
    assert caller = current_arbiter;

    return ();
}

// set map to game_contract
func set_map_to_game{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenId: Uint256, game_contract: felt
) {
    let (caller) = get_caller_address();
    let (maps_erc721_addr) = external_contracts.read(ExternalContractsIds.Maps);
    let (owner) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId);

    with_attr error_message("caller is not the owner of the map") {
        assert owner = caller;
    }

    map_id_by_game.write(game_contract, tokenId);

    return ();
}
