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
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.math import assert_not_zero, assert_le, split_felt, assert_lt_felt

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds, MapsPrice
from contracts.utils.game_constants import GOLD_START, BLOCK_NUMBER, MAP_X_SIZE

from contracts.utils.tokens_interfaces import (
    IERC721Maps,
    IERC721S_Maps,
    IERC20FrensCoin,
    IERC1155Maps,
)
from contracts.utils.interfaces import IModuleController
from contracts.library.library_module import Module
from contracts.library.library_data import Data
from contracts.utils.bArray import bArray

###########
# STORAGE #
###########

# Time is calculated using blocks. Stores the first blocks the world was generated
@storage_var
func start_block(token_id : Uint256) -> (block : felt):
end

@storage_var
func last_block(token_id : Uint256) -> (block : felt):
end

# state = 0 = game paused, state = 1 = ongoing game
@storage_var
func game_state(token_id : Uint256) -> (state : felt):
end

# Number of on-going games
@storage_var
func nb_games() -> (amount : felt):
end

# Map information
@storage_var
func map_info(token_id : Uint256, index : felt) -> (data : felt):
end

##########
# EVENTS #
##########

@event
func NewGame(owner : felt, token_id : Uint256):
end

@event
func EndGame(owner : felt, token_id : Uint256):
end

###############
# CONSTRUCTOR #
###############

@constructor
func constructor{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId_len : felt, tokenId : felt*, data_len : felt, data : felt*
):
    _initialize_maps(tokenId_len, tokenId, data_len, data, 1)

    return ()
end

@external
func initializer{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    address_of_controller : felt
):
    Module.initialize_controller(address_of_controller)
    return ()
end

func _initialize_maps{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId_len : felt, tokenId : felt*, data_len : felt, data : felt*, index : felt
):
    alloc_locals
    if tokenId_len == 0:
        return ()
    end

    let (local token_id) = felt_to_uint256(tokenId[0])
    map_info.write(token_id, index, data[0])

    return _initialize_maps(tokenId_len - 1, tokenId + 1, data_len - 1, data + 1, index + 1)
end

######################
# EXTERNAL FUNCTIONS #
######################

# Transfer available map to player
@external
func get_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(tokenId : Uint256):
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()

    # Fetch external contracts addresses
    let (minter_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.MinterMaps
    )
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )

    # TODO : Check user does not already have a map
    let (balance : Uint256) = IERC721Maps.balanceOf(maps_erc721_addr, caller)
    with_attr error_message("M01_Worlds: caller has already minted a map."):
        assert balance = Uint256(0, 0)
    end

    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: this map is not available."):
        assert owner = minter_addr
    end

    IERC721Maps.transferFrom(maps_erc721_addr, minter_addr, caller, tokenId)

    return ()
end

@external
func start_game{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    let (m01_contract) = get_contract_address()

    # Fetch external contracts addresses
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )
    let (s_maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.S_Maps
    )
    let (gold_erc20_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Gold
    )

    # Check caller is owner of tokenId
    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert owner = caller
    end

    # Stake Map_ERC721 in M01 contract
    IERC721Maps.transferFrom(maps_erc721_addr, caller, m01_contract, tokenId)

    # TODO : Mint S_Map_ERC721 and transfer to caller
    IERC721S_Maps.mint(s_maps_erc721_addr, caller, tokenId)

    # Fill array of maps & resources

    # Save block number of gameStart
    let (block_number) = get_block_number()
    start_block.write(tokenId, block_number)
    last_block.write(tokenId, block_number)
    game_state.write(tokenId, 1)

    # Emit NewGame event
    NewGame.emit(caller, tokenId)

    # TODO : Initialize the values of the map to render the world

    # Mint some Gold (minus the price of the map)
    let (amount : Uint256) = uint256_sub(Uint256(GOLD_START, 0), Uint256(MapsPrice.Map_1, 0))
    # %{ print ('Gold amount to mint : ',  ids.amount) %}
    IERC20FrensCoin.mint(gold_erc20_addr, caller, amount)

    return ()
end

