%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, split_felt, assert_lt_felt, assert_le
from starkware.starknet.common.syscalls import get_caller_address, get_block_number
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le, is_le
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

from openzeppelin.access.ownable import Ownable

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

# All info for Pay ressource

@storage_var
func daily_ressources_harvest_(token_id : Uint256, id : felt ) -> (harvest : felt):
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

# Block number 
@storage_var
func block_number_(token_id : felt) -> (block : felt):
end


##########
# EVENTS #
##########


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
func fill_ressources_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_harvest_len : felt, daily_harvest : felt*):
    fill_ressources_storage_harvest(tokenId=tokenId, daily_ressources_len=daily_harvest_len, daily_ressources=daily_harvest, index=0)
    return ()
end

@external
func fill_ressources_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_cost_len : felt, daily_cost : felt*):
    fill_ressources_storage_cost(tokenId=tokenId, daily_ressources_len=daily_cost_len, daily_ressources=daily_cost, index=0)
    return ()
end

@external
func fill_gold_energy_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_gold : felt, daily_energy : felt):
    let (old_gold) = daily_gold_harvest_.read(tokenId)
    let (old_energy) = daily_energy_harvest_.read(tokenId)

    let new_gold = daily_gold + old_gold
    let new_energy = daily_energy + old_energy

    daily_gold_harvest_.write(tokenId, new_gold)
    daily_energy_harvest_.write(tokenId, new_energy)
    return ()
end

@external
func fill_gold_energy_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_gold : felt, daily_energy : felt):
    let (old_gold) = daily_gold_cost_.read(tokenId)
    let (old_energy) = daily_energy_cost_.read(tokenId)

    let new_gold = daily_gold + old_gold
    let new_energy = daily_energy + old_energy

    daily_gold_cost_.write(tokenId, new_gold)
    daily_energy_cost_.write(tokenId, new_energy)
    return ()
end


func fill_ressources_storage_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_ressources_len : felt, daily_ressources : felt*, index : felt):
   
   if index == daily_ressources_len :
        return ()
    end

    let id = daily_ressources[index]
    let quantity = daily_ressources[index + 1]

    let (oldquantity) = daily_ressources_harvest_.read(tokenId, id)
    let newquantity = oldquantity + quantity
    daily_ressources_harvest_.write(tokenId, id,newquantity)

    return fill_ressources_storage_harvest(tokenId=tokenId, daily_ressources_len=daily_ressources_len, daily_ressources=daily_ressources, index=index + 2)
end

func fill_ressources_storage_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_ressources_len : felt, daily_ressources : felt*, index : felt):
    
    if index == daily_ressources_len :
        return ()
    end

    let id = daily_ressources[index]
    let quantity = daily_ressources[index + 1]

    let (oldquantity) = daily_ressources_cost_.read(tokenId, id)
    let newquantity = oldquantity + quantity
    daily_ressources_cost_.write(tokenId, id, newquantity)

    return fill_ressources_storage_cost(tokenId=tokenId, daily_ressources_len=daily_ressources_len, daily_ressources=daily_ressources, index=index + 2)
end



@external
func claim_resources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256):
    alloc_locals
    ### Check block
    let (block_number) = get_block_number()
    let (old_block_number) = block_number_.read(tokenId)
    let old_block_number = old_block_number + 2
     
    with_attr error_message("You need to wait 2 block before claim"):
        assert_le(old_block_number, block_number)
    end

    block_number_.write(tokenId, block_number)

    ### Get all needed values
    let (address_m3) = m03_address.read()
    let (erc1155_address) = erc1155_address_.read()
    let (local daily_harvest_gold) = daily_gold_harvest_.read(tokenId)
    let (daily_cost_gold) = daily_gold_cost_.read(tokenId)
    let (daily_harvest_energy) = daily_energy_harvest_.read(tokenId)
    let (daily_cost_energy) =daily_energy_cost_.read(tokenId)
   
    ### Pay all gold ressource and energy
    pay_ressources(erc1155_address, tokenId, 9)
    pay_gold(daily_harvest_gold, daily_cost_gold)
    pay_energy(tokenId, daily_harvest_energy, daily_cost_energy)

    return()
end

func pay_ressources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(erc1155_address : felt, tokenId : Uint256, id : felt ):
    alloc_locals

    if id == 0:
        return ()
    end

    let (caller) = get_caller_address()
    let (local harvest)  = daily_ressources_harvest_.read(tokenId, id)
    let (local cost)  = daily_ressources_cost_.read(tokenId, id)

    let (is_lower) = is_le(harvest, cost)
    let (uint_id) = felt_to_uint256(id)
    if is_lower == 1 :
        let (uint_balance) = IERC1155.balanceOf(contract_address=erc1155_address, account=caller, id=uint_id)
        let (local balance) = uint256_to_felt(uint_balance)
        local due = cost - harvest
        let (enough_blance) = is_le(due, balance)
        if enough_blance == 1 :
            let (uint_due) = felt_to_uint256(due)
            IERC1155.burn(contract_address=erc1155_address, _from=caller, id=uint_id, amount=uint_due)
            return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1)
        else :
            let (uint_balance) = felt_to_uint256(balance)
            IERC1155.burn(contract_address=erc1155_address, _from=caller, id=uint_id, amount=uint_balance)
            return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1) 
        end
    end

    let due = harvest - cost
    let (uint_due) = felt_to_uint256(due)
    IERC1155.mint(contract_address=erc1155_address, to=caller, id=uint_id, amount=uint_due)
    return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1)
end

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

func pay_energy{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_harvest_energy : felt, daily_cost_energy : felt):
    let (is_lower) = is_le(daily_harvest_energy, daily_cost_energy)
    if is_lower == 1 :
        daily_energy_harvest_.write(tokenId, 0)
        return ()
    end
    let due = daily_harvest_energy - daily_cost_energy
    daily_energy_harvest_.write(tokenId, due)
    return()
end
