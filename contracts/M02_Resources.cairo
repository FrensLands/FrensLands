%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
    get_block_number,
)
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, split_felt, assert_lt_felt
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le, is_le

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds, Cost
from contracts.utils.game_constants import GOLD_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20FrensCoin, IERC1155
from contracts.utils.interfaces import IModuleController
from contracts.library.library_module import Module
from openzeppelin.access.ownable import Ownable

###########
# STORAGE #
###########

@storage_var
func daily_ressources_harvest_(token_id : Uint256, id : felt) -> (harvest : felt):
end

@storage_var
func daily_ressources_cost_(token_id : Uint256, id : felt) -> (cost : felt):
end

@storage_var
func daily_gold_harvest_(token_id : Uint256) -> (gold_harvest : felt):
end

@storage_var
func daily_gold_cost_(token_id : Uint256) -> (gold_cost : felt):
end

@storage_var
func daily_energy_harvest_(token_id : Uint256) -> (endenergy_hervest : felt):
end

@storage_var
func daily_energy_cost_(token_id : Uint256) -> (energy_cost : felt):
end

@storage_var
func population(token_id : Uint256, allocated : felt) -> (number : felt):
end

##########
# EVENTS #
##########

@event
func StartPayTaxes(owner : felt, token_id : Uint256):
end

@event
func EndPayTaxes(owner : felt, data : BuildingFixedData):
end

func felt_to_uint256{range_check_ptr}(x) -> (uint_x : Uint256):
    let (high, low) = split_felt(x)
    return (Uint256(low=low, high=high))
end

func uint256_to_felt{range_check_ptr}(value : Uint256) -> (value : felt):
    assert_lt_felt(value.high, 2 ** 123)
    return (value.high * (2 ** 128) + value.low)
end

###############
# CONSTRUCTOR #
###############

@external
func initializer{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    address_of_controller : felt
):
    Module.initialize_controller(address_of_controller)
    return ()
end

######################
# EXTERNAL FUNCTIONS #
######################

# @notice fill resources harvested, called when building is updated
# @param daily_harvest array of resources formatted [ID1, QTY1, ID2, QTY2, etc.]
@external
func fill_ressources_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_harvest_len : felt, daily_harvest : felt*
):
    fill_ressources_storage_harvest(
        tokenId=tokenId,
        daily_ressources_len=daily_harvest_len,
        daily_ressources=daily_harvest,
        index=0,
    )
    return ()
end

@external
func fill_ressources_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_cost_len : felt, daily_cost : felt*
):
    fill_ressources_storage_cost(
        tokenId=tokenId, daily_ressources_len=daily_cost_len, daily_ressources=daily_cost, index=0
    )
    return ()
end

@external
func fill_gold_energy_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_gold : felt, daily_energy : felt
):
    let (old_gold) = daily_gold_harvest_.read(tokenId)
    let (old_energy) = daily_energy_harvest_.read(tokenId)

    let new_gold = daily_gold + old_gold
    let new_energy = daily_energy + old_energy

    daily_gold_harvest_.write(tokenId, new_gold)
    daily_energy_harvest_.write(tokenId, new_energy)
    return ()
end

@external
func fill_gold_energy_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_gold : felt, daily_energy : felt
):
    let (old_gold) = daily_gold_cost_.read(tokenId)
    let (old_energy) = daily_energy_cost_.read(tokenId)

    let new_gold = daily_gold + old_gold
    let new_energy = daily_energy + old_energy

    daily_gold_cost_.write(tokenId, new_gold)
    daily_energy_cost_.write(tokenId, new_energy)
    return ()
end

