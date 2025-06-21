// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GameToken is ERC20{
    constructor() ERC20("GameToken", "GTA"){
        _mint(msg.sender,1000000000000000*10**18);
    }
}
