import pytest
import os
import pytest_asyncio

from utils.utils import (str_to_felt, felt_to_str, uint, to_uint, from_uint, TRUE, FALSE)
from utils.Signer import Signer
from utils.helpers import (
    assert_equals,
    update_starknet_block,
    reset_starknet_block,
    get_block_timestamp,
    TIME_ELAPS_SIX_HOURS,
    TIME_ELAPS_ONE_HOUR,
    BLOCK_NUMBER,
    BLOCK_NUMBER_ELAPSE_5
)

from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.compiler.compile import compile_starknet_files, compile_starknet_codes
from starkware.starknet.business_logic.state.state import BlockInfo

ACCOUNT_FILE = os.path.join("openzeppelin", "account", "Account.cairo")
# ARBITRER_FILE = os.path.join("contracts", "Arbitrer.cairo")
# MODULE_CONTROLLER_FILE = os.path.join("contracts", "ModuleController.cairo")

# External contracts
MINTER_MAPS_ERC721_FILE = os.path.join("contracts", "tokens", "Minter_Maps_ERC721.cairo")
MAPS_ERC721_FILE = os.path.join("contracts", "tokens", "Maps_ERC721_enumerable_mintable_burnable.cairo")
GOLD_ERC20_FILE = os.path.join("contracts", "tokens", "Gold_ERC20_Mintable_Burnable.cairo")
ERC1155_FILE = os.path.join("contracts", "tokens", "ERC1155_Mintable_Burnable.cairo")

# Modules
M01_MODULE =  os.path.join("contracts", "M01_Worlds.cairo")
M02_MODULE =  os.path.join("contracts", "M02_Resources.cairo")
M03_MODULE =  os.path.join("contracts", "M03_Buildings.cairo")

ARBITER_FILE = os.path.join("contracts", "Arbiter.cairo")
MODULE_CONTROLLER = os.path.join("contracts", "ModuleController.cairo")

CONTRACT_SRC = os.path.join(os.path.dirname(__file__), "..", "contracts")

owner = Signer(123456789987654321)
user1 = Signer(11111111111111111)
user2 = Signer(22222222222222222)

def compile(path):
    return compile_starknet_files(
        files=[os.path.join(CONTRACT_SRC, path)],
        debug_info=True,
        disable_hint_validation=True
    )


@pytest_asyncio.fixture
async def starknet() -> Starknet:
    return await Starknet.empty()

@pytest_asyncio.fixture
async def admin(starknet: Starknet) -> StarknetContract:
    return await starknet.deploy(
        source=ACCOUNT_FILE,
        constructor_calldata=[owner.public_key])

@pytest_asyncio.fixture
async def user_one(starknet: StarknetContract) -> StarknetContract:
    return await starknet.deploy(
        source=ACCOUNT_FILE,
        constructor_calldata=[user1.public_key])

# Deploy external contracts 
@pytest_asyncio.fixture
async def minter_maps_erc721(starknet: StarknetContract, admin: StarknetContract):
    minter = compile("tokens/Minter_Maps_ERC721.cairo")
    await starknet.declare(contract_class=minter)
    minter_maps_erc721 = await starknet.deploy(contract_class=minter, constructor_calldata=[admin.contract_address])
    return minter_maps_erc721 

@pytest_asyncio.fixture
async def maps_erc721(starknet: StarknetContract, minter_maps_erc721: StarknetContract):
    maps = compile("tokens/Maps_ERC721_enumerable_mintable_burnable.cairo")
    await starknet.declare(contract_class=maps)
    maps_erc721 = await starknet.deploy(contract_class=maps, constructor_calldata=[
            str_to_felt("test"), 
            str_to_felt("TT"), 
            minter_maps_erc721.contract_address, 
            2, 
            str_to_felt("ipfs://QmSxbQNFpqRF9q1FC6cAF4bM"),
            str_to_felt("ikEXnGMzNuwzpHxkgvTTrX")
        ])
    return maps_erc721 

