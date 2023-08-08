// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {MockERC20} from "../mock/MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Proxy} from "../../src/Proxy.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {Distributor} from "../../src/Distributor.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployContracts} from "../../script/DeployContracts.s.sol";

contract ProxyTest is StdCheats, Test {
    // main contracts
    ProxyFactory public proxyFactory;
    Proxy public proxy;
    Distributor public distributor;
    // distributor instance through proxy address
    Distributor public proxyWithDistributorLogic;

    address public deployedProxy;

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
    address public user1 = address(14);
    address public user2 = address(15);
    address public user3 = address(16);

    // constants
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant SMALL_STARTING_USER_BALANCE = 2 ether;

    // key
    uint256 public deployerKey;

    // event
    event Distributed(address token, address[] winners, uint256[] percentages);

    function setUp() public {
        DeployContracts deployContracts = new DeployContracts();
        (proxyFactory, distributor, config) = deployContracts.run();
        (jpycv1Address, jpycv2Address, usdcAddress, usdtAddress, deployerKey) = config.activeNetworkConfig();
        // create a distributor instance through proxy
        proxyWithDistributorLogic = Distributor(address(proxy));

        if (block.chainid == 31337) {
            vm.deal(factoryAdmin, STARTING_USER_BALANCE);
            vm.deal(sponsor, SMALL_STARTING_USER_BALANCE);
            vm.deal(organizer, SMALL_STARTING_USER_BALANCE);
            vm.deal(user1, SMALL_STARTING_USER_BALANCE);
            vm.deal(user2, SMALL_STARTING_USER_BALANCE);
            vm.deal(user3, SMALL_STARTING_USER_BALANCE);
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
        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.label(user3, "user3");
        // get the addresses of the tokens to whitelist
        // deploy contracts
        // vm.prank(deployer);
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        // tokensToWhitelist = [0x431D5dfF03120AFA4bDf332c61A6e1766eF37BDB, 0x2370f9d504c7a6E775bf6E14B3F12846b594cD53];
        // proxyFactory = new ProxyFactory(tokensToWhitelist);
        // console.log(deployer);
    }

    // note: should pay attention to both the wanted and unwanted patterns.
    // note: all the calls are made through proxy contract.
    //////////////////
    //// Modifier ////
    //////////////////
    modifier setUpContestForNameAndSentAmountToken (string memory name, address token, uint256 amount) {
        // set contest
        vm.startPrank(factoryAdmin);
        bytes32 randomId = keccak256(abi.encode(name, "001"));
        proxyFactory.setContest(organizer, randomId, block.timestamp, address(distributor));
        vm.stopPrank();
        bytes32 salt = keccak256(abi.encode(organizer, randomId, address(distributor)));
        address proxyAddress = proxyFactory.getProxyAddress(salt, address(distributor));
        vm.startPrank(sponsor);
        MockERC20(token).transfer(proxyAddress, amount);
        vm.stopPrank();
        // console.log(MockERC20(jpycv2Address).balanceOf(proxyAddress));
        assertEq(MockERC20(token).balanceOf(proxyAddress), 10000 ether);
        _;
    }

    function createDataToDistributeJpycv2() public view returns (bytes memory data) {
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 9500;
        data = abi.encodeWithSelector(Distributor.distribute.selector, jpycv2Address, winners, percentages_);
    }


    //////////////////////
    //// getConstants ////
    //////////////////////
    function testConstantValuesAreOk() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));
        (address factoryAddr, address stadiumAddr, uint256 commissionFee, uint8 version) = proxyWithDistributorLogic.getConstants();
        assertEq(factoryAddr, address(proxyFactory));
        assertEq(stadiumAddr, stadiumAddress);
        assertEq(commissionFee, 500);
        assertEq(version, 1);
    }


    ////////////////////
    //// distribute ////
    ////////////////////

    function testIfTxSenderIsNotFactoryThenRevert() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));

        // prepare data
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 9500;

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(deployedProxy, 10000 ether);
        vm.stopPrank();

        // random user wants to call distribute function
        vm.startPrank(user1);
        vm.expectRevert(Distributor.Distributor__OnlyFactoryAddressIsAllowed.selector);
        proxyWithDistributorLogic.distribute(jpycv2Address, winners, percentages_);
        vm.stopPrank();
    }

    function testIfTokenAdressIsZeroThenRevert() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        // create contest id and then call to deploy proxy and distribute token
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));

        // prepare data again
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 9500;
        
        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(deployedProxy, 10000 ether);
        vm.stopPrank();

        // factory wants to call distribute function but with address zero
        vm.startPrank(address(proxyFactory));
        vm.expectRevert(Distributor.Distributor__NoZeroAddress.selector);
        proxyWithDistributorLogic.distribute(address(0), winners, percentages_);
        vm.stopPrank();
    }

    function testIfTokenAdressIsNotWhitelistedThenRevert() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));

        // prepare data
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 9500;

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(deployedProxy, 10000 ether);
        vm.stopPrank();

        // if token address is not whitelisted then revert
        vm.startPrank(address(proxyFactory));
        vm.expectRevert(Distributor.Distributor__InvalidTokenAddress.selector);
        proxyWithDistributorLogic.distribute(usdtAddress, winners, percentages_);
        vm.stopPrank();
    }

    function testIfArgumentsLengthNotEqualThenRevert() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));

        // prepare data
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](2);
        percentages_[0] = 1500;
        percentages_[0] = 8000;

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(usdcAddress).transfer(deployedProxy, 1000 ether);
        vm.stopPrank();

        // if arguments length is not equal then revert
        vm.startPrank(address(proxyFactory));
        vm.expectRevert(Distributor.Distributor__MismatchedArrays.selector);
        proxyWithDistributorLogic.distribute(usdcAddress, winners, percentages_);
        vm.stopPrank();
    }

    function testIfWinnersLengthIsZeroThenRevert() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));

        // prepare data
        address[] memory winners;
        uint256[] memory percentages_ = new uint256[](2);
        percentages_[0] = 9500;

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(usdcAddress).transfer(deployedProxy, 1000 ether);
        vm.stopPrank();

        // if arguments length is not equal then revert
        vm.startPrank(address(proxyFactory));
        vm.expectRevert(Distributor.Distributor__MismatchedArrays.selector);
        proxyWithDistributorLogic.distribute(usdcAddress, winners, percentages_);
        vm.stopPrank();
    }

    function testIfTotalPercetageIsNotCorrectThenRevert() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));

        // prepare data
        address[] memory winners = new address[](2);
        winners[0] = user1;
        winners[1] = user2;
        uint256[] memory percentages_ = new uint256[](2);
        percentages_[0] = 9500;
        percentages_[0] = 10;

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(usdcAddress).transfer(deployedProxy, 10000 ether);
        vm.stopPrank();

        // if arguments length is not equal then revert
        vm.startPrank(address(proxyFactory));
        vm.expectRevert(Distributor.Distributor__MismatchedPercentages.selector);
        proxyWithDistributorLogic.distribute(usdcAddress, winners, percentages_);
        vm.stopPrank();
    }

    function testIfAllConditionsMetThenUsdcSendingCallShouldSuceed() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        // before
        assertEq(MockERC20(usdcAddress).balanceOf(address(user1)), 0);
        assertEq(MockERC20(usdcAddress).balanceOf(address(user2)), 0);

        // deploy proxy
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));


        // prepare data
        address[] memory winners = new address[](2);
        winners[0] = user1;
        winners[1] = user2;
        uint256[] memory percentages_ = new uint256[](2);
        percentages_[0] = 9000;
        percentages_[1] = 500;

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(usdcAddress).transfer(deployedProxy, 1000 ether);
        vm.stopPrank();

        // If all conditions met then call should succeed
        vm.startPrank(address(proxyFactory));
        proxyWithDistributorLogic.distribute(usdcAddress, winners, percentages_);
        vm.stopPrank();

        // after this, token should be distributed correctly as expected 
        assertEq(MockERC20(usdcAddress).balanceOf(address(user1)), 900 ether);
        assertEq(MockERC20(usdcAddress).balanceOf(address(user2)), 50 ether);
        assertEq(MockERC20(usdcAddress).balanceOf(stadiumAddress), 50 ether);
    }


    function testIfAllConditionsMetThenJpycv2SendingCallShouldSuceed() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        // before
        assertEq(MockERC20(jpycv1Address).balanceOf(address(user1)), 0);
        assertEq(MockERC20(jpycv1Address).balanceOf(address(user2)), 0);

        // deploy proxy
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));


        // prepare data
        address[] memory winners = new address[](2);
        winners[0] = user1;
        winners[1] = user2;
        uint256[] memory percentages_ = new uint256[](2);
        percentages_[0] = 9000;
        percentages_[1] = 500;

        // sponsor send token to proxy by mistake
        deal(address(jpycv1Address), sponsor, 200000 ether);
        vm.startPrank(sponsor);
        MockERC20(jpycv1Address).transfer(deployedProxy, 200000 ether);
        vm.stopPrank();

        // If all conditions met then call should succeed
        vm.startPrank(address(proxyFactory));
        vm.expectEmit(true, false, false, false);
        emit Distributed(jpycv1Address, winners, percentages_);
        proxyWithDistributorLogic.distribute(jpycv1Address, winners, percentages_);
        vm.stopPrank();

        // after this, token should be distributed correctly as expected 
        assertEq(MockERC20(jpycv1Address).balanceOf(address(user1)), 180000 ether);
        assertEq(MockERC20(jpycv1Address).balanceOf(address(user2)), 10000 ether);
        assertEq(MockERC20(jpycv1Address).balanceOf(stadiumAddress), 10000 ether);
    }


    function testIfNoTokenToSendInProxyThenRevert() public setUpContestForNameAndSentAmountToken ("James", jpycv2Address, 10000 ether) {
        // before
        assertEq(MockERC20(jpycv1Address).balanceOf(address(user1)), 0);
        assertEq(MockERC20(jpycv1Address).balanceOf(address(user2)), 0);

        // deploy proxy
        bytes32 randomId_ = keccak256(abi.encode("James", "001"));
        bytes memory data = createDataToDistributeJpycv2();
        vm.startPrank(organizer);
        deployedProxy = proxyFactory.deployProxyAndDsitribute(randomId_, address(distributor), data);
        vm.stopPrank();

        proxyWithDistributorLogic = Distributor(address(deployedProxy));


        // prepare data
        address[] memory winners = new address[](2);
        winners[0] = user1;
        winners[1] = user2;
        uint256[] memory percentages_ = new uint256[](2);
        percentages_[0] = 9000;
        percentages_[1] = 500;

        // nobody send any token to proxy after this

        // If all conditions met then call should succeed
        vm.startPrank(address(proxyFactory));
        vm.expectRevert(Distributor.Distributor__NoTokenToDistribute.selector);
        proxyWithDistributorLogic.distribute(jpycv1Address, winners, percentages_);
        vm.stopPrank();
    }
}