// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./RegionNFT.sol";
import "./Users.sol";

contract Compute {
    address admin;
    constructor () {
        admin = msg.sender;
    }
    IERC20 public  token;

    Users public usercontract;
    address tilescontract;
    function setcontract (address _tile, address _user, address _gametoken) external {
        require(msg.sender == admin, "UNAUTHORIZED");
        usercontract = Users(_user);
        tilescontract = _tile;
        token = IERC20(_gametoken);
    }

    modifier internalcontracts() {
        require(msg.sender == address(usercontract) || msg.sender == tilescontract , "UNAUTH");
        _;
    }


    uint8 public currentSeason = 0;
    function updateSeason(uint8 season) external {
        require(msg.sender == admin, "Not authorized");
        currentSeason = season;
    }


    function _setUserExists (address _user) external {
        require( msg.sender == tilescontract, "UNAUTHORIZED" );
        usercontract.setUserExists(_user);
    }

    mapping( address => bool ) public hasusedreferral;

    event ReferralRewardGiven(address _address, uint256 _referralrewardamount);
    uint256 public _cropPrice = 50000 * 10 ** 18;
    uint256 public _factoryPrice = 500000 * 10 * 18;

    function _giveReferralRewards(address _user, uint8 _rewardtype) external internalcontracts{

        address referrer = usercontract.getReferrer(_user);
        
        if (referrer != address(0)) {
            if (_rewardtype == 1) {
                token.transfer(referrer, _cropPrice * 2 / 100);
                emit ReferralRewardGiven(referrer, _cropPrice * 2 / 100);  
            } else {
                token.transfer(referrer, _factoryPrice * 2 / 100);
                emit ReferralRewardGiven(referrer, _factoryPrice * 2 / 100);  
            }
        }

        if(!hasusedreferral[_user]){
            hasusedreferral[_user] = true;
            if ( _rewardtype == 1 ){
                usercontract.updateInventory(_user, 8, 100, true);
            } else {
                usercontract.updateInventory(_user, 6, 10, true);
            }
        }
        usercontract.updateUserExperience(_user, 10);
    }

    // ===============================
    //    PLANT GROWTH AND HARVESTINGS
    // ===============================
   
    function plantGrowthCalculator(
        uint8 _cropType, uint8 _fertility, uint8 _waterlevel, uint8 _ecoscore, uint8 _pollutionlevel, bool worf
    ) external view returns (uint8 growth) {
        uint8 growthRate = 0;

        if (_cropType == 1) {
            growthRate = (currentSeason == 1) ? 10 : 
                ((currentSeason == 0 || currentSeason == 3) ? 7 : 3);
        } else if (_cropType == 2) {
            growthRate = (currentSeason == 2) ? 20 :
                (currentSeason == 1 ? 10 : 3);
        } else if (_cropType == 3) {
            growthRate = (currentSeason == 0) ? 15 :
                (currentSeason == 1 ? 7 : 3);
        } else if (_cropType == 4) {
            growthRate = (currentSeason == 0) ? 15 :
                ((currentSeason == 1 || currentSeason == 3) ? 8 : 3);
        } else {
            growthRate = 0;
        }

        uint8 watereffect = 0;
        if ( worf ) {
            watereffect = (_waterlevel + 7) / 10;
        } 
        

        growth = growthRate * ( 1 + _fertility / 100) + watereffect + _ecoscore - _pollutionlevel; 
    }

    function getHarvestedResourceAndAmount (
        uint8 _cropTypeId, address _user
    ) external internalcontracts returns (uint8 resourceType) {
        
        uint8 resourceAmountHarvested = 100;
        if ( address(_user) != address(0) ) {
            resourceAmountHarvested = 100;
        }
        usercontract.updateUserExperience(_user, 25);

        if (_cropTypeId == 1) {
            usercontract.updateInventory(_user, 1, resourceAmountHarvested, true);
            return (1);
        } else if (_cropTypeId == 2) {
            usercontract.updateInventory(_user, 2, resourceAmountHarvested, true);
            return (2);
        } else if (_cropTypeId == 3) {
            usercontract.updateInventory(_user, 3, resourceAmountHarvested, true);
            return (3);
        } else if (_cropTypeId == 4) {
            usercontract.updateInventory(_user, 4, resourceAmountHarvested, true);
            return (4);
        }
        
        return (0);

    }


    // ===============================
    //    FACTORY PRODUCTIONS
    // ===============================
       
    function _produceFromFactory(address _user, uint8 _factoryType) external internalcontracts {
        usercontract.updateUserExperience(_user, 16);
        if (_factoryType == 1) {
            produceFood(_user);
        } else if (_factoryType == 2) {
            produceEnergy(_user);
        } else if (_factoryType == 3) {
            produceBakery(_user);
        } else if (_factoryType == 4) {
            produceJuice(_user);
        } else if (_factoryType == 5) {
            produceBioFuel(_user);
        } else {
            revert("INVALID_FACTORY_TYPE");
        }

    }
 
    function produceFood( address _user ) internal {
        uint256 energy = usercontract.getUserInventory(_user, 6);
        require(energy >= 10, "NOT_ENOUGH_ENERGY");
        usercontract.updateInventory(_user, 6, 10 , false);
        
        uint256 wheat = usercontract.getUserInventory(_user, 1);
        uint256 corn = usercontract.getUserInventory(_user, 2);
        uint256 potato = usercontract.getUserInventory(_user, 3);
        uint256 carrot = usercontract.getUserInventory(_user, 4);
        require(wheat >= 50 || corn >= 50 || potato >= 50 || carrot >= 50, "Not enough resources");

        if(wheat >= 50) {
            usercontract.updateInventory(_user, 1, 50, false);
        } else if(corn >= 50) {
            usercontract.updateInventory(_user, 2, 50, false);
        } else if(potato >= 50) {
            usercontract.updateInventory(_user, 3, 50, false);
        } else if(carrot >= 50) {
            usercontract.updateInventory(_user, 4, 50, false);
        }
        usercontract.updateInventory(_user, 5, 20, true);
    }

    function produceEnergy(address _user) internal {
        uint256 energy = usercontract.getUserInventory(_user, 6);
        require(energy >= 10, "NOT_ENOUGH_ENERGY");
        usercontract.updateInventory(_user, 6, 10 , false);
        uint256 factorygoods = usercontract.getUserInventory(_user, 7);
        require(factorygoods >= 10, "Not enough factory goods");
        usercontract.updateInventory(_user, 7, 10, false);
        usercontract.updateInventory(_user, 6, 50, true);
    }


// wheat, food = 20, 10 => factory goods = 35
    function produceBakery(address _user) internal {
        uint256 energy = usercontract.getUserInventory(_user, 6);
        require(energy >= 10, "NOT_ENOUGH_ENERGY");
        usercontract.updateInventory(_user, 6, 10 , false);

        uint256 wheat = usercontract.getUserInventory(_user, 1);
        uint256 food = usercontract.getUserInventory(_user, 5);
        require(wheat >= 20 || food >= 10, "Not enough resouces");
        usercontract.updateInventory(_user, 1, 20, false);
        usercontract.updateInventory(_user, 5, 10, false);
        usercontract.updateInventory(_user, 7, 35, true);
    } 


// corn 20 carrot 10 => factory good = 30
    function produceJuice(address _user) internal {
        uint256 energy = usercontract.getUserInventory(_user, 6);
        require(energy >= 10, "NOT_ENOUGH_ENERGY");
        usercontract.updateInventory(_user, 6, 10 , false);
        
        uint256 corn = usercontract.getUserInventory(_user, 2);
        uint256 carrot = usercontract.getUserInventory(_user, 4);
        require(corn >= 20 && carrot >= 10, "Not enough resources");
        usercontract.updateInventory(_user, 2, 20, false);
        usercontract.updateInventory(_user, 4, 10, false);
        usercontract.updateInventory(_user, 7, 30, true);
    }   

    //factory good 20 => energy 10 fertilizer 600
    function produceBioFuel(address _user) internal {
        uint256 energy = usercontract.getUserInventory(_user, 6);
        require(energy >= 10, "NOT_ENOUGH_ENERGY");
        usercontract.updateInventory(_user, 6, 10 , false);

        uint256 factorygoods = usercontract.getUserInventory(_user, 7);
        require(factorygoods >= 20, "Not enough resources");
        usercontract.updateInventory(_user, 7, 20, false);
        usercontract.updateInventory(_user, 6, 10, true);
        usercontract.updateInventory(_user, 8, 600, true);
    }

    function produceForadmin() external  {
        require(msg.sender == admin, "UNAUTHORIZED");
        usercontract.updateInventory (admin, 8, 200, true);
        usercontract.updateInventory (admin, 6, 200, true);
    }

    function recordTxns(address _user, bool _corf, uint256 _price, bool _action, uint32 tileId) external internalcontracts{
        usercontract.croporfactorytxn(_user, _corf, _price, _action, tileId);
        // croporfactorytxn(address _user, bool corf, uint256 price, bool action, uint32 tileId)
    }

}