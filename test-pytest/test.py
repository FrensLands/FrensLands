import pytest
import os
import pytest_asyncio
from utils import (str_to_felt, felt_to_str, uint, TRUE, FALSE)

@pytest.mark.asyncio
async def test_register_to_game():
    name = "ipfs://faeljfalifhailhdiahdihfjebfjlabfljaflaflajflaj"
    symbol = "TT"

    new_name = str_to_felt(name)
    assert new_name == ("admin",)

    # new_symbol = str_to_felt(symbol)
    # assert new_symbol == ("admin",)

