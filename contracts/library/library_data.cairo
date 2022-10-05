%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.math import unsigned_div_rem
from contracts.utils.game_constants import BLOCK_DATA

namespace Data {

    // @notice Decompose a chain of numbers stored in a felt
    // @param comp : chain to decompose
    func _decompose_resources{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        comp: felt, ret_array: felt*, ret_array_len : felt
    ) -> (ret_array_len: felt){
        alloc_locals;

        if (comp == 0) {
            return(ret_array_len,);
        }

        let (q, r) = unsigned_div_rem(comp, 1000);
        let (resource_id, resource_qty) = unsigned_div_rem(r, 100);
        ret_array[0] = resource_id;
        ret_array[1] = resource_qty;

        return _decompose_resources(q, ret_array + 2, ret_array_len + 2);
    }

    // @notice Decompose block information on map
    // @param comp the chain to decompose
    // @param ret_array : array filled with data
    // @param index : start at 0, will run until BLOCK_DATA is reached
    func _decompose_all_block{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        comp: felt, ret_array: felt*, index: felt
    ) {
        alloc_locals;

        if(index == BLOCK_DATA - 1){
            ret_array[0] = comp;
            return ();
        }

        let (divider) = _get_block_divider(index);
        let (q, r) = unsigned_div_rem(comp, divider);

        ret_array[0] = q;

        return _decompose_all_block(r, ret_array + 1, index + 1);
    }

    func _get_block_divider(idx: felt) -> (land: felt) {
        let (l) = get_label_location(block_divider);
        let arr = cast(l, felt*);
        return (arr[idx],);

        block_divider:        
        dw 10000000000;
        dw 100000000;
        dw 10000;
        dw 1000;
        dw 100;
    }

    func _compose_chain{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
        infra_type: felt,
        type_id: felt,
        uid: felt,
        level: felt
    ) -> (res: felt) {
        let comp = (10000000000 * infra_type) + (100000000 * type_id) + (10000 * uid) + (1000 * level) + (100 * 1) + (1 * 99);
        return (comp,);
    }
}
