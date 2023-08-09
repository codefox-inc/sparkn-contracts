// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {MockERC20} from "../mock/MockERC20.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {Proxy} from "../../src/Proxy.sol";
import {Distributor} from "../../src/Distributor.sol";
import {HelperContract} from "../integration/HelperContract.t.sol";

contract FuzzTest is StdCheats, HelperContract {}
