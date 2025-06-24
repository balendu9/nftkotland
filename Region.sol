// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

interface ITiles {
    function initializeRegion(uint256 regionId) external;
}

contract RegionNFT is ERC721Enumerable {
    address admin;
    uint256 public nftmaxSupply = 1500;
    uint256 public maxImagetypes = 2;

    using Counters for Counters.Counter;
    Counters.Counter private _ids;

    IERC20  public immutable gameToken;     // GAME token used for payment
    address public immutable treasury;      // where payment goes
    ITiles public immutable tiles;    // contract for tile data

    uint256 public constant PRICE = 10 ether;

    string public baseImageURL;  // e.g. "https://yourusername.github.io/nft-images/"

    mapping(uint256 => uint8) public regionImageType;

    constructor(
        address _gameToken,
        address _treasury,
        address _gameCore,
        string memory _baseImageURL
    ) ERC721("WorldRegion", "REGION") {
        gameToken = IERC20(_gameToken);
        treasury  = _treasury;
        tiles  = ITiles(_gameCore);
        baseImageURL = _baseImageURL;
        admin = msg.sender;
    }

    


    function claimRegion(uint8 imageType) external returns (uint256 regionId) {
        require(imageType >= 1 && imageType <= maxImagetypes, "INVALID_IMAGE_TYPE");
        require(totalSupply() < nftmaxSupply, "MAX_SUPPLY_REACHED");
        // Transfer GAME token from user
        require(
            gameToken.transferFrom(msg.sender, treasury, PRICE),
            "PAYMENT_FAILED"
        );

        // Mint NFT
        _ids.increment();   
        regionId = _ids.current();
        _safeMint(msg.sender, regionId);

        // Save image type
        regionImageType[regionId] = imageType;

        // Initialize tiles
        tiles.initializeRegion(regionId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Use _ownerOf for OpenZeppelin v5+
        require(_ownerOf(tokenId) != address(0), "Nonexistent token");

        uint8 imageType = regionImageType[tokenId];

        // Construct image URL: baseImageURL + imageType + ".png"
        string memory imageURL = string.concat(baseImageURL, Strings.toString(imageType), ".png");

        // Build metadata JSON
        string memory json = string(
            abi.encodePacked(
                '{"name":"Region #', Strings.toString(tokenId),
                '", "description":"Your region in KOTLAND", ',
                '"image":"', imageURL, '"}'
            )
        );

        // Return base64-encoded data URI
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        );
    }

    function setMaxnftSupply(uint256 newmaxsupply, uint256 newmaxImagetypes) external {
        require(msg.sender == admin , "NOT_AUTHORIZED");
        nftmaxSupply = newmaxsupply;
        maxImagetypes = newmaxImagetypes;
    }
}