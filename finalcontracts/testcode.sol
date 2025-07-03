// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./MarketPlace.sol";
import "./TileContract.sol";
import "./UsersContract.sol";
import "./Compute.sol";
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
contract Actions {
    address admin;
    constructor() {
        admin = msg.sender;
    }
    uint256 public totalseedvolume = 0;
    uint256 public totaltxn = 0;

    IERC20 public token;
    UsersContract public userContract;
    TilesContract public tileDataContract;
    MarketplaceContract public marketplaceContract;
    Compute public computeContract;


    function setContracts(address _token, address _tileDataContract, address _computeContract, address _userContract, address _marketplaceConract) external {
        require(msg.sender == admin, "Not owner");
        token = IERC20(_token);
        userContract = UsersContract(_userContract);
        tileDataContract = TilesContract(_tileDataContract);
        marketplaceContract = MarketplaceContract(_marketplaceConract);
        computeContract = Compute(_computeContract);
    }


    function getTileData(uint32 tileId) internal view returns (
        uint32 id,
        address owner,
        bool isBeingUsed,
        bool isCrop,
        uint8 cropTypeId,
        uint8 factoryTypeId,
        uint8 fertility,
        uint8 waterLevel,
        uint8 growthStage,
        bool forSale,
        uint256 price
    ) {
        return tileDataContract.getTilesData(tileId);
    }

    // ===============================
    //    tile action
    // ===============================


    function buyNewTile(uint32 tileId) external {
        require(!tileDataContract.doesTileExist(tileId), "Tile already sold");
        uint256 price = computeContract.tilePriceCalculation(msg.sender);
        require(
            token.transferFrom(msg.sender, address(this), price), "Token transfer failed"
        );
        totalseedvolume += price;
        totaltxn++;

        userContract.setUserExists(msg.sender);
        userContract.updateUserDataTileBuy(msg.sender, true, price, tileId);

        tileDataContract.updateTileDataBuy(msg.sender, tileId, true, address(this), price);
    }

    function listTileForSale(uint32 tileId, uint256 amount) external {
        require(amount > 0, "Price must be greater than 0"); 
        tileDataContract.setTileForSale(tileId, amount, msg.sender);
    }

    function buyListedTile(uint32 tileId) external {
        (, address tileOwner, bool isBeingUsed, , , , , , , bool forSale, uint256 price ) = getTileData(tileId);
        require(!isBeingUsed && forSale, "Tile not for sale");
        address seller = tileOwner;
        require(
            token.transferFrom(msg.sender, seller, price), "Token transfer failed"
        );
        totalseedvolume += price;
        totaltxn++;
        userContract.setUserExists(msg.sender);
        userContract.updateUserDataTileBuy(msg.sender, true, price, tileId);
        userContract.updateUserDataTileBuy(seller, false, price, tileId);

        tileDataContract.updateTileDataBuy(msg.sender, tileId, true, seller, price);
        tileDataContract.updateTileDataBuy(seller, tileId, false, seller, 0);
    }



    mapping(address => bool) public hasusedreferral;
    uint256 public cropPrice = 100000 * 10 ** 18;
    
    event ReferralRewardGiven(address _username, uint256 _referralrewardamount);
    function plantCrop(uint32 tileId, uint8 cropType) external {
        (, address tileOwner, bool isBeingUsed, , , , , , , bool forSale,  ) = getTileData(tileId);
        require(msg.sender == tileOwner, "Not the tile owner");
        require(!isBeingUsed && !forSale && cropType <= cropType, "Tile already being used or sale");
        require(token.transferFrom(msg.sender, address(this), cropType), "Token transfer failed");
        totalseedvolume += cropPrice;
        totaltxn++;
        address referrer = userContract.referredBy(msg.sender);
        if(referrer != address(0)) {
            token.transfer(referrer, cropPrice * 2 / 100);
            userContract.updateReferralEarning(referrer, cropPrice * 2 / 100);
            emit ReferralRewardGiven(referrer, cropPrice * 2 / 100);

            if(!hasusedreferral[msg.sender]){
                hasusedreferral[msg.sender] = true;
                userContract.updateInventory(msg.sender, 8, 100, true);
            }
        } 
    
        tileDataContract.setCropOrFactory(true, tileId, cropType, msg.sender);
        userContract.updateCropOrFactory(msg.sender, true, cropPrice, true, tileId);
    }


    mapping(uint32 => uint256) public lastWateredTime;
    function waterCrop(uint32 tileId) external {
        (, address tileOwner, bool isBeingUsed, bool isCrop, uint8 cropType, ,uint8 fertility, uint8 waterLevel , , , ) = getTileData(tileId);
        require(msg.sender == tileOwner, "Not authorized");
        require(isBeingUsed && isCrop, "No crop here");
        require(
            block.timestamp >= lastWateredTime[tileId] + 1 days, "once in 24 hours"
        );
        lastWateredTime[tileId] = block.timestamp;
        uint8 growth = computeContract.plantGrowthCalculator(
            cropType, fertility, waterLevel, msg.sender, true
        ); 

        tileDataContract.updateWaterFertilityAndGrowth(tileId, true, growth);
        userContract.updateUserExperience(msg.sender, 5);
    }

    function fertilizeCrop(uint32 tileId) external {
        (, address tileOwner, bool isBeingUsed, bool isCrop, uint8 cropType, ,uint8 fertility, uint8 waterLevel , , , ) = getTileData(tileId);
        require(msg.sender == tileOwner, "Not authorized");
        require(isBeingUsed && isCrop, "No crop here");
        require(fertility <= 100, "Already max fertility");
        uint64 fertilizerAmount = userContract.getUserInventory(msg.sender, 8);
        require(fertilizerAmount >= 100, "Not enough fertilizer");
        userContract.updateInventory(msg.sender, 8, 100, false);
        uint8 growth = computeContract.plantGrowthCalculator(cropType, fertility, waterLevel, msg.sender, false);
        
        tileDataContract.updateWaterFertilityAndGrowth(tileId, false, growth);
        userContract.updateUserExperience(msg.sender, 10);
    }

    function harvestCrop(uint32 tileId) external {
        // address actualUser = userContract._resolveUser(msg.sender);
        (, address tileOwner, bool isBeingUsed, bool isCrop, uint8 cropType, , , , uint8 growthStage , , ) = getTileData(tileId);
        require(isBeingUsed && isCrop, "No crop here");
        require(msg.sender == tileOwner, "Not authorized");
        require(growthStage == 100, "Cannot harvest Now");

        (uint8 _harvestedResource, uint8 _amount) = computeContract.getHarvestedResourceAndAmount(cropType, msg.sender);
        if(_harvestedResource != 0) {
            userContract.updateInventory(msg.sender, _harvestedResource, _amount, true);
            tileDataContract.updateTileDataAfterHarvestOrDemolish(tileId);
            userContract.updateUserExperience(msg.sender, 20);
            userContract.updateCropOrFactory(msg.sender, true, _amount, false, tileId);
        }
        
    }
        
    uint256 public factoryPrice =  2000000 * 10 ** 18;
    function buildFactory(uint32 tileId, uint8 factoryType) external {
        
        (, address tileOwner, bool isBeingUsed, , , , , , , , ) = getTileData(tileId);
        require(!isBeingUsed, "Already something there");
        require(msg.sender == tileOwner, "Not authorized");
        require(
            token.transferFrom(msg.sender, address(this), factoryPrice), "Token transfer failed"
        );
        totalseedvolume += factoryPrice;
        totaltxn++;

        address referrer = userContract.referredBy(msg.sender);
        if(referrer != address(0)) {
            token.transfer(referrer, factoryPrice * 2 / 100);
            userContract.updateReferralEarning(referrer, factoryPrice * 1 / 100);
            emit ReferralRewardGiven(referrer, factoryPrice * 2 / 100);
        } 
        if(!hasusedreferral[msg.sender]){
            hasusedreferral[msg.sender] = true;
            userContract.updateInventory(msg.sender, 6, 10, true);
        }

        tileDataContract.setCropOrFactory(false, tileId, factoryType, msg.sender);
        userContract.updateCropOrFactory(msg.sender, false, factoryPrice, true, tileId);
    }
    
    function removeFactory(uint32 tileId) external {
        (, address tileOwner, bool isBeingUsed, , , , , , , , ) = getTileData(tileId);
        require(isBeingUsed, "Nothing there");
        require(msg.sender == tileOwner, "Not authorized");
        tileDataContract.updateTileDataAfterHarvestOrDemolish(tileId);
    }

    function produceFromFactory(uint32 tileId) external {
        (, address tileOwner, bool isBeingUsed, , , uint8 factoryTypeId , , , ,bool forSale , ) = getTileData(tileId);
        require(msg.sender == tileOwner, "Not authorized");
        require(isBeingUsed && !forSale, "Nothing here");
        uint64 energy = userContract.getUserInventory(msg.sender, 6);
        require(energy >= 10, "Not enough energy");
        userContract.updateInventory(msg.sender, 6, 10, false);
        if(factoryTypeId == 1) {
            computeContract.produceFood(msg.sender);
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

        userContract.updateUserExperience(msg.sender, 20);
    }


    // ===============================
    //    marketplace action
    // ===============================

    
    function listResourceForSale(
        uint8 _resourceType, 
        uint32 _amount, 
        uint256 _pricePerUnit
    ) external {   
        require(_amount > 0, "sell more than 0");
        uint64 amount = userContract.getUserInventory(msg.sender, _resourceType);
        require(amount >= _amount , "Not enough resources");
        userContract.updateInventory(msg.sender, _resourceType, _amount, false);
        marketplaceContract.listItems(msg.sender, _resourceType, _amount, _pricePerUnit);
        userContract.setUserExists(msg.sender);

    }  

    function buyListedResource(
        uint256 listingId, uint32 buyAmount
    ) external {
        (
            address _seller,
            uint8 _resourceType,
            uint32 _amount,
            uint256 _pricePerUnit,
            bool _isActive
        ) = marketplaceContract.getMarketListing(listingId);

        require(_isActive, "Listing not available");
        require(buyAmount > 0 && buyAmount <= _amount, "Invalid buy amount");

        uint256 totalCost = _pricePerUnit * buyAmount;
        require(
            token.transferFrom(msg.sender, _seller, totalCost), "Token transfer failed"
        ); 
        totalseedvolume += totalCost;
        totaltxn++;
        marketplaceContract.buyItem(listingId, buyAmount, totalCost, _seller);
        userContract.updateInventory(msg.sender, _resourceType, buyAmount, true);

        userContract.setUserExists(msg.sender);
        
        computeContract.recordSaleHistory(msg.sender, true, _resourceType, buyAmount, totalCost);
        computeContract.recordSaleHistory(_seller, false, _resourceType, buyAmount, totalCost);
    }

    function adminWithdraw(address to) external  {
        require(msg.sender == admin, "Not authorized");
        uint256 balance = token.balanceOf(address(this));
        token.transfer(to, balance);
    }


}




// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Actions.sol";

contract TilesContract {
    address admin;
    constructor() {
        admin = msg.sender;
    }
    
    Actions public actionsContract;
    function setContract(address _actionContract) external {
        require(msg.sender == admin, "Not authorized");
        actionsContract = Actions(_actionContract);
    }
    
    using EnumerableSet for EnumerableSet.UintSet;


    struct TileData {
        uint32 id;
        address owner;
        bool isBeingUsed;
        bool isCrop;
        uint8 cropTypeId;
        uint8 factroyTypeId;
        uint8 fertility;
        uint8 waterLevel;
        uint8 growthStage;
        bool forSale;
        uint256 price;
    }

    mapping(uint32 => TileData) public tiles;
    mapping(uint32 => bool) public tileExists;
    mapping(address => EnumerableSet.UintSet) private tilesOfUser;
    EnumerableSet.UintSet private listedTilesForSale;

    uint256 public totalcropstilldate = 0;
    uint256 public totalfactoriestilldate = 0;


    // ===============================
    //    Tile History
    // ===============================


    struct TileActions {
        string actionType;
        uint256 timestamp;
        address performedBy;
    }
    struct SaleRecord {
        address seller;
        address buyer;
        uint256 price;
        uint256 timestamp;
    }
    struct TileHistory {
        address[] owners;
        TileActions[] actions;
        SaleRecord[] sales;
    }

    mapping(uint32 => TileHistory) private tileHistories;


    // ===============================
    //    utility functions
    // ===============================

    function recordOwership(uint32 tileId, address _newOwner) internal {
        TileHistory storage history = tileHistories[tileId];
        if(history.owners.length == 0 || 
           history.owners[history.owners.length - 1] != _newOwner
        ) {
            history.owners.push(_newOwner);
        }
    }


    function recordAction(uint32 tileId, string memory actionType, address _user) internal {
        TileHistory storage history = tileHistories[tileId];
        history.actions.push(TileActions({
            actionType: actionType,
            timestamp: block.timestamp,
            performedBy: _user
        }));
    }

    function recordSale(
        uint32 tileId, address seller, address buyer, uint256 price
    ) internal {
        TileHistory storage history = tileHistories[tileId];
        history.sales.push(SaleRecord({
            seller: seller,
            buyer: buyer,
            price: price,
            timestamp: block.timestamp
        }));
    }




    // ===============================
    //    Tile Data updater
    // ===============================


    modifier onlyActions() {
        require(msg.sender == address(actionsContract), "Not authorized");
        _;
    }
    event TilePurchased(address indexed buyer, uint64 tileId);
    event TileSold(address _seller, uint256 _price);
    function updateTileDataBuy(address _user, uint32 tileId, bool sellerorbuyer, address _seller, uint256 _price) external onlyActions { // true for buyer, false for seller
        
        TileData storage tile = tiles[tileId];
        if (sellerorbuyer) {
            //buyer
            tile.id = tileId;
            tile.owner = _user;
            tile.cropTypeId = 0;
            tile.factroyTypeId = 0;
            tile.forSale = false;
            tile.price = 0;
            tileExists[tileId] = true;    
            tilesOfUser[_user].add(tileId); 
            listedTilesForSale.remove(tileId);
            recordOwership(tileId, _user);
            recordAction(tileId, "Bought Tile", _user);
            recordSale(tileId, _seller, _user, _price);
            emit TilePurchased(_user, tileId);
        } else {
            //seller 
            tilesOfUser[_user].remove(tileId);
            recordAction(tileId, "Sold Tile", _user);
            emit TileSold(_seller, _price);
        }
    }

    event TileListed(uint32 tileId);
    function setTileForSale(uint32 tileId, uint256 price, address _user) external onlyActions {
        require(tileExists[tileId], "Tile doesnt exists");
        require(tiles[tileId].owner == _user, "Not the owner");
        TileData storage tile = tiles[tileId];
        require(!tile.forSale && !tile.isBeingUsed, "Tile cannot be sold");
        tile.forSale = true;
        tile.price = price;
        listedTilesForSale.add(tileId);
        recordAction(tileId, "Listed for Sale", _user);
        emit TileListed(tileId);
    }

    event CropPlanted(uint32 tileId, address _user, uint8 croptype);
    event BuiltFactory(uint32 tileId, address _user, uint8 factorytype);
    
    uint8 public cropTypes = 4;
    uint8 public factoryTypes = 5;
    function updatecropandfactorytypes(uint8 _croptypes, uint8 _factorytypes) external {
        require(msg.sender == admin, "Not authorized");
        cropTypes = _croptypes;
        factoryTypes = _factorytypes;
    }
    function setCropOrFactory(bool corf, uint32 tileId, uint8 cofType, address _user) external onlyActions {
        TileData storage tile = tiles[tileId];
        //true: crop, false: factory
        if (corf) {

            require(cofType <= cropTypes, "Invalid Crop");
            tile.isBeingUsed = true;
            tile.isCrop = true;
            tile.cropTypeId = cofType;
            totalcropstilldate++;
            recordAction(tileId, "Crop Planted", _user);
            emit CropPlanted(tileId,_user, cofType);
        } else {
            require(cofType <= factoryTypes, "Invalid factory");
            tile.isBeingUsed = true;
            tile.isCrop = false;
            tile.factroyTypeId = cofType;
            totalfactoriestilldate++;
            recordAction(tileId, "Factory Built", _user);
            emit BuiltFactory(tileId, _user, cofType);
        }
    }

    event WateredTile(uint32 tileId);
    event FertilizedTile(uint32 tileId);
    function updateWaterFertilityAndGrowth(uint32 tileId, bool worf, uint8 growth) external onlyActions {
        // true: watering, false: fertilizer
        if(worf) {
            tiles[tileId].waterLevel += 12;
            emit WateredTile(tileId);
        } else {
            tiles[tileId].fertility += 100;
            emit FertilizedTile(tileId);
        }

        tiles[tileId].growthStage += growth;    
        if(tiles[tileId].growthStage >= 100) {
           tiles[tileId].growthStage = 100;
        }   
    } 

    function updateTileDataAfterHarvestOrDemolish(uint32 tileId) external onlyActions {
        TileData storage tile = tiles[tileId];
        tile.isBeingUsed = false;
        tile.isCrop = false;
        tile.fertility = 0;
        tile.waterLevel = 0;
        tile.growthStage = 0;
        tile.factroyTypeId = 0;
        tile.cropTypeId = 0;
    }


    // ===============================
    //    Tile Data Getters
    // ===============================

    function doesTileExist(uint32 tileId) external view returns (bool) {
        return tileExists[tileId];
    }

    function getTilesData(uint32 tileId) external view returns (
        uint32 id, address owner, bool isBeingUsed,
        bool isCrop, uint8 cropTypeId, uint8 factoryTypeId,
        uint8 fertility, uint8 waterLevel, uint8 growthStage,
         bool forSale, uint256 price
    )
    {
        require(tileExists[tileId], "No tile data found");
        TileData storage tile = tiles[tileId];

        return(
            tile.id,
            tile.owner,
            tile.isBeingUsed,
            tile.isCrop,
            tile.cropTypeId,
            tile.factroyTypeId,
            tile.fertility,
            tile.waterLevel,
            tile.growthStage,
            tile.forSale,
            tile.price
        );
    }

}
