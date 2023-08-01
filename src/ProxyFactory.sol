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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./Proxy.sol";

/**
 * @notice This contract is the factory contract which will be used to deploy proxy contracts.
 * @notice It will be used to deploy proxy contracts for every contest in Taibow Stadium.
 * @dev
 */
contract ProxyFactory is Ownable {
    //////////////////////
    /////// Error ////////
    //////////////////////
    error ProxyFactory__NoZeroAddress();
    error ProxyFactory__CloseTimeNotInRange();
    error ProxyFactory__InvalidSignature();
    error ProxyFactory__ContestIsAlreadyRegistered();
    error ProxyFactory__ContestIsNotClosed();
    error ProxyFactory__ContestIsNotRegistered();
    error ProxyFactory__ContestIsNotExpired();
    error ProxyFactory__DelegateCallFailed();
    error ProxyFactory__ProxyAddressCannotBeZero();

    ////////////////////////////////
    /////// State Variables ////////
    ////////////////////////////////
    // contest distribution expiration
    uint256 public constant EXPIRATION_TIME = 7 days;
    uint256 public constant MAX_CONTEST_PERIOD = 28 days;
    uint256 public constant MIN_CONTEST_PERIOD = 1 days;

    /// @notice record contest close time by salt
    /// @notice The contest doesn't exist when value is 0
    mapping(bytes32 => uint256) public saltToCloseTime;
    /// @notice record implementation by salt
    /// @notice The implementation is not allowed when value is 0
    mapping(bytes32 => address) public saltToImplementation;

    ////////////////////////////////////////////
    /////// External & Public functions ////////
    ////////////////////////////////////////////
    /**
     * @notice Only owner can set contest's properties
     * @notice close time must be less than 14 days from now
     * @dev Set contest close time, implementation address, organizer, contest id
     * @dev only owner can call this function
     * @param organizer The owner of the contest
     * @param contestId The contest id
     * @param _closeTime The contest close time
     */
    function setContest(address organizer, bytes32 contestId, uint256 _closeTime, address implementation)
        public
        onlyOwner
    {
        if (organizer == address(0) || implementation == address(0)) revert ProxyFactory__NoZeroAddress();
        if (_closeTime > block.timestamp + MAX_CONTEST_PERIOD || _closeTime < block.timestamp + MIN_CONTEST_PERIOD) {
            revert ProxyFactory__CloseTimeNotInRange();
        }
        bytes32 salt = _calculateSalt(organizer, contestId);
        if (saltToCloseTime[salt] != 0) revert ProxyFactory__ContestIsAlreadyRegistered();
        saltToImplementation[salt] = implementation;
        saltToCloseTime[salt] = _closeTime;
    }

    /** 
    * @notice deploy proxy contract and distribute caller's prize
    * @dev the caller can only control his own contest
    * @param contestId The contest id
    * @param data The prize distribution data
    */
    function deployProxyAndDsitribute(bytes32 contestId, bytes calldata data) public {
        bytes32 salt = _calculateSalt(msg.sender, contestId);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= block.timestamp) revert ProxyFactory__ContestIsNotClosed();
        address proxy = _deployProxy(msg.sender, contestId);
        _distribute(proxy, data); // @audit how about creating data here?
    }

    /** 
    * @notice deploy proxy contract and distribute prize on behalf of organizer
    * @dev the caller can only control his own contest
    * @param organizer The organizer of the contest
    * @param contestId The contest id
    * @param signature The signature from organizer
    * @param data The prize distribution data
    */
    function deployProxyAndDistributeBySignature( // @audit replay attack?? -> EIP712追加
    address organizer, bytes32 contestId, bytes calldata signature, bytes calldata data)
        public
    {
        bytes32 hash = keccak256(abi.encode(contestId, data));
        if (ECDSA.recover(hash, signature) != organizer) revert ProxyFactory__InvalidSignature();
        bytes32 salt = _calculateSalt(msg.sender, contestId);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= block.timestamp) revert ProxyFactory__ContestIsNotClosed();
        address proxy = _deployProxy(organizer, contestId);
        _distribute(proxy, data);
    }

    function deployProxyAndDsitributeByOwner(address organizer, bytes32 contestId, bytes calldata data)
        public
        onlyOwner
    {
        bytes32 salt = _calculateSalt(organizer, contestId);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= (block.timestamp + EXPIRATION_TIME)) revert ProxyFactory__ContestIsNotExpired();
        // require(saltToCloseTime[salt] == 0, "Contest is not registered");
        // require(saltToCloseTime[salt] < block.timestamp + EXPIRATION_TIME, "Contest is not expired");
        address proxy = _deployProxy(organizer, contestId);
        _distribute(proxy, data);
    }

    function dsitributeByOwner(address proxy, address organizer, bytes32 contestId, bytes calldata data)
        public
        onlyOwner
    {
        if (proxy == address(0)) revert ProxyFactory__ProxyAddressCannotBeZero();
        // require(proxy != address(0), "Proxy address is zero");
        bytes32 salt = _calculateSalt(organizer, contestId);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= (block.timestamp + EXPIRATION_TIME)) revert ProxyFactory__ContestIsNotExpired();
        _distribute(proxy, data);
    }

    // contestIdにはDB上のcontest_idのハッシュ値、dataには賞金分配情報が入る。
    function _deployProxy(address organizer, bytes32 contestId) internal returns (address) {
        bytes32 salt = _calculateSalt(organizer, contestId);
        address implementation = saltToImplementation[salt];
        address proxy = address(new Proxy{salt: salt}(implementation));
        return proxy;
    }

    /// @dev The function to be used to call proxy to distribute prizes to the winners
    function _distribute(address proxy, bytes calldata data) internal {
        (bool success,) = proxy.call(data);
        if (!success) revert ProxyFactory__DelegateCallFailed();
    }

    // @dev Calculate salt using contest organizer address and contestId
    function _calculateSalt(address organizer, bytes32 contestId) internal pure returns (bytes32) {
        return keccak256(abi.encode(organizer, contestId));
    }
}
