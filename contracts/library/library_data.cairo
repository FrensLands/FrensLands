%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le
from contracts.utils.bArray import bArray
from starkware.cairo.common.alloc import alloc

from contracts.utils.interfaces import IModuleController

namespace Data {
    // @notice Decompose a chain of numbers stored in a felt
    // @dev
    // @param bArr multiplyer based on utils/bArr.cairo. For a 16 characters start at 0, 15 start at 1, etc.
    // @param NumChar number of characters to decompose
    // @param comp the chain to decompose
    func _decompose{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        bArr: felt, numChar: felt, comp: felt, ret_array: felt*, index: felt, i: felt, tempRes: felt
    ) {
        alloc_locals;

        let res = comp - ((index * bArr) + tempRes);

        // %{ print ('iteration : ', ids.i) %}
        // %{ print ('index : ', ids.index) %}
        // %{ print ('res : ', ids.res) %}
        // %{ print ('tempRes : ', ids.tempRes) %}
        // %{ print ('bArr : ', ids.bArr) %}

        let check = is_nn_le(res, bArr);
        // %{ print ('check : ', ids.check) %}

        if (i == numChar - 1) {
            assert ret_array[0] = res;
            return ();
        }

        if ((bArr - res) == 0) {
            assert ret_array[0] = 1;
            local new_temp = tempRes + (ret_array[0] * bArr);
            return _decompose(bArr, numChar, comp, ret_array + 1, 0, i + 1, new_temp);
        }

        if (check == 1) {
            assert ret_array[0] = index;
            local new_temp = tempRes + (ret_array[0] * bArr);
            local b_index = 16 - numChar + (i + 1);
            let (local bArr) = bArray(b_index);
            return _decompose(bArr, numChar, comp, ret_array + 1, 0, i + 1, new_temp);
        } else {
            return _decompose(bArr, numChar, comp, ret_array, index + 1, i, tempRes);
        }
    }

    func _compose_costs{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        num_resources: felt, values: felt*, costs: felt*
    ) {
        if (num_resources == 0) {
            return ();
        }

        assert costs[0] = values[0];
        assert costs[1] = (values[1] * 10) + values[2];

        return _compose_costs(num_resources - 1, values + 3, costs + 2);
    }

    func _compose_chain{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        num_char: felt, values: felt*
    ) -> (res: felt) {
        let comp = (1000000000000000 * values[0]) + (100000000000000 * values[1]) + (10000000000000 * values[2]) + (1000000000000 * values[3]) + (100000000000 * values[4]) + (10000000000 * values[5]) + (1000000000 * values[6]) + (100000000 * values[7]) + (10000000 * values[8]) + (1000000 * values[9]) + (100000 * values[10]) + (10000 * values[11]) + (1000 * values[12]) + (100 * values[13]) + (10 * values[14]) + values[15];

        return (comp,);
    }

    func _compose_chain_destroyed{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        num_char: felt, values: felt*
    ) -> (res: felt) {
        let comp = (1000000000000000 * values[0]) + (100000000000000 * values[1]) + (10000000000000 * values[2]) + (1000000000000 * values[3]) + (100000000000 * values[4]) + (100000 * values[10]) + (10000 * values[11]) + (1000 * values[12]) + (100 * values[13]) + (10 * 1) + values[15];

        return (comp,);
    }

    func _compose_chain_build{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        num_char: felt,
        values: felt*,
        building_type_id: felt,
        building_unique_id: felt,
        allocated_population: felt,
        level: felt,
    ) -> (res: felt) {
        let comp = (1000000000000000 * values[0]) + (100000000000000 * values[1]) + (10000000000000 * values[2]) + (1000000000000 * values[3]) + (100000000000 * values[4]) + (1000000000 * building_type_id) + (1000000 * building_unique_id) + (100000 * 8) + (10000 * 8) + (100 * allocated_population) + (10 * level) + values[15];

        return (comp,);
    }

    func _get_costs_from_chain{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        nb_resources: felt, resources_qty: felt
    ) -> (ret_array_len: felt, ret_array: felt*) {
        alloc_locals;

        let (local ret_array: felt*) = alloc();

        local b_index = 16 - (nb_resources * 3);
        let (local bArr) = bArray(b_index);

        Data._decompose(bArr, nb_resources * 3, resources_qty, ret_array, 0, 0, 0);

        let (local costs: felt*) = alloc();
        Data._compose_costs(nb_resources, ret_array, costs);

        return (nb_resources * 2, costs);
    }

    func _compose_chain_harvest{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        num_char: felt, values: felt*, level: felt
    ) -> (res: felt) {
        let comp = (1000000000000000 * values[0]) + (100000000000000 * values[1]) + (10000000000000 * values[2]) + (1000000000000 * values[3]) + (100000000000 * values[4]) + (10000000000 * values[5]) + (1000000000 * values[6]) + (100000000 * values[7]) + (10000000 * values[8]) + (1000000 * values[9]) + (100000 * values[10]) + (10000 * values[11]) + (1000 * values[12]) + (100 * values[13]) + (10 * level) + values[15];

        return (comp,);
    }
}
