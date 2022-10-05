%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_number
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from tests.conftest import (
    Contracts,
    setup,
    _get_test_addresses,
    _init_module_controller,
    _run_minter,
)
from tests.interfaces import FrensLands
from contracts.utils.tokens_interfaces import IERC721Lands

@external
func __setup__{syscall_ptr : felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return setup();
}

@external
func test_init_game{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);
    _run_minter(addresses, 100);

    // Start game player has an NFT
    %{ stop_prank_callable4 = start_prank(ids.addresses.player, target_contract_address=ids.addresses.frenslands_proxy) %}

    // Starting game
    let tokenId = Uint256(1, 0);
    let land_id = 11111;
    let (owner) = FrensLands.get_owner(addresses.frenslands_proxy, land_id);
    FrensLands.start_game(addresses.frenslands_proxy, land_id, 3, tokenId);

    // ------------------------------ HARVEST ----------------------
    
    // Harvest a tree 3 times
    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    FrensLands.harvest(addresses.frenslands_proxy, 8, 2);
    // Harvest a rock 3 times
    FrensLands.harvest(addresses.frenslands_proxy, 13, 2);
    FrensLands.harvest(addresses.frenslands_proxy, 13, 2);
    FrensLands.harvest(addresses.frenslands_proxy, 13, 2);
    // Repair cabin
    FrensLands.repair_building(addresses.frenslands_proxy, 20, 8);
    // harvest trees and rocks 
    FrensLands.harvest(addresses.frenslands_proxy, 4, 3);
    FrensLands.harvest(addresses.frenslands_proxy, 4, 3);
    FrensLands.harvest(addresses.frenslands_proxy, 4, 3);
    FrensLands.harvest(addresses.frenslands_proxy, 11, 3);
    FrensLands.harvest(addresses.frenslands_proxy, 11, 3);
    FrensLands.harvest(addresses.frenslands_proxy, 11, 3);
    FrensLands.harvest(addresses.frenslands_proxy, 26, 2);
    // Build 2 houses
    FrensLands.build(addresses.frenslands_proxy, 1, 1, 2);
    FrensLands.build(addresses.frenslands_proxy, 1, 2, 2);

    // let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    // %{ print("balance_food: ", ids.balance_food) %}
    // // 7
    // let (balance_wood) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 1);
    // %{ print("balance_wood: ", ids.balance_wood) %}
    // // 10
    // let (balance_rock) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 2);
    // %{ print("balance_rock: ", ids.balance_rock) %}
    // 4

    // Build cereal farm
    FrensLands.build(addresses.frenslands_proxy, 1, 3, 14);
    let (pop_len: felt, pop: felt*) = FrensLands.get_pop(addresses.frenslands_proxy, land_id);
    assert pop[0] = 7; // total_pop
    assert pop[1] = 2; // free_pop

    FrensLands.claim_production(addresses.frenslands_proxy);
    // let (farm_recharges: felt, last_claim: felt) = FrensLands.get_building_recharges(addresses.frenslands_proxy, land_id, 4);
    // assert farm_recharges = 3;
    // assert last_claim = block;


    // FrensLands.reinit_game(addresses.frenslands_proxy);
    // let (balance_food) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 3);
    // assert balance_food = 20;
    // %{ print("balance_food: ", ids.balance_food) %}
    // let (balance_wood) = FrensLands.get_balance(addresses.frenslands_proxy, land_id, 1);
    // assert balance_wood = 0;
    // let (tree_block) = FrensLands.read_map_block(addresses.frenslands_proxy, land_id, 8, 2);
    // assert tree_block = 10100011199;

    %{ stop_prank_callable4() %}

    return ();
}