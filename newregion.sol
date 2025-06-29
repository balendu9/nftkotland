// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "./newcompute.sol";
contract RegionNFT1 is ERC721Enumerable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    address public admin;
    uint256 public nftmaxSupply = 1500;

    IERC20 public immutable token;
    address public treasury;
    address public computecontract;

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
        string memory _baseImageURL
      ) ERC721 ("Region", "KREGION") {
        token = IERC20(_gametoken);
        treasury = _treasury;
        baseImageURL = _baseImageURL;
        admin = msg.sender;
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

    
    mapping ( uint256 => TileData[] ) public regionTiles;
    mapping ( uint256 => bool ) public regionInitialized;

    modifier onlyRegionOwner( uint256 regionId ) {
        require(_exists(regionId), "REGION_DOES_NOT_EXIST");
        require(ownerOf(regionId) == msg.sender, "NOT_OWNER");
        _;
    }

    function initializeRegion ( uint256 regionId ) internal {
        require(!regionInitialized[regionId], "ALREADY_INITIALIZED");

        TileData [] storage tiles = regionTiles[regionId];
        for ( uint8 i = 0; i < 9; i++ ) {
            tiles.push();
        }

        for ( uint8 i = 0; i < 9; i++ ) {
            TileData storage t = tiles[i];
            t.id = i;
            t.isBeingUsed = false;
            t.isCrop = false;
            t.cropTypeId = 0;
            t.factoryTypeId = 0;
            t.fertility = 0;
            t.waterLevel = 0;
            t.growthStage = 0;
        }
        regionInitialized[regionId]= true;
    }

    function calculateRegionMeta(uint256 regionId) internal {
        TileData[] memory tiles = regionTiles[regionId];
        uint256 total = tiles.length;

        uint8 pollution;
        uint8 fertility;
        uint8 waterSum;



        for (uint8 i = 0; i < total; i++) {
            if (tiles[i].factoryTypeId > 0) {
                pollution += 10;
            }
            fertility += tiles[i].fertility;
            waterSum += tiles[i].waterLevel;
        }
        
        uint8 avgFertility = fertility/ uint8(total);
        uint8 avgWater = waterSum / uint8(total);

        uint8 ecoScore = 100 - pollution + avgFertility + avgWater;
        regionMeta[regionId] = RegionMeta({
            pollutionLevel: pollution,
            fertilityIndex: avgFertility,
            waterLevelIndex: avgWater,
            ecoScore: ecoScore,
            lastUpdatedAt: block.timestamp
        });

    }


    uint256 public tileExpansionPrice = 1000000 * 10 ** 18;
    function expandRegion ( uint256 regionId ) 
    external onlyRegionOwner ( regionId )  {
        require(regionInitialized[regionId], "NOT_YET_INITIALIZED");

        require(
            token.transferFrom(msg.sender, admin, tileExpansionPrice),
            "TOKEN_TRANSFER_FAILED"
        );

        uint256 newTileId = regionTiles[reginId].length;
        regionTiles[regionId].push( TileData ({
            id: uint32(newTileId),
            isBeingUsed: false,
            isCrop: false,
            cropTypeId: 0,
            factoryTypeId: 0,
            fertility: 0,
            waterLevel: 0,
            growthStage: 0
        }));
    }


    // ===============================
    //    Crop
    // ===============================
    
    uint256 public cropPrice = 50000 * 10 ** 18;
    function plantCrop(uint256 regionId, uint8 tileId, uint8 cropTypeId)
    external onlyRegionOwner (regionId) {
        require( tileId < regionTiles[regionId].length, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require( !tile.isBeingUsed, "TILE_OCCUPIED" );
        require( cropTypeId >= 1 && cropTypeId < 4, "INVALID_CROP" );
        require(
            token.transferFrom(msg.sender, admin, cropPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tile.isBeingUsed = true;
        tile.isCrop = true;
        tile.cropTypeId = cropTypeId;
        tile.factoryTypeId = 0;
        tile.growthStage = 0;


        computecontract._giveReferralRewards(msg.sender);
        calculateRegionMeta(regionId);
    }

    mapping ( uint256 => mapping( uint32 => uint256 ) ) public lastWateredTime;
    function waterCrop ( uint256 regionId, uint32 tileId )
    external onlyRegionOwner ( regionId ) {
        require( tileId < regionTile[regionId].length, "INVALID_TILE_ID" );
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
        require( tileId < regionTiles[regionId].length, "INVALID_TILE_ID" );
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
        require( tileId < regionTiles[regionId].length, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed, "NO_CROP");
        require(tile.growthStage == 100, "NOT_YET_GROWN");

        (uint8 _harvestedResource) = 
        computeContract.getHarvestedResourceAndAmount(tile.cropTypeId, msg.sender);

        if ( _harvestedResource != 0) {
            tile.isBeingUsed = false;
            tile.cropTypeId = 0;
            tile.fertility = regionMeta[regionId].fertilityIndex / 10;
            tile.waterLevel = regionMeta[regionId].fertilityIndex / 10;
        }
        calculateRegionMeta(regionId);
    }

    // ===============================
    //    Factory
    // ===============================
    
    uint256 public factoryPrice = 500000 * 10 * 18;
    function buildFactory ( uint256 regionId, uint8 tileId, uint8 _factoryTypeId )
    external onlyRegionOwner(regionId) {
        require( tileId < regionTiles[regionId].length, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(!tile.isBeingUsed, "TILE_OCCUPIED");
        require( _factoryTypeId >= 1 && _factoryTypeId < 4, "INVALID_FACTORY" );
        
        require(
            token.transferFrom(msg.sender, admin, cropPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tile.isBeingUsed = true;
        tile.isCrop = true;
        tile.cropTypeId = 0;
        tile.factoryTypeId = _factoryTypeId;
        tile.growthStage = 0;
        computecontract._giveReferralRewards(msg.sender);
        calculateRegionMeta(regionId);
    }

    function produceFromFactory(uint256 regionid, uint32 tileId, uint8 _factoryTypeId) 
    external onlyRegionOwner( regionId ) {
        require( tileId < regionTiles[regionId].length, "INVALID_TILE_ID" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(!tile.isBeingUsed, "TILE_OCCUPIED");
        require( _factoryTypeId >= 1 && _factoryTypeId < 4, "INVALID_FACTORY" );

        if (_factoryTypeId == 1) {
            computecontract.produceFood(msg.sender);
        } else if (factoryTypeId == 2) {
            computeContract.produceEnergy(msg.sender);
        } else if (factoryTypeId == 3) {
            computeContract.produceBakery(msg.sender);
        } else if (factoryTypeId == 4) {
            computeContract.produceJuice(msg.sender);
        } else if (factoryTypeId == 5) {
            computeContract.produceBioFuel(msg.sender);
        } else {
            revert("Invalid Factory Type");
        }
                
    } 
    
    




}
