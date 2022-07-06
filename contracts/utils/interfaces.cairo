%lang starknet

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
namespace IModule01:
    func get_map(tokenId : Uint256):
    end

    func start_game(tokenId : Uint256) -> ():
    end

    func pause_game(tokenId : Uint256) -> ():
    end

    func save_map(tokenId : Uint256) -> ():
    end

    func get_game_status(tokenId : Uint256) -> (state : felt):
    end

    func get_latest_block(tokenId : Uint256) -> (block_number : felt):
    end
end

@contract_interface
namespace IModule02:
end

@contract_interface
namespace IModule03:
    func upgrade(
        token_id : Uint256,
        building_type_id : felt,
        level : felt,
        position : felt,
        allocated_population : felt,
    ):
    end

    func destroy(token_id : Uint256, building_unique_id : felt):
    end

    func move(token_id : Uint256, building_id : felt, level : felt):
    end

    func get_building_count(token_id : Uint256) -> (count : felt):
    end

    func view_fixed_data(type : felt, level : felt) -> (data : BuildingFixedData):
    end

    func get_building_data(token_id : Uint256, building_id) -> (data_len : felt, data : felt*):
    end

    func get_all_building_ids(token_id : Uint256) -> (data_len : felt, data : felt*):
    end
end
