// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/ERC721A.sol";

contract HolySkully is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;

    string public baseURI; // i.e. ipfs://__CID__/
    string public uriSuffix = ".json";
    string public hiddenMetadataUri; // i.e. ipfs://__CID__/hidden.json

    uint256 public publicSaleCost = 0.05 ether;
    uint256 public preSaleCost = 0.03 ether;
    uint256 public maxMintAmountPerTx = 5;
    uint256 public maxWhiteListMint = 5;
    uint256 public constant maxSupply = 5; 

    uint32 public revealedTime;
    uint32 public preSaleStartTime;

    bool public publicSaleStart = false;
    bool public paused = true;

    bytes32 private merkleRoot = "";

    // config name and symbol
    constructor() ERC721A("Holy Skully", "HSY") {}

    modifier mintCompliance(uint256 _mintAmount) {
        require(!paused, "The contract is paused!");
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
            "Invalid mint amount!"
        );
        require(
            totalSupply() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        _;
    }

    function initialize(
        string memory _hiddenMetadataUri,
        uint32 _revealedTime,
        uint32 _preSaleStartTime
    ) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
        revealedTime = _revealedTime;
        preSaleStartTime = _preSaleStartTime;
    }

    function mint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
    {
        require(publicSaleStart, "Public sale not start!");
        require(
            msg.value >= publicSaleCost * _mintAmount,
            "Insufficient funds!"
        );

        _safeMint(msg.sender, _mintAmount);
    }

    function mintForAddress(uint256 _mintAmount, address _receiver)
        public
        mintCompliance(_mintAmount)
        onlyOwner
    {
        _safeMint(_receiver, _mintAmount);
    }

    function whiteListMint(uint256 _mintAmount, bytes32[] calldata _merkleProof)
        public
        payable
        mintCompliance(_mintAmount)
    {
        require(block.timestamp >= preSaleStartTime, "Presale not start!");
        require(msg.value >= preSaleCost * _mintAmount, "Insufficient funds!");
        require(
            _numberMinted(msg.sender) + _mintAmount <= maxWhiteListMint,
            "Max whitelist mint reached!"
        );

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Not in whitelist."
        );

        _safeMint(msg.sender, _mintAmount);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 0;
        uint256 ownedTokenIndex = 0;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= totalSupply()
        ) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;

                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (block.timestamp < revealedTime) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setPreSaleTime(uint32 _preSaleStartTime) public onlyOwner {
        preSaleStartTime = _preSaleStartTime;
    }

    function setPublicSaleTime(bool _publicSaleStart) public onlyOwner {
        publicSaleStart = _publicSaleStart;
    }

    function setRevealTime(uint32 _revealedTime) public onlyOwner {
        revealedTime = _revealedTime;
    }

    function setPreSaleCost(uint256 _preSaleCost) public onlyOwner {
        preSaleCost = _preSaleCost;
    }

    function setPublicSaleCost(uint256 _publicSaleCost) public onlyOwner {
        publicSaleCost = _publicSaleCost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }    
    
    function setMaxWhiteListMint(uint256 _maxWhiteListMint)
        public
        onlyOwner
    {
        maxWhiteListMint = _maxWhiteListMint;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        if (_state == false) {
            require(revealedTime > 0, "Not initialized yet!");
            require(preSaleStartTime > 0, "Not initialized yet!");
            require(publicSaleCost > 0, "Not initialized yet!");
            require(preSaleCost > 0, "Not initialized yet!");
        }

        paused = _state;
    }

    function withdraw() public onlyOwner nonReentrant {
        // This will transfer the remaining contract balance to the owner.
        // Do not remove this otherwise you will not be able to withdraw the funds.
        // =============================================================================
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        require(success, "Withdraw Fails.");
        // =============================================================================
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}
