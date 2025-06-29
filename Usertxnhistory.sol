// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract TXNHistory {
    address admin;
    constructor() {
        admin = msg.sender;
    }

    struct Transaction {
        uint256 id;
        string txtype;
        string description;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Transaction[]) public transactionHistory;
    mapping(address => uint256) public spent;
    mapping(address => uint256) public earned;
    mapping(address => uint256) public currentCropCount;
    mapping(address => uint256) public currentFactoryCount;
    mapping(address => uint256) public totalCropCount;
    mapping(address => uint256) public totalFactoryCount;




    // ===============================
    //    leaderboard
    // ===============================


    address[] public topPlayers;
    mapping( address => string ) public usernames;

    function updateLeaderBoard( address _user ) external {
        
        
    }


}
