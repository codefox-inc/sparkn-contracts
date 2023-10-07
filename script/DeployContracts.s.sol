// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {Distributor} from "../src/Distributor.sol";
import {Proxy} from "../src/Proxy.sol";
import {ProxyFactory} from "../src/ProxyFactory.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployContracts is Script {
    // contract instance
    ProxyFactory public proxyFactory;
    
    // tokens' array to whitelist
    // satadium_address = 0x5aB0ffF1a51ee78F67247ac0B90C8c1f1f54c37F
    address[] public finalTokensToWhitelist;
    address public avalancheStadiumAddress = vm.envAddress("MAINNET_STADIUM_ADDRESS"); // SPARKN STADDIUM
    address public stadiumAddress = vm.envAddress("STADIUM_ADDRESS"); // SPARKN STADDIUM
    address public factoryAdmin = vm.envAddress("SPARKN_DEV"); // SPARKN DEV
    address public jpycv1Address;
    address public jpycv2Address;
    address public usdcAddress;
    // address public usdtAddress;
    uint256 public deployerKey;

    function run() external returns (ProxyFactory, Distributor, HelperConfig) {
        // set up config
        HelperConfig config = new HelperConfig();
        if (block.chainid == 43114 || block.chainid == 43113) {
            // get the addresses of the tokens to whitelist
            (,jpycv2Address, usdcAddress,, deployerKey) =
                config.activeNetworkConfig();
            address[] memory tokensToWhitelist = new address[](2);
            // whitelist 3 kinds of tokens
            tokensToWhitelist[0] = jpycv2Address;
            tokensToWhitelist[1] = usdcAddress;
            for (uint256 i; i < tokensToWhitelist.length; ++i) {
                if (tokensToWhitelist[i] != address(0)) {
                    finalTokensToWhitelist.push(tokensToWhitelist[i]);
                }
            }
        } else {
            // get the addresses of the tokens to whitelist
            (jpycv1Address, jpycv2Address, usdcAddress,, deployerKey) =
                config.activeNetworkConfig();
            address[] memory tokensToWhitelist = new address[](3);
            // whitelist 3 kinds of tokens
            tokensToWhitelist[0] = jpycv1Address;
            tokensToWhitelist[1] = jpycv2Address;
            tokensToWhitelist[2] = usdcAddress;
            for (uint256 i; i < tokensToWhitelist.length; ++i) {
                if (tokensToWhitelist[i] != address(0)) {
                    finalTokensToWhitelist.push(tokensToWhitelist[i]);
                }
            }
        }

        // console.log("finalTokensToWhitelist length:", finalTokensToWhitelist.length);
        // console.log("tokensToWhitelist: %s", tokensToWhitelist[0]);
        // console.log("tokensToWhitelist: %s",  tokensToWhitelist[1]);
        // console.log("tokensToWhitelist: %s", tokensToWhitelist[2]);
        // console.log("deployerKey: %s", deployerKey);

        vm.startBroadcast(deployerKey); // prank
        // console.log("Deploying contracts...sender: ", msg.sender);
        if (block.chainid == 43114 ) {
            proxyFactory = new ProxyFactory(finalTokensToWhitelist, avalancheStadiumAddress);
        } else {
            proxyFactory = new ProxyFactory(finalTokensToWhitelist, stadiumAddress);
        }
        // console.log("proxyFactory Owner: %s", proxyFactory.owner());
        // console.log("address this: %s", address(this));
        // console.log("address deployerKey: %s", deployerKey);
        // console.log("address factoryAdmin: %s", factoryAdmin);
        
        // do this when it is in local test
        // TODO: now the prod cases only include testnet and mainnet of avalanche
        if (block.chainid != 43114 && block.chainid != 43113) {
            // console.log("Deploying contracts...sender: ", msg.sender);
            proxyFactory.transferOwnership(factoryAdmin);
        }
        // console.log("After transferring, proxyFactory Owner: %s", proxyFactory.owner());

        // deploy distributor - implementation contract
        // 5% as starting fee as constant value
        Distributor distributor = new Distributor(address(proxyFactory));

        vm.stopBroadcast();

        return (proxyFactory, distributor, config);
    }
}
