// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*ERC721包含三個事件
Transfer事件: 轉帳時被釋放，紀錄代幣發出地址(from)、接收地址(to)、物品id(tokenId)
Approval事件: 授權時被釋放，紀錄代幣授權地址(owner)、被授權地址(approved)、物品id(tokenId)
ApprovalAll事件: 批量授權時釋放，記錄批量授權發出地址(owner)，被授權地址(operator)和授權與否的approved
*/


/*驗證其他合約是否實作某個特定街口*/
interface  IERC165 {  
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface IERC721 is IERC165{
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed  owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256);  //返回nft持有量
    function ownerOf(uint256 tokenId) external view returns (address);   //返回tokenID的主人owner


    /*兩版本差在是否需要傳遞額外資料，通常會自動跑第一個*/
    function safeTransferFrom( //安全轉帳（如果接收方為合約地址，則必須實作 ERC721Receiver 介面），參數為轉出地址（from）、接收地址（to）以及 tokenId。
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external; //授權另一個地址使用你的 NFT，參數為被授權地址（approve）和 tokenId。
    function setApprovalForAll(address operator, bool _approved) external; //將自己持有的該系列 NFT 批量授權給某個地址（operator）。
    function getApproved(uint256 tokenId) external view returns (address operator); //查詢某個 tokenId 被批准給哪個地址。
    function isApprovedForAll(address owner, address operator) external view returns (bool); //查詢某個地址的 NFT 是否已批量授權給另一個 operator 地址。
}


/*實現safetransferFrom()安全轉帳函數，目標合約必須實現IERC721Receiver接口才能接受ERC721代幣，否則會Revert，IERC721Receiver接口只包含一個onERC721Received()函數*/
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface IERC721Metadata is IERC721 {
    /*
        name():返回代幣名稱
        symbol():返回代幣代號
        tokenURI: 通過tokenID查詢metadata的連接url，ERC721特有函數
    */
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}