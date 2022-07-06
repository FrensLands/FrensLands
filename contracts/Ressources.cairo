%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, split_felt, assert_lt_felt
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le, is_le
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc


from contracts.utils.interfaces import IModuleController

from openzeppelin.access.ownable import Ownable

from contracts.utils.game_structs import Cost, BuildingFixedData

#############
# Interface #
#############

@contract_interface
namespace IERC1155:
    func balanceOf(account : felt, id : Uint256) -> (balance : Uint256):
    end

    func burn(_from : felt, id : Uint256, amount : Uint256):
    end

    func mint(to : felt, id : Uint256, amount : Uint256):
    end
end
    
@contract_interface
namespace IM03Buldings:
    func get_daily_cost(token_id : Uint256) -> (daily_cost_len : felt, daily_cost : felt*):
    end

    func get_daily_harvest(token_id : Uint256) -> (daily_harvest_len : felt, daily_harvest : felt*):
    end

    func get_harvest_gold_energy(token_id : Uint256) -> (daily_harvest_gold : felt, daily_harvest_energy : felt):
    end

    func get_cost_gold_energy(token_id : Uint256) -> (daily_cost_gold : felt, daily_cost_energy : felt):
    end
end

@contract_interface
namespace IERC20:
    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func mint(to : felt, amount : Uint256):
    end

    func burnFrom(account : felt, amount : Uint256):
    end


end
###########
# STORAGE #
###########

# All info for Building

@storage_var
func daily_harvest_(owner : felt, type : felt ) -> (harvest : felt):
end

@storage_var
func daily_cost_(owner : felt, type : felt) -> (cost : felt):
end

# Address of M03 Contract
@storage_var
func m03_address() -> (address : felt):
end

# Address of ERC1155Contract
@storage_var
func erc1155_address_() -> (address : felt):
end

# Address of Gold ERC20 contract
@storage_var
func gold_address_() -> (address : felt):
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

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(address_m3 : felt, erc1155_address : felt, gold_erc20_address : felt):
    
    assert_not_zero(address_m3)
    assert_not_zero(erc1155_address)
    assert_not_zero(gold_erc20_address)

    m03_address.write(address_m3)
    erc1155_address_.write(erc1155_address)
    gold_address_.write(gold_erc20_address)
    return ()
end

@external
func claim_resources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256):
    
    alloc_locals

    let (address_m3) = m03_address.read()
    let (erc1155_address) = erc1155_address_.read()
    ### Get an array of all building ids with type
    let (daily_cost_len : felt, daily_cost : felt*) = IM03Buldings.get_daily_cost(contract_address=address_m3, token_id=tokenId)
    let (daily_harvest_len : felt, daily_harvest : felt*) = IM03Buldings.get_daily_harvest(contract_address=address_m3, token_id=tokenId)
    let (local daily_harvest_gold : felt, daily_harvest_energy : felt) = IM03Buldings.get_harvest_gold_energy(contract_address=address_m3, token_id=tokenId)
    let (daily_cost_gold : felt, daily_cost_energy : felt) = IM03Buldings.get_cost_gold_energy(contract_address=address_m3, token_id=tokenId)

    sum_harvest_and_cost(erc1155_address, daily_cost_len, daily_cost, daily_harvest_len, daily_harvest)

    pay_gold(daily_harvest_gold, daily_cost_gold)

    return()
    # let (building_data : BuildingData) = get_building_data(tokenId)
    # let (building_fixed_data : BuildingFixedData) = get_building_fix_data()
end

func sum_harvest_and_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(erc1155_address : felt, daily_cost_len : felt, daily_cost : felt*, daily_harvest_len : felt, daily_harvest : felt*):

    alloc_locals

    assert daily_cost_len = daily_harvest_len
    
    if daily_cost_len == 0:
        return ()
    end
    
    let (caller) = get_caller_address()
    local harvest  = daily_harvest[daily_harvest_len]
    local cost  = daily_cost[daily_cost_len]
    let (local id) = felt_to_uint256(daily_harvest_len)
    let (is_lower) = is_le(harvest, cost)

    if is_lower == 1 :
        let (uint_balance) = IERC1155.balanceOf(contract_address=erc1155_address, account=caller, id=id)
        let (local balance) = uint256_to_felt(uint_balance)
        local due = cost - harvest
        let (enough_blance) = is_le(due, balance)
        if enough_blance == 1 :
            let (uint_due) = felt_to_uint256(due)
            IERC1155.burn(contract_address=erc1155_address, _from=caller, id=id, amount=uint_due)
            return sum_harvest_and_cost(erc1155_address, daily_cost_len - 1, daily_cost, daily_harvest_len - 1, daily_harvest)
        else :
            let (uint_balance) = felt_to_uint256(balance)
            IERC1155.burn(contract_address=erc1155_address, _from=caller, id=id, amount=uint_balance)
            return sum_harvest_and_cost(erc1155_address, daily_cost_len - 1, daily_cost, daily_harvest_len - 1, daily_harvest)
        end
    end

    let due = harvest - cost
    let (uint_due) = felt_to_uint256(due)
    IERC1155.mint(contract_address=erc1155_address, to=caller, id=id, amount=uint_due)
    return sum_harvest_and_cost(erc1155_address, daily_cost_len - 1, daily_cost, daily_harvest_len - 1, daily_harvest)
end

# func pay_taxes{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}( : felt, daily_cost : felt):
#     let (amount) =  daily_harvest - daily_cost
# end

### Pensé à si le joueur n'a pas assez d'argent pour payer
func pay_gold{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(daily_harvest_gold : felt, daily_cost_gold : felt):
    
    alloc_locals

    let (caller) = get_caller_address()
    let (address) = gold_address_.read()
    let (is_lower) = is_le(daily_harvest_gold, daily_cost_gold)
    if is_lower == 1 :
        let (local balance) = IERC20.balanceOf(contract_address=address, account=caller)
        local due = daily_cost_gold - daily_harvest_gold
        let (felt_balance) = uint256_to_felt(balance)
        let (enough_blance) = is_le(due, felt_balance)
        if enough_blance == 1 :
            let (uint_due) = felt_to_uint256(due)
            IERC20.burnFrom(contract_address=address, account=caller, amount=uint_due)
            return()
        else :
            IERC20.burnFrom(contract_address=address, account=caller, amount=balance)
            return()
        end
    end

    let due = daily_harvest_gold - daily_cost_gold
    let (uint_due) = felt_to_uint256(due)
    IERC20.mint(contract_address=address, to=caller, amount=uint_due)
    return()
end

