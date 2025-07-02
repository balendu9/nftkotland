// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
contract Users {
    using Strings for uint32;
    using Strings for uint256;


    address admin;
    constructor () {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ONLY_ADMIN");
        _;
    }

    address public computecontract;
    address public marketplace;

    function setcontract (address _compute, address _marketplace) external onlyAdmin {
        computecontract = _compute;
        marketplace = _marketplace;
    }

    uint8 totalresources = 9;
    function updateResources(uint8 _newtotal) external onlyAdmin {
        totalresources = _newtotal;
    }


    struct UserData {
        address userAddress;
        uint32 totalTilesOwned;
        uint32 tilesUnderUse;
        uint32 userExperience;
        bool exists;
        mapping(uint8 => uint256) inventory;
    }


    mapping ( address => UserData ) public users;

    struct Transaction {
        uint256 id;
        string txtype;
        string description;
        uint256 amount;
        uint256 timestamp;
    }
    mapping (address => Transaction[]) public transactionHistory;
    // ===============================
    //    GETTERS
    // ===============================

    function getUserData(address _user) external view returns(
        address userAddress, uint32 totalTilesOwned, uint32 tilesUnderUse, uint32 userExperience, bool exists
    ) {
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

    function getUserInventory(address user, uint8 resource) external view returns(uint256) {
        return users[user].inventory[uint8(resource)];
    }

    function getUserAllInventory(
        address user
    ) external view returns (uint256[] memory) {
        uint256[] memory inventoryData = new uint256[](totalresources);

        for (uint8 i = 0; i < totalresources; i++) {
            inventoryData[i] = users[user].inventory[i];
        }
        return inventoryData;        
    }

    // ===============================
    //    SETTERS
    // ===============================

    modifier internalContracts() {
        require( msg.sender == computecontract || msg.sender == marketplace , "NOT_AUTHORIZED");
        _;
    }

    uint256 public totalusers = 0;
    mapping ( address => uint256 ) public accountage;
    function setUserExists ( address _user ) external internalContracts {

        if ( !users[_user].exists ) {
            totalusers += 1;
            users[_user].userAddress = _user;
            users[_user].exists = true;
            accountage[_user] = block.timestamp;
        }
    }

    function updateInventory (
        address _user, uint8 resource, uint32 amount, bool increase
    ) external internalContracts {
        if (increase) {
            users[_user].inventory[resource] += amount;
        } else {
            users[_user].inventory[resource] -= amount;
        }
    }


    // ===============================
    //    REFERRAL SYSTEM
    // ===============================

    // mapping from user => their reffer
    mapping(address => address) public referredBy;
    // mapping from reffer => list of referrals
    mapping(address => address[]) private referrals;
    // track if user has already set a referrer
    mapping(address => bool) public hasSetReferrer;

    struct referreraddtime {
        address referree;
        uint256 timestamp;
    }
    mapping(address => referreraddtime[]) public referraladdTimeHistory;


    function setReferrer ( address _referrer ) external {
        require(!hasSetReferrer[msg.sender], "REFERRER_ALREADY_SET");
        require(_referrer != address(0), "INVALID_REFERRER");
        require(_referrer != msg.sender, "CANNOT_REFERRER_YOURSELF");

        referredBy[msg.sender] = _referrer;
        referrals[_referrer].push(msg.sender);
        hasSetReferrer[msg.sender] = true;
        referraladdTimeHistory[_referrer].push(
            referreraddtime({
                referree: msg.sender,
                timestamp: block.timestamp
            })
        );
    }

    function getReferralCount(address _referrer) external view returns (uint256) {
        return referrals[_referrer].length;
    }



    struct ReferralEarning{
        address referee;
        uint256 amount;
        uint256 timestamp;
    } 
    mapping(address => ReferralEarning[]) public referralrewardhistory;
    mapping(address => uint256) public totalReferralEarnings;

    function updateReferralEarning(address _user, uint256 _amount) external internalContracts {
        totalReferralEarnings[_user] += _amount;
        
    } 

    function getReferrer(address user) external view returns (address) {
        return referredBy[user];
    }

    mapping ( address => uint256 ) public userTxIdCounter;
    function croporfactorytxn(address _user, bool corf, uint256 price, bool action, uint32 tileId)
    external internalContracts {
        UserData storage user = users[_user];
        // true: crop, false: factory
        //action: true: planting or factory build.. false: harvesting

        userTxIdCounter[_user] += 1;
        if ( corf ) {
            user.userExperience += 15;
            if (action) {
                user.tilesUnderUse +=1;
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Sow",
                    description: string(abi.encodePacked("Crop Planted on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
            } else  {
                user.tilesUnderUse -= 1;
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Harvest",
                    description: string(abi.encodePacked("Crop Harvested on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
            }
        } else {
            user.userExperience += 40;
            if (action) {
                user.tilesUnderUse += 1;
                transactionHistory[_user].push(Transaction({
                    id: userTxIdCounter[_user],
                    txtype: "Investment",
                    description: string(abi.encodePacked("Built Factory on Tile #", tileId.toString())),
                    amount: price,
                    timestamp: block.timestamp
                }));
            }
        }
    }


    function recordMarketplacetx(
        address _user, string memory _txtype, string memory _resource, uint256 amount, bool _spent, uint256 _price
    ) external internalContracts {
        userTxIdCounter[_user] += 1;

        if (_spent) {
            transactionHistory[_user].push(Transaction({
                id: userTxIdCounter[_user],
                txtype: _txtype,
                description: string(abi.encodePacked("Bought ", amount.toString(), " ", _resource)),
                amount: _price,
                timestamp: block.timestamp
            }));
        } else {
            transactionHistory[_user].push(Transaction({
                id: userTxIdCounter[_user],
                txtype: _txtype,
                description: string(abi.encodePacked("Sold ", amount.toString(), " ", _resource)),
                amount: _price,
                timestamp: block.timestamp
            }));
        }
        users[_user].userExperience += 10;
    }


    // gettransactionhistory

    function getTransactionHistory(address user, uint256 page) external view returns (
        string[] memory txtype,
        string[] memory descriptions,
        uint256[] memory amounts,
        uint256[] memory timestamps
    ) {
        uint256 total = transactionHistory[user].length;
        require(total >0, "NO_TRANSACTION_HISTORY");
        uint256 itemsPerPage = 10;
        uint256 start = total > page * itemsPerPage ? total - (page * itemsPerPage) : 0;

        uint256 end = total - ((page - 1) * itemsPerPage);
        if (end > total) end = total;
        if (start > end) start = 0;
        uint256 len = end - start;

        txtype = new string[](len);
        descriptions = new string[](len);
        amounts = new uint256[](len);
        timestamps = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            Transaction memory txData = transactionHistory[user][start + i];
            txtype[i] = txData.txtype;
            descriptions[i] = txData.description;
            amounts[i] = txData.amount;
            timestamps[i] = txData.timestamp;
        }
    }


    // leaderboard
    address[] public topPlayers;
    function updateLeaderBoard (address _user) internal  {
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

        for(uint256 i = 0; i < topPlayers.length; i++) {
            for (uint256 j = i+1; j < topPlayers.length; j++) {
                if (users[topPlayers[j]].userExperience > users[topPlayers[i]].userExperience) {
                    (topPlayers[i], topPlayers[j]) = (topPlayers[j], topPlayers[i]);
                }
            }
        }

        if (topPlayers.length > 50) {
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

    function updateUserExperience(address _user, uint8 _exp) external internalContracts {
        users[_user].userExperience += _exp;
        updateLeaderBoard(_user);
    }


}