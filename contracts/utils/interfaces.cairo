%lang starknet

from starkware.cairo.common.uint256 import Uint256
from contracts.utils.game_structs import BuildingFixedData

# Interface for ModuleController
@contract_interface
namespace IModuleController:
    func get_module_address(module_id : felt) -> (address : felt):
    end

    func get_arbitrer() -> (arbitrer_addr : felt):
    end

    func has_write_access(address_attempting_to_write : felt) -> (success : felt):
    end

    func get_external_contract_address(external_contract_id : felt) -> (address : felt):
    end

    func appoint_new_arbitrer(new_arbitrer : felt):
    end

    func set_address_for_module_id(module_id : felt, module_address : felt):
    end

    func set_initial_module_addresses(m01_addr : felt, m02_addr : felt, m03_addr : felt):
    end

    func set_write_access(module_id_doing_writing : felt, module_id_being_written_to : felt):
    end

    func update_external_contracts(external_contract_id : felt, external_contract_address : felt):
    end
end

@contract_interface
namespace IM01Worlds:
    func get_map_array(tokenId : Uint256) -> (data_len : felt, data : felt*):
    end

    func get_latest_block(tokenId : Uint256) -> (block_number : felt):
    end

    func get_game_status(tokenId : Uint256) -> (state : felt):
    end

    func _check_can_build(tokenId : Uint256, building_size : felt, pos_start : felt) -> (
        bool : felt
    ):
    end
end

@contract_interface
namespace IM02Resources:
    func fill_ressources_harvest(
        tokenId : Uint256, daily_harvest_len : felt, daily_harvest : felt*
    ):
    end

    func fill_ressources_cost(tokenId : Uint256, daily_cost_len : felt, daily_cost : felt*):
    end

    func fill_gold_energy_harvest(tokenId : Uint256, daily_gold : felt, daily_energy : felt):
    end

    func fill_gold_energy_cost(tokenId : Uint256, daily_gold : felt, daily_energy : felt):
    end

    func update_population(tokenId : Uint256, allocated : felt, number : felt):
    end
end

@contract_interface
namespace IM03Buldings:
    func view_fixed_data(type : felt, level : felt) -> (data : BuildingFixedData):
    end

    func get_building_count(token_id : Uint256) -> (count : felt):
    end

    func get_all_building_ids(token_id : Uint256) -> (data_len : felt, data : felt*):
    end

    func get_building_data(token_id : Uint256, building_id) -> (data_len : felt, data : felt*):
    end

    func get_upgrade_cost(building_type : felt, level : felt) -> (res : felt):
    end
end
