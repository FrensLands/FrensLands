import pytest
import os
import pytest_asyncio

from utils.utils import (str_to_felt, felt_to_str, uint, to_uint, from_uint, TRUE, FALSE)
from utils.Signer import Signer

from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract

ACCOUNT_FILE = os.path.join("openzeppelin", "account", "Account.cairo")
ARBITRER_FILE = os.path.join("contracts", "Arbitrer.cairo")
MODULE_CONTROLLER_FILE = os.path.join("contracts", "ModuleController.cairo")

# External contracts
MINTER_MAPS_ERC721_FILE = os.path.join("contracts", "tokens", "Minter_Maps_ERC721.cairo")
MAPS_ERC721_FILE = os.path.join("contracts", "tokens", "Maps_ERC721_enumerable_mintable_burnable.cairo")
GOLD_ERC20_FILE = os.path.join("contracts", "tokens", "Gold_ERC20_Mintable_Burnable.cairo")

# Modules
M01_MODULE =  os.path.join("contracts", "M01_Worlds.cairo")

owner = Signer(123456789987654321)
user1 = Signer(11111111111111111)
user2 = Signer(22222222222222222)

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
    return await starknet.deploy(
        source=MINTER_MAPS_ERC721_FILE,
        constructor_calldata=[admin.contract_address])

@pytest_asyncio.fixture
async def maps_erc721(starknet: StarknetContract, minter_maps_erc721: StarknetContract):
    return await starknet.deploy(
        source=MAPS_ERC721_FILE,
        constructor_calldata=[
            str_to_felt("test"), 
            str_to_felt("TT"), 
            minter_maps_erc721.contract_address, 
            2, 
            str_to_felt("ipfs://faeljfalifhail"),
            str_to_felt("hdiahdihfjebfjlabfljaflaflajf")
        ])

@pytest_asyncio.fixture
async def gold_erc20(starknet: StarknetContract, admin: StarknetContract, m01: StarknetContract):
    return await starknet.deploy(
        source=GOLD_ERC20_FILE,
        constructor_calldata=[
            str_to_felt("Gold"), 
            str_to_felt("GG"), 
            18,
            0,
            0,
            m01.contract_address,
            m01.contract_address
        ])

# Deploy moduels 
@pytest_asyncio.fixture
async def m01(starknet: StarknetContract, admin: StarknetContract):
    return await starknet.deploy(
        source=M01_MODULE)

@pytest_asyncio.fixture
async def arbitrer(starknet: StarknetContract, admin: StarknetContract):
    return await starknet.deploy(
        source=ARBITRER_FILE,
        constructor_calldata=[admin.contract_address])

@pytest_asyncio.fixture
async def module_controller(
    starknet: StarknetContract, 
    arbitrer: StarknetContract, 
    maps_erc721: StarknetContract, 
    minter_maps_erc721: StarknetContract, 
    gold_erc20: StarknetContract
    ):
    return await starknet.deploy(
        source=MODULE_CONTROLLER_FILE,
        constructor_calldata=[
            arbitrer.contract_address, 
            maps_erc721.contract_address, 
            minter_maps_erc721.contract_address, 
            gold_erc20.contract_address
        ])


@pytest.mark.asyncio
async def test_set_up_MC(admin, user_one, arbitrer, m01, module_controller, maps_erc721, minter_maps_erc721):
    # Set address of controller in Arbitrer contract
    await owner.send_transaction(admin, arbitrer.contract_address, 'set_address_of_controller', [module_controller.contract_address])

    # initialize M01 contract w/ controller addr
    await owner.send_transaction(admin, m01.contract_address, 'initializer', [module_controller.contract_address])
    
    # Check admin is arbitrer of MC contract
    assert (await module_controller.get_arbitrer().call()).result == (arbitrer.contract_address,)

    # Initialize Modules adresses through Arbitrer contract 
    await owner.send_transaction(admin, arbitrer.contract_address, 'batch_set_controller_addresses', [m01.contract_address])

    # Initialize minter Maps ERC721
    await owner.send_transaction(admin, minter_maps_erc721.contract_address, "set_maps_erc721_address", [maps_erc721.contract_address])
    assert (await minter_maps_erc721.get_maps_erc721_address().call()).result == (maps_erc721.contract_address,)

    # Set Approval for all in Maps ERC721
    await owner.send_transaction(admin, minter_maps_erc721.contract_address, "set_maps_erc721_approval", [m01.contract_address, 1])
    await owner.send_transaction(admin, minter_maps_erc721.contract_address, "mint_all", [10, 1, 0])
    assert(await maps_erc721.ownerOf(to_uint(1)).call()).result == (minter_maps_erc721.contract_address,)
    assert(await maps_erc721.totalSupply().call()).result == (to_uint(10),)

    # Test minting from M01_Worlds
    await user1.send_transaction(user_one, m01.contract_address, "get_map", [1, 0])
    assert(await maps_erc721.ownerOf(to_uint(1)).call()).result == (user_one.contract_address,)

    # Test start_game in M01_Worlds
    # Firs user1 needs to setApproval
    await user1.send_transaction(user_one, maps_erc721.contract_address, "setApprovalForAll", [m01.contract_address, 1])

    await user1.send_transaction(user_one, m01.contract_address, "start_game", [1, 0])
    assert(await maps_erc721.ownerOf(to_uint(1)).call()).result == (m01.contract_address,)


