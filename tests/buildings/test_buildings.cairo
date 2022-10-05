%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from tests.interfaces import Buildings

from contracts.Buildings.Buildings_Data import BuildingFixedData, MultipleResources

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
func test_buildings_storage{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;
    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.buildings_proxy) %}

    let (struct_build: MultipleResources) = Buildings.read_build_data(
        addresses.buildings_proxy, type_id=2, level=1
    );
    assert struct_build.comp = 103202;
    assert struct_build.popRequired = 0;
    assert struct_build.popAdd = 2;

    %{
        print("comp: ", ids.struct_build.comp)
        print("popRequired: ", ids.struct_build.popRequired)
        print("timeRequired: ", ids.struct_build.popAdd)
    %}

    let (struct_bakery: MultipleResources) = Buildings.read_build_data(
        addresses.buildings_proxy, type_id=5, level=1
    );
    assert struct_bakery.comp = 103207302;
    assert struct_bakery.popRequired = 2;
    assert struct_bakery.popAdd = 0;

    let (counter) = Buildings.read_building_count(addresses.buildings_proxy);
    assert counter = 23;

    let (struct_repair_cabin: MultipleResources) = Buildings.read_repair_data(
        addresses.buildings_proxy, type_id=1
    );
    // assert struct_repair_cabin.nb = 1;
    assert struct_repair_cabin.comp = 102;
    assert struct_repair_cabin.popRequired = 0;
    assert struct_repair_cabin.popAdd = 2;


    // Read maintenance costs 
    let (costs_len: felt, costs: felt*) = Buildings.read_maintenance_cost_data(
        addresses.buildings_proxy, type_id=4, level=1
    );
    assert costs_len = 6;
    assert costs[0] = 7;
    assert costs[1] = 3;
    assert costs[2] = 6;
    assert costs[3] = 3;
    assert costs[4] = 3;
    assert costs[5] = 7;

    // Read daily production
    let (gains_len: felt, gains: felt*) = Buildings.read_production_daily_data(
        addresses.buildings_proxy, type_id=13, level=1
    );
    assert gains_len = 4;
    assert gains[0] = 2;
    assert gains[1] = 4;
    assert gains[2] = 1;
    assert gains[3] = 4;

    // Read repair data
    let (struct_repair_cabin: MultipleResources) = Buildings.read_repair_data(
        addresses.buildings_proxy, type_id=1
    );
    assert struct_repair_cabin.comp = 102;
    assert struct_repair_cabin.popRequired = 0;
    assert struct_repair_cabin.popAdd = 2;

    let (pop_add : felt) = Buildings.read_pop_add_data(
        addresses.buildings_proxy, type_id=4, level=1
    );
    assert pop_add = 28;

    let (pop_required : felt) = Buildings.read_pop_required_data(
        addresses.buildings_proxy, type_id=13, level=1
    );
    assert pop_required = 12;

    %{ stop_prank_callable5() %}

    return ();
}