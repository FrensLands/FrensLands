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

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds, MapsPrice
from contracts.utils.game_constants import GOLD_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC721S_Maps, IERC20Gold
from contracts.utils.interfaces import IModuleController
from contracts.library.library_module import Module

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

# Ground type for map
@storage_var
func map_ground_type(token_id : Uint256, x : felt, y : felt) -> (type : felt):
end

# Map Resources
@storage_var
func map_resources(token_id : Uint256, x : felt, y : felt) -> (id : felt):
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
    %{ print ('Gold amount to mint : ',  ids.amount) %}
    IERC20Gold.mint(gold_erc20_addr, caller, amount)

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

######################
# INTERNAL FUNCTIONS #
######################

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
