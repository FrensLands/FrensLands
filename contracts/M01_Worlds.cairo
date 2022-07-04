%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_block_timestamp,
    get_contract_address,
    get_block_number,
)
from starkware.cairo.common.uint256 import Uint256

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds
from contracts.utils.tokens_interfaces import IERC721Maps
from contracts.utils.interfaces import IModuleController
from contracts.library.library_module import Module

###########
# STORAGE #
###########

# Time is calculated using blocks. Stores the first blocks the world was generated
@storage_var
func start_block(token_id : Uint256) -> (block : felt):
end

# Number of on-going games
@storage_var
func nb_games() -> (amount : felt):
end

# # Number of on-going games
# @storage_var
# func index_maps(map_type : felt) -> (index : felt):
# end

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

##################
# VIEW FUNCTIONS #
##################

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
) -> (success : felt):
    let (caller) = get_caller_address()
    let (controller) = Module.get_controller()
    let (m01_contract) = get_contract_address()

    # Fetch external contracts addresses
    let (maps_erc721_addr) = IModuleController.get_external_contract_address(
        controller, ExternalContractsIds.Maps
    )

    # Check caller is owner of tokenId
    let (owner : felt) = IERC721Maps.ownerOf(maps_erc721_addr, tokenId)
    with_attr error_message("M01_Worlds: caller is not owner of this tokenId"):
        assert owner = caller
    end

    # Stake Map_ERC721 in M01 contract
    IERC721Maps.transferFrom(maps_erc721_addr, caller, m01_contract, tokenId)

    # TODO : Mint S_Map_ERC721 and transfer to caller

    # Save block number of gameStart
    let (block_number) = get_block_number()
    start_block.write(tokenId, block_number)

    # Emit NewGame event
    NewGame.emit(caller, tokenId)

    # TODO : Initialize the values of the map to render the world

    return (1)
end

######################
# INTERNAL FUNCTIONS #
######################
