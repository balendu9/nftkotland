// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Actions.sol";
import "./Compute.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
contract UsersContract {

    address admin;
    Actions public actionContract;
    Compute public computeContract;
    using Strings for uint32;
    using Strings for uint256;

    uint8 totalresources = 9;

    struct UserData{
        address userAddress;
        uint32 totalTilesOwned;
        uint32 tilesUnderUse;
        uint32 userExperience;
        bool exists;
        mapping(uint8 => uint64) inventory;
    }

    struct Transaction {
        uint256 id;
        string txtype;
        string description;
        uint256 amount;
        uint256 timestamp;
    }


    mapping(address => UserData) public users;
    mapping(address => Transaction[]) public transactionHistory;

    mapping(address => uint256) public spent;
    mapping(address => uint256) public earned;
    mapping(address => uint256) public currentCropCount;
    mapping(address => uint256) public currentFactoryCount;
    mapping(address => uint256) public totalCropCount;
    mapping(address => uint256) public totalFactoryCount;

    constructor() {
        admin = msg.sender;
    }

    function setContract(address _actionContract, address _computeContract) external {
        require(msg.sender == admin, "Not authorized");
        actionContract = Actions(_actionContract);
        computeContract = Compute(_computeContract);
    }


    // =========================================
    // Referral System
    // =========================================

 
    // mapping from user => their reffer
    mapping(address => address) public referredBy;
    // mapping from reffer => list of referrals
    mapping(address => address[]) private referrals;
    // track if user has already set a referrer
    mapping(address => bool) public hasSetReferrer;

    event ReferrerSet(address indexed user, address indexed referrer);
    struct referreraddtime {
        address referree;
        uint256 timestamp;
    }
    mapping(address => referreraddtime[]) public referraladdTimeHistory;
    
    function setReferrer(address _referrer) external {
        // address actualUser = _resolveUser(msg.sender);
        require(!hasSetReferrer[msg.sender], "Referrer already set");
        require(_referrer != address(0), "Invalid referrer");
        require(_referrer != msg.sender, "Cannot refer yourself");

        referredBy[msg.sender] = _referrer;
        referrals[_referrer].push(msg.sender);
        hasSetReferrer[msg.sender] = true;
        referraladdTimeHistory[_referrer].push(
            referreraddtime({
            referree: msg.sender,
            timestamp: block.timestamp
        }));

        emit ReferrerSet(msg.sender, _referrer);
    }

    function getReferralCount(address _referrer) external view returns(uint256) {
        return referrals[_referrer].length;
    }


    struct ReferralEarning{
        address referee;
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => ReferralEarning[] ) public referralrewardhistory;
    mapping(address => uint256) public totalReferralEarnings;
    
    function updateReferralEarning(address _user, uint256 _amount) external onlySeedContracts {
        totalReferralEarnings[_user] += _amount;
        
        ReferralEarning memory newEarning = ReferralEarning({
            referee: msg.sender,       // This could be the contract calling — maybe you need to pass referee explicitly
            amount: _amount,
            timestamp: block.timestamp
        });
        referralrewardhistory[_user].push(newEarning);
    }

    
function getReferralAddTimeHistory(address referrer) external view returns (address[] memory referees, uint256[] memory timestamps) {
    uint256 length = referraladdTimeHistory[referrer].length;
    referees = new address[](length);
    timestamps = new uint256[](length);

    for (uint256 i = 0; i < length; i++) {
        referreraddtime memory entry = referraladdTimeHistory[referrer][i];
        referees[i] = entry.referree;
        timestamps[i] = entry.timestamp;
    }
}

    function getReferralRewardHistory(address referrer) external view returns (address[] memory referees, uint256[] memory amounts, uint256[] memory timestamps) {
    uint256 length = referralrewardhistory[referrer].length;
    referees = new address[](length);
    amounts = new uint256[](length);
    timestamps = new uint256[](length);

    for (uint256 i = 0; i < length; i++) {
        ReferralEarning memory entry = referralrewardhistory[referrer][i];
        referees[i] = entry.referee;
        amounts[i] = entry.amount;
        timestamps[i] = entry.timestamp;
    }
}



    
    



    // ===============================
    //    leaderboard
    // ===============================

    address[] public topPlayers;
    mapping(address => string) public usernames;

    function updateLeaderBoard(address _user) internal {
        if(!users[_user].exists) return;

        bool exists = false;
        for (uint256 i = 0; i < topPlayers.length; i++) {
            if (topPlayers[i] == _user) {
                exists = true;
                break;
            }
        }

        if (!exists) {
            topPlayers.push(_user);
        }
        //sorting leaderboard by exp
        for(uint256 i = 0; i < topPlayers.length; i++) {
            for (uint256 j = i+1; j < topPlayers.length; j++) {
                if (users[topPlayers[j]].userExperience > users[topPlayers[i]].userExperience) {
                    (topPlayers[i], topPlayers[j]) = (topPlayers[j], topPlayers[i]);
                }
            }
        }

        // only 100 players
        if (topPlayers.length > 100) {
            topPlayers.pop();
        }
    }

    function getLeaderboard() external view returns (address[] memory, uint32[] memory) {
        uint256 len = topPlayers.length;
        address[] memory playerAddresses = new address[](len);
        uint32[] memory playerExperience = new uint32[](len);

        for(uint8 i = 0; i< len; i++) {
            playerAddresses[i] = topPlayers[i];
            playerExperience[i] = users[topPlayers[i]].userExperience;
        }

        return(playerAddresses ,playerExperience);

    }



    // ===============================
    //    VIEWS
    // ===============================

    function getUserData(address _user) external view returns(
        address userAddress, uint32 totalTilesOwned, uint32 tilesUnderUse, uint32 userExperience, bool exists
    ) {
        // address actualUser = _resolveUser(_user);
        require(users[_user].exists, "User doesnt exist");
        UserData storage userData = users[_user];
        return (
            userData.userAddress,
            userData.totalTilesOwned,
            userData.tilesUnderUse,
            userData.userExperience,
            userData.exists
        );
    }

    function getTransactionHistory(address user) external view returns (
        string[] memory txtype,
        string[] memory descriptions,
        uint256[] memory amounts,
        uint256[] memory timestamps
    ) {
        uint256 len = transactionHistory[user].length;
        txtype = new string[](len);
        descriptions = new string[](len);
        amounts = new uint256[](len);
        timestamps = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            Transaction memory txData = transactionHistory[user][i];
            txtype[i] = txData.txtype;
            descriptions[i] = txData.description;
            amounts[i] = txData.amount;
            timestamps[i] = txData.timestamp;
        }
    }

    function getUserInventory(address user, uint8 resource) external view returns(uint64) {
        return users[user].inventory[uint8(resource)];
    }

    function getUserAllInventory(
        address user
    ) external view returns (uint64[] memory) {
        uint64[] memory inventoryData = new uint64[](totalresources);

        for (uint8 i = 0; i < totalresources; i++) {
            inventoryData[i] = users[user].inventory[i];
        }
        return inventoryData;        
    }

    // ===============================
    //    UPDATERS
    // ===============================

 
    modifier onlySeedContracts() {
        require(msg.sender == address(actionContract) || msg.sender == address(computeContract) , "Not authorized");
        _;
    }
    uint256 public totalUsers = 0;
    mapping(address => uint256) public accountage;
    function setUserExists(address _user) external onlySeedContracts {
        totalUsers += users[_user].exists ? 0 : 1;
        users[_user].userAddress = _user;
        users[_user].exists = true;
        accountage[_user] = block.timestamp;
    }

    mapping(address => uint256) public userTxIdCounter;
    function updateUserDataTileBuy(address _user, bool sellerorbuyer, uint256 price, uint32 tileId) external onlySeedContracts {
        // false for seller and true for buyer
        UserData storage user = users[_user];
        require(user.exists, "User dont exist");
        user.userExperience += 20;
        updateLeaderBoard(_user);
        userTxIdCounter[_user] += 1;

        if(sellerorbuyer) { //buyer
            user.totalTilesOwned += 1;
            transactionHistory[_user].push(Transaction({
                id: userTxIdCounter[_user],
                txtype: "Purchase",
                description: string(abi.encodePacked("Purchased Tile #", tileId.toString())),
                amount: price,
                timestamp: block.timestamp
            }));
            spent[_user] += price;
        } else { // seller
            user.totalTilesOwned -= 1;
            transactionHistory[_user].push(Transaction({
                id: userTxIdCounter[_user],
                txtype: "Sale",
                description: string(abi.encodePacked("Sold Tile #", tileId.toString())),
                amount: price,
                timestamp: block.timestamp
            }));
        }
    }

    function updateCropOrFactory(
        address _user, bool corf, uint256 price, bool action, uint32 tileId
    ) external onlySeedContracts { 
        UserData storage user = users[_user];
        require(user.exists, "user dont exist");
        // true: crop, false: factory
        // action: true: planting or factory build... false: harvesting or factory demolish
        userTxIdCounter[_user] += 1;
        if(corf) {
            user.userExperience += 15;
            if(action){
                user.tilesUnderUse += 1;
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Sow",
                    description: string(abi.encodePacked("Crop Planted on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
                spent[_user] += price;
                currentCropCount[_user] += 1;
                totalCropCount[_user] += 1;
            } else {
                user.tilesUnderUse -= 1;
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Harvest",
                    description: string(abi.encodePacked("Crop Harvested on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
                currentCropCount[_user] -= 1;
            }
        } else {
            user.userExperience += 40;
            if(action) {
                user.tilesUnderUse+= 1;
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Investment",
                    description: string(abi.encodePacked("Built Factory on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
                spent[_user] += price;
                currentFactoryCount[_user] += 1;
                totalFactoryCount[_user] += 1;
            } else {
                user.tilesUnderUse -= 1;
                user.userExperience += 20;
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Demolish",
                    description: string(abi.encodePacked("Factory Demolished on Tile #", tileId.toString())),
                    amount: 0,
                    timestamp: block.timestamp
                }));
                currentFactoryCount[_user] -= 1;
            }
        }
    }

    function updateUserExperience(address user, uint8 exp) external onlySeedContracts {
        users[user].userExperience += exp;
        updateLeaderBoard(user);
    }

    function updateInventory(
        address _user, uint8 resource, uint32 amount, bool increase
    ) external onlySeedContracts {
        if (increase) {
            users[_user].inventory[resource] += amount;
        } else {
            users[_user].inventory[resource] -= amount;
        }
    }


    function recordTransactionHistory(
        address _user, string memory _txtype, string memory _description, uint256 amount, bool _spent, uint256 _price
    ) external onlySeedContracts {
        userTxIdCounter[_user] += 1;
        
        if(_spent) {
            spent[_user] += _price;
            transactionHistory[_user].push(Transaction({
            id: userTxIdCounter[_user],
            txtype: _txtype,
            description: string(abi.encodePacked("Bought ", amount.toString(), " ", _description)),
            amount: _price,
            timestamp: block.timestamp
        }));

        } else {
            earned[_user] += _price;
            transactionHistory[_user].push(Transaction({
            id: userTxIdCounter[_user],
            txtype: _txtype,
            description: string(abi.encodePacked("Sold ", amount.toString(), " ", _description)),
            amount: _price,
            timestamp: block.timestamp
        }));
        }

        users[_user].userExperience += 10;
        updateLeaderBoard(_user);

    }

}




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

 string[] public resources = [
    "None",
    "Wheat",
    "Corn",
    "Potato",
    "Carrot",
    "Food",
    "Energy",
    "FactoryGoods",
    "Fertilizer"
    ];

    function recordSaleHistory(address _user, bool typeoftnx, uint8 resourcetype, uint256 amount, uint256 price) external onlyActions {
        if (typeoftnx) {
            // purchase
            string memory usertxtype = "Purchase";
            string memory resource = resources[resourcetype];
            userContract.recordTransactionHistory(_user, usertxtype, resource, amount, true, price);
    
        } else {
            string memory usertxtype = "Sale";
            string memory resource = resources[resourcetype];
            userContract.recordTransactionHistory(_user, usertxtype, resource, amount, false, price);
        }
    }
