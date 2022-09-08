%lang starknet
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC1155_Receiver {
    func onERC1155Received(operator: felt, _from: felt, id: Uint256, value: Uint256) -> (
        selector: felt
    ) {
    }

    func onERC1155BatchReceived(
        operator: felt,
        _from: felt,
        ids_len: felt,
        ids: Uint256*,
        values_len: felt,
        values: Uint256*,
    ) -> (selector: felt) {
    }

    func supportsInterface(interfaceId: felt) -> (success: felt) {
    }
}
