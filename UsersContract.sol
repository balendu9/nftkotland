// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract UsersContract {
    address admin;
    constructor () {
        admin = msg.sender;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "ONLY_ADMIN");
        _;
    }

    address public tileContract;
    address public computeContract;

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

    mapping(address => UserData) public users;

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

    function setContracts ( address _tilecontract, address _computecontract ) external  onlyAdmin {
        tileContract = _tilecontract;
        computeContract = _computecontract;
    }

    modifier internalContracts() {
        require( msg.sender == tileContract || msg.sender == computeContract, "NOT_AUTHORIZED");
        _;
    }

    
    uint256 public totalusers = 0;
    mapping(address => uint256) public accountage;
    function setUserExists(address _user) external internalContracts {
        if ( !users[_user].exists ) {
            totalusers += 1;
            users[_user].userAddress = _user;
            users[_user].exists = true;
            accountage[_user] = block.timestamp;
        }
    }

    function updateInventory(
        address _user, uint8 resource, uint32 amount, bool increase
    ) external internalContracts {
        if (increase) {
            users[_user].inventory[resource] += amount;
        } else {
            users[_user].inventory[resource] -= amount;
        }
    }

}