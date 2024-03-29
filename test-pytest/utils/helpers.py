import pytest
from starkware.starknet.business_logic.state.state import BlockInfo
# from conftest import starknet

TIME_ELAPS_ONE_HOUR = 3600
TIME_ELAPS_SIX_HOURS = 21600
UINT_DECIMALS = 10**18
BLOCK_NUMBER = 1
BLOCK_NUMBER_ELAPSE_5 = 6


def assert_equals(a, b):
    assert a == b


def update_starknet_block(
    starknet, block_number=BLOCK_NUMBER, block_timestamp=TIME_ELAPS_ONE_HOUR
):
    starknet.state.state.block_info = BlockInfo(
        block_number=block_number,
        block_timestamp=block_timestamp,
        gas_price=0,
        sequencer_address=0,
    )


def reset_starknet_block(starknet):
    update_starknet_block(starknet=starknet)


def get_block_timestamp(starknet):
    return starknet.state.block_info.block_timestamp