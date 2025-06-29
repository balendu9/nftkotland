// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Users {
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

    


}