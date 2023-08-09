// SPDX-License-Identifier: MIT

// Have our invariant aka properties

// What are our invariants?

// 1. The total distributed token amount should always be the sum of tokens sent to the proxy contract
// 2. Getter view functions should never revert <- evergreen invariant
// 3. any calls to the proxy contract except the ones in 

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";