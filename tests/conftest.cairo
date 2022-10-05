%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import Uint256
from tests.interfaces import (
    Minter, 
    Arbiter, 
    FrensLands, 
    Resources, 
    Buildings,
    FrensLands_Storage
)
from contracts.Buildings.Buildings_Data import MultipleResources, BuildingFixedData, MultipleResourcesTime

const PK = 11111;
const PK2 = 22222;
const PK3 = 33333;
const ERC721_NAME = 123456789;
const ERC721_SYMBOL = 123456789;
const URI_LEN = 1;
const URI = 111111111;

struct Contracts {
    owner: felt,
    player: felt,
    player2: felt,
    frenslands: felt,
    frenslands_proxy: felt,
    storage_proxy: felt,
    minter: felt,
    erc721: felt,
    arbiter: felt,
    modulecontroller: felt,
    resources_proxy: felt,
    buildings_proxy: felt,
}

func setup{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() {
// @external
// func __setup__{syscall_ptr : felt*, range_check_ptr}() {

    alloc_locals;
    %{
        context.owner_address = deploy_contract("lib/openzeppelin/account/presets/Account.cairo", [ids.PK]).contract_address
        print("account owner: ", context.owner_address)
        context.player_address = deploy_contract("lib/openzeppelin/account/presets/Account.cairo", [ids.PK2]).contract_address 
        print("account player: ", context.player_address)
        context.player2_address = deploy_contract("lib/openzeppelin/account/presets/Account.cairo", [ids.PK3]).contract_address 
        print("account player: ", context.player2_address)

        context.minter_address = deploy_contract("contracts/tokens/Minter_Maps_ERC721.cairo", [context.owner_address]).contract_address
        print("minter_address: ", context.minter_address)
        context.erc721_address = deploy_contract("contracts/tokens/Maps_ERC721_enumerable_mintable_burnable.cairo",[ids.ERC721_NAME, ids.ERC721_SYMBOL, context.minter_address, ids.URI_LEN, ids.URI]).contract_address
        print("erc721_address: ", context.erc721_address)

        # declare proxy_class_hash so that starknet knows about it. It's required to deploy proxies from contracts
        declared_proxy = declare("./lib/openzeppelin/upgrades/presets/Proxy.cairo")
        context.proxy_class_hash = declared_proxy.class_hash

        # deploy FL_storage contract and proxy
        context.FL_Storage_implementation_hash = declare("contracts/FrensLands_Storage.cairo").class_hash
        prepared_proxy_FL_storage = prepare(declared_proxy,{"implementation_hash":context.FL_Storage_implementation_hash})
        context.frenslands_storage_proxy = deploy(prepared_proxy_FL_storage).contract_address
        context.storage_address = context.FL_Storage_implementation_hash

        # context.storage_address = deploy_contract("contracts/FrensLands_Storage.cairo",[]).contract_address
        # print("storage_address: ", context.storage_address)

        #context.frenslands_address = deploy_contract("contracts/FrensLands.cairo",[]).contract_address
        # context.frenslands_proxy = deploy_contract("lib/openzeppelin/upgrades/presets/Proxy.cairo",[context.frenslands_address]).contract_address
        #context.declare_proxy_frenslands = declare("lib/openzeppelin/upgrades/presets/Proxy.cairo")
        #context.prepare_proxy = prepare(context.declare_proxy_frenslands, [context.frenslands_address])
        #context.frenslands_proxy = context.prepare_proxy.contract_address
        #deploy(context.prepare_proxy)

        # Deploy FL and FL proxy
        #declare class implementation of basic_proxy_impl
        context.FL_implementation_hash = declare("contracts/FrensLands.cairo").class_hash
        prepared_proxy = prepare(declared_proxy,{"implementation_hash":context.FL_implementation_hash})
        context.frenslands_proxy = deploy(prepared_proxy).contract_address
        context.frenslands_address = context.FL_implementation_hash


        print("frenslands_address: ", context.FL_implementation_hash)
        print("frenslands_proxy: ", context.frenslands_proxy)

        # Deploy Resources module
        context.resources_implementation_hash = declare("contracts/Resources/Resources.cairo").class_hash
        prepared_proxy_resources = prepare(declared_proxy,{"implementation_hash":context.resources_implementation_hash})
        context.resources_proxy = deploy(prepared_proxy_resources).contract_address
        # context.resources_address = deploy_contract("contracts/Resources/Resources.cairo", []).contract_address
        print("resources_address: ", context.resources_proxy)


        # context.buildings_address = deploy_contract("contracts/Buildings/Buildings.cairo", []).contract_address
        # print("buildings_address: ", context.buildings_address)
        
        # Deploy Building module 
        context.buildings_implementation_hash = declare("contracts/Buildings/Buildings.cairo").class_hash
        prepared_proxy_buildings = prepare(declared_proxy,{"implementation_hash":context.buildings_implementation_hash})
        context.buildings_proxy = deploy(prepared_proxy_buildings).contract_address

        # ModuleController 
        context.arbiter_address = deploy_contract("contracts/Arbiter.cairo",[context.owner_address]).contract_address
        print("arbiter_address: ", context.arbiter_address)
        context.controller_address = deploy_contract("contracts/ModuleController.cairo",[context.arbiter_address, context.erc721_address, context.minter_address]).contract_address
        print("controller_address: ", context.controller_address)
    %}
    return ();
}

@view
func _get_test_addresses{syscall_ptr: felt*, range_check_ptr}() -> (addresses: Contracts) {
    tempvar _addresses: Contracts;
    %{
        ids._addresses.owner = context.owner_address
        ids._addresses.player = context.player_address
        ids._addresses.player2 = context.player2_address
        ids._addresses.minter = context.minter_address
        ids._addresses.erc721 = context.erc721_address

        # Modules
        ids._addresses.storage_proxy = context.frenslands_storage_proxy
        ids._addresses.frenslands = context.frenslands_address
        ids._addresses.frenslands_proxy = context.frenslands_proxy

        ids._addresses.resources_proxy = context.resources_proxy
        ids._addresses.buildings_proxy = context.buildings_proxy

        ids._addresses.modulecontroller = context.controller_address
        ids._addresses.arbiter = context.arbiter_address

        # stop_prank_callable = start_prank(ids._addresses.owner, target_contract_address=ids._addresses.manager)
    %}
    return (_addresses,);
}

@view
func _init_module_controller{syscall_ptr: felt*, range_check_ptr}(addresses: Contracts) {
    %{ stop_prank_callable2 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.arbiter) %}
    Arbiter.set_address_of_controller(addresses.arbiter, addresses.modulecontroller);
    Arbiter.batch_set_controller_addresses(
        addresses.arbiter, addresses.frenslands_proxy, addresses.storage_proxy, addresses.resources_proxy, addresses.buildings_proxy
    );

    // Initialize module controller addresses & proxy in modules 
    FrensLands.initializer(addresses.frenslands_proxy, addresses.modulecontroller, addresses.owner);
    FrensLands_Storage.initializer(addresses.storage_proxy, addresses.modulecontroller, addresses.owner);
    Resources.initializer(addresses.resources_proxy, addresses.modulecontroller, addresses.owner);
    Buildings.initializer(addresses.buildings_proxy, addresses.modulecontroller, addresses.owner);
    return ();
}

func _run_minter{syscall_ptr: felt*, range_check_ptr}(addresses: Contracts, n_lands: felt) {
    alloc_locals;
    %{ stop_prank_callable3 = start_prank(ids.addresses.owner, target_contract_address=ids.addresses.minter) %}
    Minter.set_maps_erc721_address(addresses.minter, addresses.erc721);
    Minter.set_maps_erc721_approval(addresses.minter, addresses.owner, TRUE);
    Minter.mint_all(addresses.minter, n_lands, Uint256(1, 0));

    let (local tokenId: felt*) = alloc();
    assert tokenId[0] = 1;
    let (local playerAddr: felt*) = alloc();
    assert playerAddr[0] = addresses.player;

    Minter.transfer_batch(addresses.minter, 1, 1, tokenId, 1, playerAddr);
    return ();
}
