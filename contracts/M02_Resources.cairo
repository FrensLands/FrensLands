%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
    get_block_number,
)
from starkware.cairo.common.uint256 import Uint256, uint256_sub
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, split_felt, assert_lt_felt, assert_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_not_zero, is_nn_le, is_le, is_in_range

from contracts.utils.game_structs import (
    ModuleIds,
    ExternalContractsIds,
    BuildingFixedData,
    MapsPrice,
    MultipleResources
)
from contracts.utils.game_constants import GOLD_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20FrensCoin, IERC1155
from contracts.utils.interfaces import IModuleController, IM03Buldings, IM01Worlds
from contracts.library.library_module import Module
from openzeppelin.access.ownable import Ownable
from contracts.utils.bArray import bArray
from contracts.library.library_data import Data


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

# Stores allocated population
# allocated = 0, means available
# allocated = 1, means allocated to building
@storage_var
func population_(token_id : Uint256, allocated : felt) -> (number : felt):
end

@storage_var
func energy_level(token_id : Uint256) -> (number : felt):
end

# Time is calculated using blocks. Stores the first blocks the world was generated
@storage_var
func start_block_(token_id : Uint256) -> (block : felt):
end

# Stores the last block
@storage_var
func block_number_(token_id : Uint256) -> (block : felt):
end

# Stores the last block
@storage_var
func initialized_(token_id : Uint256) -> (value : felt):
end


# Interfaces 
# Address of M03 Contract
@storage_var
func m03_address() -> (address : felt):
end

@storage_var
func m01_address() -> (address : felt):
end

# Address of ERC1155Contract
@storage_var
func erc1155_address_() -> (address : felt):
end

# Address of Gold ERC20 contract
@storage_var
func gold_address_() -> (address : felt):
end

@storage_var
func admin_() -> (value : felt):
end

@storage_var
func maps_address_() -> (address : felt):
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
func constructor{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(admin_addr : felt):
    admin_.write(admin_addr)
    return ()
end

@external
func initializer{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    # address_of_controller : felt
    address_m3 : felt, 
    address_m1 : felt,
    erc1155_address : felt, 
    gold_erc20_address : felt,
    maps_addr: felt
):
    let (caller) = get_caller_address()
    let (admin_addr) = admin_.read()
    assert caller = admin_addr 

    # Module.initialize_controller(address_of_controller)
    assert_not_zero(address_m3)
    assert_not_zero(address_m1)
    assert_not_zero(erc1155_address)
    assert_not_zero(gold_erc20_address)
    assert_not_zero(maps_addr)

    m03_address.write(address_m3)
    m01_address.write(address_m1)
    erc1155_address_.write(erc1155_address)
    gold_address_.write(gold_erc20_address)
    maps_address_.write(maps_addr)
    return ()
end

######################
# EXTERNAL FUNCTIONS #
######################

# @notice fill resources harvested, called when building is updated
# @param daily_harvest array of resources formatted [ID1, QTY1, ID2, QTY2, etc.]
@external
func fill_ressources_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_harvest_len : felt, daily_harvest : felt*, operation : felt
):
    # Only M03 can update ressources_harvest
    # _only_approved()
    let (m03_addr) = m03_address.read()
    let (caller) = get_caller_address()
    assert caller = m03_addr

    # Check operation allowed
    assert_le(operation, 1)
    fill_ressources_storage_harvest(
        tokenId=tokenId,
        daily_ressources_len=daily_harvest_len,
        daily_ressources=daily_harvest,
        index=0,
        operation=operation,
    )
    return ()
end

@external
func fill_ressources_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_cost_len : felt, daily_cost : felt*, operation : felt
):
    # Only M03 can update ressources costs
    # _only_approved()
    let (m03_addr) = m03_address.read()
    let (caller) = get_caller_address()
    assert caller = m03_addr

    # Check operation allowed
    assert_le(operation, 1)
    fill_ressources_storage_cost(
        tokenId=tokenId,
        daily_ressources_len=daily_cost_len,
        daily_ressources=daily_cost,
        index=0,
        operation=operation,
    )
    return ()
