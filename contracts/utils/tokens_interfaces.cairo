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

@contract_interface
namespace IERC721S_Maps:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
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
end

@contract_interface
namespace IERC20FrensCoin:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func decimals() -> (decimals : felt):
    end

    func totalSupply() -> (totalSupply : Uint256):
    end

    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func allowance(owner : felt, spender : felt) -> (remaining : Uint256):
    end

    func transfer(recipient : felt, amount : Uint256) -> (success : felt):
    end

    func transferFrom(sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    end

    func approve(spender : felt, amount : Uint256) -> (success : felt):
    end

    func mint(to : felt, amount : Uint256):
    end

    func burn(account : felt, amount : Uint256):
    end
end

@contract_interface
namespace IERC1155:

    func balanceOf(owner : felt, token_id : Uint256) -> (balance : Uint256):
    end

    func isApprovedForAll(account : felt, operator : felt) -> (res : felt):
    end

    func setApprovalForAll(operator : felt, approved : felt):
    end

    func mint(to : felt, id : Uint256, amount : Uint256) -> ():
    end

    func mintBatch(
        to : felt, ids_len : felt, ids : Uint256*, amounts_len : felt, amounts : Uint256*
    ) -> ():
    end

    func burn(_from : felt, id : Uint256, amount : Uint256):
    end
end