@external
func pause_game{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    # Checks ?
    _pause_game(tokenId)
    return ()
end

@external
func save_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    # Checks ?
    # Needs to setApproval before saving_map
    _pause_game(tokenId)
    # Fetch data needed for MapsERC721 new mint
    # Burn Maps
    # Mint Map with new updated_data
    # Burn S_map
    return ()
end

@external
func reinitialize_world{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    # Regen maps resources by blocks
    # Burn resources, and tokens left and restart from scratch
    # Need setApprovalForAll before
    return ()
end

##################
# VIEW FUNCTIONS #
##################

# @notice get game status
# Returns 0 if game paused, 1 if ongoing game
@view
func get_game_status{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (state : felt):
    let (state) = game_state.read(tokenId)
    return (state)
end

@view
func get_latest_block{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (block_number : felt):
    let (block_number) = last_block.read(tokenId)
    return (block_number)
end

# @notice get map array
@view
func get_map_array{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> (data_len : felt, data : felt*):
    alloc_locals
    let (local data : felt*) = alloc()

    _get_map_array_iter(tokenId, data, 0)

    return (BLOCK_NUMBER, data)
end

func _get_map_array_iter{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, data : felt*, index : felt
):
    alloc_locals
    if index == BLOCK_NUMBER:
        return ()
    end

    let (local value) = map_info.read(tokenId, index)
    data[0] = value

    return _get_map_array_iter(tokenId, data + 1, index + 1)
end

######################
# INTERNAL FUNCTIONS #
######################

# TODO : pass en Internal
# @notice checks if player can build a building
# @param building_size : 1, 2 or 4 blocks
# @param pos_start first block on the bottom left
# @param building_type_id
# @param building_unique_id
@view
func _check_can_build{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, building_size : felt, pos_start : felt
) -> (bool : felt):
    alloc_locals

    # Decompose first position
    let (local too_big_1) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_1 == 0:
        return (0)
    end
    let (local first_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info.read(tokenId, pos_start)
    Data._decompose(bArr, 16, comp, first_block, 0, 0, 0)

    local index_1 = (first_block[5] * 10) + first_block[6]

    let (local available) = is_not_zero(index_1)
    if available == 1:
        return (0)
    end

    if building_size == 1:
        return (1)
    end

    # Decompose 2nd position
    let (local too_big_2) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_2 == 0:
        return (0)
    end

    # Check que ce n'est pas hors map sur Axe X ?

    let (local second_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info.read(tokenId, pos_start + 1)
    Data._decompose(bArr, 16, comp, second_block, 0, 0, 0)

    local index_2 = (second_block[5] * 10) + second_block[6]

    let (local available) = is_not_zero(index_2)
    if available == 1:
        return (0)
    end

    if building_size == 2:
        # TODO : write sur le block
        # second_block
        return (1)
    end

    # Decompose 3nd and 4th position
    let (local too_big_3) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_3 == 0:
        return (0)
    end

    let (local too_big_4) = is_le(pos_start + MAP_X_SIZE, 640)
    if too_big_4 == 0:
        return (0)
    end

    let (local third_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info.read(tokenId, pos_start + MAP_X_SIZE)
    Data._decompose(bArr, 16, comp, third_block, 0, 0, 0)

    local index_3 = (third_block[5] * 10) + third_block[6]

    let (local available) = is_not_zero(index_3)
    if available == 1:
        return (0)
    end

    let (local fourth_block : felt*) = alloc()
    let (local bArr) = bArray(0)
    let (local comp) = map_info.read(tokenId, pos_start + MAP_X_SIZE + 1)
    Data._decompose(bArr, 16, comp, fourth_block, 0, 0, 0)

    local index_4 = (fourth_block[5] * 10) + fourth_block[6]

    let (local available) = is_not_zero(index_4)
    if available == 1:
        return (0)
    end

    return (1)
end

func _pause_game{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256
) -> ():
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()

    let (s_maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.S_Maps
    )
    # Check caller is owner of tokenId
    let (owner : felt) = IERC721S_Maps.ownerOf(s_maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert owner = caller
    end

    let (block_number) = get_block_number()
    last_block.write(tokenId, block_number)
    game_state.write(tokenId, 0)

    return ()
end

# @notice fill map array
# @param index need to start at index at 1
func _fill_map_array{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    tokenId : Uint256, data_len : felt, data : felt*, index : felt
) -> ():
    if data_len == 0:
        return ()
    end

    map_info.write(tokenId, index, data[0])

    _fill_map_array(tokenId, data_len - 1, data + 1, index + 1)

    return ()
end

func felt_to_uint256{range_check_ptr}(x) -> (uint_x : Uint256):
    let (high, low) = split_felt(x)
    return (Uint256(low=low, high=high))
end

func uint256_to_felt{range_check_ptr}(value : Uint256) -> (value : felt):
    assert_lt_felt(value.high, 2 ** 123)
    return (value.high * (2 ** 128) + value.low)
end

# @notice Checks write-permission of the calling contract.
func _only_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    # Get the address of the module trying to write to this contract.
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    IModuleController.has_write_access(
        contract_address=controller, address_attempting_to_write=caller
    )
    return ()
end

# Si map erc1155
# func mint_map{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
#     map_type : Uint256
# ):
#     alloc_locals
#     let (caller) = get_caller_address()
#     let (controller) = Module.get_controller()

# # Fetch external contracts addresses
#     let (erc1155_adr) = IModuleController.get_external_contract_address(
#         controller, ExternalContractsIds.ERC1155Maps
#     )

# with_attr error_message("M01_Worlds: maps doesn't exist."):
#         assert_not_zero(map_type.low)
#         assert_le(map_type.low, MapsPrice.count)
#     end

# IERC1155Maps.mint(erc1155_adr, caller, map_type, Uint256(1, 0))

# return ()
# end