end

@external
func fill_gold_energy_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_gold : felt, daily_energy : felt, operation : felt
):
    alloc_locals
    # Only M03 can update gold & energy harvest
    # _only_approved()
    let (m03_addr) = m03_address.read()
    let (caller) = get_caller_address()
    assert caller = m03_addr

    let (local old_gold) = daily_gold_harvest_.read(tokenId)
    let (local old_energy) = daily_energy_harvest_.read(tokenId)

    if operation == 1:
        local new_gold = old_gold + daily_gold
        local new_energy = old_energy + daily_energy
        daily_gold_harvest_.write(tokenId, new_gold)
        daily_energy_harvest_.write(tokenId, new_energy)
        tempvar syscall_ptr = syscall_ptr
    else:
        local new_gold = old_gold - daily_gold
        local new_energy = old_energy - daily_energy
        daily_gold_harvest_.write(tokenId, new_gold)
        daily_energy_harvest_.write(tokenId, new_energy)
        tempvar syscall_ptr = syscall_ptr
    end

    return ()
end

@external
func fill_gold_energy_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, daily_gold : felt, daily_energy : felt, operation : felt
):
    # Only M03 can update gold & energy cost
    # _only_approved()
    let (m03_addr) = m03_address.read()
    let (caller) = get_caller_address()
    assert caller = m03_addr

    let (old_gold) = daily_gold_cost_.read(tokenId)
    let (old_energy) = daily_energy_cost_.read(tokenId)

    if operation == 1:
        let new_gold = old_gold + daily_gold
        let new_energy = old_energy + daily_energy
        daily_gold_cost_.write(tokenId, new_gold)
        daily_energy_cost_.write(tokenId, new_energy)
        tempvar syscall_ptr = syscall_ptr
    else:
        let new_gold = old_gold - daily_gold
        let new_energy = old_energy - daily_energy
        daily_gold_cost_.write(tokenId, new_gold)
        daily_energy_cost_.write(tokenId, new_energy)
        tempvar syscall_ptr = syscall_ptr
    end

    return ()
end

func fill_ressources_storage_harvest{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    tokenId : Uint256,
    daily_ressources_len : felt,
    daily_ressources : felt*,
    index : felt,
    operation : felt,
):
    alloc_locals
    if index == daily_ressources_len:
        return ()
    end

    let id = daily_ressources[index]
    let quantity = daily_ressources[index + 1]

    let (oldquantity) = daily_ressources_harvest_.read(tokenId, id)
    if operation == 1:
        local newquantity = oldquantity + quantity
        daily_ressources_harvest_.write(tokenId, id, newquantity)
        tempvar syscall_ptr = syscall_ptr
    else:
        local newquantity = oldquantity - quantity
        daily_ressources_harvest_.write(tokenId, id, newquantity)
        tempvar syscall_ptr = syscall_ptr
    end

    return fill_ressources_storage_harvest(
        tokenId=tokenId,
        daily_ressources_len=daily_ressources_len,
        daily_ressources=daily_ressources,
        index=index + 2,
        operation=operation,
    )
end

func fill_ressources_storage_cost{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    tokenId : Uint256,
    daily_ressources_len : felt,
    daily_ressources : felt*,
    index : felt,
    operation : felt,
):
    alloc_locals
    if index == daily_ressources_len:
        return ()
    end

    let id = daily_ressources[index]
    let quantity = daily_ressources[index + 1]

    let (oldquantity) = daily_ressources_cost_.read(tokenId, id)
    if operation == 1:
        local newquantity = oldquantity + quantity
        daily_ressources_cost_.write(tokenId, id, newquantity)
        tempvar syscall_ptr = syscall_ptr
    else:
        local newquantity = oldquantity - quantity
        daily_ressources_cost_.write(tokenId, id, newquantity)
        tempvar syscall_ptr = syscall_ptr
    end

    return fill_ressources_storage_cost(
        tokenId=tokenId,
        daily_ressources_len=daily_ressources_len,
        daily_ressources=daily_ressources,
        index=index + 2,
        operation=operation,
    )
