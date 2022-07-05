%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
    get_block_number,
)
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_lt
from starkware.cairo.common.math_cmp import is_le, is_le_felt, is_nn_le

# [pos:x][pos:x][pos:y][pos:y][mat type][ress or bat type]
# [ress or bat type][health][health][quantity ress or pop]
# [quantity ress or pop][current level][activity index or number of days active]

const A1 = 5
const A2 = 4
const A3 = 3
const A4 = 2
const A5 = 1

const B1 = 100000
const B2 = 10000
const B3 = 1000
const B4 = 100
const B5 = 10

###########
# STORAGE #
###########

@storage_var
func composition() -> (res : felt):
end

@storage_var
func decomp(i : felt) -> (res : felt):
end

@external
func decompose{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    multArr_len : felt, multArr : felt*, bArr_len : felt, bArr : felt*, numChar : felt
):
    alloc_locals
    let (local arr : felt*) = alloc()

    let (comp) = composition.read()

    _decompose(bArr_len, bArr, numChar, arr, comp, 0, 0, 0)

    return ()
end

func _decompose{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    bArr_len : felt,
    bArr : felt*,
    numChar : felt,
    arr : felt*,
    comp : felt,
    index : felt,
    i : felt,
    tempRes : felt,
):
    alloc_locals
    let res = comp - ((index * bArr[0]) + tempRes)

    %{ print ('iteration : ', ids.i) %}
    %{ print ('index : ', ids.index) %}
    %{ print ('res : ', ids.res) %}
    %{ print ('tempRes : ', ids.tempRes) %}

    let (check) = is_nn_le(res, bArr[0])

    %{ print ('check : ', ids.check) %}

    if i == 5:
        # arr[0] = res
        decomp.write(i, res)
        return ()
    end

    if check == 1:
        arr[0] = index
        local new_temp = tempRes + (arr[0] * bArr[0])
        decomp.write(i, index)
        _decompose(bArr_len - 1, bArr + 1, numChar, arr + 1, comp, 0, i + 1, new_temp)

        tempvar pedersen_ptr = pedersen_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        _decompose(bArr_len, bArr, numChar, arr, comp, index + 1, i, tempRes)
        tempvar pedersen_ptr = pedersen_ptr
        tempvar syscall_ptr = syscall_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return ()
end

@view
func view_decomp{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(i : felt) -> (
    res : felt
):
    let (res) = decomp.read(i)
    return (res)
end

@external
func compose{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    bArr_len : felt, bArr : felt*, values_len : felt, values : felt*
):
    let comp = (bArr[0] * values[0]) + (bArr[1] * values[1]) + (bArr[2] * values[2]) + (bArr[3] * values[3]) + (bArr[4] * values[4]) + values[5]

    composition.write(comp)

    return ()
end

@view
func view_composition{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}() -> (
    comp : felt
):
    let (comp) = composition.read()
    return (comp)
end

# @external
# func calcul_pow_all{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
#     varArr_len : felt, varArr: felt*, multArr_len : felt, multArr : felt*, i : felt
# ):
#     alloc_locals
#     let (local res : felt*) = alloc()
#
#     if i == 7:
#       return ()
#     end
#
#     _calcul_pow_elem(varArr[0], multArr[0], 0, i)
#
#     calcul_pow_all(varArr_len - 1, varArr + 1, multArr_len - 1, multArr + 1, i + 1)
#
#     return ()
#
# end

# @external
# func calcul_pow_elem{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
#     value : felt, multiplier : felt
# ):
#     alloc_locals
#     local index = 0
#     local i = 1
#
#     _calcul_pow_elem(value, multiplier, index, i)
#
#     return ()
# end
#
# func _calcul_pow_elem{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
#     result : felt, multiplier : felt, index : felt, i : felt
# ):
#     alloc_locals
#     %{ print ('result : ', ids.result) %}
#     %{ print ('index : ', ids.index) %}
#     %{ print ('multiplier : ', ids.multiplier) %}
#
#     if multiplier == 117:
#       preCompArr.write(i, result)
#       tempvar pedersen_ptr = pedersen_ptr
#       tempvar syscall_ptr = syscall_ptr
#       tempvar range_check_ptr = range_check_ptr
#       return ()
#     else:
#       if index == multiplier:
#         preCompArr.write(i, result)
#         tempvar pedersen_ptr = pedersen_ptr
#         tempvar syscall_ptr = syscall_ptr
#         return ()
#       else:
#         local temp = result * 10
#
#         _calcul_pow_elem(temp, multiplier, index + 1, i)
#         tempvar pedersen_ptr = pedersen_ptr
#         tempvar syscall_ptr = syscall_ptr
#       end
#       tempvar pedersen_ptr = pedersen_ptr
#       tempvar syscall_ptr = syscall_ptr
#       tempvar range_check_ptr = range_check_ptr
#     end
#
#     return ()
# end

# @view
# func get_values{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(index : felt) -> (value : felt):
#
#     let (value) = preCompArr.read(index)
#     return (value)
# end

# @view
# func get_values{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}() -> (values_len : felt, values : felt*):
#     alloc_locals
#     local values_len = 6
#
#     let (values : felt*) = alloc()
#
#     values[0] = posX1_CF.read()
#     values[1] = posX2_CF.read()
#     values[2] = posY1_CF.read()
#     values[3] = posY2_CF.read()
#     values[4] = id1_CF.read()
#     values[5] = id2_CF.read()
#
#     return (values_len, values)
# end

###############
# CONSTRUCTOR #
###############

######################
# EXTERNAL FUNCTIONS #
######################

##################
# VIEW FUNCTIONS #
##################

######################
# INTERNAL FUNCTIONS #
######################
