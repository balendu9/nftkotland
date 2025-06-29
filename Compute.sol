// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./UsersContract.sol";
import "./Tiles.sol";

contract Compute {
    address admin;
    constructor () {
        admin = msg.sender;
    }

    UsersContract public userContract;
    Tiles public tilecontract;
    function setContract(address _usercontract, address _tilecontract) external {
        require(msg.sender == admin, "Not authorized");
        userContract = UsersContract(_usercontract);
        tilecontract = Tiles(_tilecontract);
    }

    uint8 public currentSeason = 0;
    function updateSeason(uint8 season) external {
        require(msg.sender == admin, "Not authorized");
        currentSeason = season;
    }

    function plantGrowthCalculator(
        uint8 cropType, uint8 fertility, uint8 waterlevel, uint8 _ecoscore, uint8 _pollutionlevel, bool worf
    ) external view returns (uint8 growth) {
        uint8 growthRate = 0;

        if (cropType == 1) {
            growthRate = (currentSeason == 1) ? 10 : 
                ((currentSeason == 0 || currentSeason == 3) ? 7 : 3);
        } else if (cropType == 2) {
            growthRate = (currentSeason == 2) ? 20 :
                (currentSeason == 1 ? 10 : 3);
        } else if (cropType == 3) {
            growthRate = (currentSeason == 0) ? 15 :
                (currentSeason == 1 ? 7 : 3);
        } else if (cropType == 4) {
            growthRate = (currentSeason == 0) ? 15 :
                ((currentSeason == 1 || currentSeason == 3) ? 8 : 3);
        } else {
            growthRate = 0;
        }

        uint8 watereffect = 0;
        if(worf) {
            watereffect = (waterlevel + 12)/10;
        } 
        uint8 fertilityeffect = fertility /10;
        
        growth = growthRate * (1 + fertilityeffect / 10) + watereffect + _ecoscore - _pollutionlevel;
    }

    

    // MODIFIER
    modifier internalContracts() {
        require(msg.sender == address(userContract) || msg.sender == address(tilecontract) , "UNAUTH");
        _;
    }


    // HARVEST

    function getHarvestedResourceAndAmount (
        uint8 _cropTypeId, address _user
    ) external pure returns (uint8 resourceType, uint8 amount)  {
        uint8 resourceAmountHarvested = 100;
        if (address(_user) != address(0)) {
            resourceAmountHarvested = 100;
        }

        if (_cropTypeId == 1) {
            return (1, resourceAmountHarvested);
        } else if (_cropTypeId == 2) {
            return (2, resourceAmountHarvested);
        } else if (_cropTypeId == 3) {
            return (3, resourceAmountHarvested);
        } else if (_cropTypeId == 4) {
            return (4, resourceAmountHarvested);
        }
        
        return (0, 0);
    }

    // FACTORY

    function produceFood(address _user) external internalContracts {
        uint256 wheat = userContract.getUserInventory(_user, 1);
        uint256 corn = userContract.getUserInventory(_user, 2);
        uint256 potato = userContract.getUserInventory(_user, 3);
        uint256 carrot = userContract.getUserInventory(_user, 4);
        require(wheat >= 50 || corn >= 50 || potato >= 50 || carrot >= 50, "Not enough resources");

        if(wheat >= 50) {
            userContract.updateInventory(_user, 1, 50, false);
        } else if(corn >= 50) {
            userContract.updateInventory(_user, 2, 50, false);
        } else if(potato >= 50) {
            userContract.updateInventory(_user, 3, 50, false);
        } else if(carrot >= 50) {
            userContract.updateInventory(_user, 4, 50, false);
        }

        userContract.updateInventory(_user, 5, 20, true);
    }

    function produceEnergy(address _user) external internalContracts {
        uint256 factorygoods = userContract.getUserInventory(_user, 7);
        require(factorygoods >= 10, "Not enough factory goods");
        userContract.updateInventory(_user, 7, 10, false);
        userContract.updateInventory(_user, 6, 50, true);
    }


// wheat, food = 20, 10 => factory goods = 35
    function produceBakery(address _user) external internalContracts {
        uint256 wheat = userContract.getUserInventory(_user, 1);
        uint256 food = userContract.getUserInventory(_user, 5);
        require(wheat >= 20 || food >= 10, "Not enough resouces");
        userContract.updateInventory(_user, 1, 20, false);
        userContract.updateInventory(_user, 5, 10, false);
        userContract.updateInventory(_user, 7, 35, true);
    } 


// corn 20 carrot 10 => factory good = 30
    function produceJuice(address _user) external internalContracts {
        uint256 corn = userContract.getUserInventory(_user, 2);
        uint256 carrot = userContract.getUserInventory(_user, 4);
        require(corn >= 20 && carrot >= 10, "Not enough resources");
        userContract.updateInventory(_user, 2, 20, false);
        userContract.updateInventory(_user, 4, 10, false);
        userContract.updateInventory(_user, 7, 30, true);
    }   

    //factory good 20 => energy 10 fertilizer 600
    function produceBioFuel(address _user) external internalContracts {
        uint256 factorygoods = userContract.getUserInventory(_user, 7);
        require(factorygoods >= 20, "Not enough resources");
        userContract.updateInventory(_user, 7, 20, false);
        userContract.updateInventory(_user, 6, 10, true);
        userContract.updateInventory(_user, 8, 600, true);
    }


    function regiontilesprops(uint8 typeid) external internalContracts returns ( uint8 fertility, uint8 waterLevel) {
        if ( typeid == 1) {
            fertility = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, typeid, "fertility"))) % 21 + 5);
            waterLevel = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, typeid, "water"))) % 21 + 5);
        } else {
            fertility = 0;
            waterLevel = 0;
        }

        return ( fertility, waterLevel );
    }


}