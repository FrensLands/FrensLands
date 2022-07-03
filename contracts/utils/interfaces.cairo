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

    func appoint_new_arbitrer(new_arbitrer : felt):
    end

    func set_address_for_module_id(module_id : felt, module_address : felt):
    end

    func set_initial_module_addresses(module_01_addr : felt):
    end

    func set_write_access(module_id_doing_writing : felt, module_id_being_written_to : felt):
    end

    func update_external_contracts(external_contract_id : felt, external_contract_address : felt):
    end
end