# Deploy modules 
@pytest_asyncio.fixture
async def m01(starknet: StarknetContract, admin: StarknetContract):
    module01 = compile("M01_Worlds.cairo")
    await starknet.declare(contract_class=module01)
    m01 = await starknet.deploy(contract_class=module01, constructor_calldata=[])
    return m01

@pytest_asyncio.fixture
async def m02(starknet: StarknetContract, admin: StarknetContract):
    module02 = compile("M02_Resources.cairo")
    await starknet.declare(contract_class=module02)
    m02 = await starknet.deploy(contract_class=module02, constructor_calldata=[])
    return m02

@pytest_asyncio.fixture
async def m03(starknet: StarknetContract, admin: StarknetContract):
    module03 = compile("M03_Buildings.cairo")
    await starknet.declare(contract_class=module03)
    m03 = await starknet.deploy(
        contract_class=module03, 
        constructor_calldata=[
            23, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24,
            1,
            92, # update costs
            0,0,0,0,
            0,0,0,0,
            0,0,0,0,
            4, 105208303503, 3, 0, #house
            4, 112218305508, 8, 0, # appartment
            5, 112218309508605, 11, 0, # hotel
            4, 103214302503, 7, 0, # boulangerie
            5, 109216307507611, 15, 10, #grocery shop
            5, 111221306509610, 12, 9, #restaurant
            5, 115228335540642, 32, 17, #mall
            5, 123209307510604, 7, 6, # Bar 
            5, 127213312512608, 15, 8, # Library 
            5, 103224308510612, 18, 7, # SwimmingPool 
            5, 107226328530621, 22, 14, # Cinema 
            5, 143226332552612, 27, 0, # Market 
            4, 112204303503, 2, 0, # CerealFarm 
            3, 112205528, 5, 0, # CowFarm 
            5, 115205314522603, 8, 5, # TreeFarm 
            0,0,0,0,  # Mine 
            4, 235315530615, 14, 0, # CoalPlant 
            5, 115222321523614, 21, 5, # PoliceStation 
            5, 109243336542633, 32, 19, # Hospital 
            4, 230342536656, 54, 25, # Lab  
            92, #daily costs
            0,0,0,0,
            1, 301, 0, 0,
            1, 301, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            2, 310510, 0, 3, #hotel
            2, 303503, 1, 0, #boulangerie
            2, 310510, 3, 2, #grocery
            2, 315515, 2, 1, #restaurant
            2, 325525, 7, 5, #mall
            2, 308508, 1, 1, # Bar 
            2, 306506, 2, 3, # Library 
            2, 304504, 3, 3, # SwimmingPool 
            2, 305505, 5, 5, # Cinema 
            2, 306506, 3, 3, # Market 
            2, 303503, 1, 0, # CerealFarm 
            1, 515, 1, 0, # CowFarm 
            2, 305505, 1, 1, # TreeFarm 
            1, 301, 0, 0,  # Mine 
            2, 304504, 3, 0, # CoalPlant 
            2, 305505, 2, 1, # PoliceStation 
            1, 313513, 4, 2, # Hospital 
            1, 308508, 2, 1, # Lab 
            92, # daily harvests
            0,0,0,0,
            1,202,0,0,
            1,102,0,0, 
            0,0,0,0,
            0,0,0,0,
            0, 0, 12, 0,
            0, 0, 5, 0,
            0, 0, 18, 0,
            0, 0, 15, 0,
            0, 0, 55, 0,
            0, 0, 9, 0, # Bar 
            0, 0, 10, 0, # Library 
            0, 0, 18, 0, # SwimmingPool 
            0, 0, 25, 0, # Cinema 
            0, 0, 10, 0, # Market 
            1, 520, 0, 0, # CerealFarm 
            # 2, 202802, 1, 1, # VegetableFarm 
            1, 320, 1, 1, # CowFarm 
            2, 202802, 1, 1, # TreeFarm 
            3,212614825,0,0,  # Mine 
            0, 0, 0, 20, # CoalPlant 
            0, 0, 0, 0, # PoliceStation 
            0, 0, 25, 0, # Hospital 
            0, 0, 14, 0, # Lab 
            46,
            0, 1,
            1, 0,
            1, 0,
            0, 5,
            0, 20,
            0, 28, # hotel
            2, 0, #boulangerie
            5, 0,
            6, 0,
            16, 0,
            4, 0, # Bar 
            5, 0, # Library 
            3, 0, # SwimmingPool 
            4, 0, # Cinema 
            12, 0, # Market 
            5, 0, # CerealFarm 
            5, 0, # CowFarm 
            9, 0, # TreeFarm 
            10, 0, # Mine 
            12, 0, # CoalPlant 
            7, 0, # PoliceStation 
            20, 0, # Hospital 
            10, 3, # Lab 
            admin.contract_address
        ])
    return m03

