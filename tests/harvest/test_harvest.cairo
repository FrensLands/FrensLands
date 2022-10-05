%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from tests.interfaces import FrensLands
from contracts.Resources.Resources_Data import ResourcesFixedData
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
func test_harvest{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Check harvest a tree 3 times
    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 19;
    let (balance_wood) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 1);
    assert balance_wood = 2;
    let (tree_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 8, 2);
    assert tree_block = 10100012199;

    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 18;
    let (balance_wood) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 1);
    assert balance_wood = 4;
    let (tree_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 8, 2);
    assert tree_block = 10100013199;

    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 17;
    let (balance_wood) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 1);
    assert balance_wood = 6;
    let (tree_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 8, 2);
    assert tree_block = 0;

    // Harvest a rock 3 times
    FrensLands.harvest(addresses.frenslands_proxy, 13, 2);
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 16;
    let (balance_rock) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 2);
    assert balance_rock = 2;
    let (rock_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 13, 2);
    assert rock_block = 10200022199;

    FrensLands.harvest(addresses.frenslands_proxy, 13, 2);
    FrensLands.harvest(addresses.frenslands_proxy, 13, 2);
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 14;
    let (balance_rock) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 2);
    assert balance_rock = 6;
    let (rock_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 13, 2);
    assert rock_block = 0;

    // Harvest a bush : pos(92) = (3-1)*40 + 14 = (14, 3)
    FrensLands.harvest(addresses.frenslands_proxy, 12, 3);
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 16;
    let (balance_rock) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 2);
    assert balance_rock = 6;
    let (balance_wood) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 1);
    assert balance_wood = 6;
    let (bush_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 12, 3);
    assert bush_block = 10300112199;
   
    %{ stop_prank_callable5() %}

    return ();
}

@external
func test_harvest_empty{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Try harvesting an empty block 
    %{ expect_revert("TRANSACTION_FAILED") %}
    FrensLands.harvest(addresses.frenslands_proxy, 1, 1);
   
    %{ stop_prank_callable5() %}

    return ();
}

@external
func test_harvest_occupied{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Try harvesting a block with a building (cabin)
    %{ expect_revert("TRANSACTION_FAILED") %}
    FrensLands.harvest(addresses.frenslands_proxy, 20, 8);
   
    %{ stop_prank_callable5() %}

    return ();
}

@external
func test_harvest_pop{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Try harvesting a mine without enough free pop
    let (pop_len: felt, pop: felt*) = FrensLands.get_pop(addresses.frenslands_proxy, land_id);
    assert pop[0] = 1; // total_pop
    assert pop[1] = 1; // free_pop
    %{ expect_revert("TRANSACTION_FAILED") %}
    FrensLands.harvest(addresses.frenslands_proxy, 13, 3);
   
    %{ stop_prank_callable5() %}

    return ();
}