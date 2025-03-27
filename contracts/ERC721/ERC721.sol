// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IERC721.sol";
import "./IERC721Metadata.sol";
import "./IERC721Receiver.sol";
import "./Strings.sol"; // 請確保此檔案存在，或改用 OpenZeppelin 的實作

contract ERC721 is IERC721, IERC721Metadata {
    using Strings for uint256;

    string public override name;
    string public override symbol;
    
    // tokenId => owner 映射
    mapping (uint256 => address) private _owners;
    // owner => 持有數量映射
    mapping (address => uint256) private _balances;
    // tokenId => 授權地址映射
    mapping (uint256 => address) private _tokenApprovals;
    // owner => (operator => 批量授權) 映射
    mapping (address => mapping(address => bool)) private _operatorApprovals;

    error ERC721InvalidReceiver(address receiver);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }  

    /*實現IERC165接口supportsInterface*/
    function supportsInterface(bytes4 interfaceID) external pure override returns (bool) {
        return interfaceID == type(IERC721).interfaceId ||
               interfaceID == type(IERC165).interfaceId ||
               interfaceID == type(IERC721Metadata).interfaceId;
    }

    /*實現IERC721 balanceOf，利用_owners變量查詢tokenID的owner*/
    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "owner = zero address");
        return _balances[owner];
    }

    /*實現IERC721 ownerOf，利用_owners便量查詢tokenId的owner*/
    function ownerOf(uint tokenId) public view override returns (address owner) {
        owner = _owners[tokenId];
        require(owner != address(0), "token doesn't exist");
    }

    /*實現IERC721的isApprovedForAll，利用_operatorApprovals變量查詢owner地址是否將所有NFT批量授權給operator*/
    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /*實現IERC721的setApprovalForAll函數，將代幣授權給operator地址。調用_setApprovalForAll函數*/
    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC721 can't approve for yourself");
        _operatorApprovals[msg.sender][operator] = approved;  // 將msg.senders地址的批量授權設為approved     
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    /*實現IERC721的getApprovalForAll函數，授權to地址操作tokenId，同時釋放Approval事件*/
    function getApproved(uint tokenId) external view override returns (address) {
        require(_owners[tokenId] != address(0), "token doesn't exist");
        return _tokenApprovals[tokenId];
    }


    /*授權函數 通過調整_tokenApproval來授權to地址操作tokenId，同時釋放Approval事件*/
    function _approve(address owner, address to, uint tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }  

    /*實現IERC721的approve，將tokenId授權給to地址。 當to不是owner且msg.sender是owner或授權地址，調用approve函數*/
    function approve(address to, uint tokenId) external override {
        address owner = _owners[tokenId];
        require(
            msg.sender == owner || _operatorApprovals[owner][msg.sender], 
            "not owner nor approved for all"
        );
        _approve(owner, to, tokenId);
    }

    /*將tokenID設置為owner地址查詢spender地址是否可以使用tokenid，需要owner or被授權地址*/
    function _isApprovedOrOwner(address owner, address spender, uint tokenId) private view returns (bool) {
        return (spender == owner ||
            _tokenApprovals[tokenId] == spender ||
            _operatorApprovals[owner][spender]);
    }

    /*
    轉帳函數。通過調整_balances和_owner變量將tokenId從from轉帳給to，同時釋放transfer事件
    條件:
    1. tokenId被from持有
    2. to不是空地址
    */
    function _transfer(address owner, address from, address to, uint tokenId) private {
        require(from == owner, "not owner");
        require(to != address(0), "transfer to the zero address");

        _approve(owner, address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /* 實現IERC721的transferFrom，非安全轉帳，不建議使用 */
    function transferFrom(address from, address to, uint tokenId) external override {
        address owner = ownerOf(tokenId);
        require(
            _isApprovedOrOwner(owner, msg.sender, tokenId),
            "not owner nor approved"
        );
        _transfer(owner, from, to, tokenId);
    }

    /* 內部安全轉帳函數，呼叫 _transfer 並檢查接收合約 */
    function _safeTransfer(address owner, address from, address to, uint tokenId, bytes memory _data) private {
        _transfer(owner, from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, _data);
    }

    /*實現IERC721的safeTransferFrom，調用_safetransfer函數*/
    function safeTransferFrom(address from, address to, uint tokenId, bytes memory _data) public override {
        address owner = ownerOf(tokenId);
        require(_isApprovedOrOwner(owner, msg.sender, tokenId), "not owner nor approved");
        _safeTransfer(owner, from, to, tokenId, _data);
    }

    /*safeTransfrom重載函數*/
    function safeTransferFrom(address from, address to, uint tokenId) external override {
        safeTransferFrom(from, to, tokenId, "");
    }


    /*
    調整_balance和_owners變量來mint tokenId並轉帳給to，同時釋放Transfer事件，mint函數所有人都能使用
    條件:
    1. tokenId尚不存在
    2. to不是0地址
    */
    function _mint(address to, uint tokenId) internal virtual {
        require(to != address(0), "mint to zero address");
        require(_owners[tokenId] == address(0), "token already minted");

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /* 調整_balance和_owners來銷毀tokenId*/
    function _burn(uint tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "not owner of token");

        _approve(owner, address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /*用於在to合約時候調用IERC721Receiver-onERC721Received，以防tokenId不小心轉入黑洞*/
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /*查詢metadata*/
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_owners[tokenId] != address(0), "Token Not Exist");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /*計算tokenURI的BaseURI，tpkenURI就是把baseURI和tokenId並接再一起，需要開發重寫*/
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

}