@pytest_asyncio.fixture
async def erc1155(starknet: StarknetContract, admin: StarknetContract, m02: StarknetContract):
    erc1155_c = compile("tokens/ERC1155_Mintable_Burnable.cairo")
    await starknet.declare(contract_class=erc1155_c)
    erc1155 = await starknet.deploy(
        contract_class=erc1155_c, 
        constructor_calldata=[
            str_to_felt("Resources_uri"), 
            m02.contract_address
        ])
    return erc1155

@pytest_asyncio.fixture
async def erc20(starknet: StarknetContract, m02: StarknetContract):
    return await starknet.deploy(
        source=GOLD_ERC20_FILE, 
        constructor_calldata=[
            str_to_felt("Test coin"), 
            str_to_felt("TC"), 
            18,
            0, 
            0,
            m02.contract_address,
            m02.contract_address
        ])

@pytest_asyncio.fixture
async def arbiter(starknet: StarknetContract, admin: StarknetContract):
    return await starknet.deploy(
        source=ARBITER_FILE,
        constructor_calldata=[admin.contract_address])

# @pytest_asyncio.fixture
# async def module_controller(
#     starknet: StarknetContract, 
#     maps_erc721: StarknetContract, 
#     minter_maps_erc721: StarknetContract, 
#     erc20: StarknetContract,
#     erc1155: StarknetContract,
#     arbiter: StarknetContract
#     ):
#     return await starknet.deploy(
#         source=MODULE_CONTROLLER,
#         constructor_calldata=[
#             arbiter.contract_address, 
#             maps_erc721.contract_address, 
#             minter_maps_erc721.contract_address, 
#             erc20.contract_address,
#             erc1155.contract_address
#         ])

@pytest_asyncio.fixture
async def module_controller(starknet: StarknetContract, 
    maps_erc721: StarknetContract, 
    minter_maps_erc721: StarknetContract, 
    erc20: StarknetContract,
    erc1155: StarknetContract,
    arbiter: StarknetContract):
    moduleController = compile("ModuleController.cairo")
    await starknet.declare(contract_class=moduleController)
    module_controller = await starknet.deploy(contract_class=moduleController, constructor_calldata=[
        arbiter.contract_address, 
        maps_erc721.contract_address, 
        minter_maps_erc721.contract_address, 
        erc20.contract_address,
        erc1155.contract_address
    ])
    return module_controller

