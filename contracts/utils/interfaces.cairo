%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.Resources.Resources_Data import ResourcesFixedData
from contracts.Buildings.Buildings_Data import MultipleResources, BuildingFixedData, MultipleResourcesTime

// Interface FrensLands Storage contract
@contract_interface
namespace IFrensLandsStorage {
    func set_value(x: felt, y: felt) {
    }

    func read_value(x: felt) -> (y: felt) {
    }
}

// Interface for ModuleController
@contract_interface
namespace IModuleController {
    func get_module_address(module_id: felt) -> (address: felt) {
    }

    func get_arbiter() -> (arbiter_addr: felt) {
    }

    func has_write_access(address_attempting_to_write: felt) -> (success: felt) {
    }

    func get_external_contract_address(external_contract_id: felt) -> (address: felt) {
    }

    func appoint_new_arbiter(new_arbiter: felt) {
    }

    func set_address_for_module_id(module_id: felt, module_address: felt) {
    }

    func set_initial_module_addresses(
        frenslands_address: felt, storage_address: felt, resources_address: felt, buildings_address: felt
    ) {
    }

    func set_write_access(module_id_doing_writing: felt, module_id_being_written_to: felt) {
    }
}

@contract_interface
namespace IM01Worlds {
    func get_map_array(tokenId: Uint256) -> (data_len: felt, data: felt*) {
    }

    func get_game_status(tokenId: Uint256) -> (state: felt) {
    }

    func _check_can_build(tokenId: Uint256, building_size: felt, pos_start: felt) -> (bool: felt) {
    }

    func get_map_block(tokenId: Uint256, index: felt) -> (data: felt) {
    }

    func update_map_block(tokenId: Uint256, index: felt, data: felt) -> () {
    }
}

@contract_interface
namespace IM02Resources {
    func update_population(tokenId: Uint256, allocated: felt, number: felt) {
    }

    func update_block_number(tokenId: Uint256, _block_nb: felt) {
    }

    func get_latest_block(tokenId: Uint256) -> (block_number: felt) {
    }

    func get_block_start(tokenId: Uint256) -> (block_number: felt) {
    }

    func get_population(tokenId: Uint256) -> (pop_len: felt, pop: felt*) {
    }

    func _receive_resources_start(amount: Uint256, account: felt) {
    }

    func _get_tokens(tokenId: Uint256, caller: felt, amount: Uint256) {
    }

    func _get_resources(tokenId: Uint256, caller: felt, res_len: felt, res: felt*) {
    }

    func get_energy_level(tokenId: Uint256) -> (energy: felt) {
    }

    func _update_energy(tokenId: Uint256, operation: felt, val: felt) {
    }

    func _pay_frens_coins(account: felt, amount: Uint256) {
    }

    func has_resources(
        player: felt, erc1155_addr: felt, costs_len: felt, costs: felt*, multiplier
    ) -> (bool: felt) {
    }

    func _get_resources_destroyed(
        tokenId: Uint256, caller: felt, res_len: felt, res: felt*, multiplier: felt
    ) {
    }

    func _reinitialize_resources(tokenId: Uint256, caller: felt) {
    }
}

@contract_interface
namespace IM03Buildings {
    func view_fixed_data(type: felt, level: felt) -> (data: BuildingFixedData) {
    }

    func get_building_count(token_id: Uint256) -> (count: felt) {
    }

    func get_all_building_ids(token_id: Uint256) -> (data_len: felt, data: felt*) {
    }

    func get_building_data(token_id: Uint256, building_id) -> (data_len: felt, data: felt*) {
    }

    func get_upgrade_cost(building_type: felt, level: felt) -> (res: felt) {
    }

    func initialize_resources(tokenId: Uint256, block_number: felt, unique_id_count: felt) {
    }

    func _destroy_building(tokenId: Uint256, building_unique_id: felt) -> () {
    }

    func _update_level(tokenId: Uint256, building_unique_id: felt, level: felt) -> () {
    }

    func update_building_claimed_data(
        tokenId: Uint256, building_unique_id: felt, recharge: felt, last_claim: felt
    ) {
    }

    func view_fixed_data_claim(type: felt, level: felt) -> (
        building_data_len: felt, building_data: felt*
    ) {
    }

    func get_all_buildings_data(token_id: Uint256) -> (data_len: felt, data: felt*) {
    }

    func _reinitialize_buildings(tokenId: Uint256, caller: felt) {
    }
}

@contract_interface
namespace IResourcesSpawned {
    func read_rs_data(type_id: felt, level: felt) -> (data: ResourcesFixedData) {
    }
}

@contract_interface
namespace IBuildings {

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
