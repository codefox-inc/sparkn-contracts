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

/* 
* */
contract ProxyFactory is Ownable {
    // contest distribution expiration
    uint256 public constant EXPIRATION_TIME = 7 days;

    // record contest close time by salt
    // The contest doesn't exist when the value is 0
    mapping(bytes32 => uint256) public closeTime;

    /* @dev Set contest close time
     * @param organizer The owner of the contest
     * @param contestId The contest id
     * @param _closeTime The contest close time
    */
    function setContest(address organizer, bytes32 contestId, uint256 _closeTime) public onlyOwner {
        bytes32 salt = _calculateSalt(organizer, contestId);
        require(closeTime[salt] == 0, "Contest is already registered");
        closeTime[salt] = _closeTime;
    }

    function deployProxyAndDsitribute(address implementation, bytes32 contestId, bytes calldata data) public {
        bytes32 salt = _calculateSalt(msg.sender, contestId);
        require(closeTime[salt] == 0, "Contest is not registered");
        require(closeTime[salt] < block.timestamp, "Contest is not closed");
        address proxy = _deployProxy(implementation, msg.sender, contestId);
        _distribute(proxy, data);
    }

    function deployProxyAndDsitributeBySignature(
        address implementation,
        address organizer,
        bytes32 contestId,
        bytes calldata signature,
        bytes calldata data
    ) public {
        bytes32 salt = _calculateSalt(organizer, contestId);
        _signatureCheck(organizer, contestId, closeTime[salt], signature);
        address proxy = _deployProxy(implementation, organizer, contestId);
        _distribute(proxy, data);
    }

    function dsitributeBySignature(
        address proxy,
        address organizer,
        bytes32 contestId,
        bytes calldata signature,
        bytes calldata data
    ) public {
        bytes32 salt = _calculateSalt(organizer, contestId);
        _signatureCheck(organizer, contestId, closeTime[salt], signature);

        _distribute(proxy, data);
    }

    // contestIdにはDB上のcontest_idのハッシュ値、dataには賞金分配情報が入る。
    function _deployProxy(address implementation, address organizer, bytes32 contestId) internal returns (address) {
        bytes32 salt = _calculateSalt(organizer, contestId);

        address proxy = address(new Proxy{salt: salt}(implementation));
        return proxy;
    }

    function _distribute(address proxy, bytes calldata data) internal {
        // 分配処理を行う
        (bool success,) = proxy.call(data);
        require(success, "Failed to execute delegate call in the Proxy contract");
    }

    function _signatureCheck(address organizer, bytes32 contestId, uint256 closeTime_, bytes calldata signature)
        internal
        view
        returns (bool)
    {
        require(closeTime_ != 0, "Contest is not registered");
        require(closeTime_ < block.timestamp + EXPIRATION_TIME, "Contest is not closed");
        bytes32 hash = keccak256(abi.encodePacked(organizer, contestId, closeTime_, signature));
        return ECDSA.recover(hash, signature) == organizer;
    }

    // コンテストIDと主催者のアドレスを用いてソルトを生成
    function _calculateSalt(address organizer, bytes32 contestId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(organizer, contestId));
    }
}
