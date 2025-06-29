// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "./Compute.sol";
contract RegionNFT is ERC721Enumerable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    address public admin;
    uint256 public nftmaxSupply = 1500;

    IERC20 public immutable token;
    address public treasury;

    uint256 public constant PRICE = 100 ether;

    string public baseImageURL;

    Counters.Counter private _ids;
    
    struct RegionMeta {
        uint8 pollutionLevel;
        uint8 fertilityIndex;
        uint8 waterLevelIndex;
        uint8 ecoScore;
        uint256 lastUpdatedAt;
    }

    mapping ( uint256 => RegionMeta ) public regionMeta;

    Compute public computecontract;
    constructor ( 
        address _gametoken,
        address _treasury,
        string memory _baseImageURL,
        address _computecontract
      ) ERC721 ("Region", "KREGION") {
        token = IERC20(_gametoken);
        treasury = _treasury;
        baseImageURL = _baseImageURL;
        admin = msg.sender;
        computecontract = Compute(_computecontract);
    }

    function claimRegion() external returns (uint256 regionId) {
        require(totalSupply() < nftmaxSupply, "MAX_SUPPLY_REACHED");

        require(
            token.transferFrom(msg.sender, treasury, PRICE),
            "TOKEN_TRANSFER_FAILED"
        );

        _ids.increment();
        regionId = _ids.current();
        _safeMint(msg.sender, regionId);

        regionMeta[regionId] = RegionMeta({
            pollutionLevel: 0,
            fertilityIndex: 0,
            waterLevelIndex: 0,
            ecoScore: 0,
            lastUpdatedAt: block.timestamp
        });

        initializeRegion(regionId);
        computecontract._setUserExists(msg.sender);
    }


    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Nonexistent token");

        RegionMeta memory meta = regionMeta[tokenId];

        string memory attributes = string(
            abi.encodePacked(
                '[{"trait_type":"Pollution Level","value":', uint256(meta.pollutionLevel).toString(),
                '},{"trait_type":"Fertility Index","value":', uint256(meta.fertilityIndex).toString(),
                '},{"trait_type":"Water Level","value":', uint256(meta.waterLevelIndex).toString(),
                '},{"trait_type":"Eco Score","value":', uint256(meta.ecoScore).toString(),
                '}]'
            )
        );
        
        string memory json = string (
            abi.encodePacked(
                '{"name":"Region #', tokenId.toString(),
                '", "description":"Your region in KOTLAND", ',
                '"image":"', baseImageURL, '", ',
                '"attributes":', attributes, '}'
            )
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    // ===============================
    //    Tiles system
    // ===============================
   
    struct TileData {
        uint32 id;
        bool isBeingUsed;
        bool isCrop;
        uint8 cropTypeId;
        uint8 factoryTypeId;
        uint8 fertility;
        uint8 waterLevel;
        uint8 growthStage;
    }
   
    mapping ( uint256 => TileData[9] ) public regionTiles;
    mapping ( uint256 => bool ) public regionInitialized;

    modifier onlyRegionOwner( uint256 regionId ) {
        require(ownerOf(regionId) == msg.sender, "NOT_OWNER");
        _;
    }

    function initializeRegion ( uint256 regionId ) internal {
        require(!regionInitialized[regionId], "ALREADY_INITIALIZED");     

        for ( uint8 i = 0; i < 9; ) {
            TileData storage t = regionTiles[regionId][i];
            t.id = i;

            unchecked { i++; }
        }
        regionInitialized[regionId]= true;
    }

    function calculateRegionMeta(uint256 regionId) internal {
    TileData[9] memory tiles = regionTiles[regionId];
    uint256 len = tiles.length;
    uint256 p; uint256 f; uint256 w;

    for (uint256 i = 0; i < len; i++) {
        TileData memory t = tiles[i];
        if (t.factoryTypeId > 0) p += 10;
        f += t.fertility;
        w += t.waterLevel;
    }

    uint8 avgF = uint8(f / len);
    uint8 avgW = uint8(w / len);
    uint8 pol = uint8(p);
    uint8 eco = 100 - pol + avgF + avgW;

    regionMeta[regionId] = RegionMeta(pol, avgF, avgW, eco, block.timestamp);
}

    

    // ===============================
    //    Crop
    // ===============================
    
    uint256 public cropPrice = 50000 * 10 ** 18;
    function plantCrop(uint256 regionId, uint8 tileId, uint8 cropTypeId)
    external onlyRegionOwner (regionId) {
        require( tileId < 9, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require( !tile.isBeingUsed, "TILE_OCCUPIED" );
        require( cropTypeId >= 1 && cropTypeId <= 4, "INVALID_CROP" );
        require(
            token.transferFrom(msg.sender, admin, cropPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tile.isBeingUsed = true;
        tile.isCrop = true;
        tile.cropTypeId = cropTypeId;

        computecontract._giveReferralRewards(msg.sender, 1);
        calculateRegionMeta(regionId);
        computecontract.recordTxns(msg.sender, true, cropPrice, true, tileId);
    }

    mapping ( uint256 => mapping( uint32 => uint256 ) ) public lastWateredTime;
    function waterCrop ( uint256 regionId, uint32 tileId )
    external onlyRegionOwner ( regionId ) {
        require( tileId < 9, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed, "NO_CROP");
        require(block.timestamp > lastWateredTime[regionId][tileId] + 1 days, "ONCE_IN_24_HOURS" );
        
        lastWateredTime[regionId][tileId] = block.timestamp;

        uint8 growth = computecontract.plantGrowthCalculator(
            tile.cropTypeId, tile.fertility, tile.waterLevel, regionMeta[regionId].ecoScore, regionMeta[regionId].pollutionLevel, true
        );
        tile.waterLevel += 7;
        tile.growthStage += growth;
        calculateRegionMeta(regionId);
    }

    function fertilizeCrop ( uint256 regionId, uint32 tileId ) 
    external onlyRegionOwner ( regionId ) {
        require( tileId < 9, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed, "NO_CROP");
        require(tile.fertility <= 100, "ALREADY_MAX_FERTILITY");

        uint8 growth = computecontract.plantGrowthCalculator(
            tile.cropTypeId, tile.fertility, tile.waterLevel, regionMeta[regionId].ecoScore, regionMeta[regionId].pollutionLevel, true
        );

        tile.fertility = 100;
        tile.growthStage += growth;
        calculateRegionMeta(regionId);
    }

    function harvestCrop ( uint256 regionId, uint32 tileId ) 
    external onlyRegionOwner ( regionId ) {
        require( tileId < 9, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed && tile.growthStage == 100, "NO_CROP");
        
        computecontract.getHarvestedResourceAndAmount(tile.cropTypeId, msg.sender);

        tile.isBeingUsed = false;
        tile.cropTypeId = 0;
        tile.fertility = 0;
        tile.waterLevel = 0;
        
        calculateRegionMeta(regionId);

        computecontract.recordTxns(msg.sender, true, 0, false, tileId);
    }

    // ===============================
    //    Factory
    // ===============================
    
    uint256 public factoryPrice = 500000 * 10 * 18;
    function buildFactory ( uint256 regionId, uint8 tileId, uint8 _factoryTypeId )
    external onlyRegionOwner(regionId) {
        require( tileId < 9, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(!tile.isBeingUsed, "TILE_OCCUPIED");
        require( _factoryTypeId >= 1 && _factoryTypeId < 4, "INVALID_FACTORY" );
        
        require(
            token.transferFrom(msg.sender, admin, cropPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tile.isBeingUsed = true;
        tile.factoryTypeId = _factoryTypeId;
        computecontract._giveReferralRewards(msg.sender, 2);
        calculateRegionMeta(regionId);

        computecontract.recordTxns(msg.sender, false, 0, true, tileId);
    }

    function produceFromFactory(uint256 regionId, uint32 tileId, uint8 _factoryTypeId) 
    external onlyRegionOwner( regionId ) {
        require( tileId < 9, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed && !tile.isCrop, "TILE_UNOCCUPIED");
        computecontract._produceFromFactory(msg.sender, _factoryTypeId);
    } 

    function getRegionTiles(uint256 regionId) external view returns (TileData[9] memory) {
        return regionTiles[regionId];
    }
}