end

@external
func claim_resources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256
):
    alloc_locals

    # Check caller is owner
    let (caller) = get_caller_address()
    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert bool = 1
    end

    # ## Check block
    let (block_number) = get_block_number()
    let (old_block_number) = block_number_.read(tokenId)
    let old_block_number = old_block_number + 2

    with_attr error_message("M02_Resources: You need to wait 2 block before claiming resources"):
        assert_le(old_block_number, block_number)
    end

    block_number_.write(tokenId, block_number)

    # let (controller) = Module.get_controller()
    let (address_m3) = m03_address.read()
    let (erc1155_address) = erc1155_address_.read()
    let (local daily_harvest_gold) = daily_gold_harvest_.read(tokenId)
    let (daily_cost_gold) = daily_gold_cost_.read(tokenId)
    let (daily_harvest_energy) = daily_energy_harvest_.read(tokenId)
    let (daily_cost_energy) = daily_energy_cost_.read(tokenId)

    let (erc20_addr) = gold_address_.read()

    ### Multiplier if we are more than 2 block
    local multiplier = block_number - old_block_number
    let (is_zero) = is_not_zero(multiplier)
    if is_zero == 1:
        let (q, _) = unsigned_div_rem(multiplier, 2)
        let new_daily_harvest_gold = daily_harvest_gold * q
        let new_daily_cost_gold = daily_cost_gold * q
        let new_daily_harvest_energy = daily_harvest_energy * q
        let new_daily_cost_energy = daily_cost_energy * q
        pay_ressources(erc1155_address, tokenId, 9, q)
        pay_gold(caller, new_daily_harvest_gold, new_daily_cost_gold)
        pay_energy(tokenId, new_daily_harvest_energy, new_daily_cost_energy)
        return()
    end

    # ## Pay all gold ressource and energy
    pay_ressources(erc1155_address, tokenId, 9, 1)
    pay_gold(caller, daily_harvest_gold, daily_cost_gold)
    pay_energy(tokenId, daily_harvest_energy, daily_cost_energy)

    # Update block_number_ storage var
    block_number_.write(tokenId, old_block_number)

    return ()
end

func pay_ressources{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    erc1155_address : felt, tokenId : Uint256, id : felt, mul : felt
):
    alloc_locals

    if id == 0:
        return ()
    end

    let (caller) = get_caller_address()
    let (old_harvest)  = daily_ressources_harvest_.read(tokenId, id)
    let (old_cost)  = daily_ressources_cost_.read(tokenId, id)

    let harvest = old_harvest * mul
    let cost = old_cost * mul
    let (is_lower) = is_le(harvest, cost)
    let (uint_id) = felt_to_uint256(id)
    if is_lower == 1 :
        let (uint_balance) = IERC1155.balanceOf(contract_address=erc1155_address, owner=caller, token_id=uint_id)
        let (local balance) = uint256_to_felt(uint_balance)
        local due = cost - harvest
        let (enough_blance) = is_le(due, balance)
        if enough_blance == 1 :
            let (uint_due) = felt_to_uint256(due)
            IERC1155.burn(contract_address=erc1155_address, _from=caller, id=uint_id, amount=uint_due)
            return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1, mul=mul)
        else :
            let (uint_balance) = felt_to_uint256(balance)
            IERC1155.burn(contract_address=erc1155_address, _from=caller, id=uint_id, amount=uint_balance)
            return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1, mul=mul) 
        end
    end

    let due = harvest - cost
    let (uint_due) = felt_to_uint256(due)
    IERC1155.mint(contract_address=erc1155_address, to=caller, id=uint_id, amount=uint_due)
    return pay_ressources(erc1155_address=erc1155_address, tokenId=tokenId, id=id - 1, mul=mul)
end

