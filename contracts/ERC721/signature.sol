// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./ERC721.sol";

// ECDSA 函式庫
library ECDSA {
    /**
     * @dev 透過 ECDSA 驗證簽名地址是否正確，若正確則回傳 true
     * @param _msgHash 為訊息的雜湊值
     * @param _signature 為簽名資料
     * @param _signer 為簽名地址
     */
    function verify(bytes32 _msgHash, bytes memory _signature, address _signer) internal pure returns (bool) {
        return recoverSigner(_msgHash, _signature) == _signer;
    }

    /**
     * @dev 從 _msgHash 與簽名 _signature 中恢復出簽名者地址
     * 檢查簽名長度是否正確（標準 r, s, v 簽名長度為 65）
     */
    function recoverSigner(bytes32 _msgHash, bytes memory _signature) internal pure returns (address) {
        // 檢查簽名長度，65 為標準 r, s, v 簽名的長度
        require(_signature.length == 65, "invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        // 目前只能使用 assembly（內聯彙編）從簽名中取得 r, s, v 的值
        assembly {
            /*
            前 32 個位元組儲存簽名的長度（動態數組的儲存規則）
            add(_signature, 32) = _signature 的指標 + 32
            等同於略過 _signature 的前 32 個位元組
            mload(p) 從記憶體地址 p 開始載入接下來 32 個位元組的資料
            */
            // 讀取長度資料後的 32 個位元組，對應 r
            r := mload(add(_signature, 0x20))
            // 讀取接下來的 32 個位元組，對應 s
            s := mload(add(_signature, 0x40))
            // 讀取最後一個位元組，對應 v
            v := byte(0, mload(add(_signature, 0x60)))
        }
        // 使用 ecrecover（全域函數）：根據 _msgHash 與 r, s, v 恢復簽名者地址
        return ecrecover(_msgHash, v, r, s);
    }
    
    /**
     * @dev 回傳以太坊簽名訊息
     * @param hash 訊息雜湊值
     * 符合以太坊簽名標準：https://eth.wiki/json-rpc/API#eth_sign [`eth_sign`]
     * 以及 EIP191：https://eips.ethereum.org/EIPS/eip-191
     * 在訊息前添加 "\x19Ethereum Signed Message:\n32" 字段，防止簽名用於可執行交易。
     */
    function toEthSignedMessageHash(bytes32 hash) public pure returns (bytes32) {
        // 32 是 hash 的位元組長度，由上方的型別宣告所強制
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}

contract SignatureNFT is ERC721 {
    address immutable public signer; // 簽名地址
    mapping(address => bool) public mintedAddress;   // 記錄已鑄造過的地址

    // 建構子，初始化 NFT 系列的名稱、代號與簽名地址
    constructor(string memory _name, string memory _symbol, address _signer)
        ERC721(_name, _symbol)
    {
        signer = _signer;
    }

    // 利用 ECDSA 驗證簽名並鑄造 NFT
    function mint(address _account, uint256 _tokenId, bytes memory _signature)
        external
    {
        bytes32 _msgHash = getMessageHash(_account, _tokenId); // 將 _account 與 _tokenId 打包成訊息
        bytes32 _ethSignedMessageHash = ECDSA.toEthSignedMessageHash(_msgHash); // 計算以太坊簽名訊息
        require(verify(_ethSignedMessageHash, _signature), "Invalid signature"); // ECDSA 驗證通過
        require(!mintedAddress[_account], "Already minted!"); // 該地址尚未鑄造過
                
        mintedAddress[_account] = true; // 記錄該地址已鑄造過
        _mint(_account, _tokenId); // 鑄造 NFT
    }

    /*
     * 將鑄造地址（address 類型）與 tokenId（uint256 類型）拼接成訊息 msgHash
     * _account: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
     * _tokenId: 0
     * 對應的訊息 msgHash: 0x1bf2c0ce4546651a1a2feb457b39d891a6b83931cc2454434f39961345ac378c
     */
    function getMessageHash(address _account, uint256 _tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _tokenId));
    }

    // ECDSA 驗證，呼叫 ECDSA 庫的 verify() 函數
    function verify(bytes32 _msgHash, bytes memory _signature)
        public view returns (bool)
    {
        return ECDSA.verify(_msgHash, _signature, signer);
    }
}


/* 簽名驗證

如何簽名與驗證
# 簽名
1. 創建待簽名訊息
2. 對訊息進行雜湊
3. 對雜湊值進行簽名（離線進行，請保護您的私鑰）

# 驗證
1. 從原始訊息重新計算雜湊值
2. 從簽名與雜湊值中恢復簽名者地址
3. 將恢復出的簽名者地址與聲稱的簽名者進行比對
*/


contract VerifySignature {
    /* 1. 解鎖 MetaMask 帳戶
       ethereum.enable()
    */

    /* 2. 取得待簽名訊息的雜湊值
       getMessageHash(
           0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C,
           123,
           "coffee and donuts",
           1
       )

       雜湊值 = "0xcf36ac4f97dc10d91fc2cbb20d718e94a8cbfe0f82eaedc6a4aa38946fb797cd"
    */
    function getMessageHash(
        address _addr,
        uint256 _tokenId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_addr, _tokenId));
    }

    /* 3. 對訊息雜湊值進行簽名
       # 使用瀏覽器方式
       account = "在此複製並貼上簽名者的帳戶地址"
       ethereum.request({ method: "personal_sign", params: [account, hash]}).then(console.log)

       # 使用 web3
       web3.personal.sign(hash, web3.eth.defaultAccount, console.log)

       注意：不同帳戶的簽名結果會不同
       0x993dab3dd91f5c6dc28e17439be475478f5635c92a56e17e82349d3fb2f166196f466c0b4e0c146f285204f0dcb13e5ae67bc33f4b888ec32dfe0a063e8f3f781b
    */
    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        /*
        簽名是透過對以下格式的 keccak256 雜湊值進行簽名：
        "\x19Ethereum Signed Message:\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    /* 4. 驗證簽名
       signer = 0xB273216C05A8c0D4F0a4Dd0d7Bae1D2EfFE636dd
       to = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C
       amount = 123
       message = "coffee and donuts"
       nonce = 1
       signature =
           0x993dab3dd91f5c6dc28e17439be475478f5635c92a56e17e82349d3fb2f166196f466c0b4e0c146f285204f0dcb13e5ae67bc33f4b888ec32dfe0a063e8f3f781b
    */
    function verify(
        address _signer,
        address _addr,
        uint _tokenId,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_addr, _tokenId);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        public
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        // 檢查簽名長度，65 為標準 r, s, v 簽名的長度
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            前 32 個位元組儲存簽名的長度

            add(sig, 32) = sig 的指標 + 32
            實際上，略過簽名的前 32 個位元組

            mload(p) 從記憶體地址 p 開始載入接下來 32 個位元組的資料
            */
            // 第一個 32 個位元組（略過長度前綴）
            r := mload(add(sig, 0x20))
            // 第二個 32 個位元組
            s := mload(add(sig, 0x40))
            // 最後一個位元組（下一個 32 位元組的第一個位元組）
            v := byte(0, mload(add(sig, 0x60)))
        }
        // 隱式回傳 (r, s, v)
    }
}
