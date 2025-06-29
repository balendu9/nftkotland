// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Compute.sol";
import "./UsersContract.sol";
interface IRegionNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract Tiles {
    address admin;
    IERC20 public token;
    IRegionNFT public regionNFT;
    Compute public computeContract;
    UsersContract public userContract;
    
    uint8  public constant GRID = 3;                      // 3×3
    uint256 public constant GRID_SIZE = 9;         // = 9
    
    constructor() { 

        admin = msg.sender;
    }
    
    function setContract(address _regionNFT, address compute, address _user, address _token) external {
        require(msg.sender == admin, "Not auth");
        regionNFT = IRegionNFT(_regionNFT); 
        computeContract = Compute(compute);
        userContract = UsersContract(_user);
        token = IERC20(_token);
    }

    struct RegionMeta {
        uint8 pollutionLevel;
        uint8 fertilityIndex;
        uint8 waterLevelIndex;
        uint8 ecoScore;
        uint256 lastUpdated;
    }

    mapping(uint256 => RegionMeta) public regionMeta;

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

    // regionId -> Tile[9]
    // mapping(uint256 => TileData[GRID_SIZE]) public regionTiles;
    mapping(uint256 => TileData[]) public regionTiles;
    mapping(uint256 => bool) public regionInitialzied;

    modifier onlyRegionOwner(uint256 regionId) {
        require(regionNFT.ownerOf(regionId) == msg.sender, "NOT_OWNER");
        _;
    }

    function initializeRegion(uint256 regionId, uint8 regionType) external {
        require(msg.sender == address(regionNFT), "ONLY_REGION_NFT");
        require(!regionInitialzied[regionId], "ALREADY_INITIALIZED");

        address owner = regionNFT.ownerOf(regionId);
        TileData[] storage tiles = regionTiles[regionId];

        for (uint8 i = 0; i < GRID_SIZE; i++) {
            tiles.push(); // this adds an empty TileData slot
        }
        (uint8 _fertility, uint8 _waterLevel) = computeContract.regiontilesprops(regionType);

        for (uint8 i =0; i < GRID_SIZE; i++) {
            TileData storage t = tiles[i];
            t.id = i;
            t.isBeingUsed = false;
            t.isCrop = false;
            t.cropTypeId = 0;
            t.factoryTypeId = 0;
            t.fertility = _fertility;
            t.waterLevel = _waterLevel;
            t.growthStage = 0;
        } 
        regionInitialzied[regionId] = true;
        calculateRegionMeta(regionId);
        userContract.setUserExists(owner);
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
            lastUpdated: block.timestamp
        });
    }

    uint256 public cropPrice = 50000 * 10 ** 18;
    function plantCrop(uint256 regionId, uint8 tileId, uint8 cropTypeId) 
    external onlyRegionOwner(regionId) {
        require(tileId < regionTiles[regionId].length, "BAD_INDEX");
        TileData storage tile = regionTiles[regionId][tileId];
        require(!tile.isBeingUsed, "TILE_OCCUPIED");
        require(
            token.transferFrom(msg.sender, admin, cropPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tile.isBeingUsed = true;
        tile.isCrop = true;
        tile.cropTypeId = cropTypeId;
        tile.factoryTypeId = 0;
        tile.growthStage = 0;

        calculateRegionMeta(regionId);
    }

    uint256 public factoryPrice = 500000 * 10 * 18;
    function buildFactory(uint256 regionId, uint8 index, uint8 factoryType) 
    external onlyRegionOwner(regionId){
        require(index < regionTiles[regionId].length, "BAD_INDEX" );
        TileData storage tile = regionTiles[regionId][index];
        require(!tile.isBeingUsed, "TILE_OCCUPIED");
        require(
            token.transferFrom(msg.sender, admin, factoryPrice),
            "TOKEN_TRANSFER_FAILED"
        );
        tile.isBeingUsed = true;
        tile.isCrop = false;
        tile.cropTypeId = 0;
        tile.factoryTypeId = factoryType;
        tile.growthStage = 0;

        calculateRegionMeta(regionId);

    }

    //regionid => tileid => last time when the user watered the plant
    mapping(uint256 => mapping(uint32 => uint256)) public lastWateredTime;
    function waterCrop(uint256 regionId, uint32 tileId) 
    external onlyRegionOwner(regionId) {
        require(tileId < regionTiles[regionId].length, "BAD_INDEX" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed && tile.isCrop, "NO_CROP_HERE");

        require(block.timestamp > lastWateredTime[regionId][tileId] + 1 days, "ONCE_IN_24_HOURS");

        lastWateredTime[regionId][tileId] = block.timestamp;
        uint8 growth = computeContract.plantGrowthCalculator(
            tile.cropTypeId, tile.fertility, tile.waterLevel, regionMeta[regionId].ecoScore, regionMeta[regionId].pollutionLevel, true
        );

        tile.waterLevel += 7;
        tile.growthStage += growth;
        calculateRegionMeta(regionId);
    }

    function fertilizeCrop(uint256 regionId, uint32 tileId) 
    external onlyRegionOwner(regionId) {
        require(tileId < regionTiles[regionId].length, "BAD_INDEX" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed && tile.isCrop, "NO_CROP_HERE");
        require(tile.fertility <= 100, "Already max fertility");
        uint256 fertilizer = userContract.getUserInventory(msg.sender, 8);
    
        require(fertilizer >= 100, "NOT_ENOUGH_FERTILIZER");
        userContract.updateInventory(msg.sender, 8, 100, false);

        uint8 growth = computeContract.plantGrowthCalculator(
            tile.cropTypeId, tile.fertility, tile.waterLevel, regionMeta[regionId].ecoScore, regionMeta[regionId].pollutionLevel, true
        );

        tile.fertility = 100;
        tile.growthStage += growth;
        calculateRegionMeta(regionId);
    }

    function harvestCrop(uint256 regionId, uint32 tileId) 
    external onlyRegionOwner(regionId) {
        require(tileId < regionTiles[regionId].length, "BAD_INDEX" );
        TileData storage tile = regionTiles[regionId][tileId];
        require(tile.isBeingUsed && tile.isCrop, "NO_CROP_HERE");
        require(tile.growthStage == 100, "NOT_YET_GROWN");

        (uint8 _harvestedResource, uint8 _amount) = 
        computeContract.getHarvestedResourceAndAmount(tile.cropTypeId, msg.sender);

        if (_harvestedResource != 0) {
            userContract.updateInventory(msg.sender, _harvestedResource, _amount, true);
            tile.isBeingUsed = false;
            tile.cropTypeId = 0;
            tile.fertility = regionMeta[regionId].fertilityIndex / 10;
            tile.waterLevel = regionMeta[regionId].fertilityIndex / 10;
        }
        calculateRegionMeta(regionId);
    }


    uint256 public tileExpansionPrice = 1000000 * 10 ** 18;
    function expandRegion(uint256 regionId) 
    external onlyRegionOwner(regionId) {
        require(regionInitialzied[regionId], "NOT_INITIALIZED");

        require(
            token.transferFrom(msg.sender, admin, tileExpansionPrice), 
            "TOKEN_TRANSFER_FAILED"
        );

        uint256 newTileId = regionTiles[regionId].length;

        regionTiles[regionId].push(TileData({
            id: uint32(newTileId),
            isBeingUsed: false,
            isCrop: false,
            cropTypeId: 0,
            factoryTypeId: 0,
            fertility: 0,
            waterLevel: 0,
            growthStage: 0
        }));

        calculateRegionMeta(regionId);
    }

}