func fill_ressources_storage_harvest{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(tokenId : Uint256, daily_ressources_len : felt, daily_ressources : felt*, index : felt):
    if index == daily_ressources_len:
        return ()
    end

    let id = daily_ressources[index]
    let quantity = daily_ressources[index + 1]

    let (oldquantity) = daily_ressources_harvest_.read(tokenId, id)
    let newquantity = oldquantity + quantity
    daily_ressources_harvest_.write(tokenId, id, newquantity)

    return fill_ressources_storage_harvest(
        tokenId=tokenId,
        daily_ressources_len=daily_ressources_len,
        daily_ressources=daily_ressources,
        index=index + 2,
    )
end

func fill_ressources_storage_cost{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(tokenId : Uint256, daily_ressources_len : felt, daily_ressources : felt*, index : felt):
    if index == daily_ressources_len:
        return ()
    end

    let id = daily_ressources[index]
    let quantity = daily_ressources[index + 1]

    let (oldquantity) = daily_ressources_cost_.read(tokenId, id)
    let newquantity = oldquantity + quantity
    daily_ressources_cost_.write(tokenId, id, newquantity)

    return fill_ressources_storage_cost(
        tokenId=tokenId,
        daily_ressources_len=daily_ressources_len,
        daily_ressources=daily_ressources,
        index=index + 2,
    )
end

@external
func claim_resources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256
):
    alloc_locals
    let (address_m3) = m03_address.read()
    let (erc1155_address) = erc1155_address_.read()
    let (local daily_harvest_gold) = daily_gold_harvest_.read(tokenId)
    let (daily_cost_gold) = daily_gold_cost_.read(tokenId)
    let (daily_harvest_energy) = daily_energy_harvest_.read(tokenId)
    let (daily_cost_energy) = daily_energy_cost_.read(tokenId)

    # ## Pay all gold ressource and energy
    pay_ressources(erc1155_address, tokenId, 9)
    pay_gold(daily_harvest_gold, daily_cost_gold)
    pay_energy(tokenId, daily_harvest_energy, daily_cost_energy)

    return ()
end

func pay_ressources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    erc1155_address : felt, tokenId : Uint256, id : felt
):
    alloc_locals

    if id == 0:
        return ()
    end

    let (caller) = get_caller_address()
    let (local harvest) = daily_ressources_harvest_.read(tokenId, id)
    let (local cost) = daily_ressources_cost_.read(tokenId, id)

    let (is_lower) = is_le(harvest, cost)
    let (uint_id) = felt_to_uint256(id)
    if is_lower == 1:
        let (uint_balance) = IERC1155.balanceOf(
            contract_address=erc1155_address, account=caller, id=uint_id
        )
        let (local balance) = uint256_to_felt(uint_balance)
        local due = cost - harvest
        let (enough_blance) = is_le(due, balance)
        if enough_blance == 1:
            let (uint_due) = felt_to_uint256(due)
            IERC1155.burn(
                contract_address=erc1155_address, _from=caller, id=uint_id, amount=uint_due
            )
            return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1)
        else:
            let (uint_balance) = felt_to_uint256(balance)
            IERC1155.burn(
                contract_address=erc1155_address, _from=caller, id=uint_id, amount=uint_balance
            )
            return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1)
        end
    end

    let due = harvest - cost
    let (uint_due) = felt_to_uint256(due)
    IERC1155.mint(contract_address=erc1155_address, to=caller, id=uint_id, amount=uint_due)
    return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1)
end

# ## Pensé à si le joueur n'a pas assez d'argent pour payer
func pay_gold{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    daily_harvest_gold : felt, daily_cost_gold : felt
):
    alloc_locals

    let (caller) = get_caller_address()
    let (address) = gold_address_.read()
    let (is_lower) = is_le(daily_harvest_gold, daily_cost_gold)
    if is_lower == 1:
        let (local balance) = IERC20FrensCoin.balanceOf(contract_address=address, account=caller)
        local due = daily_cost_gold - daily_harvest_gold
        let (felt_balance) = uint256_to_felt(balance)
        let (enough_blance) = is_le(due, felt_balance)
        if enough_blance == 1:
            let (uint_due) = felt_to_uint256(due)
            IERC20FrensCoin.burnFrom(contract_address=address, account=caller, amount=uint_due)
            return ()
        else:
            IERC20FrensCoin.burnFrom(contract_address=address, account=caller, amount=balance)
            return ()
        end
    end

    let due = daily_harvest_gold - daily_cost_gold
    let (uint_due) = felt_to_uint256(due)
    IERC20FrensCoin.mint(contract_address=address, to=caller, amount=uint_due)
    return ()
end

func pay_energy{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_harvest_energy : felt, daily_cost_energy : felt
):
    let (is_lower) = is_le(daily_harvest_energy, daily_cost_energy)
    if is_lower == 1:
        daily_energy_harvest_.write(tokenId, 0)
        return ()
    end
    let due = daily_harvest_energy - daily_cost_energy
    daily_energy_harvest_.write(tokenId, due)
    return ()
end

# @notice Update storage var population
# @param allocated : 1 means allocated to building, 0 means available
@external
func update_population{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, allocate : felt, number : felt
):
    alloc_locals
    let (local available_pop) = population.read(tokenId, 1)

    if allocated == 1:
        with_attr error_message("M01_Resources: not enough population to allocate."):
            assert_le(number, available_pop)
        end
        population.write(tokenId, allocate, available_pop + number)
    end

    if allocated == 0:
        population.write(tokenId, allocate, pop - number)
    end

    return ()
end
