%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from tests.interfaces import FrensLands
from contracts.Resources.Resources import ResourcesFixedData
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
func test_repair_building{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Repair Cabin 
    let (cabin_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 20, 8);
    assert cabin_block = 20100011199;
    let (d_level) = FrensLands.get_building_decay(addresses.frenslands_proxy, land_id, 1);
    assert d_level = 100;
    let (pop_len: felt, pop: felt*) = FrensLands.get_pop(addresses.frenslands_proxy, land_id);
    assert pop[0] = 1; // total_pop
    assert pop[1] = 1; // free_pop

    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    FrensLands.repair_building(addresses.frenslands_proxy, 20, 8);

    let (d_level_updated) = FrensLands.get_building_decay(addresses.frenslands_proxy, land_id, 1);
    assert d_level_updated = 0;
    let (pop_len: felt, pop: felt*) = FrensLands.get_pop(addresses.frenslands_proxy, land_id);
    assert pop[0] = 3; // total_pop
    assert pop[1] = 3; // free_pop
   
    %{ stop_prank_callable5() %}

    return ();
}

@external
func test_repair_empty{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Try repairing empty block
    %{ expect_revert("TRANSACTION_FAILED") %}
    FrensLands.repair_building(addresses.frenslands_proxy, 1, 1);
   
    %{ stop_prank_callable5() %}

    return ();
}

@external
func test_repair_rs{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // Try repairing resource spawned
    %{ expect_revert("TRANSACTION_FAILED") %}
    FrensLands.repair_building(addresses.frenslands_proxy, 8, 2);
   
    %{ stop_prank_callable5() %}

    return ();
}

@external
func test_repair_resources{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    %{ store(ids.addresses.storage_proxy, "balance", [0], key=[ids.land_id, 1]) %}

    // Try repairing cabin without enough wood
    %{ expect_revert("TRANSACTION_FAILED") %}
    FrensLands.repair_building(addresses.frenslands_proxy, 20, 8);
   
    %{ stop_prank_callable5() %}

    return ();
}