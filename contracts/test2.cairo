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
# [ress or bat type][UNIQUE ID][UNIQUE ID]
# [UNIQUE ID][health][health][quantity ress or pop]
# [quantity ress or pop][current level][activity index or number of days active]


#1.[pos:x]
#2.[pos:x]
#3.[pos:y]
#4.[pos:y]
#5.[mat type]
#6.[ress or bat type]
#7.[ress or bat type]
#8.[UNIQUE ID]
#9.[UNIQUE ID]
#10.[UNIQUE ID]
#11.[health]
#12.[health]
#13.[quantity ress or pop]
#14.[quantity ress or pop]
#15.[current level]
#16.[activity index or number of days active]

# Nb of resources
# [RES ID RX0][RES Qty QX0][RES Qty QX0][RES ID RX1][RES Qty QX1][RES Qty QX1][RES ID RX2][RES Qty QX2][RES Qty QX2]



# namespace ResourcesType:
#     const Wood = 1
#     const Rock = 2
#     const Meat = 3
#     const Vegetables = 4
#     const Cereal = 5
#     const Metal = 6
#     const Copper = 7
#     const Coal = 8
#     const Phosphore = 9
# end

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
    # multArr_len : felt,
    # multArr : felt*,
    bArr_len : felt,
    bArr : felt*,
    # cArr_len : felt,
    # cArr : felt*,
    numChar : felt,
):
    alloc_locals
    let (local arr : felt*) = alloc()

    let (comp) = composition.read()

    _decompose(bArr_len, bArr, numChar, arr, comp, 0, 0, 0)
    # _decompose(bArr_len, bArr, cArr_len, cArr, numChar, arr, comp, 0, 0, 0)

    return ()
end

func _decompose{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    bArr_len : felt,
    bArr : felt*,
    # cArr_len : felt,
    # cArr : felt*,
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
    # let (check) = is_le(res, cArr[0])
    %{ print ('check : ', ids.check) %}

    if i == 15:
        # arr[0] = res
        decomp.write(i, res)
        return ()
    end

    if (bArr[0] - res) == 0:
      assert arr[0] = 1
      local new_temp = tempRes + (arr[0] * bArr[0])
      decomp.write(i, 1)
      _decompose(
          bArr_len - 1,
          bArr + 1,
          #cArr_len - 1,
          #cArr + 1,
          numChar,
          arr + 1,
          comp,
          0,
          i + 1,
          new_temp,
      )
      return ()
    end

    if check == 1:
        arr[0] = index
        local new_temp = tempRes + (arr[0] * bArr[0])
        decomp.write(i, index)
        _decompose(
            bArr_len - 1,
            bArr + 1,
            #cArr_len - 1,
            #cArr + 1,
            numChar,
            arr + 1,
            comp,
            0,
            i + 1,
            new_temp,
        )
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
    let comp = (bArr[0] * values[0]) + (bArr[1] * values[1]) + (bArr[2] * values[2]) + (bArr[3] * values[3]) + (bArr[4] * values[4]) + (bArr[5] * values[5]) + (bArr[6] * values[6]) + (bArr[7] * values[7]) + (bArr[8] * values[8]) + (bArr[9] * values[9]) + (bArr[10] * values[10]) + (bArr[11] * values[11]) + (bArr[12] * values[12]) + (bArr[13] * values[13]) + (bArr[14] * values[14]) + values[15]

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
