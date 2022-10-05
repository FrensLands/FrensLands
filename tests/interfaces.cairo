%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.Resources.Resources_Data import ResourcesFixedData
from contracts.Buildings.Buildings_Data import MultipleResources, BuildingFixedData

@contract_interface
namespace FrensLands {
    func initializer(address_of_controller: felt, proxy_admin : felt) {
    }

    func start_game(land_id: felt, biome_id : felt, tokenId : Uint256) -> () {
    }

    // ----- Getters
    func get_land_id(owner : felt) -> (land_id : felt) {
    }

    func get_owner(land_id : felt) -> (owner : felt) {
    }

    func get_biome_id(land_id : felt) -> (biome_id : felt) {
    }

    func read_map_block(account: felt, pos_x: felt, pos_y : felt) -> (data: felt) {
    }

    func get_balance(land_id: felt, resource_id: felt) -> (balance: felt) {
    }

    func get_balance_all(land_id: felt) -> (balance_len: felt, balance: felt*) {
    }

    func get_pop(land_id: felt) -> (pop_len: felt, pop: felt*) {
    }

    func get_building_decay(land_id : felt, building_uid : felt) -> (decay_level : felt) {
    }

    func get_building_recharges(land_id : felt, building_uid : felt) -> (nb_recharges : felt, last_claim: felt) {
    }

    func get_building_counter(land_id : felt) -> (counter: felt) {
    }


    // Game actions

    func harvest(pos_x: felt, pos_y : felt) {
    }

    func build(pos_x: felt, pos_y : felt, building_type_id : felt) {
    }

    func destroy_building(pos_x: felt, pos_y: felt) {
    }

    func repair_building(pos_x: felt, pos_y: felt) {
    }

    func move_infrastructure(pos_x: felt, pos_y: felt, new_pos_x : felt, new_pos_y : felt) {
    }

    func fuel_building_production(pos_x: felt, pos_y: felt, nb_days: felt) {
    }

    func claim_production() {
    }

    func reinit_game() {
    }

}

@contract_interface
namespace Minter {
    func set_maps_erc721_address(address: felt) {
    }

    func set_maps_erc721_approval(operator: felt, approved: felt) {
    }

    func mint_all(nb: felt, token_id: Uint256) {
    }

    func transfer_batch(
        nb: felt, token_id_len: felt, token_id: felt*, player_len: felt, player: felt*
    ) {
    }
}

@contract_interface
namespace Arbiter {
    func set_address_of_controller(address: felt) {
    }

    func batch_set_controller_addresses(
        frenslands_address: felt, storage_address: felt, resources_address: felt, buildings_address: felt
    ) {
    }
}


@contract_interface
namespace FrensLands_Storage {
    func initializer(address_of_controller: felt, proxy_admin : felt) {
    }
}

@contract_interface
namespace Resources {
    func initializer(address_of_controller: felt, proxy_admin : felt) {
    }
    
    func read_rs_data(type_id: felt, level: felt) -> (data: ResourcesFixedData) {
    }

    func read_rs_count() -> (rs_count: felt) {
    }
}

@contract_interface
namespace Buildings {
    func initializer(address_of_controller: felt, proxy_admin : felt) {
    }

    // func update_building_data(type_id: felt, level: felt, data: BuildingFixedData) {
    // }

    // func add_building_data(type_id: felt, level: felt, data: BuildingFixedData) {
    // }

    func read_building_count() -> (building_count: felt) {
    }

    func read_build_data(type_id: felt, level: felt) -> (data: MultipleResources) {
    }

    func read_upgrade_data(type_id: felt) -> (data: MultipleResources) {
    }

    func read_maintenance_cost_data(type_id: felt, level: felt) -> (costs_len: felt, costs: felt*) {
    }

    func read_production_daily_data(type_id: felt, level: felt) -> (gains_len: felt, gains: felt*) {
    }

    func read_repair_data(type_id: felt) -> (data: MultipleResources) {
    }

    func read_pop_add_data(type_id: felt, level: felt) -> (data: felt) {
    }

    func read_pop_required_data(type_id: felt, level: felt) -> (data: felt) {
    }
}
