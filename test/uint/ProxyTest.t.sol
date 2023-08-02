// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Proxy} from "../../src/Proxy.sol";

contract ProxyTest is StdCheats, Test {
    Proxy public proxy;
    Proxy public secondProxy;
    Proxy public thirdProxy;

    function setUp() public {
        // deploy contracts
        proxy = new Proxy(address(1));
        secondProxy = new Proxy(makeAddr('randomImplementation'));
        thirdProxy = new Proxy(makeAddr('randomImplementation2'));
    }

    /// expected pattern
    function testImmutableVariableIsSet() public {
        // test something
        // assertEq(proxy.getImlementation(), address(1));
        // assertEq(secondProxy.getImlementation(), makeAddr('randomImplementation'));
        // assertEq(thirdProxy.getImlementation(), makeAddr('randomImplementation2'));
    }


    /// expected failing pattern
}

