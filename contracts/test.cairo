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

// Map Size
@storage_var
func map_size(token_id: Uint256, axis: felt) -> (blocks: felt) {
}

// Ground type for map
@storage_var
func map_ground(token_id: Uint256, x: felt, y: felt) -> (type: felt) {
}

@constructor
func constructor{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, axis_x: felt, blocks_x: felt, axis_y: felt, blocks_y: felt
) {
    map_size.write(tokenId, axis_x, blocks_x);
    map_size.write(tokenId, axis_y, blocks_y);
    return ();
}

@external
func fill_block_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _x: felt, _y: felt, _type: felt
) -> () {
    map_ground.write(token_id=tokenId, x=_x, y=_y, value=_type);
    return ();
}

@view
func get_block_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _x: felt, _y: felt
) -> (type: felt) {
    let (_type: felt) = map_ground.read(tokenId, _x, _y);
    return (_type,);
}

// Fill one line

@external
func fill_line_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _y: felt, type_len: felt, type: felt*
) -> () {
    alloc_locals;
    local _x = 0;

    map_ground.write(tokenId, _x, _y, type[0]);

    _fill_line_ground(tokenId, _y, type_len - 1, type + 1, _x + 1);

    return ();
}

func _fill_line_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _y: felt, type_len: felt, type: felt*, index: felt
) -> () {
    if (type_len == 0) {
        return ();
    }

    map_ground.write(tokenId, index, _y, type[0]);

    return _fill_line_ground(tokenId, _y, type_len - 1, type + 1, index + 1);
}

@view
func get_line_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _y: felt
) -> (type_len: felt, type: felt*) {
    alloc_locals;

    local _x = 0;
    let (local type: felt*) = alloc();
    let (local max_x) = map_size.read(tokenId, 0);

    _get_line_ground(tokenId, _y, _x, type, max_x);

    return (max_x, type);
}

func _get_line_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _y: felt, _x: felt, type: felt*, max_x: felt
) {
    if (_x == max_x) {
        return ();
    }

    let (value) = map_ground.read(tokenId, _x, _y);
    type[0] = value;

    return _get_line_ground(tokenId, _y, _x + 1, type + 1, max_x);
}

// Fill one line 16 times

@external
func fill_all_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, type_len: felt, type: felt*
) -> () {
    alloc_locals;
    local _x = 1;
    local _y = 1;

    _fill_all_ground(tokenId, _x, _y, type_len, type);

    return ();
}

func _fill_all_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _x: felt, _y: felt, type_len: felt, type: felt*
) -> () {
    // type is an array with all entries (16 lignes de 40 itérations en partant de en bas à gauche)
    let (max_y) = map_size.read(tokenId, 1);
    let (max_x) = map_size.read(tokenId, 0);

    // If all iterations are done return
    if (_x == max_x + 1) {
        return ();
    }

    // %{ print ('_x : ',  ids._x) %}
    // %{ print ('_y : ', ids._y) %}

    map_ground.write(tokenId, _x, _y, type[0]);

    if (_y == max_y) {
        _fill_all_ground(tokenId, _x + 1, 1, type_len - 1, type + 1);
    } else {
        _fill_all_ground(tokenId, _x, _y + 1, type_len - 1, type + 1);
    }

    return ();
}

@view
func get_all_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256
) -> (type_len: felt, type: felt*) {
    alloc_locals;

    local _x = 1;
    local _y = 1;
    local len = 40 * 16;
    let (local type: felt*) = alloc();

    _get_all_ground(tokenId, _x, _y, type);

    return (len, type);
}

func _get_all_ground{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    tokenId: Uint256, _x: felt, _y: felt, type: felt*
) {
    let (max_y) = map_size.read(tokenId, 1);
    let (max_x) = map_size.read(tokenId, 0);

    if (_x == max_x + 1) {
        return ();
    }

    // %{ print ('Get all _x : ',  ids._x) %}
    // %{ print ('Get all _y : ', ids._y) %}

    let (value) = map_ground.read(tokenId, _x, _y);
    type[0] = value;

    if (_y == max_y) {
        _get_all_ground(tokenId, _x + 1, 1, type + 1);
    } else {
        _get_all_ground(tokenId, _x, _y + 1, type + 1);
    }

    return ();
}
