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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./Proxy.sol";

/**
 * @notice This contract is the factory contract which will be used to deploy proxy contracts.
 * @notice It will be used to deploy proxy contracts for every contest in Taibow Stadium.
 */
contract ProxyFactory is Ownable {
    // contest distribution expiration
    uint256 public constant EXPIRATION_TIME = 7 days;
    uint256 public constant MAX_CONTEST_PERIOD = 28 days;

    /// @notice record contest close time by salt
    /// @notice The contest doesn't exist when value is 0
    mapping(bytes32 => uint256) public closeTime;
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
        require(_closeTime < block.timestamp + MAX_CONTEST_PERIOD, "Close time is zero");
        bytes32 salt = _calculateSalt(organizer, contestId);
        saltToImplementation[salt] = implementation;
        require(closeTime[salt] == 0, "Contest is already registered");
        closeTime[salt] = _closeTime;
    }

    function deployProxyAndDsitribute(bytes32 contestId, bytes calldata data) public {
        bytes32 salt = _calculateSalt(msg.sender, contestId);
        require(closeTime[salt] == 0, "Contest is not registered");
        require(closeTime[salt] < block.timestamp, "Contest is not closed");
        address proxy = _deployProxy(msg.sender, contestId);
        _distribute(proxy, data);
    }

    function deployProxyAndDistributeBySignature(
        address organizer,
        bytes32 contestId,
        bytes calldata signature,
        bytes calldata data
    ) public {
        bytes32 hash = keccak256(abi.encode(contestId, data));
        require(ECDSA.recover(hash, signature) == organizer, "Invalid signature");
        bytes32 salt = _calculateSalt(msg.sender, contestId);
        require(closeTime[salt] == 0, "Contest is not registered");
        require(closeTime[salt] < block.timestamp, "Contest is not closed");
        address proxy = _deployProxy(organizer, contestId);
        _distribute(proxy, data);
    }

    function deployProxyAndDsitributeByOwner(address organizer, bytes32 contestId, bytes calldata data)
        public
        onlyOwner
    {
        bytes32 salt = _calculateSalt(organizer, contestId);
        require(closeTime[salt] == 0, "Contest is not registered");
        require(closeTime[salt] < block.timestamp + EXPIRATION_TIME, "Contest is not expired");
        address proxy = _deployProxy(organizer, contestId);
        _distribute(proxy, data);
    }

    function dsitributeByOwner(address proxy, address organizer, bytes32 contestId, bytes calldata data)
        public
        onlyOwner
    {
        require(proxy != address(0), "Proxy address is zero");
        bytes32 salt = _calculateSalt(organizer, contestId);
        require(closeTime[salt] == 0, "Contest is not registered");
        require(closeTime[salt] < block.timestamp + EXPIRATION_TIME, "Contest is not expired");
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
        require(success, "Failed to execute delegate call in the Proxy contract");
    }

    // @dev Calculate salt using contest organizer address and contestId
    function _calculateSalt(address organizer, bytes32 contestId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(organizer, contestId));
    }
}
