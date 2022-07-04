%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds

###########
# STORAGE #
###########

# Stores the address of the Arbitrer contract
@storage_var
func arbitrer() -> (address : felt):
end

# Stores contract address for each module id
@storage_var
func address_of_module_id(module_id : felt) -> (address : felt):
end

# Stores modules_id for each address
@storage_var
func module_id_of_address(address : felt) -> (module_id : felt):
end

# Maps write access between modules. 1 means module can write
@storage_var
func can_write_to(doing_writing : felt, being_written_to : felt) -> (bool : felt):
end

# Maps external module ids with their addresses
@storage_var
func external_contracts(external_contract_id : felt) -> (address : felt):
end

###############
# CONSTRUCTOR #
###############

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arbitrer_address : felt, _maps_address : felt, _minter_maps_address : felt
):
    arbitrer.write(arbitrer_address)

    # add logic of writing between contracts

    external_contracts.write(ExternalContractsIds.Maps, _maps_address)
    external_contracts.write(ExternalContractsIds.MinterMaps, _minter_maps_address)

    return ()
end

######################
# EXTERNAL FUNCTIONS #
######################

# Called by the current arbitrer to replace itself
@external
func appoint_new_arbitrer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_arbitrer : felt
):
    only_arbitrer()
    arbitrer.write(new_arbitrer)

    return ()
end

# Called by current arbitrer to set new address mappings
@external
func set_address_for_module_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    module_id : felt, module_address : felt
):
    only_arbitrer()
    module_id_of_address.write(module_address, module_id)
    address_of_module_id.write(module_id, module_address)

    return ()
end

# Called by current arbitrer to new address mappings in batch
@external
func set_initial_module_addresses{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(m01_addr : felt):
    only_arbitrer()

    # for each module update the storage_vars module_id_of_address & address_of_module_id
    module_id_of_address.write(address=m01_addr, value=ModuleIds.M01_Worlds)
    address_of_module_id.write(module_id=ModuleIds.M01_Worlds, value=m01_addr)

    return ()
end

# Called by arbitrer to authorise write access between two modules
@external
func set_write_access{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    module_id_doing_writing : felt, module_id_being_written_to : felt
):
    only_arbitrer()
    can_write_to.write(module_id_doing_writing, module_id_being_written_to, 1)

    return ()
end

@external
func update_external_contracts{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    external_contract_id : felt, external_contract_address : felt
):
    only_arbitrer()
    external_contracts.write(external_contract_id, external_contract_address)

    return ()
end

##################
# VIEW FUNCTIONS #
##################

@view
func get_module_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    module_id : felt
) -> (address : felt):
    let (address) = address_of_module_id.read(module_id)
    return (address)
end

@view
func get_arbitrer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    arbitrer_addr : felt
):
    let (arbitrer_addr) = arbitrer.read()
    return (arbitrer_addr)
end

@view
func get_external_contract_address{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(external_contract_id : felt) -> (address : felt):
    let (address) = external_contracts.read(external_contract_id)
    return (address)
end

######################
# INTERNAL FUNCTIONS #
######################

@view
func has_write_access{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address_attempting_to_write : felt
) -> (success : felt):
    alloc_locals

    # Get address of module calling (being written to) & make sure it hasn't been replaced
    let (caller) = get_caller_address()
    let (module_id_being_written_to) = module_id_of_address.read(caller)

    let (local current_module_address) = address_of_module_id.read(module_id_being_written_to)

    if current_module_address != caller:
        return (0)
    end

    # Get module id of contract trying to write & make sure it hasn't been replaced
    let (module_id_attempting_to_write) = module_id_of_address.read(address_attempting_to_write)
    let (local active_address) = address_of_module_id.read(module_id_attempting_to_write)

    if active_address != address_attempting_to_write:
        return (0)
    end

    let (bool) = can_write_to.read(module_id_attempting_to_write, module_id_being_written_to)

    if bool == 0:
        return (0)
    end

    return (1)
end

#####################
# PRIVATE FUNCTIONS #
#####################

# checks person calling is arbitrer
func only_arbitrer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    let (local caller) = get_caller_address()
    let (current_arbitrer) = arbitrer.read()
    assert caller = current_arbitrer

    return ()
end
