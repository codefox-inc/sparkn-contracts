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
    error ProxyFactory__NoEmptyArray();
    error ProxyFactory__NoZeroAddress();
    error ProxyFactory__CloseTimeNotInRange();
    error ProxyFactory__InvalidSignature();
    error ProxyFactory__ContestIsAlreadyRegistered();
    error ProxyFactory__ContestIsNotClosed();
    error ProxyFactory__ContestIsNotRegistered();
    error ProxyFactory__ContestIsNotExpired();
    error ProxyFactory__DelegateCallFailed();
    error ProxyFactory__ProxyAddressCannotBeZero();

    /////////////////////
    /////// Event ///////
    /////////////////////
    event SetContest(address indexed organizer, bytes32 indexed contestId, uint256 closeTime, address implementation);

    ////////////////////////////////
    /////// State Variables ////////
    ////////////////////////////////
    // contest distribution expiration
    uint256 public constant EXPIRATION_TIME = 7 days;
    uint256 public constant MAX_CONTEST_PERIOD = 28 days;

    /// @notice record contest close time by salt
    /// @notice The contest doesn't exist when value is 0
    mapping(bytes32 => uint256) public saltToCloseTime;
    /// @notice record the whitelisted tokens
    mapping(address => bool) public whitelistTokens;

    ////////////////////////////////////////////
    /////// External & Public functions ////////
    ////////////////////////////////////////////
    /// @notice The constructor will set the whitelist tokens. e.g. JPYCv1, JPYCv2, USDC, USDT, DAI
    /// @notice the array is not supposed to be so long
    constructor(address[] memory _whitelistTokens) {
        if (_whitelistTokens.length == 0) revert ProxyFactory__NoEmptyArray();
        for (uint256 i; i < _whitelistTokens.length;) {
            if (_whitelistTokens[i] == address(0)) revert ProxyFactory__NoZeroAddress();
            whitelistTokens[_whitelistTokens[i]] = true;
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Only owner can set contest's properties
     * @notice close time must be less than 14 days from now
     * @dev Set contest close time, implementation address, organizer, contest id
     * @dev only owner can call this function
     * @param organizer The owner of the contest
     * @param contestId The contest id
     * @param closeTime The contest close time
     * @param implementation The implementation address
     */
    function setContest(address organizer, bytes32 contestId, uint256 closeTime, address implementation)
        public
        onlyOwner
    {
        if (organizer == address(0) || implementation == address(0)) revert ProxyFactory__NoZeroAddress();
        if (closeTime > block.timestamp + MAX_CONTEST_PERIOD || closeTime < block.timestamp) {
            revert ProxyFactory__CloseTimeNotInRange();
        }
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] != 0) revert ProxyFactory__ContestIsAlreadyRegistered();
        saltToCloseTime[salt] = closeTime;
        emit SetContest(organizer, contestId, closeTime, implementation);
    }

    /**
     * @notice deploy proxy contract and distribute caller's prize
     * @dev the caller can only control his own contest
     * @param contestId The contest id
     * @param implementation The implementation address
     * @param data The prize distribution data
     */
    function deployProxyAndDsitribute(bytes32 contestId, address implementation, bytes calldata data) public {
        bytes32 salt = _calculateSalt(msg.sender, contestId, implementation);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= block.timestamp) revert ProxyFactory__ContestIsNotClosed();
        address proxy = _deployProxy(msg.sender, contestId, implementation);
        _distribute(proxy, data);
    }

    /**
     * @notice deploy proxy contract and distribute prize on behalf of organizer
     * @dev the caller can only control his own contest
     * @param organizer The organizer of the contest
     * @param contestId The contest id
     * @param implementation The implementation address
     * @param signature The signature from organizer
     * @param data The prize distribution data
     */
    function deployProxyAndDistributeBySignature(
    address organizer, bytes32 contestId, address implementation, bytes calldata signature, bytes calldata data)
        public
    {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(contestId, data)));
        if (ECDSA.recover(digest, signature) != organizer) revert ProxyFactory__InvalidSignature();
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= block.timestamp) revert ProxyFactory__ContestIsNotClosed();
        address proxy = _deployProxy(organizer, contestId, implementation);
        _distribute(proxy, data);
    }

    function deployProxyAndDsitributeByOwner(
        address organizer,
        bytes32 contestId,
        address implementation,
        bytes calldata data
    ) public onlyOwner {
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= (block.timestamp + EXPIRATION_TIME)) revert ProxyFactory__ContestIsNotExpired();
        // require(saltToCloseTime[salt] == 0, "Contest is not registered");
        // require(saltToCloseTime[salt] < block.timestamp + EXPIRATION_TIME, "Contest is not expired");
        address proxy = _deployProxy(organizer, contestId, implementation);
        _distribute(proxy, data);
    }

    function dsitributeByOwner(
        address proxy,
        address organizer,
        bytes32 contestId,
        address implementation,
        bytes calldata data
    ) public onlyOwner {
        if (proxy == address(0)) revert ProxyFactory__ProxyAddressCannotBeZero();
        // require(proxy != address(0), "Proxy address is zero");
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        if (saltToCloseTime[salt] >= (block.timestamp + EXPIRATION_TIME)) revert ProxyFactory__ContestIsNotExpired();
        _distribute(proxy, data);
    }

    function getProxyAddress(bytes32 salt, address implementation) public view returns (address proxy) {
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        bytes memory code = abi.encodePacked(type(Proxy).creationCode, uint256(uint160(implementation)));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(code)));
        proxy = address(uint160(uint256(hash)));
    }

    // contestIdにはDB上のcontest_idのハッシュ値、dataには賞金分配情報が入る。
    function _deployProxy(address organizer, bytes32 contestId, address implementation) internal returns (address) {
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        address proxy = address(new Proxy{salt: salt}(implementation));
        return proxy;
    }

    /// @dev The function to be used to call proxy to distribute prizes to the winners
    function _distribute(address proxy, bytes calldata data) internal {
        (bool success,) = proxy.call(data);
        if (!success) revert ProxyFactory__DelegateCallFailed();
    }

    // @dev Calculate salt using contest organizer address and contestId
    function _calculateSalt(address organizer, bytes32 contestId, address implementation)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(organizer, contestId, implementation));
    }
}
