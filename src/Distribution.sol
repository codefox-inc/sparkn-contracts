// SPDX-License-Identifier: BUSL-1.1

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
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
* @notice General ERC20 stable coin tokens, e.g. JPYC, USDC, USDT, DAI, etc, are suppsoed to be used in Taibow.
* @dev This contract is used as the implementation of proxy contracts to distribute ERC20 token(e.g. JPYC) to winners
* @dev If we want to upgrade the implementation contract we can deploy a new one and change the implementation address of proxy contract.
*/
contract Distributor {
    using SafeERC20 for IERC20;
    //////////////////////
    /////// Error ////////
    //////////////////////

    error JpycDistribution__InvalidCommissionFee();
    error JpycDistribution__NoZeroAddress();
    error JpycDistribution__OnlyFactoryAddressIsAllowed();
    error JpycDistribution__InvalidTokenAddress();
    error JpycDistribution__MismatchedArrays();
    error JpycDistribution__FailedToTransfer();
    error JpycDistribution__MismatchedPercentages();

    //////////////////////////////////
    /////// State Variables //////////
    //////////////////////////////////
    address private immutable FACTORY_ADDRESS;
    address private immutable STUDIUM_ADDRESS;
    address private immutable JPYC_V2_ADDRESS;
    // mapping (address => bool) private whitelistedTokens; // @audit 
    address private immutable JPYC_V1_ADDRESS;
    uint256 private immutable COMMISSION_FEE; // uses basis point 10000 = 100%

    event Distributed(address token, address[] winners, uint256[] percentages);

    ////////////////////////////
    /////// Constructor ////////
    ////////////////////////////
    /// @dev initiate the contract with factory address and other key addresses, fee rate
    constructor(
        address factory_address,
        address stadium_address,
        address jpyc_v1_address,
        address jpyc_v2_address,
        uint256 commission_fee
    ) {
        if (commission_fee > 1000) revert JpycDistribution__InvalidCommissionFee(); // more than 10%
        if (factory_address == address(0) || stadium_address == address(0)) revert JpycDistribution__NoZeroAddress();
        if (jpyc_v1_address == address(0) && jpyc_v2_address == address(0)) revert JpycDistribution__NoZeroAddress();
        FACTORY_ADDRESS = factory_address; // initialize with deployed factory address beforehand
        STUDIUM_ADDRESS = stadium_address;
        JPYC_V1_ADDRESS = jpyc_v1_address; // 0x2370f9d504c7a6E775bf6E14B3F12846b594cD53 polygon
        JPYC_V2_ADDRESS = jpyc_v2_address; // 0x431D5dfF03120AFA4bDf332c61A6e1766eF37BDB polygon
        COMMISSION_FEE = commission_fee; // 5% this can be changed in the future
    }

    ////////////////////////////////////////////
    /////// External & Public functions ////////
    ////////////////////////////////////////////
    /**
     * @notice Distribute token to winners
     * @dev Only factory contract can call this function
     * @dev percentages sum must be correct. It must be (100 - COMMITION_FEE)
     * @param token The token address to distribute
     * @param winners The addresses of winners
     * @param percentages The percentages of winners
     */
    function distribute(address token, address[] memory winners, uint256[] memory percentages) external {
        if (msg.sender != FACTORY_ADDRESS) {
            revert JpycDistribution__OnlyFactoryAddressIsAllowed();
        }
        _distribute(token, winners, percentages);
        emit Distributed(token, winners, percentages);
    }

    ////////////////////////////////////////////
    /////// Internal & Private functions ///////
    ////////////////////////////////////////////
    /**
     * @notice Main logic of distribution is implemented here
     * @dev A internal function to distribute JPYC to winners
     * @dev The length of winners and percentages must be the same
     * @dev The token address must be either JPYC_V1_ADDRESS or JPYC_V2_ADDRESS
     * @dev The winners and percentages array are supposed not to be so long, so the loop can stay unbounded
     * @param token The token address
     * @param winners The addresses of winners
     * @param percentages The percentages of winners
     */
    function _distribute(address token, address[] memory winners, uint256[] memory percentages) internal {
        // token address input check
        if (token == address(0) || token != JPYC_V1_ADDRESS || token != JPYC_V2_ADDRESS) {
            revert JpycDistribution__InvalidTokenAddress();
        }
        if (winners.length != percentages.length) revert JpycDistribution__MismatchedArrays();
        uint256 percentagesLength = percentages.length;
        uint256 totalPercentage;
        for (uint256 i; i < percentagesLength;) {
            totalPercentage += percentages[i];
            unchecked {
                ++i;
            }
        }
        // check if totalPercentage is correct
        if (totalPercentage != (10000 - COMMISSION_FEE)) {
            revert JpycDistribution__MismatchedPercentages();
        }
        IERC20 erc20 = IERC20(token);
        uint256 totalAmount = erc20.balanceOf(address(this));
        uint256 winnersLength = winners.length; // cache length
        for (uint256 i; i < winnersLength;) {
            uint256 amount = totalAmount * percentages[i] / 10000;
            erc20.safeTransfer(winners[i], amount);
            unchecked {
                ++i;
            }
        }
        // send all the remaining tokens to STADIUM_ADDRESS to avoid dust remained in the proxy contract
        _commissionTransfer(erc20);
    }

    /*
    * @notice Transfer commission fee to STUDIUM_ADDRESS
    */
    function _commissionTransfer(IERC20 token) internal {
        token.safeTransfer(STUDIUM_ADDRESS, token.balanceOf(address(this)));
    }

    ///////////////////////////////////////////
    /////// Getter pure/view functions ////////
    ///////////////////////////////////////////
    /**
     * @notice returns all the immutable and constant addresses and values
     */
    function getConstants()
        external
        view
        returns (
            address _FACTORY_ADDRESS,
            address _STUDIUM_ADDRESS,
            address _JPYC_V1_ADDRESS,
            address _JPYC_V2_ADDRESS,
            uint256 _COMMISSION_FEE
        )
    {
        _FACTORY_ADDRESS = FACTORY_ADDRESS;
        _STUDIUM_ADDRESS = STUDIUM_ADDRESS;
        _JPYC_V1_ADDRESS = JPYC_V1_ADDRESS;
        _JPYC_V2_ADDRESS = JPYC_V2_ADDRESS;
        _COMMISSION_FEE = COMMISSION_FEE;
    }
}
