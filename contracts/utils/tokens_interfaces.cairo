%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC721Maps:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func tokenURI(tokenId : Uint256) -> (tokenURI : felt):
    end

    func balanceOf(owner : felt) -> (balance : Uint256):
    end

    func ownerOf(tokenId : Uint256) -> (owner : felt):
    end

    func safeTransferFrom(
        from_ : felt, to : felt, tokenId : Uint256, data_len : felt, data : felt*
    ):
    end

    func transferFrom(from_ : felt, to : felt, tokenId : Uint256):
    end

    func approve(approved : felt, tokenId : Uint256):
    end

    func setApprovalForAll(operator : felt, approved : felt):
    end

    func getApproved(tokenId : Uint256) -> (approved : felt):
    end

    func isApprovedForAll(owner : felt, operator : felt) -> (isApproved : felt):
    end

    func totalSupply() -> (totalSupply : Uint256):
    end

    func tokenByIndex(index : Uint256) -> (tokenId : Uint256):
    end

    func tokenOfOwnerByIndex(owner : felt, index : Uint256) -> (tokenId : Uint256):
    end

    func mint(to : felt, tokenId : Uint256):
    end

    func setTokenURI(tokenURI_len : felt, tokenURI : felt*):
    end
end
