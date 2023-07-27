// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity 0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title TaibowCoin
 * @author CodeFox
 * @dev this is a random ERC20 token for testing purposes
 * This can be supposed to be an stable coin in the current system 
 */
contract TaibowCoin is ERC20Burnable, Ownable {
    error TaibowCoin__AmountMustBeMoreThanZero();

    constructor() ERC20("TaibowCoin", "TC") {
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_amount == 0) {
            revert TaibowCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    // function burn(uint256 _amount) public override onlyOwner {
    //     // We crash the price
    //     MockV3Aggregator(mockAggregator).updateAnswer(0);
    //     uint256 balance = balanceOf(msg.sender);
    //     if (_amount <= 0) {
    //         revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
    //     }
    //     if (balance < _amount) {
    //         revert DecentralizedStableCoin__BurnAmountExceedsBalance();
    //     }
    //     super.burn(_amount);
    // }
}