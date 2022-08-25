%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero

from contracts.utils.interfaces import IModuleController

#
# Storage
#

@storage_var
func Module_controller_address() -> (address : felt):
end

#
# Events
#

namespace Module:
    #
    # Constructor
    #
    func initialize_controller{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address_of_controller : felt
    ):
        Module_controller_address.write(address_of_controller)
        return ()
    end

    #
    # Getters
    #
    func get_controller{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        controller_address : felt
    ):
        let (controller_address) = Module_controller_address.read()
        return (controller_address)
    end

    func only_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ):
        alloc_locals
        let (caller) = get_caller_address()

        let (success) = _only_approved()
        let (self) = check_self()
        assert_not_zero(success + self)

        return ()
    end

    #
    # Private
    #
    func _only_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        success : felt
    ):
        let (caller) = get_caller_address()
        let (controller) = Module_controller_address.read()

        let (success) = IModuleController.has_write_access(contract_address=controller, address_attempting_to_write=caller)

        return (success)
    end

    func check_self{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        success : felt
    ):
        let (caller) = get_caller_address()
        let (contract_addr) = get_contract_address()

        if caller == contract_addr:
            return (1)
        end

        return (0)
    end


end
