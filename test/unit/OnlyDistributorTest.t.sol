// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Distributor} from "../../src/Distributor.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";


/// test the implementation contract when it is alone
contract DistributionTest is StdCheats, Test {
    Distributor public distributor;
    ProxyFactory public factoryProxy;

    // user
    address public stadiumAddress = makeAddr("stadium");
    address public factoryAdmin = makeAddr("factoryAdmin");
    address public tokenMinter = makeAddr("tokenMinter");
    address public organizer = address(11);
    address[] finalTokensToWhitelist;

    // constant
    uint256 public constant COMMISSION_FEE = 500; // 5%

    ///////////
    // setup //
    ///////////
    function setUp() public {
        address[] memory tokensToWhitelist = new address[](3);
        // whitelist 3 kinds of tokens
        tokensToWhitelist[0] = address(1);
        tokensToWhitelist[1] = address(1);
        tokensToWhitelist[2] = address(1);
        for (uint256 i; i < 3; ++i) {
            if (tokensToWhitelist[i] != address(0)) {
                finalTokensToWhitelist.push(tokensToWhitelist[i]);
            }
        }

        // only deploy contracts
        factoryProxy = new ProxyFactory(tokensToWhitelist, stadiumAddress);
        distributor = new Distributor(address(factoryProxy));
    }

    /////////////////
    // constructor //
    /////////////////
    // function testIfCommissionFeeIsOutOfRangeThenRevert() public {
    //     // 0%
    //     new Distributor(factoryAdmin, stadiumAddress, 0);
    //     // 10%
    //     new Distributor(factoryAdmin, stadiumAddress, 1000);
    //     // revert
    //     vm.expectRevert(Distributor.Distributor__InvalidCommissionFee.selector);
    //     new Distributor(factoryAdmin, stadiumAddress, 1001);
    //     // revert
    //     vm.expectRevert(Distributor.Distributor__InvalidCommissionFee.selector);
    //     new Distributor(factoryAdmin, stadiumAddress, 10001);
    //     // revert
    //     vm.expectRevert(Distributor.Distributor__InvalidCommissionFee.selector);
    //     new Distributor(factoryAdmin, stadiumAddress, 20000);
    // }

    function testIfFactoryAddressIsZeroThenRevert() public {
        // revert
        vm.expectRevert(Distributor.Distributor__NoZeroAddress.selector);
        new Distributor(address(0));
    }

    // function testIfStadiumAddressIsZeroThenRevert() public {
    //     // revert
    //     vm.expectRevert(Distributor.Distributor__NoZeroAddress.selector);
    //     new Distributor(factoryAdmin, address(0));
    // }

    function testIfBothAddressesAreZeroThenRevert() public {
        // revert
        vm.expectRevert(Distributor.Distributor__NoZeroAddress.selector);
        new Distributor(address(0));
    }

    ////////////////////////////////
    // getConstants & constructor //
    ////////////////////////////////
    function testGetConstantsReturnsRightValues() public {
        (address factoryAddr, address statidumAddr, uint256 commissionFee, uint8 version) = distributor.getConstants();
        assertEq(factoryAddr, address(factoryProxy));
        assertEq(statidumAddr, stadiumAddress);
        assertEq(commissionFee, COMMISSION_FEE);
        assertEq(version, 1);
    }

    // any calls from non-factory address will fail, so tests end here
    function testCallingdistributeWillFail() public {
        // revert
        vm.startPrank(organizer);
        vm.expectRevert(Distributor.Distributor__OnlyFactoryAddressIsAllowed.selector);
        distributor.distribute(address(0), new address[](0), new uint256[](0), "");
        vm.expectRevert(Distributor.Distributor__OnlyFactoryAddressIsAllowed.selector);
        distributor.distribute(address(0), new address[](0), new uint256[](0), "");
        vm.stopPrank();
    }
}
