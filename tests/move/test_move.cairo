%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from tests.interfaces import FrensLands
from tests.interfaces import Resources

from tests.conftest import (
    Contracts,
    setup,
    _get_test_addresses,
    _init_module_controller,
)

@external
func __setup__{syscall_ptr : felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return setup();
}

@external
func test_move{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Get enough resources to build a house
    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    FrensLands.harvest(addresses.frenslands_proxy, 13, 2);

    // Build a house
    FrensLands.build(addresses.frenslands_proxy, 1, 1, 2);
    
    let (pop_len: felt, pop: felt*) = FrensLands.get_pop(addresses.frenslands_proxy, land_id);
    assert pop[0] = 3; // total_pop
    assert pop[1] = 3; // free_pop
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 17;
    let (balance_wood) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 1);
    assert balance_wood = 1;
    let (balance_rock) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 2);
    assert balance_rock = 0;

    let (house_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 1, 1);
    assert house_block = 20200021199;
    let (empty_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 1, 10);
    assert empty_block = 0;

    FrensLands.move_infrastructure(addresses.frenslands_proxy, 1, 1, 1, 10);

    let (house_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 1, 1);
    assert house_block = 0;
    let (dest_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 1, 10);
    assert dest_block = 20200021199;

   
    %{ stop_prank_callable5() %}

    return ();
}

// @external
// func test_try_build_resources{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
//     alloc_locals;

//     let (addresses: Contracts) = _get_test_addresses();

//     _init_module_controller(addresses);

//     %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

//     let tokenId = Uint256(1, 0);
//     let land_id = 11111;
//     FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

//     // Try building without enough resources 
//     %{ expect_revert("TRANSACTION_FAILED") %}
//     FrensLands.build(addresses.frenslands_proxy, 1, 1, 2);
   
//     %{ stop_prank_callable5() %}

//     return ();
// }

// @external
// func test_try_build_occupied{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
//     alloc_locals;

//     let (addresses: Contracts) = _get_test_addresses();

//     _init_module_controller(addresses);

//     %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

//     let tokenId = Uint256(1, 0);
//     let land_id = 11111;
//     FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

//     // Get enough resources to build a house
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 13, 2);

//     // Try building a house on a block occupied by another building
//     %{ expect_revert("TRANSACTION_FAILED") %}
//     FrensLands.build(addresses.frenslands_proxy, 20, 8, 2);
   
//     %{ stop_prank_callable5() %}

//     return ();
// }

// @external
// func test_try_build_occupied_rs{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
//     alloc_locals;

//     let (addresses: Contracts) = _get_test_addresses();

//     _init_module_controller(addresses);

//     %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

//     let tokenId = Uint256(1, 0);
//     let land_id = 11111;
//     FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

//     // Get enough resources to build a house
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 13, 2);

//     // Try building a house on a block occupied by a resource spawned 
//     %{ expect_revert("TRANSACTION_FAILED") %}
//     FrensLands.build(addresses.frenslands_proxy, 13, 2, 2);
   
//     %{ stop_prank_callable5() %}

//     return ();
// }

// @external
// func test_try_build_cabin{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
//     alloc_locals;

//     let (addresses: Contracts) = _get_test_addresses();

//     _init_module_controller(addresses);

//     %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

//     let tokenId = Uint256(1, 0);
//     let land_id = 11111;
//     FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

//     // Get enough resources to build a house
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 13, 2);

//     // Try building a cabin
//     %{ expect_revert("TRANSACTION_FAILED") %}
//     FrensLands.build(addresses.frenslands_proxy, 1, 1, 1);
   
//     %{ stop_prank_callable5() %}

//     return ();
// }

// @external
// func test_try_build_unexisting{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
//     alloc_locals;

//     let (addresses: Contracts) = _get_test_addresses();

//     _init_module_controller(addresses);

//     %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

//     let tokenId = Uint256(1, 0);
//     let land_id = 11111;
//     FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

//     // Get enough resources to build a house
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
//     FrensLands.harvest(addresses.frenslands_proxy, 13, 2);

//     // Try building an unexisting building
//     %{ expect_revert("TRANSACTION_FAILED") %}
//     FrensLands.build(addresses.frenslands_proxy, 1, 1, 45);
   
//     %{ stop_prank_callable5() %}

//     return ();
// }