# ## Pensé à si le joueur n'a pas assez d'argent pour payer
func pay_gold{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    caller : felt, daily_harvest_gold : felt, daily_cost_gold : felt
):
    alloc_locals

    let (erc20_addr) = gold_address_.read()

    let (is_lower) = is_le(daily_harvest_gold, daily_cost_gold)
    if is_lower == 1:
        let (local balance) = IERC20FrensCoin.balanceOf(contract_address=erc20_addr, account=caller)
        local due = daily_cost_gold - daily_harvest_gold
        let (felt_balance) = uint256_to_felt(balance)
        let (enough_blance) = is_le(due, felt_balance)
        if enough_blance == 1:
            let (uint_due) = felt_to_uint256(due)
            IERC20FrensCoin.burnFrom(contract_address=erc20_addr, account=caller, amount=uint_due)
            return ()
        else:
            IERC20FrensCoin.burnFrom(contract_address=erc20_addr, account=caller, amount=balance)
            return ()
        end
    end

    let due = daily_harvest_gold - daily_cost_gold
    let (uint_due) = felt_to_uint256(due)
    IERC20FrensCoin.mint(contract_address=erc20_addr, to=caller, amount=uint_due)
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
# @param allocated : 1 means allocated to building, 0 means available, 3 to add new pop to land
@external
func update_population{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, allocate : felt, number : felt
):
    alloc_locals
    # Only M03 can update population
    # _only_approved()
    let (m03_addr) = m03_address.read()
    let (m01_addr) = m01_address.read()
    let (caller) = get_caller_address()
    
    local check = 0
    if m03_addr == caller:
        local check = 1
        tempvar range_check_ptr = range_check_ptr
    else:
        with_attr error_message("M02_Resources: you can't update population."):
            assert m01_addr = caller
        end
        tempvar range_check_ptr = range_check_ptr
    end

    let (available_pop) = population_.read(tokenId, 0)
    let (allocated_pop) = population_.read(tokenId, 1)

    if allocate == 1:
        with_attr error_message("M01_Resources: not enough population to allocate."):
            assert_le(number, available_pop)
        end
        population_.write(tokenId, 1, allocated_pop + number)
        population_.write(tokenId, 0, available_pop - number)
        tempvar syscall_ptr = syscall_ptr
        return ()
    end

    if allocate == 0:
        population_.write(tokenId, 1, allocated_pop - number)
        population_.write(tokenId, 0, available_pop + number)
        tempvar syscall_ptr = syscall_ptr
        return ()
    end

    if allocate == 3:
        population_.write(tokenId, 0, available_pop + number)
        tempvar syscall_ptr = syscall_ptr
        return ()
    end

    return ()
end

# @notice updates start_block_ number on initialization
# @notice updates last block_number_ needed to calculate costs
@external
func update_block_number{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    tokenId : Uint256, _block_nb : felt
):
    alloc_locals
    # Only M01 can update block_number value
    # _only_approved()
    let (m01_addr) = m01_address.read()
    let (caller) = get_caller_address()
    assert m01_addr = caller

    block_number_.write(tokenId, _block_nb)

    let (local start) = start_block_.read(tokenId)
    if start == 0:
        start_block_.write(tokenId, _block_nb)
        return ()
    end

    return ()
end

@external
func _receive_resources_erc20{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    account : felt
):
    let (m01_addr) = m01_address.read()
    let (caller) = get_caller_address()
    assert m01_addr = caller

    let (_initialized) = initialized_.read(tokenId)

    assert _initialized = 0

    let (gold_erc20_addr) = gold_address_.read()

    # Mint some Gold (minus the price of the map)
    let (amount : Uint256) = uint256_sub(Uint256(GOLD_START, 0), Uint256(MapsPrice.Map_1, 0))
    IERC20FrensCoin.mint(gold_erc20_addr, account, amount)

    initialized_.write(tokenId, 1)

    return ()
end


@external
func _reinitialize_resources_erc20{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256,
    account : felt
):
    let (m01_addr) = m01_address.read()
    let (caller) = get_caller_address()
    assert m01_addr = caller


    let (gold_erc20_addr) = gold_address_.read()

    # Mint some Gold (minus the price of the map)
    let (amount : Uint256) = uint256_sub(Uint256(GOLD_START, 0), Uint256(MapsPrice.Map_1, 0))
    IERC20FrensCoin.burn(gold_erc20_addr, account, amount)

    return ()
