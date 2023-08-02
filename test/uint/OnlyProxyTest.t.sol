// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Proxy} from "../../src/Proxy.sol";

contract ProxyTest is StdCheats, Test {
    Proxy proxy;
    Proxy secondProxy;
    Proxy thirdProxy;

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
    function testFallbackFuncitonWillFail() public {
        // test something
        vm.expectRevert();
        (bool success, ) = address(proxy).call(abi.encodeWithSignature("nonExistingFunction()"));
        // console.log(success);
        assertEq(success, false);
    }

    function testFallbackFuncitonWillFailPattern2() public {
        // test something
        vm.expectRevert();
        (bool success, ) = address(proxy).call(abi.encodeWithSignature("getConstants()"));
        // console.log(success);
        assertEq(success, false);
    }


    function testCannotSendEtherToProxy() public {
        vm.deal(msg.sender, 2 ether);
        vm.expectRevert();
        (bool success, ) = address(proxy).call{value: 1 ether}('');
        assertEq(0, address(proxy).balance);
    }
}
