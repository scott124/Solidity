// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract openeppelinERC721 is ERC721{
    uint256 public counter;

    constructor() ERC721("MYNFT", "SHIRO"){
        counter = 0;
    }
    
    function mint(address to) public {
        _safeMint(to, counter);
        counter++;  // 增加Counter，為下一次 mint 操作提供唯一的 tokenId
    }

    function _baseURI() internal view virtual  override returns (string memory) {
        return "https://api.com/metadata/";
    }

}