end

# IERC20FrensCoin.mint(gold_erc20_addr, caller, amount)

##################
# VIEW FUNCTIONS #
##################

@view
func get_block_start{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (block_number : felt):
    let (block_number) = start_block_.read(tokenId)
    return (block_number)
end

@view
func get_latest_block{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (block_number : felt):
    let (block_number) = block_number_.read(tokenId)
    return (block_number)
end

# @notice gets population allocated and available
# @dev returns array [pop_available, pop_allocated]
@view
func get_population{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (pop_len : felt, pop : felt*):
    alloc_locals
    let (local pop : felt*) = alloc()
    let (pop_available) = population_.read(tokenId, 0)
    let (pop_allocated) = population_.read(tokenId, 1)
    pop[0] = pop_available
    pop[1] = pop_allocated
    return (2, pop)
end

@view
func get_energy_level{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (energy : felt):
    let (energy) = energy_level.read(tokenId)
    return (energy)
end

@view
func fetch_daily_ressources_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256) -> (daily_ressources_len : felt, daily_ressources : felt*):
    alloc_locals

    let (daily_ressources : felt*) = alloc()
    fill_ressource_harvest_array(tokenId, 18, daily_ressources, 1)

    return (daily_ressources_len=18, daily_ressources=daily_ressources)
end

@view
func fetch_daily_ressources_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256) -> (daily_ressources_len : felt, daily_ressources : felt*):
    alloc_locals

    let (daily_ressources : felt*) = alloc()
    fill_ressource_cost_array(tokenId, 18, daily_ressources, 1)

    return (daily_ressources_len=18, daily_ressources=daily_ressources)
end

@view
func fill_ressource_harvest_array{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_ressources_len : felt, daily_ressources : felt*, id : felt):

    if id == 10:
        return ()
    end

    let (ressource) = daily_ressources_harvest_.read(tokenId, id)

    assert daily_ressources[0] = id
    assert daily_ressources[1] = ressource

    return fill_ressource_harvest_array(tokenId, daily_ressources_len, daily_ressources + 2, id + 1)
end

@view
func fill_ressource_cost_array{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256, daily_ressources_len : felt, daily_ressources : felt*, id : felt):

    if id == 10:
        return ()
    end

    let (ressource) = daily_ressources_cost_.read(tokenId, id)

    assert daily_ressources[0] = id
    assert daily_ressources[1] = ressource

    return fill_ressource_cost_array(tokenId, daily_ressources_len, daily_ressources + 2, id + 1)
end


@view
func daily_gold_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256) -> (gold : felt):
    let (gold) = daily_gold_harvest_.read(tokenId)
    return (gold)
end

@view
func daily_gold_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256) -> (gold : felt):
    let (gold) = daily_gold_cost_.read(tokenId)
    return (gold)
end

@view
func daily_energy_harvest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256) -> (energy : felt):
    let (energy) = daily_energy_harvest_.read(tokenId)
    return (energy)
end


@view
func daily_energy_cost{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(tokenId : Uint256) -> (energy : felt):
    let (energy) = daily_energy_cost_.read(tokenId)
    return (energy)
end

######################
# INTERNAL FUNCTIONS #
######################

# @notice Checks write-permission of the calling contract.
func _only_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    # Get the address of the module trying to write to this contract.
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    let (bool) = IModuleController.has_write_access(
        contract_address=controller, address_attempting_to_write=caller
    )
    assert_not_zero(bool)
    return ()
end

func _is_owner_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    caller : felt, tokenId : Uint256
) -> (success : felt):
    # let (controller) = Module.get_controller()
    # let (maps_erc721_addr) = IModuleController.get_external_contract_address(
    #     controller, ExternalContractsIds.Maps
    # )
    let (maps_erc721_addr) = maps_address_.read()
    # Check caller is owner of tokenId
    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    if owner == caller:
        return (1)
    end
    return (0)
end

