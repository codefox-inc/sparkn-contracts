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

/**
 * @dev This contract is the proxy contract which will be deployed by the factory contract.
 * This contract is based on the OpenZeppelin's Proxy contract.
 * This contract is designed to be with minimal logic in it.
 * @notice This contract is created and paired with every contest in Taibow Stadium.
 * This disposable contract is supposed to be used during the contest's life cycle.
 */
contract Proxy {
    // implementation address
    address private immutable _implementation;

    /// @dev set implementation address
    constructor(address implementation) {
        _implementation = implementation;
    }

    /**
     * @dev Delegate all the calls to implementation contract
     */
    fallback() external {
        address implementation = _implementation;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), implementation, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    // function getImlementation() external view returns (address) { // TODO: maybe remove this function
    //     return _implementation;
    // }
}
