// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {MockERC20} from "../mock/MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {Proxy} from "../../src/Proxy.sol";
import {Distributor} from "../../src/Distributor.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployContracts} from "../../script/DeployContracts.s.sol";

contract ProxyFactoryTest is StdCheats, Test {
    // address deployer = makeAddr("deployer");
    // they are JPYC tokens on polygon mainnet
    // address[] tokensToWhitelist;
    // main contracts
    ProxyFactory public proxyFactory;
    Proxy public proxy;
    Distributor public distributor;

    // token
    address public jpycv1Address;
    address public jpycv2Address;
    address public usdcAddress;
    address public usdtAddress;

    // helpers
    HelperConfig public config;

    // user
    address public stadiumAddress = makeAddr("stadium");
    address public factoryAdmin = makeAddr("factoryAdmin");
    address public tokenMinter = makeAddr("tokenMinter");
    address public organizer = address(11);
    address public sponsor = address(12);
    address public supporter = address(13);
    address public user = address(14);

    // constants
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant SMALL_STARTING_USER_BALANCE = 2 ether;
    uint256 public constant UNIT_ONE = 1e18;

    // key
    uint256 public deployerKey;

    function setUp() public {
        DeployContracts deployContracts = new DeployContracts();
        (proxyFactory, distributor, config) = deployContracts.run();
        (jpycv1Address, jpycv2Address, usdcAddress, usdtAddress, deployerKey) = config.activeNetworkConfig();

        if (block.chainid == 31337) {
            vm.deal(factoryAdmin, STARTING_USER_BALANCE);
            vm.deal(user, SMALL_STARTING_USER_BALANCE);
            vm.deal(sponsor, SMALL_STARTING_USER_BALANCE);
            vm.deal(organizer, SMALL_STARTING_USER_BALANCE);
            vm.startPrank(tokenMinter);
            MockERC20(jpycv1Address).mint(sponsor, 100_000 ether); // 100k JPYCv1
            MockERC20(jpycv2Address).mint(sponsor, 300_000 ether); // 300k JPYCv2
            MockERC20(usdcAddress).mint(sponsor, 10_000 ether); // 10k USDC
            MockERC20(jpycv1Address).mint(organizer, 100_000 ether); // 100k JPYCv1
            MockERC20(jpycv2Address).mint(organizer, 300_000 ether); // 300k JPYCv2
            MockERC20(usdcAddress).mint(organizer, 10_000 ether); // 10k USDC
            vm.stopPrank();
        }

        // label
        vm.label(stadiumAddress, "stadiumAddress");
        vm.label(factoryAdmin, "factoryAdmin");
        vm.label(tokenMinter, "tokenMinter");
        vm.label(organizer, "organizer");
        vm.label(sponsor, "sponsor");
        vm.label(supporter, "supporter");
        vm.label(user, "user");
        // get the addresses of the tokens to whitelist
        // deploy contracts
        // vm.prank(deployer);
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        // tokensToWhitelist = [0x431D5dfF03120AFA4bDf332c61A6e1766eF37BDB, 0x2370f9d504c7a6E775bf6E14B3F12846b594cD53];
        // proxyFactory = new ProxyFactory(tokensToWhitelist);
        // console.log(deployer);
    }

    ///////////
    // setup //
    ///////////
    function testSetupContractsExist() public {
        // addresses are not zero
        assertTrue(jpycv1Address != address(0));
        assertTrue(jpycv2Address != address(0));
        assertTrue(usdcAddress != address(0));
        assertTrue(address(proxyFactory) != address(0));
        assertTrue(address(distributor) != address(0));
    }

    function testSetupBalancesAreOk() public {
        // check balances
        assertEq(MockERC20(jpycv1Address).balanceOf(sponsor), 100_000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(sponsor), 300_000 ether);
        assertEq(MockERC20(usdcAddress).balanceOf(sponsor), 10_000 ether);
        assertEq(MockERC20(jpycv1Address).balanceOf(organizer), 100_000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(organizer), 300_000 ether);
        assertEq(MockERC20(usdcAddress).balanceOf(organizer), 10_000 ether);

        assertEq(factoryAdmin.balance, STARTING_USER_BALANCE);
        assertEq(user.balance, SMALL_STARTING_USER_BALANCE);
        assertEq(sponsor.balance, SMALL_STARTING_USER_BALANCE);
        assertEq(organizer.balance, SMALL_STARTING_USER_BALANCE);
    }

    function testSetupOwnersAreOK() public {
        // check owners
        assertEq(proxyFactory.owner(), factoryAdmin);
        assertEq(MockERC20(jpycv1Address).owner(), tokenMinter);
        assertEq(MockERC20(jpycv2Address).owner(), tokenMinter);
        assertEq(MockERC20(usdcAddress).owner(), tokenMinter);
    }

    function testSetupProxyFactoryIsWhitelisted() public {
        // check whitelist
        assertTrue(proxyFactory.whitelistedTokens(jpycv1Address));
        assertTrue(proxyFactory.whitelistedTokens(jpycv2Address));
        assertTrue(proxyFactory.whitelistedTokens(usdcAddress));
        // check non-whitelisted
        assertFalse(proxyFactory.whitelistedTokens(address(1231)));
    }

    function testConstantValuesAreSetCorrectly() public {
        assertEq(proxyFactory.EXPIRATION_TIME(), 7 days);
        assertEq(proxyFactory.MAX_CONTEST_PERIOD(), 28 days);
    }

    /////////////////
    // constructor //
    /////////////////
    function testConstructorWhitelistedTokensIsEmptyThenRevert() public {
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        address[] memory tokensToWhitelist = new address[](0);
        // should revert
        vm.expectRevert(ProxyFactory.ProxyFactory__NoEmptyArray.selector);
        new ProxyFactory(tokensToWhitelist);
    }

    function testConstructorWhitelistedTokensWithZeroAddressesThenRevert() public {
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        address[] memory tokensToWhitelist = new address[](2);
        // should revert
        vm.expectRevert(ProxyFactory.ProxyFactory__NoZeroAddress.selector);
        new ProxyFactory(tokensToWhitelist);
    }

    function testConstructorVariablesAreSetCorrectly() public {
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        address[] memory tokensToWhitelist = new address[](3);
        tokensToWhitelist[0] = jpycv1Address;
        tokensToWhitelist[1] = jpycv2Address;
        tokensToWhitelist[2] = usdcAddress;
        // deploy contracts
        ProxyFactory newProxyFactory = new ProxyFactory(tokensToWhitelist);
        // check whitelist
        assertTrue(newProxyFactory.whitelistedTokens(jpycv1Address));
        assertTrue(newProxyFactory.whitelistedTokens(jpycv2Address));
        assertTrue(newProxyFactory.whitelistedTokens(jpycv2Address));
        // check non-whitelisted
        assertFalse(proxyFactory.whitelistedTokens(usdtAddress));
    }

    ////////////////
    // setContest //
    ////////////////
    function testOrganizerIsZeroThenRevert() public {
        bytes32 randomId = keccak256(abi.encode("Jason", "001")); // do not use abi.encodePacked because hash collision can happen.
        console.logBytes32(randomId);
        // bytes32 contestId_ = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__NoZeroAddress.selector);
        proxyFactory.setContest(address(0), randomId, block.timestamp + 1 days, address(distributor));
        // console.log(bytes32(0x01));
        vm.stopPrank();
    }

    function testImplementationIsZeroThenRevert() public {
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        console.logBytes32(randomId);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__NoZeroAddress.selector);
        proxyFactory.setContest(organizer, randomId, block.timestamp + 1 days, address(0));
        // console.log(bytes32(0x01));
        vm.stopPrank();
    }

    function testClosetimeIsLessThanNowThenRevert() public {
        vm.warp(12345); // warp to 12345 seconds
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__CloseTimeNotInRange.selector);
        proxyFactory.setContest(organizer, randomId, block.timestamp - 1 minutes, address(distributor));
        // console.log(bytes32(0x01));
        vm.stopPrank();
    }

    function testClosetimeIsMoreThanMaxPeriodThenRevert() public {
        vm.warp(12345); // warp to 12345 seconds
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__CloseTimeNotInRange.selector);
        proxyFactory.setContest(organizer, randomId, block.timestamp + 29 days, address(distributor));
        // console.log(bytes32(0x01));
        vm.stopPrank();
    }

    function testSetContestAgainThenRevert() public {
        vm.warp(12345); // warp to 12345 seconds
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.startPrank(factoryAdmin);
        proxyFactory.setContest(organizer, randomId, block.timestamp + 20 days, address(distributor));
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsAlreadyRegistered.selector);
        proxyFactory.setContest(organizer, randomId, block.timestamp + 20 days, address(distributor));
        vm.stopPrank();
    }
    function testSetContestSucessfully() public {
        vm.warp(12345); // warp to 12345 seconds
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.startPrank(factoryAdmin);
        proxyFactory.setContest(organizer, randomId, block.timestamp + 20 days, address(distributor));
        vm.stopPrank();
        bytes32 salt_ = keccak256(abi.encode(organizer, randomId, address(distributor)));
        assertEq(proxyFactory.saltToCloseTime(salt_), block.timestamp + 20 days);
    }

    //////////////////////////////
    // deployProxyAndDistribute //
    //////////////////////////////

    
}
