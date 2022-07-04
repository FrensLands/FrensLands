%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address

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
end
