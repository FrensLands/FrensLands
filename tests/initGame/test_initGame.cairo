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
func test_init_game{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    let (land) = FrensLands.get_land_id(addresses.frenslands_proxy, addresses.player);
    assert land = land_id;

    let (owner) = FrensLands.get_owner(addresses.frenslands_proxy, land_id);
    assert owner = addresses.player;

    let (biome_id) = FrensLands.get_biome_id(addresses.frenslands_proxy, land_id);
    assert biome_id = 3;

    // Check all balances are correct
    let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    assert balance_food = 20;

    let (balance_all_len : felt, balance_all : felt*) = FrensLands.get_balance_all(addresses.frenslands_proxy, land_id);
    assert balance_all_len = 7;
    assert balance_all[0] = 0;
    assert balance_all[1] = 0;
    assert balance_all[2] = 20;
    assert balance_all[3] = 0;
    assert balance_all[4] = 0;
    assert balance_all[5] = 0;
    assert balance_all[6] = 0;

    let (pop_len: felt, pop: felt*) = FrensLands.get_pop(addresses.frenslands_proxy, land_id);
    assert pop_len = 2;
    assert pop[0] = 1; // total_pop
    assert pop[1] = 1; // free_pop

    // Cabin 
    let (d_level) = FrensLands.get_building_decay(addresses.frenslands_proxy, land_id, 1);
    assert d_level = 100;
    let (cabin_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 20, 8);
    assert cabin_block = 20100011199;

    // ResourcesSpawned
    let (tree_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 8, 2);
    assert tree_block = 10100011199;

    let (counter) = FrensLands.get_building_counter(addresses.frenslands_proxy, land_id);
    assert counter = 1;
   
    %{ stop_prank_callable5() %}

    return ();
}