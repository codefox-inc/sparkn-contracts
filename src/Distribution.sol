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

/*
* @dev This contract is used as the implementation of proxy contracts to distribute ERC20 token(JPYC) to winners
*/
contract JpycDistribution {
    //////////////////////
    /////// Error ////////
    //////////////////////
    error JpycDistribution__InvalidTokenAddress();
    error JpycDistribution__MismatchedArrays();
    error JpycDistribution__FailedToTransfer();


    //////////////////////////////////
    /////// State Variables //////////
    //////////////////////////////////
    address private immutable FACTORY_ADDRESS;
    address private immutable STUDIUM_ADDRESS;
    address private constant JPYC_V2_ADDRESS = 0x431D5dfF03120AFA4bDf332c61A6e1766eF37BDB; // This is on Polygon
    address private constant JPYC_V1_ADDRESS = 0x2370f9d504c7a6E775bf6E14B3F12846b594cD53; // This is on Polygon
    uint256 private constant COMMITION_FEE = 5; // 5% this can be changed in the future

    event Distributed(address token, address[] winners, uint256[] percentages);

    ///////////////////////////
    /////// Modifier //////////
    ///////////////////////////
    /* 
    * @dev Makes only factory contract can call it
    */
    modifier onlyFactory() {
        require(msg.sender == FACTORY_ADDRESS);
        _;
    }

    ////////////////////////////
    /////// Constructor ////////
    ////////////////////////////
    constructor(address factory_address, address stadium_address) {
        FACTORY_ADDRESS = factory_address; // initialize with deployed factory address beforehand
        STUDIUM_ADDRESS = stadium_address;
    }

    ////////////////////////////////////////////
    /////// External & Public functions ////////
    ////////////////////////////////////////////
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

    ////////////////////////////////////////////
    /////// Internal & Private functions ///////
    ////////////////////////////////////////////
    /* @dev A internal function to distribute JPYC to winners
    *  @notice Main logic of distribution is implemented here
    */
    function _distribute(address token, address[] memory winners, uint256[] memory percentages) internal { // @audit unbounded loop here
        IERC20 erc20 = IERC20(token);
        uint256 totalAmount = erc20.balanceOf(address(this));
        _commissionTransfer(erc20, totalAmount); // @audit ピッタリになれるか確認、または、分配後に残りがあればSTADIUM_ADDRESSに送る?

        for (uint256 i; i < winners.length;) {
            uint256 amount = totalAmount * percentages[i] / 100;
            require(erc20.transfer(winners[i], amount), "Failed to transfer tokens"); // @audit must use safeTransfer here
            unchecked {
                ++i;
            }
        }
    }

    /*
    * @notice Transfer commission fee to STUDIUM_ADDRESS
    */
    function _commissionTransfer(IERC20 token, uint256 totalAmount) internal {
        uint256 amount = totalAmount * COMMITION_FEE / 100;
        require(token.transfer(STUDIUM_ADDRESS, amount), "Failed to transfer tokens");
    }

    ///////////////////////////////////////////
    /////// Getter pure/view functions ////////
    ///////////////////////////////////////////
    /*
    * @notice returns all the immutable and constant addresses and value
    */
    function getConstants()
        external
        view
        returns (
            address _FACTORY_ADDRESS,
            address _STUDIUM_ADDRESS,
            address _JPYC_V1_ADDRESS,
            address _JPYC_V2_ADDRESS,
            uint256 _COMMITION_FEE
        )
    {
        _FACTORY_ADDRESS = FACTORY_ADDRESS;
        _STUDIUM_ADDRESS = STUDIUM_ADDRESS;
        _JPYC_V1_ADDRESS = JPYC_V1_ADDRESS;
        _JPYC_V2_ADDRESS = JPYC_V2_ADDRESS;
        _COMMITION_FEE = COMMITION_FEE;
    }
}
