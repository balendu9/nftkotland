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
import "./UsersContract.sol";
import "./Actions.sol";

contract MarketplaceContract {    
    address public admin;
    constructor() {
        admin = msg.sender;
    }
    modifier onlyAdmin() {
        require(msg.sender == admin, "not authorized");
        _;
    }

    UsersContract public userContract;
    Actions public actionContract;
    function setContract(address _actionContract, address _userContract) external {
        require(msg.sender == admin, "Not authorized");
        actionContract = Actions(_actionContract);
        userContract = UsersContract(_userContract);
    }

    uint8 totalTypes = 9;
    function updatetotaltypes(uint8 _total) external onlyAdmin {
        totalTypes = _total;
    }

    struct MarketListing {
        address seller;
        uint8 resourceType;
        uint32 amount;
        uint256 pricePerUnit;
        bool isActive;
    }

    mapping(uint256 => MarketListing) public marketListing;

    uint256 public nextListingId;

    struct ResourceAnalytics {
        uint64 totalUnitsSold;
        uint256 totalRevenue;
        uint256 averagePrice;
        uint256 lastPrice;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 lastUpdatedTime;
    }

    mapping(uint8 => ResourceAnalytics) public resourceAnalytics;

    struct ListingAnalytics {
        uint64 totalUnitsListed;
        uint256 totalListingValue;
        uint64 totalListings;
        uint256 averageListingPrice;
        uint256 lastUpdatedTime;
    }

    mapping(uint8 => ListingAnalytics) public listingAnalytics;


    struct PricePoint {
        uint256 price;
        uint256 timestamp;
    }
    mapping(uint8 => PricePoint[]) public priceHistory;


    struct DailyPriceSummary {
        uint256 low;
        uint256 high;
        uint256 total;
        uint256 count;
        uint256 average;
    }
    mapping(uint8 => mapping(uint256 => DailyPriceSummary)) public dailyPriceSummary;


    event ListedResourceForSale(
        address seller,
        uint8 resourceType,
        uint32 amount,
        uint256 pricePerUnit
    );
    function listItems(
        address _seller,
        uint8 _resourceType,
        uint32 _amount,
        uint256 _pricePerUnit
    ) public {
        require(msg.sender == address(actionContract), "Not authorized");
        marketListing[nextListingId] = MarketListing({
            seller: _seller,
            resourceType: _resourceType,
            amount: _amount,
            pricePerUnit: _pricePerUnit,
            isActive: true
        });

        ListingAnalytics storage la = listingAnalytics[_resourceType];
        la.totalUnitsListed += _amount;
        la.totalListingValue += (_pricePerUnit * _amount);
        la.totalListings += 1;
        la.lastUpdatedTime = block.timestamp;
        nextListingId++;

        if (la.totalUnitsListed > 0) {
            la.averageListingPrice = la.totalListingValue / la.totalUnitsListed;
        }
        emit ListedResourceForSale(_seller, _resourceType, _amount, _pricePerUnit);
    }

    event ProductPurchased(address seller, uint256 earned);
    function buyItem(uint256 listingId, uint32 buyAmount, uint256 totalCost, address seller) external {
        require(msg.sender == address(actionContract), "Not authorized");

        marketListing[listingId].amount -= buyAmount;
        if (marketListing[listingId].amount == 0) {
            marketListing[listingId].isActive = false;
        } 

        MarketListing storage listing = marketListing[listingId];
        ResourceAnalytics storage ra = resourceAnalytics[listing.resourceType];
        ra.totalUnitsSold += buyAmount;
        ra.totalRevenue += totalCost;
        ra.lastPrice = listing.pricePerUnit;
        ra.lastUpdatedTime = block.timestamp;

        
        if (ra.minPrice == 0 || listing.pricePerUnit < ra.minPrice) {
            ra.minPrice = listing.pricePerUnit;
        }
        if (listing.pricePerUnit > ra.maxPrice) {
            ra.maxPrice = listing.pricePerUnit;
        }

        if (ra.totalUnitsSold > 0) {
            ra.averagePrice = ra.totalRevenue / ra.totalUnitsSold;

        }

        PricePoint memory point = PricePoint({
            price: listing.pricePerUnit,
            timestamp: block.timestamp
        });

        priceHistory[listing.resourceType].push(point);
        uint256 day = block.timestamp / 1 days;
        DailyPriceSummary storage summary = dailyPriceSummary[listing.resourceType][day];

        
        if (summary.count == 0) {
            summary.low = listing.pricePerUnit;
            summary.high = listing.pricePerUnit;
        } else {
            if (listing.pricePerUnit < summary.low) summary.low = listing.pricePerUnit;
            if (listing.pricePerUnit > summary.high) summary.high = listing.pricePerUnit;
        }

        summary.total += listing.pricePerUnit;
        summary.count += 1;
        summary.average = summary.total / summary.count;


        emit ProductPurchased(seller, totalCost);
    }



    function getListingAnalytics() external view returns (
        uint8[] memory resourceIds,
        uint64[] memory listedUnits,
        uint256[] memory avgListingPrices,
        uint64[] memory totalListings,
        uint64[] memory soldUnits,
        uint256[] memory avgSoldPrices,
        uint256[] memory totalRevenues,
        uint256[] memory minPrices,
        uint256[] memory maxPrices,
        uint256[] memory lastSoldTimes
    ) {
    
        resourceIds = new uint8[](totalTypes);
        listedUnits = new uint64[](totalTypes);
        avgListingPrices = new uint256[](totalTypes);
        totalListings = new uint64[](totalTypes);
        soldUnits = new uint64[](totalTypes);
        avgSoldPrices = new uint256[](totalTypes);
        totalRevenues = new uint256[](totalTypes);
        minPrices = new uint256[](totalTypes);
        maxPrices = new uint256[](totalTypes);
        lastSoldTimes = new uint256[](totalTypes);

        for (uint8 i = 0; i < totalTypes; i++) {
            ListingAnalytics memory la = listingAnalytics[i];
            ResourceAnalytics memory ra = resourceAnalytics[i];

            resourceIds[i] = i;
            listedUnits[i] = la.totalUnitsListed;
            avgListingPrices[i] = la.averageListingPrice;
            totalListings[i] = la.totalListings;

            soldUnits[i] = ra.totalUnitsSold;
            avgSoldPrices[i] = ra.averagePrice;
            totalRevenues[i] = ra.totalRevenue;
            minPrices[i] = ra.minPrice;
            maxPrices[i] = ra.maxPrice;
            lastSoldTimes[i] = ra.lastUpdatedTime;
        }

    }


    function getResourceAnalytics(uint8 resourceType) external view returns (
        uint64 totalUnitsSold,
        uint256 totalRevenue,
        uint256 averagePrice,
        uint256 lastPrice,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 lastUpdatedTime
    ) {
        ResourceAnalytics memory analytics = resourceAnalytics[resourceType];
        return (
            analytics.totalUnitsSold,
            analytics.totalRevenue,
            analytics.averagePrice,
            analytics.lastPrice,
            analytics.minPrice,
            analytics.maxPrice,
            analytics.lastUpdatedTime
        );
    }

    function getMarketListing(uint256 listingId) external view returns (
        address seller,
        uint8 resourceType,
        uint32 amount,
        uint256 pricePerUnit,
        bool isActive
    ) {
        MarketListing memory listing = marketListing[listingId];
        return (
            listing.seller,
            listing.resourceType,
            listing.amount,
            listing.pricePerUnit,
            listing.isActive
        );
    }

    function getAllMarketListings()
        external
        view
        returns (
            uint256[] memory listingIds,
            address[] memory sellers,
            uint8[] memory resourceTypes,
            uint32[] memory amounts,
            uint256[] memory pricePerUnits
        )
    {
        uint256 count = 0;

        // First, count active listings
        for (uint256 i = 0; i < nextListingId; i++) {
            if (marketListing[i].isActive) {
                count++;
            }
        }

        // Then fill arrays
        listingIds = new uint256[](count);
        sellers = new address[](count);
        resourceTypes = new uint8[](count);
        amounts = new uint32[](count);
        pricePerUnits = new uint256[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            MarketListing memory m = marketListing[i];
            if (m.isActive) {
                listingIds[index] = i;
                sellers[index] = m.seller;
                resourceTypes[index] = m.resourceType;
                amounts[index] = m.amount;
                pricePerUnits[index] = m.pricePerUnit;
                index++;
            }
        }
    }




}