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
func test_resources_storage{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let (addresses: Contracts) = _get_test_addresses();

    _init_module_controller(addresses);

    %{ stop_prank_callable5 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.resources_proxy) %}

    let (struct_harvest: ResourcesFixedData) = Resources.read_rs_data(
        addresses.resources_proxy, type_id=1, level=1
    );
    assert struct_harvest.harvestingCost_qty = 301;
    assert struct_harvest.harvestingGain_qty = 102;
    assert struct_harvest.popFreeRequired = 1;
    assert struct_harvest.timeRequired = 1;

    let (struct_harvest_rock: ResourcesFixedData) = Resources.read_rs_data(
        addresses.resources_proxy, type_id=2, level=1
    );
    assert struct_harvest_rock.harvestingCost_qty = 301;
    assert struct_harvest_rock.harvestingGain_qty = 202;
    assert struct_harvest_rock.popFreeRequired = 1;
    assert struct_harvest_rock.timeRequired = 1;


    let (struct_harvest_bush: ResourcesFixedData) = Resources.read_rs_data(
        addresses.resources_proxy, type_id=3, level=1
    );
    assert struct_harvest_bush.harvestingCost_qty = 0;
    assert struct_harvest_bush.harvestingGain_qty = 302;
    assert struct_harvest_bush.popFreeRequired = 1;
    assert struct_harvest_bush.timeRequired = 1;

    let (struct_harvest_mine: ResourcesFixedData) = Resources.read_rs_data(
        addresses.resources_proxy, type_id=4, level=1
    );
    assert struct_harvest_mine.harvestingCost_qty = 303;
    assert struct_harvest_mine.harvestingGain_qty = 402502;
    assert struct_harvest_mine.popFreeRequired = 3;
    assert struct_harvest_mine.timeRequired = 2;

    let (counter_rs) = Resources.read_rs_count(addresses.resources_proxy);
    assert counter_rs = 4;

    %{ stop_prank_callable5() %}

    return ();
}
