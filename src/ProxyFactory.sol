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
    error CloseTimeTooFarAway();
    error InvalidSignature();
    error ContestIsAlreadyRegistered();
    error ContestIsNotClosed();
    error ContestIsNotRegistered();
    error ContestIsNotExpired();
    error DelegateCallFailed();
    error ProxyAddressCannotBeZero();

    // contest distribution expiration
    uint256 public constant EXPIRATION_TIME = 7 days;
    uint256 public constant MAX_CONTEST_PERIOD = 28 days;

    /// @notice record contest close time by salt
    /// @notice The contest doesn't exist when value is 0
    mapping(bytes32 => uint256) public saltTocloseTime; 
    mapping(bytes32 => address) public saltToImplementation;

    /**
     * @dev Set contest close time
     * @notice close time must be less than 14 days from now
     * @param organizer The owner of the contest
     * @param contestId The contest id
     * @param _closeTime The contest close time
     */
    function setContest(address organizer, bytes32 contestId, uint256 _closeTime, address implementation)
        public
        onlyOwner
    {
        if (_closeTime > block.timestamp + MAX_CONTEST_PERIOD) revert CloseTimeTooFarAway();
        bytes32 salt = _calculateSalt(organizer, contestId);
        saltToImplementation[salt] = implementation;
        if (saltTocloseTime[salt] != 0) revert ContestIsAlreadyRegistered();
        saltTocloseTime[salt] = _closeTime;
    }

    function deployProxyAndDsitribute(bytes32 contestId, bytes calldata data) public {
        bytes32 salt = _calculateSalt(msg.sender, contestId);
        if (saltTocloseTime[salt] == 0) revert ContestIsNotRegistered();
        if (saltTocloseTime[salt] >= block.timestamp) revert ContestIsNotClosed();
        address proxy = _deployProxy(msg.sender, contestId);
        _distribute(proxy, data);
    }

    function deployProxyAndDistributeBySignature( // @audit replay attack?? -> EIP712追加
        address organizer,
        bytes32 contestId,
        bytes calldata signature,
        bytes calldata data
    ) public {
        bytes32 hash = keccak256(abi.encode(contestId, data)); 
        if (ECDSA.recover(hash, signature) != organizer) revert InvalidSignature();
        bytes32 salt = _calculateSalt(msg.sender, contestId);
        if (saltTocloseTime[salt] == 0) revert ContestIsNotRegistered();
        if (saltTocloseTime[salt] >= block.timestamp) revert ContestIsNotClosed();
        address proxy = _deployProxy(organizer, contestId);
        _distribute(proxy, data);
    }

    function deployProxyAndDsitributeByOwner(address organizer, bytes32 contestId, bytes calldata data)
        public
        onlyOwner
    {
        bytes32 salt = _calculateSalt(organizer, contestId);
        if (saltTocloseTime[salt] == 0) revert ContestIsNotRegistered();
        if (saltTocloseTime[salt] >= (block.timestamp + EXPIRATION_TIME)) revert ContestIsNotExpired();
        // require(saltTocloseTime[salt] == 0, "Contest is not registered");
        // require(saltTocloseTime[salt] < block.timestamp + EXPIRATION_TIME, "Contest is not expired");
        address proxy = _deployProxy(organizer, contestId);
        _distribute(proxy, data);
    }

    function dsitributeByOwner(address proxy, address organizer, bytes32 contestId, bytes calldata data)
        public
        onlyOwner
    {
        if (proxy == address(0)) revert ProxyAddressCannotBeZero();
        // require(proxy != address(0), "Proxy address is zero");
        bytes32 salt = _calculateSalt(organizer, contestId);
        if (saltTocloseTime[salt] == 0) revert ContestIsNotRegistered();
        if (saltTocloseTime[salt] >= (block.timestamp + EXPIRATION_TIME)) revert ContestIsNotExpired();
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
        if (!success) revert DelegateCallFailed();
    }

    // @dev Calculate salt using contest organizer address and contestId
    function _calculateSalt(address organizer, bytes32 contestId) internal pure returns (bytes32) {
        return keccak256(abi.encode(organizer, contestId));
    }
}
