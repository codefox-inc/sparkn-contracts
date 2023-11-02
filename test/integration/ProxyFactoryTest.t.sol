// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {MockERC20} from "../mock/MockERC20.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {Proxy} from "../../src/Proxy.sol";
import {Distributor} from "../../src/Distributor.sol";
import {HelperContract} from "./HelperContract.t.sol";
import {ERC1271WalletMock, ERC1271MaliciousMock} from "openzeppelin/mocks/ERC1271WalletMock.sol";
import {SignatureChecker} from "openzeppelin/utils/cryptography/SignatureChecker.sol";

contract ProxyFactoryTest is StdCheats, HelperContract {
    using SignatureChecker for address;

    function setUp() public {
        // set up balances of each token belongs to each user
        if (block.chainid == 31337) {
            // deal ether
            vm.deal(factoryAdmin, STARTING_USER_BALANCE);
            vm.deal(sponsor, SMALL_STARTING_USER_BALANCE);
            vm.deal(organizer, SMALL_STARTING_USER_BALANCE);
            vm.deal(user1, SMALL_STARTING_USER_BALANCE);
            vm.deal(user2, SMALL_STARTING_USER_BALANCE);
            vm.deal(user3, SMALL_STARTING_USER_BALANCE);
            vm.deal(TEST_SIGNER, SMALL_STARTING_USER_BALANCE);
            // mint erc20 token
            vm.startPrank(tokenMinter);
            MockERC20(jpycv1Address).mint(sponsor, 100_000 ether); // 100k JPYCv1
            MockERC20(jpycv2Address).mint(sponsor, 300_000 ether); // 300k JPYCv2
            MockERC20(usdcAddress).mint(sponsor, 10_000 ether); // 10k USDC
            MockERC20(jpycv1Address).mint(organizer, 100_000 ether); // 100k JPYCv1
            MockERC20(jpycv2Address).mint(organizer, 300_000 ether); // 300k JPYCv2
            MockERC20(usdcAddress).mint(organizer, 10_000 ether); // 10k USDC
            MockERC20(jpycv1Address).mint(TEST_SIGNER, 100_000 ether); // 100k JPYCv1
            MockERC20(jpycv2Address).mint(TEST_SIGNER, 300_000 ether); // 300k JPYCv2
            MockERC20(usdcAddress).mint(TEST_SIGNER, 10_000 ether); // 10k USDC
            vm.stopPrank();
        }

        // labels
        vm.label(organizer, "organizer");
        vm.label(sponsor, "sponsor");
        vm.label(supporter, "supporter");
        vm.label(user1, "user1");
        vm.label(user2, "user2");
        vm.label(user3, "user3");
    }

    ////////////////
    // test setup //
    ////////////////
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
        assertEq(MockERC20(jpycv1Address).balanceOf(TEST_SIGNER), 100_000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(TEST_SIGNER), 300_000 ether);
        assertEq(MockERC20(usdcAddress).balanceOf(TEST_SIGNER), 10_000 ether);

        assertEq(factoryAdmin.balance, STARTING_USER_BALANCE);
        assertEq(sponsor.balance, SMALL_STARTING_USER_BALANCE);
        assertEq(organizer.balance, SMALL_STARTING_USER_BALANCE);
        assertEq(user1.balance, SMALL_STARTING_USER_BALANCE);
        assertEq(user2.balance, SMALL_STARTING_USER_BALANCE);
        assertEq(user3.balance, SMALL_STARTING_USER_BALANCE);
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

    /////////////////////
    // constant values //
    /////////////////////
    function testConstantValuesAreSetCorrectly() public {
        assertEq(proxyFactory.EXPIRATION_TIME(), 7 days);
        assertEq(proxyFactory.MAX_CONTEST_PERIOD(), 60 days);
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
        new ProxyFactory(tokensToWhitelist, stadiumAddress);
    }

    function testConstructorWhitelistedTokensWithZeroAddressesThenRevert() public {
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        address[] memory tokensToWhitelist = new address[](2);
        // should revert
        vm.expectRevert(ProxyFactory.ProxyFactory__NoZeroAddress.selector);
        new ProxyFactory(tokensToWhitelist, stadiumAddress);
    }

    function testConstructorVariablesAreSetCorrectly() public {
        // create a list of tokens to whitelist.
        // here we use JPYC v1, and v2
        address[] memory tokensToWhitelist = new address[](3);
        tokensToWhitelist[0] = jpycv1Address;
        tokensToWhitelist[1] = jpycv2Address;
        tokensToWhitelist[2] = usdcAddress;
        // deploy contracts
        ProxyFactory newProxyFactory = new ProxyFactory(tokensToWhitelist, stadiumAddress);
        // check whitelist
        assertTrue(newProxyFactory.whitelistedTokens(jpycv1Address));
        assertTrue(newProxyFactory.whitelistedTokens(jpycv2Address));
        assertFalse(newProxyFactory.whitelistedTokens(usdtAddress));
        // check non-whitelisted
        assertFalse(proxyFactory.whitelistedTokens(usdtAddress));
    }

    ////////////////
    // setContest //
    ////////////////
    function testImplementationHasNoCodeThenRevert() public {
        bytes32 randomId = keccak256(abi.encode("Jason", "001")); // do not use abi.encodePacked because hash collision can happen.
        // console.logBytes32(randomId);
        // bytes32 contestId_ = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ImplementationNotDeployed.selector);
        proxyFactory.setContest(organizer, randomId, block.timestamp + 1 days, makeAddr("nocode"));
        // console.log(bytes32(0x01));
        vm.stopPrank();
    }

    function testOrganizerIsZeroThenRevert() public {
        bytes32 randomId = keccak256(abi.encode("Jason", "001")); // do not use abi.encodePacked because hash collision can happen.
        // console.logBytes32(randomId);
        // bytes32 contestId_ = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__NoZeroAddress.selector);
        proxyFactory.setContest(address(0), randomId, block.timestamp + 1 days, address(distributor));
        // console.log(bytes32(0x01));
        vm.stopPrank();
    }

    function testImplementationIsZeroThenRevert() public {
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        // console.logBytes32(randomId);
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
        proxyFactory.setContest(organizer, randomId, block.timestamp + 61 days, address(distributor));
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

    function testCalledByNonOwnerThenRevert() public {
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.startPrank(organizer);
        vm.expectRevert("Ownable: caller is not the owner");
        proxyFactory.setContest(organizer, randomId, block.timestamp + 20 days, address(distributor));
        vm.stopPrank();
    }

    function testSetContestSucessfullyWithEventEmitted() public {
        vm.warp(12345); // warp to 12345 seconds
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.startPrank(factoryAdmin);
        vm.expectEmit(true, true, false, true);
        emit SetContest(organizer, randomId, block.timestamp + 20 days, address(distributor));
        proxyFactory.setContest(organizer, randomId, block.timestamp + 20 days, address(distributor));
        vm.stopPrank();
        bytes32 salt_ = keccak256(abi.encode(organizer, randomId, address(distributor)));
        assertEq(proxyFactory.saltToCloseTime(salt_), block.timestamp + 20 days);
        assertFalse(proxyFactory.saltToCloseTime(salt_) == block.timestamp + 19 days);
    }

    ///////////////////////
    // Modifier for test //
    ///////////////////////
    // Set contest for `Jason`, `001` and sent JPYC v2 token to the
    // undeployed proxy contract address and then check the balance
    modifier setUpContestForJasonAndSentJpycv2Token(address _organizer) {
        vm.startPrank(factoryAdmin);
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        proxyFactory.setContest(_organizer, randomId, block.timestamp + 8 days, address(distributor));
        vm.stopPrank();
        bytes32 salt = keccak256(abi.encode(_organizer, randomId, address(distributor)));
        address proxyAddress = proxyFactory.getProxyAddress(salt, address(distributor));
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10500 ether);
        vm.stopPrank();
        // console.log(MockERC20(jpycv2Address).balanceOf(proxyAddress));
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress), 10500 ether);
        _;
    }

    function createData() public view returns (bytes memory data) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = jpycv2Address;
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 10000;
        data = abi.encodeWithSelector(Distributor.distribute.selector, jpycv2Address, winners, percentages_, "");
    }

    function createDataToSendToAdmin() public view returns (bytes memory data) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = jpycv2Address;
        address[] memory winners = new address[](1);
        winners[0] = stadiumAddress;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 10000;
        data = abi.encodeWithSelector(Distributor.distribute.selector, jpycv2Address, winners, percentages_, "");
    }

    //////////////////////////////
    // deployProxyAndDistribute //
    //////////////////////////////
    // contest id set and prize token is sent to the proxy
    function testCalledWithContestIdNotExistThenRevert() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        // create data with wrong contestId
        bytes32 randomId_ = keccak256(abi.encode("Watson", "001"));
        bytes memory data = createData();

        // deploy proxy and distribute
        vm.warp(14 days);
        vm.startPrank(organizer);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testCloseTimeNotReachedThenRevert() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();
        // console.log(proxyFactory.saltToCloseTime(keccak256(abi.encode(organizer, randomId_, address(distributor)))));

        // deploy proxy and distribute
        vm.startPrank(organizer);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotClosed.selector);
        proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();
    }

    // create data with wrong implementation address
    function testCalledWithWrongImplementationAddrThenRevert()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();
        // console.log(proxyFactory.saltToCloseTime(keccak256(abi.encode(organizer, randomId_, usdcAddress))));

        vm.warp(9 days);
        vm.startPrank(organizer);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.deployProxyAndDistribute(randomId_, usdcAddress, data);
        vm.stopPrank();
    }

    function testCalledWithNonOrganizerThenRevert() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();
        // console.log(proxyFactory.saltToCloseTime(keccak256(abi.encode(organizer, randomId_, usdcAddress))));

        vm.warp(9 days);
        vm.startPrank(user1);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testCalledWithWrongDataThenRevert() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        address[] memory tokens_ = new address[](1);
        tokens_[0] = jpycv2Address;
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 10000;
        // lack key arguments
        bytes memory data = abi.encodeWithSelector(Distributor.distribute.selector, jpycv2Address, randomId_, winners);
        // console.log(proxyFactory.saltToCloseTime(keccak256(abi.encode(organizer, randomId_, usdcAddress))));

        vm.warp(9 days);
        vm.startPrank(organizer);
        vm.expectRevert(ProxyFactory.ProxyFactory__DelegateCallFailed.selector);
        proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testSucceedsWhenConditionsAreMet() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);

        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();
        // console.log(proxyFactory.saltToCloseTime(keccak256(abi.encode(organizer, randomId_, address(distributor)))));
        // console.log(proxyFactory.whitelistedTokens(jpycv2Address)); // true
        // console.log(distributor._isWhiteListed(jpycv2Address)); // true

        vm.warp(9 days); // 9 days later
        vm.startPrank(organizer);
        proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();

        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 500 ether);
    }

    ///////////////////////////////////////
    /// deployProxyAndDistributeByOwner ///
    ///////////////////////////////////////
    function testRevertsIfCalledByNonOwnerTodeployProxyAndDistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        vm.warp(16 days);
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testRevertsIfCalledWithWrongContestId() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jackson", "001"));
        bytes memory data = createData();

        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testRevertsIfContestIsNotExpired() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        vm.warp(15 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotExpired.selector);
        proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testRevertsIfCalledWithWrongImplementation() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(usdcAddress), data);
        vm.stopPrank();
    }

    function testRevertsIfCalledWithWrongOrganizer() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.deployProxyAndDistributeByOwner(user1, randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testRevertsIfCalledWithWrongData() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        address[] memory tokens_ = new address[](1);
        tokens_[0] = jpycv2Address;
        address[] memory winners = new address[](1);
        winners[0] = user1;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 10000;
        bytes memory data = abi.encodeWithSelector(Distributor.distribute.selector, jpycv2Address, winners);

        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__DelegateCallFailed.selector);
        proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();
    }

    function testSucceedsIfAllConditionsMet() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);

        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();

        // after
        console.log(MockERC20(jpycv2Address).balanceOf(user1));
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 500 ether);
    }

    /////////////////////////
    /// distributeByOwner ///
    /////////////////////////

    function testRevertsIfContestIdIsNotRightDistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        // owner deploy and distribute
        vm.warp(9 days);
        vm.startPrank(organizer);
        address proxyAddress = proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        // wrong id created
        bytes32 wrongId_ = keccak256(abi.encode("Mumin", "001"));

        // 15 days is the edge of close time, after that tx can go through
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.distributeByOwner(organizer, wrongId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();
    }

    function testRevertsIfImplementationIsNotRightDistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        // owner deploy and distribute
        vm.warp(9 days);
        vm.startPrank(organizer);
        address proxyAddress = proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        // 15 days is the edge of close time, after that tx can go through
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.distributeByOwner(organizer, randomId_, usdcAddress, dataToSendToAdmin);
        vm.stopPrank();
    }

    function testRevertsIfOrganizerIsNotRightDistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        // owner deploy and distribute
        vm.warp(9 days);
        vm.startPrank(organizer);
        address proxyAddress = proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        // 15 days is the edge of close time, after that tx can go through
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.distributeByOwner(user1, randomId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();
    }

    function testRevertsIfClosetimeIsNotReadyDistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        // owner deploy and distribute
        vm.warp(9 days);
        vm.startPrank(organizer);
        address proxyAddress = proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);
        vm.stopPrank();

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        // 15 days is the edge of close time, after that tx can go through
        vm.warp(15 days);
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotExpired.selector);
        proxyFactory.distributeByOwner(organizer, randomId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();
    }

    function testRevertsIfDataIsWrongDistributeByOwner() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        // owner deploy and distribute
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        address proxyAddress =
            proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();

        // create wrong data to send the token to admin
        address[] memory tokens_ = new address[](1);
        tokens_[0] = jpycv2Address;
        address[] memory winners = new address[](1);
        winners[0] = stadiumAddress;
        uint256[] memory percentages_ = new uint256[](1);
        percentages_[0] = 10000;
        bytes memory dataToSendToAdmin = abi.encodeWithSelector(Distributor.distribute.selector, jpycv2Address, winners);

        // 16 days passed
        vm.warp(16 days);
        // adming calls distributeByOwner but it will fail
        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__DelegateCallFailed.selector);
        proxyFactory.distributeByOwner(organizer, randomId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();
    }

    function testRevertsIfCalledByNonOwnerdistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory data = createData();

        // owner deploy and distribute
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        address proxyAddress =
            proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        vm.warp(16 days);
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        proxyFactory.distributeByOwner(organizer, randomId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();
    }

    function testSucceedsIfAllConditionsMetDistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);

        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes32 salt_ = keccak256(abi.encode(organizer, randomId_, address(distributor)));
        bytes memory data = createData();

        // calculate proxy address
        address calculatedProxyAddress = proxyFactory.getProxyAddress(salt_, address(distributor));

        // owner deploy and distribute
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        address proxyAddress =
            proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();
        assertEq(proxyAddress, calculatedProxyAddress);

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();

        bytes memory dataToSendToAdmin = createDataToSendToAdmin();
        vm.startPrank(factoryAdmin);
        proxyFactory.distributeByOwner(organizer, randomId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();

        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 10500 ether);
        // stadiumAddress get 500 ether from sponsor and then get all the token sent from sponsor by mistake.
    }

    function testRevertsIfAddressIsNotAContractAndItSucceedsIfItIsProxyAddressDistributeByOwner()
        public
        setUpContestForJasonAndSentJpycv2Token(organizer)
    {
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);

        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes32 salt_ = keccak256(abi.encode(organizer, randomId_, address(distributor)));
        bytes memory data = createData();

        // calculate proxy address
        address calculatedProxyAddress = proxyFactory.getProxyAddress(salt_, address(distributor));

        // owner deploy and distribute
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        // address emptyAddress = makeAddr("empty");
        // no empty address test cuz proxyAddress is removed
        address proxyAddress =
            proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();
        assertEq(proxyAddress, calculatedProxyAddress);

        // sponsor send token to proxy by mistake
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10500 ether);
        vm.stopPrank();

        bytes memory dataToSendToAdmin = createDataToSendToAdmin();
        vm.startPrank(factoryAdmin);
        // vm.expectRevert(ProxyFactory.ProxyFactory__ProxyAddressMismatch.selector);
        proxyFactory.distributeByOwner(organizer, randomId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();

        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 11000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress), 0 ether);
        // stadiumAddress get 500 ether from sponsor and then get all the token sent from sponsor by mistake.

        vm.startPrank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__DelegateCallFailed.selector);
        proxyFactory.distributeByOwner(organizer, randomId_, address(distributor), dataToSendToAdmin);
        vm.stopPrank();

        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 11000 ether);
    }

    ///////////////////////////////////////////
    /// deployProxyAndDistributeBySignature ///
    ///////////////////////////////////////////
    /// commmon signature creatation function
    function createSignatureByASigner(uint256 privateK) public view returns (bytes32, bytes memory, bytes memory) {
        // organizer is test signer this time
        // build the digest according to EIP712 and sign it by test signer to create signature
        bytes32 domainSeparatorV4 = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ProxyFactory")),
                keccak256(bytes("1")),
                block.chainid,
                address(proxyFactory)
            )
        );
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory sendingData = createData();
        bytes32 data =
            keccak256(abi.encode(_DEPLOY_AND_DISTRIBUTE_TYPEHASH, randomId_, address(distributor), keccak256(sendingData)));
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparatorV4, data);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateK, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        return (digest, sendingData, signature);
    }

    function testIfSignerCanBeRecoveredOrNot() public {
        // vm.stopPrank();
        (bytes32 digest,, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        // console.log(ECDSA.recover(digest, signature), TEST_SIGNER);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);
        // adding EIP1271
        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);
    }

    function testIfSigner2CanBeRecoveredOrNot() public {
        // vm.stopPrank();
        (bytes32 digest,, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY2);
        // console.log(ECDSA.recover(digest, signature), TEST_SIGNER);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER2);
        // adding EIP1271
        bool result = TEST_SIGNER2.isValidSignatureNow(digest, signature);
        assertEq(result, true);
    }

    function testIfSignatureIsWrongAndReturnsNonOrganizerThenRevert()
        public
        setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER)
    {
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY2);
        assertFalse(ECDSA.recover(digest, signature) == TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, false);

        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(8.1 days);
        // expect revert with wrong address erecover
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(distributor), signature, sendingData
        );
    }

    function testIfSignatureIsRightButContestIsNotRegisteredThenRevert()
        public
        setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER2)
    {
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(8.1 days);
        // expect revert with wrong address erecover
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(distributor), signature, sendingData
        );
    }

    function testIfDigestIsWrongThenRevert() public setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER) {
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        bytes32 randomId = keccak256(abi.encode("WrongName", "a01"));
        vm.warp(8.1 days);
        // expect revert with wrong address erecover
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(distributor), signature, sendingData
        );
    }

    function testIfSignatureIsRightButContestIsNotExpiredThenRevert()
        public
        setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER)
    {
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(7.9 days);
        // expect revert with wrong address erecover
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotClosed.selector);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(distributor), signature, sendingData
        );
    }

    function testIfSignatureIsRightButImplementationIsWrongThenRevert()
        public
        setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER)
    {
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(8.01 days);
        // expect revert with wrong address erecover
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(proxyFactory), signature, sendingData
        );
    }

    function testIfSignatureIsRightButOrganizerArgumentIsWrongThenRevert()
        public
        setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER)
    {
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(8.01 days);
        // expect revert with wrong address erecover
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        proxyFactory.deployProxyAndDistributeBySignature(user1, randomId, address(distributor), signature, sendingData);
    }

    function testIfAllConditionsMetThenSucceeds() public setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER) {
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);

        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);
        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(8.01 days);
        // it succeeds
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(distributor), signature, sendingData
        );

        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 500 ether);
    }

    ///////////////////////
    /// getProxyAddress ///
    ///////////////////////
    // function testSaltDoesNotExistThenRevert() public {
    //     bytes32 randomId = keccak256(abi.encode("Jason", "001"));
    //     bytes32 salt_ = keccak256(abi.encode(organizer, randomId, address(distributor)));
    //     vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
    //     proxyFactory.getProxyAddress(salt_, address(distributor));
    // }

    // function testArgumentImplementationIsZeroThenRevert() public setUpContestForJasonAndSentJpycv2Token(organizer) {
    //     bytes32 salt_ = keccak256(abi.encode(organizer, keccak256(abi.encode("Jason", "001")), address(distributor)));
    //     vm.expectRevert(ProxyFactory.ProxyFactory__NoZeroAddress.selector);
    //     proxyFactory.getProxyAddress(salt_, address(0));
    // }

    function testReturnedAddressIsNotZero() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 salt_ = keccak256(abi.encode(organizer, keccak256(abi.encode("Jason", "001")), address(distributor)));
        address calculatedProxyAddress = proxyFactory.getProxyAddress(salt_, address(distributor));
        assertFalse(calculatedProxyAddress == address(0));
    }

    function testReturnedAddressMatchesRealProxy() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        // prepare for data
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes32 salt_ = keccak256(abi.encode(organizer, randomId_, address(distributor)));
        bytes memory data = createData();

        // calculate proxy address
        address calculatedProxyAddress = proxyFactory.getProxyAddress(salt_, address(distributor));

        // owner deploy and distribute
        vm.warp(16 days);
        vm.startPrank(factoryAdmin);
        address proxyAddress =
            proxyFactory.deployProxyAndDistributeByOwner(organizer, randomId_, address(distributor), data);
        vm.stopPrank();
        assertEq(proxyAddress, calculatedProxyAddress);
    }

    ///////////////////////////////////////////////
    /// EIP1271 contract signature verification ///
    ///////////////////////////////////////////////
    // adding tests for EIP1271 of SmartContractWallet

    function testIfSignerCanBeRecoveredOrNotWithEip1271() public {
        // vm.stopPrank();
        (bytes32 digest,, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        // console.log(ECDSA.recover(digest, signature), TEST_SIGNER);
        bool result = address(SmartContractWallet).isValidSignatureNow(digest, signature); // owner of the contract is TEST_SIGNER
        assertEq(result, true);
    }

    function testIfSigner2CanBeRecoveredOrNotWithEip1271() public {
        // vm.stopPrank();
        (bytes32 digest,, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY2);
        // console.log(ECDSA.recover(digest, signature), TEST_SIGNER);
        bool result = address(SmartContractWallet2).isValidSignatureNow(digest, signature); // owner of the contract is TEST_SIGNER2
        assertEq(result, true);
    }

    function testIfSignatureIsWrongThenRevertWithEip1271()
        public
        setUpContestForJasonAndSentJpycv2Token(address(SmartContractWallet)) // owner of the contract is TEST_SIGNER
    {
        // create a wrong signature using the mock wallet's private key
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY2);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER2);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, false);

        // create the random id
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));

        // time elapsed
        vm.warp(8.01 days);
        // calling will revert
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        address proxyAddress = proxyFactory.deployProxyAndDistributeBySignature(
            address(SmartContractWallet), randomId, address(distributor), signature, sendingData
        );

        // verify if the function executed not successfully
        assertTrue(proxyAddress == address(0), "Proxy deployment should fail and return 0x0");
    }

    function testIfDigestIsWrongThenRevertWithEip1271()
        public
        setUpContestForJasonAndSentJpycv2Token(address(SmartContractWallet))
    {
        // create a wrong signature using the mock wallet's private key
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY2);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER2);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, false);

        // create the random id
        bytes32 randomId = keccak256(abi.encode("Wrong", "001"));

        // time elapsed
        vm.warp(8.01 days);
        // calling will revert
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        address proxyAddress = proxyFactory.deployProxyAndDistributeBySignature(
            address(SmartContractWallet), randomId, address(distributor), signature, sendingData
        );

        // verify if the function executed not successfully
        assertTrue(proxyAddress == address(0), "Proxy deployment should fail and return 0x0");
    }

    function testIfSignatureIsRightButContestIsNotRegisteredThenRevertWithEip1271()
        public
        setUpContestForJasonAndSentJpycv2Token(address(SmartContractWallet2)) // owner of the contract is TEST_SIGNER2
    {
        // create a signature using the mock wallet's private key
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);

        // not right signer
        assertTrue(ECDSA.recover(digest, signature) == TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        // create the random id
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(8.01 days);

        // calling the function
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        address proxyAddress = proxyFactory.deployProxyAndDistributeBySignature(
            address(SmartContractWallet), randomId, address(distributor), signature, sendingData
        );

        // verify if the function executed successfully
        assertTrue(proxyAddress == address(0), "Proxy deployment should not succeed");
        // Add any other assertions you need to verify the function's behavior
    }

    function testIfSignatureIsRightButContestIsNotExpiredThenRevertWithEip1271()
        public
        setUpContestForJasonAndSentJpycv2Token(address(SmartContractWallet))
    {
        // create a signature using the mock wallet's private key
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);

        // not right signer
        assertTrue(ECDSA.recover(digest, signature) == TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        // create the random id
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));

        // no time warp
        // vm.warp(8.01 days);

        // calling the function
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotClosed.selector);
        address proxyAddress = proxyFactory.deployProxyAndDistributeBySignature(
            address(SmartContractWallet), randomId, address(distributor), signature, sendingData
        );

        // verify if the function executed successfully
        assertTrue(proxyAddress == address(0), "Proxy deployment should not succeed");
        // Add any other assertions you need to verify the function's behavior
    }

    function testIfSignatureIsRightButImplementationIsWrongThenRevertWithEip1271()
        public
        setUpContestForJasonAndSentJpycv2Token(address(SmartContractWallet))
    {
        // create a signature using the mock wallet's private key
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);

        // not right signer
        assertTrue(ECDSA.recover(digest, signature) == TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        // create the random id
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));

        // no time warp
        vm.warp(8.01 days);

        // calling the function
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        address proxyAddress = proxyFactory.deployProxyAndDistributeBySignature(
            address(SmartContractWallet), randomId, address(proxyFactory), signature, sendingData
        );

        // verify if the function executed successfully
        assertTrue(proxyAddress == address(0), "Proxy deployment should not succeed");
        // Add any other assertions you need to verify the function's behavior
    }

    function testIfConditionsMetThenSucceedsWithEip1271()
        public
        setUpContestForJasonAndSentJpycv2Token(address(SmartContractWallet))
    {
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);

        // create a signature using the mock wallet's private key
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);

        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        // create the random id
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));

        // warp time
        vm.warp(8.01 days);

        // call deployProxyAndDistributeByOwner function with the signature
        address proxyAddress = proxyFactory.deployProxyAndDistributeBySignature(
            address(SmartContractWallet), randomId, address(distributor), signature, sendingData
        );

        // verify if the function executed successfully
        assertTrue(proxyAddress != address(0), "Proxy deployment failed");

        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 500 ether);
    }

    // test/integration/ProxyFactoryTest.t.sol:ProxyFactoryTest
    // $ forge test --match-test "testSignatureCanBeUsedToNewImplementation" -vvv
    function testSignatureCannotBeUsedToNewImplementation() public {
        address organizer = TEST_SIGNER;
        bytes32 contestId = keccak256(abi.encode("Jason", "001"));
        //
        // 1. Owner setContest using address(distributor)
        vm.startPrank(factoryAdmin);
        proxyFactory.setContest(organizer, contestId, block.timestamp + 8 days, address(distributor));
        vm.stopPrank();
        bytes32 salt = keccak256(abi.encode(organizer, contestId, address(distributor)));
        address proxyAddress = proxyFactory.getProxyAddress(salt, address(distributor));
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10500 ether);
        vm.stopPrank();
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress), 10500 ether);
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);
        
        // 2. Organizer creates a signature
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);
        vm.warp(8.01 days);
        
        // 3. Caller distributes prizes using the signature
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, contestId, address(distributor), signature, sendingData
        );
        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10000 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 500 ether);
        //
        // 4. For some reason there is a new distributor implementation.
        // The Owner set the new distributor for the same contestId
        Distributor newDistributor = new Distributor(address(proxyFactory));
        vm.startPrank(factoryAdmin);
        proxyFactory.setContest(organizer, contestId, block.timestamp + 8 days, address(newDistributor));
        vm.stopPrank();
        bytes32 newDistributorSalt = keccak256(abi.encode(organizer, contestId, address(newDistributor)));
        address proxyNewDistributorAddress = proxyFactory.getProxyAddress(newDistributorSalt, address(newDistributor));
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyNewDistributorAddress, 10000 ether);
        vm.stopPrank();
        
        // 5. The caller can distribute prizes using the same signature in different distributor implementation
        vm.warp(20 days);
        vm.expectRevert(ProxyFactory.ProxyFactory__InvalidSignature.selector);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, contestId, address(newDistributor), signature, sendingData
        );
        assertFalse(MockERC20(jpycv2Address).balanceOf(user1) == 20000 ether);
    }

    // special poc test case
    function testOwnerCanPullFundsFromContestsWithDifferentProxiesUsingRightArguments() public {
        // Imagine that 2 contests are started by the same organizer & sponsor. This is just for
        // simplicity; the organizers/sponsors can be considered as different too for the contests in question.

        vm.startPrank(factoryAdmin);
        bytes32 randomId_1 = keccak256(abi.encode("Jason", "015")); // contest_1
        bytes32 randomId_2 = keccak256(abi.encode("Watson", "016")); // contest_2
        proxyFactory.setContest(organizer, randomId_1, block.timestamp + 8 days, address(distributor));
        proxyFactory.setContest(organizer, randomId_2, block.timestamp + 10 days, address(distributor));
        vm.stopPrank();

        bytes32 salt_1 = keccak256(abi.encode(organizer, randomId_1, address(distributor)));
        address proxyAddress_1 = proxyFactory.getProxyAddress(salt_1, address(distributor));
        bytes32 salt_2 = keccak256(abi.encode(organizer, randomId_2, address(distributor)));
        address proxyAddress_2 = proxyFactory.getProxyAddress(salt_2, address(distributor));

        vm.startPrank(sponsor);
        // sponsor funds both his contests
        MockERC20(jpycv2Address).transfer(proxyAddress_1, 10500 ether);
        MockERC20(jpycv2Address).transfer(proxyAddress_2, 525 ether);
        vm.stopPrank();

        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether, "user1 balance not zero");
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether, "STADIUM balance not zero");
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_1), 10500 ether, "proxy1 balance not 10000e18");
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_2), 525 ether, "proxy2 balance not 500e18");

        bytes memory data = createData();

        // 9 days later, organizer deploy and distribute -- for contest_1
        vm.warp(9 days);
        vm.prank(organizer);
        // user1 9500, stadium 500
        proxyFactory.deployProxyAndDistribute(randomId_1, address(distributor), data);
        // sponsor send token to proxy by mistake
        vm.prank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress_1, 10500 ether);
        // 11 days later, organizer deploy and distribute -- for contest_2
        vm.warp(11 days);
        vm.prank(organizer);
        // user1 9500+475=9975, stadium 525
        proxyFactory.deployProxyAndDistribute(randomId_2, address(distributor), data);
        // sponsor send token to proxy by mistake
        vm.prank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress_2, 525 ether);

        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        // 16 days later from the start date, contest_1 has EXPIRED,
        // but contest_2 is only CLOSED, not "EXPIRED".
        // Hence, Owner should NOT be able to distribute rewards from funds reserved for contest_2.
        vm.warp(16 days);

        // Owner provides `proxyAddress_2` by mistake, but remaining params are for `contest_1`

        // after fixing this will succeed
        vm.prank(factoryAdmin);
        // vm.expectRevert(ProxyFactory.ProxyFactory__ProxyAddressMismatch.selector);
        // this sends all the token to admin: stadiumAddress 10525
        proxyFactory.distributeByOwner(organizer, randomId_1, address(distributor), dataToSendToAdmin);

        // after fixing this will revert by not being expired
        vm.prank(factoryAdmin);
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotExpired.selector);
        proxyFactory.distributeByOwner(organizer, randomId_2, address(distributor), dataToSendToAdmin);
        // above call should have reverted with "ProxyFactory__ContestIsNotExpired()"

        // after
        // STADIUM balance has now become // (10000 + 500) * 0.95 = 9975
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 10500 ether, "user1 balance not zero");
        // (10000 + 500) * 0.05 = 525
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 11025 ether, "STADIUM balance not 1125e18");
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_1), 0 ether, "proxy1 balance not 11000e18");
        // contest_2 is fully drained
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_2), 525 ether, "proxy2 balance not zero");
    }

    // additional tests added after contest's fixing
    ////////////////////////////
    ////// test winners ////////
    ////////////////////////////

    function createDataIncludesZeroAddress() public view returns (bytes memory data) {
        // address[] memory tokens_ = new address[](1);
        // tokens_[0] = jpycv2Address;
        address[] memory winners = new address[](3);
        winners[0] = user1;
        winners[1] = address(100);
        winners[2] = address(0);
        // console.logAddress(winners[0]);
        // console.logAddress(winners[1]);
        // console.logAddress(winners[2]);
        uint256[] memory percentages_ = new uint256[](3);
        percentages_[0] = 1000;
        percentages_[1] = 8000;
        percentages_[2] = 500;
        data = abi.encodeWithSelector(Distributor.distribute.selector, jpycv2Address, winners, percentages_, "");
    }

    function createSignatureByASignerIncludesZeroAddress(uint256 privateK)
        public
        view
        returns (bytes32, bytes memory, bytes memory)
    {
        // organizer is test signer this time
        // build the digest according to EIP712 and sign it by test signer to create signature
        bytes32 domainSeparatorV4 = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ProxyFactory")),
                keccak256(bytes("1")),
                block.chainid,
                address(proxyFactory)
            )
        );
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));
        bytes memory sendingData = createDataIncludesZeroAddress();
        bytes32 data =
            keccak256(abi.encode(_DEPLOY_AND_DISTRIBUTE_TYPEHASH, randomId_, address(distributor), keccak256(sendingData)));
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparatorV4, data);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateK, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        return (digest, sendingData, signature);
    }

    function testRevertsifWinnersAddressesIncludeZeroAddress()
        public
        setUpContestForJasonAndSentJpycv2Token(TEST_SIGNER)
    {
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);

        (bytes32 digest, bytes memory sendingData, bytes memory signature) =
            createSignatureByASignerIncludesZeroAddress(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);
        bool result = TEST_SIGNER.isValidSignatureNow(digest, signature);
        assertEq(result, true);

        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        vm.warp(8.01 days);
        // it won't succeed
        vm.expectRevert(ProxyFactory.ProxyFactory__DelegateCallFailed.selector);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, randomId, address(distributor), signature, sendingData
        );

        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);
    }

    /// distributeByOwner()
    function testRevertsIfProxyAddressHasNoCodeDistributeByOwner() public {
        vm.startPrank(factoryAdmin);
        bytes32 randomId = keccak256(abi.encode("Waterloo", "991"));
        proxyFactory.setContest(organizer, randomId, block.timestamp + 8 days, address(distributor));
        vm.stopPrank();
        bytes32 salt = keccak256(abi.encode(organizer, randomId, address(distributor)));
        address proxyAddress = proxyFactory.getProxyAddress(salt, address(distributor));
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        // console.log(MockERC20(jpycv2Address).balanceOf(proxyAddress));
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress), 10000 ether);

        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        // time is ok
        vm.warp(16 days);
        // prank admin
        vm.prank(factoryAdmin);
        // it will revert cuz proxy is not deployed yet
        vm.expectRevert(ProxyFactory.ProxyFactory__ProxyIsNotAContract.selector);
        proxyFactory.distributeByOwner(organizer, randomId, address(distributor), dataToSendToAdmin);
    }

    ///////////////////////////
    ///// getProxyAddress /////
    ///////////////////////////

    function testGetProxyAddressRevertsIfDoesntExist() public {
        bytes32 randomId = keccak256(abi.encode("NotRegistered", "000"));
        bytes32 salt = keccak256(abi.encode(organizer, randomId, address(distributor)));
        vm.expectRevert(ProxyFactory.ProxyFactory__ContestIsNotRegistered.selector);
        proxyFactory.getProxyAddress(salt, address(distributor));
    }

    //////////////////////////
    ///// stadiumAddress /////
    //////////////////////////

    function testCanGetStadiumAddress() public {
        address stadiumAddressGot = proxyFactory.stadiumAddress();
        assertEq(stadiumAddressGot, stadiumAddress);
    }

    function testOwnerCanSetStadiumAddress() public {
        address newStadiumAddress = address(0x123);
        vm.prank(factoryAdmin);
        proxyFactory.setStadiumAddress(newStadiumAddress);
        address stadiumAddressGot = proxyFactory.stadiumAddress();
        assertEq(stadiumAddressGot, newStadiumAddress);
    }

    function testNonownerCannotSetStadiumAddress() public {
        address newStadiumAddress = address(0x123);
        address newStadiumAddress2 = makeAddr("NEW_STADIUM_ADDRESS");
        vm.prank(organizer);
        vm.expectRevert("Ownable: caller is not the owner");
        proxyFactory.setStadiumAddress(newStadiumAddress);
        vm.prank(supporter);
        vm.expectRevert("Ownable: caller is not the owner");
        proxyFactory.setStadiumAddress(newStadiumAddress2);
        address stadiumAddressGot = proxyFactory.stadiumAddress();
        assertEq(stadiumAddressGot, stadiumAddress);
        assertFalse(stadiumAddressGot == newStadiumAddress);
    }

    function testIfStadiumAddressIsSetAsZeroInConstructorThenRevert() public {
        address zeroStadiumAddress = address(0x0);
        (, jpycv2Address, usdcAddress,,) = config.activeNetworkConfig();
        address[] memory tokensToWhitelist = new address[](2);
        // whitelist 3 kinds of tokens
        tokensToWhitelist[0] = jpycv2Address;
        tokensToWhitelist[1] = usdcAddress;
        for (uint256 i; i < tokensToWhitelist.length; ++i) {
            if (tokensToWhitelist[i] != address(0)) {
                finalTokensToWhitelist.push(tokensToWhitelist[i]);
            }
        }
        vm.expectRevert(ProxyFactory.ProxyFactory__NoZeroAddress.selector);
        new ProxyFactory(finalTokensToWhitelist, zeroStadiumAddress);
    }
}
