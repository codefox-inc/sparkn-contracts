// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";

contract ProxyFactoryTest is StdCheats, Test {
    ProxyFactory proxyFactory;
    address deployer = makeAddr("deployer");
    // they are JPYC tokens on polygon mainnet
    address[] tokensToWhitelist;

    function setUp() public {
        // deploy contracts
        vm.prank(deployer);
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        tokensToWhitelist = [0x431D5dfF03120AFA4bDf332c61A6e1766eF37BDB, 0x2370f9d504c7a6E775bf6E14B3F12846b594cD53];
        proxyFactory = new ProxyFactory(tokensToWhitelist);
        console.log(deployer);
    }

    function test111() public {}
}
