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

from contracts.utils.game_structs import ModuleIds, ExternalContractsIds, Cost
from contracts.utils.game_constants import GOLD_START

from contracts.utils.tokens_interfaces import IERC721Maps, IERC20Gold
from contracts.utils.interfaces import IModuleController
from contracts.library.library_module import Module

###########
# STORAGE #
###########

###############
# CONSTRUCTOR #
###############

# Add initialize Controller Address
