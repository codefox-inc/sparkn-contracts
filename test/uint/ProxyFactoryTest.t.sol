// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";

contract ProxyFactoryTest is StdCheats, Test {
    ProxyFactory proxyFactory;
    address deployer = makeAddr('deployer');

    function setUp() public {
        // deploy contracts
        vm.prank(deployer);
        proxyFactory = new ProxyFactory();
        console.log(deployer);
    }

    function test111() public {}
}