func _get_resources{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, caller : felt, res_len : felt, res : felt*
):
    
    let (erc1155_addr) = erc1155_address_.read()

    if res_len == 0:
        return ()
    end

    # Mint Resources
    let amount_felt = res[1]
    let id_felt = res[0]
    let (amount) = felt_to_uint256(amount_felt)
    let (res_id) = felt_to_uint256(id_felt)
    IERC1155.mint(contract_address=erc1155_addr, to=caller, id=res_id, amount=amount)

    return _get_resources(tokenId, caller, res_len - 2, res + 2)
end

@external
func farm{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, 
    pos_start: felt
):
    alloc_locals

    let (caller) = get_caller_address()
    let (m01_addr) = m01_address.read()
    let (m03_addr) = m03_address.read()
    let (erc1155_addr) = erc1155_address_.read()
    let (erc20_addr) = gold_address_.read()

    let (local bool) = _is_owner_token(caller, tokenId)
    with_attr error_message("M02_Resources: caller is not owner of this tokenId"):
        assert bool = 1
    end

    # let (controller) = Module.get_controller()

    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, pos_start)
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)

    # Get current id et assert qu'elles sont identiques 
    let building_unique_id = decomp_array[7] * 100 + decomp_array[8] * 10 + decomp_array[9]
    assert_not_zero(building_unique_id)

    let res_type = decomp_array[5] * 10 + decomp_array[6]
    let level = decomp_array[14]

    # Check resource of type 2 or 3 or 20
    local check = 0
    if res_type == 20:
        local check = 1
        tempvar range_check_ptr = range_check_ptr
    else:
        let (local check) = is_in_range(res_type, 1, 4)
        tempvar range_check_ptr = range_check_ptr
        with_attr error_message("M02_Resources: it's not possible to harvest this resource."):
            assert check = 1
        end
        tempvar range_check_ptr = range_check_ptr
    end

    # Get resources data from M03
    # change level from 1 to level value (if Fixed data are all filled)
    # TODO change 1 with level
    let (building_data : BuildingFixedData) = IM03Buldings.view_fixed_data(m03_addr, res_type, 1)
    let (gains_len : felt, gains : felt*) = Data._get_costs_from_chain(
        building_data.daily_harvest.nb_resources, building_data.daily_harvest.resources_qty
    )
    # Increase energy
    # let (old_energy) = energy_level.read(tokenId)
    # energy_level.write(tokenId, old_energy + gains_energy)

    # Get resources from farming
    _get_resources(tokenId, caller, gains_len, gains)

    IM03Buldings._update_level(m03_addr, tokenId, building_unique_id, level)

    if level  == 3:
        let (local comp) = Data._compose_chain_destroyed(16, decomp_array)
        IM01Worlds.update_map_block(m01_addr, tokenId, pos_start, comp)
        tempvar pedersen_ptr = pedersen_ptr
        return ()
    else:
        let (local comp) = Data._compose_chain_harvest(16, decomp_array, level + 1)
        IM01Worlds.update_map_block(m01_addr, tokenId, pos_start, comp)
        tempvar pedersen_ptr = pedersen_ptr
        return()
    end
end

func _destroy_resources_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, index_len : felt, index: felt*, building_unique_id: felt
):
    alloc_locals

    let (m01_addr) = m01_address.read()
    # Get block info
    let (block) = IM01Worlds.get_map_block(m01_addr, tokenId, index[0])
    let (local decomp_array : felt*) = alloc()
    let (local bArr) = bArray(16)
    Data._decompose(bArr, 16, block, decomp_array, 0, 0, 0)

    let current = decomp_array[7] * 100 + decomp_array[8] * 100 + decomp_array[9]

    if current != building_unique_id :
        return ()
    end 
    
    # Recompose with resources destroyed
    let (comp) = Data._compose_chain_destroyed(16, decomp_array)

    # Update map Array
    IM01Worlds.update_map_block(m01_addr, tokenId, index[0], comp)

    return _destroy_resources_map(tokenId, index_len - 1, index + 1, building_unique_id)
end
