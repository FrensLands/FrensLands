%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le
from contracts.utils.bArray import bArray

from contracts.utils.interfaces import IModuleController

namespace Data:
    # @notice Decompose a chain of numbers stored in a felt
    # @dev
    # @param bArr multiplyer based on utils/bArr.cairo. For a 16 characters start at 0, 15 start at 1, etc.
    # @param NumChar number of characters to decompose
    # @param comp the chain to decompose
    func _decompose{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        bArr : felt,
        numChar : felt,
        comp : felt,
        ret_array : felt*,
        index : felt,
        i : felt,
        tempRes : felt,
    ):
        alloc_locals

        let res = comp - ((index * bArr) + tempRes)

        # %{ print ('iteration : ', ids.i) %}
        # %{ print ('index : ', ids.index) %}
        # %{ print ('res : ', ids.res) %}
        # %{ print ('tempRes : ', ids.tempRes) %}
        # %{ print ('bArr : ', ids.bArr) %}

        let (check) = is_nn_le(res, bArr)
        # %{ print ('check : ', ids.check) %}

        if i == numChar - 1:
            assert ret_array[0] = res
            return ()
        end

        if (bArr - res) == 0:
            assert ret_array[0] = 1
            local new_temp = tempRes + (ret_array[0] * bArr)
            return _decompose(bArr, numChar, comp, ret_array + 1, 0, i + 1, new_temp)
        end

        if check == 1:
            assert ret_array[0] = index
            local new_temp = tempRes + (ret_array[0] * bArr)
            local b_index = 16 - numChar + (i + 1)
            let (local bArr) = bArray(b_index)
            return _decompose(bArr, numChar, comp, ret_array + 1, 0, i + 1, new_temp)
        else:
            return _decompose(bArr, numChar, comp, ret_array, index + 1, i, tempRes)
        end
    end

    func _compose_costs{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        num_resources : felt, values : felt*, costs : felt*
    ):
        if num_resources == 0:
            return ()
        end

        assert costs[0] = values[0]
        assert costs[1] = (values[1] * 10) + values[2]

        return _compose_costs(num_resources - 1, values + 3, costs + 2)
    end
end