@pytest.mark.asyncio
async def test_set_up(starknet, admin, user_one, m01, m02, m03, erc1155, erc20, minter_maps_erc721, maps_erc721, arbiter, module_controller):
    await owner.send_transaction(admin, arbiter.contract_address, 'set_address_of_controller', [
        module_controller.contract_address
    ])
    # Initialize module controller addresses in modules
    await owner.send_transaction(admin, arbiter.contract_address, 'batch_set_controller_addresses', [
        m01.contract_address,
        m02.contract_address,
        m03.contract_address
    ])
    
    # Initialize modules 
    await owner.send_transaction(admin, m01.contract_address, 'initializer', [
        # m03.contract_address,
        # m02.contract_address,
        # erc1155.contract_address,
        # erc20.contract_address,
        # minter_maps_erc721.contract_address,
        # maps_erc721.contract_address
        module_controller.contract_address
    ])

    await owner.send_transaction(admin, m02.contract_address, 'initializer', [
        # m03.contract_address,
        # m01.contract_address,
        # erc1155.contract_address,
        # erc20.contract_address,
        # maps_erc721.contract_address,
        module_controller.contract_address
    ])
    
    await owner.send_transaction(admin, m03.contract_address, 'initializer', [
        # m01.contract_address,
        # m02.contract_address,
        # erc1155.contract_address,
        # maps_erc721.contract_address,
        # erc20.contract_address,
        module_controller.contract_address
    ])

    # Initialize minter
    await owner.send_transaction(admin, minter_maps_erc721.contract_address, 'set_maps_erc721_address', [
        maps_erc721.contract_address
    ])
    await owner.send_transaction(admin, minter_maps_erc721.contract_address, 'set_maps_erc721_approval', [
        m01.contract_address,
        1
    ])
    await owner.send_transaction(admin, minter_maps_erc721.contract_address, 'mint_all', [
        50,
        1, 0
    ])
    assert (await maps_erc721.totalSupply().call()).result == (to_uint(50),)
    assert (await maps_erc721.balanceOf(minter_maps_erc721.contract_address).call()).result == (to_uint(50),)

    # Add building data for level 2 and 3
    await owner.send_transaction(admin, m03.contract_address, 'initialize_global_data', [
        4,
        1, 2, 3, 20,
        2,
        16,
        1,105,0,0,
        0,0,0,0,
        0,0,0,0,
        0,0,0,0, 
        16,
        0,0,0,0,
        1, 301, 0, 0,
        1, 301, 0, 0,
        1, 301, 0, 0,
        16,
        0,0,0,0,
        1,202,0,0,
        1,102,0,0,
        3,212614825,0,0, 
        8,
        0, 2,
        1, 0,
        1, 0,
        10, 0,
    ])
    await owner.send_transaction(admin, m03.contract_address, 'initialize_global_data', [
        4,
        1, 2, 3, 20,
        3,
        16,
        1,105,0,0,
        0,0,0,0,
        0,0,0,0,
        0,0,0,0, 
        16,
        0,0,0,0,
        1, 301, 0, 0,
        1, 301, 0, 0,
        1, 301, 0, 0,
        16,
        0,0,0,0,
        1,202,0,0,
        1,102,0,0,
        3,212614825,0,0, 
        8,
        0, 2,
        1, 0,
        1, 0,
        10, 0,
    ])

    # Mint a map
    await user1.send_transaction(user_one, m01.contract_address, 'get_map', [])

    # Set approval
    await user1.send_transaction(user_one, erc1155.contract_address, 'setApprovalForAll', [m02.contract_address, 1])

    # Start game
    await user1.send_transaction(user_one, m01.contract_address, "start_game", [1, 0])
    assert(await erc1155.balanceOf(user_one.contract_address, to_uint(3)).call()).result == (to_uint(20),)
    assert(await m01.get_game_status(to_uint(1)).call()).result == (1,)

    # Harvest trees 3 times and check if tree has been deleted 
    await user1.send_transaction(user_one, m02.contract_address, "harvest", [1, 0, 48])
    await user1.send_transaction(user_one, m02.contract_address, "harvest", [1, 0, 48])
    await user1.send_transaction(user_one, m02.contract_address, "harvest", [1, 0, 48])
    assert(await erc1155.balanceOf(user_one.contract_address, to_uint(1)).call()).result == (to_uint(6),)
    assert(await erc1155.balanceOf(user_one.contract_address, to_uint(3)).call()).result == (to_uint(17),)
    assert(await m01.get_map_block(to_uint(1), 48).call()).result == (802100000880011,)

    # Reinitialize game
    await user1.send_transaction(user_one, m01.contract_address, "reinitialize_game", [1])
    assert(await erc20.balanceOf(user_one.contract_address).call()).result == (to_uint(0),)
    assert(await erc1155.balanceOf(user_one.contract_address, to_uint(1)).call()).result == (to_uint(0),)
    assert(await erc1155.balanceOf(user_one.contract_address, to_uint(3)).call()).result == (to_uint(20),)
    assert(await m01.get_game_status(to_uint(1)).call()).result == (1,)
