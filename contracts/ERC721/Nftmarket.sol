// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC721.sol";
import "./IERC721Receiver.sol";

contract NFTmarket is IERC721Receiver {
    event List(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );
    event Purchase(
        address indexed buyer,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );
    event Revoke(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId
    );
    event Update(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 newPrice
    );

    // 定義 Order 結構體
    struct Order {
        address owner;
        uint256 price;
    }
    // NFT 訂單映射: NFT 合約地址 => (tokenId => Order)
    mapping(address => mapping(uint256 => Order)) public nftList;

    fallback() external payable {}

    // 掛單：賣家上架 NFT，_nftAddr 為 NFT 合約地址，_tokenId 為 NFT 的 ID，_price 為價格（單位 wei）
    function list(address _nftAddr, uint256 _tokenId, uint256 _price) public {
        IERC721 _nft = IERC721(_nftAddr); // 宣告 IERC721 介面合約變數
        require(_nft.getApproved(_tokenId) == address(this), "Need Approval"); // 確認合約獲授權
        require(_price > 0, "Price must be > 0"); // 價格必須大於 0

        Order storage _order = nftList[_nftAddr][_tokenId]; // 取得或創建 Order
        _order.owner = msg.sender;
        _order.price = _price;
        // 將 NFT 轉帳到此合約
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);

        // 觸發 List 事件
        emit List(msg.sender, _nftAddr, _tokenId, _price);
    }

    // 購買：買家購買 NFT，呼叫時需附帶足夠的 ETH
    function purchase(address _nftAddr, uint256 _tokenId) public payable {
        Order storage _order = nftList[_nftAddr][_tokenId]; // 取得 Order
        require(_order.price > 0, "Invalid Price"); // NFT 價格必須大於 0
        require(msg.value >= _order.price, "Insufficient ETH sent"); // ETH 需大於等於標價
        IERC721 _nft = IERC721(_nftAddr); // 宣告 IERC721 介面合約變數
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT 必須在合約中

        // 將 NFT 轉給買家
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        // 將 ETH 轉給賣家
        payable(_order.owner).transfer(_order.price);
        // 多餘 ETH 退款給買家
        if (msg.value > _order.price) {
            payable(msg.sender).transfer(msg.value - _order.price);
        }

        // 觸發 Purchase 事件
        emit Purchase(msg.sender, _nftAddr, _tokenId, _order.price);

        // 刪除訂單
        delete nftList[_nftAddr][_tokenId];
    }

    // 撤單：賣家取消掛單，將 NFT 退回給賣家
    function revoke(address _nftAddr, uint256 _tokenId) public {
        Order storage _order = nftList[_nftAddr][_tokenId]; // 取得 Order
        require(_order.owner == msg.sender, "Not Owner"); // 只有持有者才能撤單
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT 必須在合約中

        // 將 NFT 轉回賣家
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        // 刪除訂單
        delete nftList[_nftAddr][_tokenId];

        // 觸發 Revoke 事件
        emit Revoke(msg.sender, _nftAddr, _tokenId);
    }

    // 調整價格：賣家調整掛單價格
    function update(address _nftAddr, uint256 _tokenId, uint256 _newPrice) public {
        require(_newPrice > 0, "Invalid Price"); // 價格必須大於 0
        Order storage _order = nftList[_nftAddr][_tokenId]; // 取得 Order
        require(_order.owner == msg.sender, "Not Owner"); // 只有持有者可調整價格
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT 必須在合約中

        _order.price = _newPrice; // 更新價格

        // 觸發 Update 事件
        emit Update(msg.sender, _nftAddr, _tokenId, _newPrice);
    }

    // 實作 IERC721Receiver 的 onERC721Received，使合約能接收 ERC721 代幣
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // receive 函數：用於接收純 ETH 轉帳，避免警告
    receive() external payable {}
}
