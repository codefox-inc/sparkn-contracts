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

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ProxyFactory} from "./ProxyFactory.sol";

/**
 * @title Distributor contract
 * @notice General ERC20 stable coin tokens, e.g. JPYC, USDC, USDT, DAI, etc, are suppsoed to be used in SPARKN.
 * @notice This contract is used as the implementation of proxy contracts to distribute ERC20 token(e.g. JPYC) to winners
 * @dev The main logic of prize token distribution sits in this contract waiting to be called by factory contract
 * @dev Although the contract is immutable after deployment, If we want to upgrade the implementation contract
 * we can deploy a new one and change the implementation address of proxy contract.
 */
contract Distributor {
    using SafeERC20 for IERC20;
    //////////////////////
    /////// Error ////////
    //////////////////////

    error Distributor__NoZeroAddress();
    error Distributor__OnlyFactoryAddressIsAllowed();
    error Distributor__InvalidTokenAddress();
    error Distributor__MismatchedArrays();
    error Distributor__MismatchedPercentages();
    error Distributor__NoTokenToDistribute();

    //////////////////////////////////////
    /////// Immutable Variables //////////
    //////////////////////////////////////
    /* solhint-disable */
    uint8 private constant VERSION = 1; // version is 1 for now
    address private immutable FACTORY_ADDRESS;
    uint256 private constant COMMISSION_FEE = 500; // this can be changed in the future
    // a constant value of 10,000 (basis points) = 100%
    uint256 private constant BASIS_POINTS = 10_000;

    // prize distribution event. data is for logging purpose
    event Distributed(address token, address[] winners, uint256[] percentages, bytes data);

    ////////////////////////////
    /////// Constructor ////////
    ////////////////////////////
    /// @dev initiate the contract with factory address and other key addresses, fee rate
    constructor(
        // uint256 version, // for future use
        address factoryAddress
    ) 
    /* solhint-enable */
    {
        if (factoryAddress == address(0)) revert Distributor__NoZeroAddress();
        FACTORY_ADDRESS = factoryAddress; // initialize with deployed factory address beforehand
    }

    ////////////////////////////////////////////
    /////// External & Public functions ////////
    ////////////////////////////////////////////
    /**
     * @notice Distribute token to winners according to the percentages
     * @dev Only factory contract can call this function
     * @param token The token address to distribute
     * @param winners The addresses array of winners
     * @param percentages The percentages array of winners
     */
    function distribute(address token, address[] calldata winners, uint256[] calldata percentages, bytes calldata data)
        external
    {
        if (msg.sender != FACTORY_ADDRESS) {
            revert Distributor__OnlyFactoryAddressIsAllowed();
        }
        _distribute(token, winners, percentages, data);
    }

    ////////////////////////////////////////////
    /////// Internal & Private functions ///////
    ////////////////////////////////////////////
    /**
     * @notice An internal function to distribute JPYC to winners
     * @dev Main logic of distribution is implemented here. The length of winners and percentages must be the same
     * The token address must be one of the whitelisted tokens
     * The winners and percentages array are supposed not to be so long, so the loop can stay unbounded
     * The total percentage must be correct. It must be (100 - COMMITION_FEE).
     * Finally send the remained token(fee) to proxyFactory's stadiumAddress with no dust in the contract
     * @param token The token address
     * @param winners The addresses of winners
     * @param percentages The percentages of winners
     * @param data The data to be logged. It is supposed to be used for showing the realation bbetween winners and proposals.
     */
    function _distribute(address token, address[] calldata winners, uint256[] calldata percentages, bytes calldata data)
        internal
    {
        // token address input check
        if (!_isWhiteListed(token)) {
            revert Distributor__InvalidTokenAddress();
        }
        // winners and percentages input check
        uint256 winnersLength = winners.length; // cache length
        if (winners.length == 0 || winnersLength != percentages.length) revert Distributor__MismatchedArrays();

        // prepare for the loop
        IERC20 erc20 = IERC20(token);
        // cashe the total amount of token to distribute
        uint256 totalAmount = erc20.balanceOf(address(this));
        // if there is no token to distribute, then revert
        if (totalAmount == 0) revert Distributor__NoTokenToDistribute();

        // percentages.length is equal to winners length
        uint256 totalPercentage;
        for (uint256 i; i < winnersLength;) {
            uint256 percentage = percentages[i];
            totalPercentage += percentage;
            uint256 amount = totalAmount * percentage / (BASIS_POINTS + COMMISSION_FEE);
            address winner = winners[i];
            if (winner == address(0)) revert Distributor__NoZeroAddress();
            erc20.safeTransfer(winner, amount);
            unchecked {
                ++i;
            }
        }

        // check if totalPercentage is correct
        if (totalPercentage != BASIS_POINTS) {
            revert Distributor__MismatchedPercentages();
        }

        // send commission fee as well as all the remaining tokens to stadiumAddress to avoid dust remaining
        _commissionTransfer(erc20);
        emit Distributed(token, winners, percentages, data);
    }

    /**
     * @notice Transfer commission fee to stadiumAddress
     * @dev This internal function is called after distribution in `_distribute` function
     * @param token The token address
     */
    function _commissionTransfer(IERC20 token) internal {
        token.safeTransfer(getStadiumAddress(), token.balanceOf(address(this)));
    }

    /**
     * @dev Check if the token is whitelisted. calling FACTORY_ADDRESS
     * @param token The token address
     * @return true if the token is whitelisted, vice versa
     */
    function _isWhiteListed(address token) internal view returns (bool) {
        return ProxyFactory(FACTORY_ADDRESS).whitelistedTokens(token);
    }

    ///////////////////////////////////////////
    /////// Getter pure/view functions ////////
    ///////////////////////////////////////////
    /**
     * @notice returns all the immutable and constant addresses and values
     * @dev This function is for convenience to check the addresses and values
     */
    function getConstants()
        external
        view
        returns (address _FACTORY_ADDRESS, address _STADIUM_ADDRESS, uint256 _COMMISSION_FEE, uint8 _VERSION)
    {
        /* solhint-disable */
        _FACTORY_ADDRESS = FACTORY_ADDRESS;
        _STADIUM_ADDRESS = getStadiumAddress();
        _COMMISSION_FEE = COMMISSION_FEE;
        _VERSION = VERSION;
        /* solhint-enable */
    }

    /**
     * @notice returns stadium address from proxy factory
     * @dev This function is for convenience to get the stadium address
     */
    function getStadiumAddress() internal view returns (address) {
        return ProxyFactory(FACTORY_ADDRESS).stadiumAddress();
    }
}
