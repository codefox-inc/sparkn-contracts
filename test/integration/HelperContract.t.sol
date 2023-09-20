// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {MockERC20} from "../mock/MockERC20.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ProxyFactory} from "../../src/ProxyFactory.sol";
import {Proxy} from "../../src/Proxy.sol";
import {Distributor} from "../../src/Distributor.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployContracts} from "../../script/DeployContracts.s.sol";
import {ERC1271WalletMock, ERC1271MaliciousMock} from "openzeppelin/mocks/ERC1271WalletMock.sol";

abstract contract HelperContract is Test {
    // 3 main contracts
    ProxyFactory public proxyFactory;
    Proxy public proxy;
    Distributor public distributor;

    // distributor instance through proxy address
    Distributor public proxyWithDistributorLogic;

    // EIP1271 SmartContractWallet
    ERC1271WalletMock public SmartContractWallet;
    ERC1271WalletMock public SmartContractWallet2;

    // contract address for proxy which is deployed by proxy factory
    address public deployedProxy;

    // mock major erc20 tokens
    address public jpycv1Address;
    address public jpycv2Address;
    address public usdcAddress;
    address public usdtAddress;

    // helper
    HelperConfig public config;

    // users
    address public stadiumAddress = 0x1FBcd7D20155274DFD796343149D0FCA41338F14;
    address public factoryAdmin = 0xbe5b0d1386BE331080fbb2C8c517BAA148497D97;
    address public tokenMinter = makeAddr("tokenMinter");
    address public organizer = address(11);
    address public sponsor = address(12);
    address public supporter = address(13);
    address public user1 = address(14);
    address public user2 = address(15);
    address public user3 = address(16);

    // test signer's key pair when testing meta tx
    // **these are all for test. should never use these in production**
    // bytes32 internal constant _DEPLOY_AND_DISTRIBUTE_TYPEHASH =
        // keccak256("DeployAndDistribute(bytes32 contestId,bytes data)");
    bytes32 internal constant _DEPLOY_AND_DISTRIBUTE_TYPEHASH =
        keccak256("DeployAndDistribute(bytes32 contestId,address implementation,bytes data)");
    uint256 public constant TEST_SIGNER_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address public constant TEST_SIGNER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 public constant TEST_SIGNER_KEY2 = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address public constant TEST_SIGNER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    // constants
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant SMALL_STARTING_USER_BALANCE = 2 ether;

    // deployer key
    uint256 public deployerKey;

    // event
    // event in Proxy Factory
    event SetContest(
        address indexed organizer, bytes32 indexed contestId, uint256 closeTime, address indexed implementation
    );
    // event in Distributor
    event Distributed(address token, address[] winners, uint256[] percentages, bytes data);

    constructor() {
        DeployContracts deployContracts = new DeployContracts();
        (proxyFactory, distributor, config) = deployContracts.run();
        (jpycv1Address, jpycv2Address, usdcAddress, usdtAddress, deployerKey) = config.activeNetworkConfig();
        // 1. Deploy the ERC1271WalletMock contract
        SmartContractWallet = new ERC1271WalletMock(TEST_SIGNER); // Assuming factoryAdmin is the owner of the mock wallet
        SmartContractWallet2 = new ERC1271WalletMock(TEST_SIGNER2); // Assuming factoryAdmin is the owner of the mock wallet
    }
}
