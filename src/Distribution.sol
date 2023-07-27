// SPDX-License-Identifier: MIT

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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JpycDistribution {
    address public constant FACTORY_ADDRESS = 0x2370f9d504c7a6E775bf6E14B3F12846b594cD53; // TODO: change after deployment
    address public constant JPYC_V2_ADDRESS = 0x431D5dfF03120AFA4bDf332c61A6e1766eF37BDB; // Polygon
    address public constant JPYC_V1_ADDRESS = 0x2370f9d504c7a6E775bf6E14B3F12846b594cD53; // Polygon
    address public constant STUDIUM_ADDRESS = 0x431D5dfF03120AFA4bDf332c61A6e1766eF37BDB; // TODO: change before launch
    uint256 public constant COMMITION_FEE = 5; // 5%

    event Distributed(address token, address[] winners, uint256[] percentages);

    modifier onlyFactory() {
        require(msg.sender == FACTORY_ADDRESS);
        _;
    }

    /* @dev Distribute JPYC to winners
    *  @notice Only factory can call this
    *  @notice percentages sum must be 95 = (100 - COMMITION_FEE)
    *  @param _owner The owner of the contest
    *  @param token The token address to distribute
    *  @param winners The addresses of winners
    *  @param percentages The percentages of winners
    */
    function distribute(address token, address[] memory winners, uint256[] memory percentages) public onlyFactory {
        require(token == JPYC_V1_ADDRESS || token == JPYC_V2_ADDRESS, "Invalid token address");
        require(winners.length == percentages.length, "Mismatched winners and percentages arrays");
        _distribute(token, winners, percentages);
        emit Distributed(token, winners, percentages);
    }

    function _distribute(address token, address[] memory winners, uint256[] memory percentages) internal {
        IERC20 erc20 = IERC20(token);
        uint256 totalAmount = erc20.balanceOf(address(this));
        _commissionTransfer(erc20, totalAmount);

        for (uint256 i; i < winners.length;) {
            uint256 amount = totalAmount * percentages[i] / 100;
            require(erc20.transfer(winners[i], amount), "Failed to transfer tokens");
            unchecked {
                ++i;
            }
        }
    }

    function _commissionTransfer(IERC20 token, uint256 totalAmount) internal {
        uint256 amount = totalAmount * COMMITION_FEE / 100;
        require(token.transfer(STUDIUM_ADDRESS, amount), "Failed to transfer tokens");
    }
}
