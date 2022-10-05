%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2

namespace Compute {
    // @notice compute x value of storage_var
    // @param function_id: name of the storage_var
    // @param len_params: number of params of the storage_var
    // @param params: params of the storage_var
    // @return hash
    func _compute_x{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        function_id: felt, len_params: felt, params: felt*
    ) -> (hash: felt) {
        if (len_params == 0) {
            return (function_id,);
        }
        let (rest) = _compute_x(function_id, len_params - 1, params);
        let (hashed) = hash2{hash_ptr=pedersen_ptr}(params[len_params - 1], rest);

        return (hashed,);
    }
}
