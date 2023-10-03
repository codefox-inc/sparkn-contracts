// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {Distributor} from "../src/Distributor.sol";
import {Proxy} from "../src/Proxy.sol";
import {ProxyFactory} from "../src/ProxyFactory.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployContracts is Script {
    // tokens' array to whitelist
    // satadium_address = 0x5aB0ffF1a51ee78F67247ac0B90C8c1f1f54c37F
    address[] finalTokensToWhitelist;
    address public stadiumAddress = 0x1FBcd7D20155274DFD796343149D0FCA41338F14; // SPARKN STADDIUM
    address public factoryAdmin = 0xbe5b0d1386BE331080fbb2C8c517BAA148497D97; // SPARKN DEV

    function run() external returns (ProxyFactory, Distributor, HelperConfig) {
        // set up config
        HelperConfig config = new HelperConfig();
        // get the addresses of the tokens to whitelist
        (address jpycv1Address, address jpycv2Address, address usdcAddress,, uint256 deployerKey) =
            config.activeNetworkConfig();
        address[] memory tokensToWhitelist = new address[](3);
        // whitelist 3 kinds of tokens
        tokensToWhitelist[0] = jpycv1Address;
        tokensToWhitelist[1] = jpycv2Address;
        tokensToWhitelist[2] = usdcAddress;
        for (uint256 i; i < 3; ++i) {
            if (tokensToWhitelist[i] != address(0)) {
                finalTokensToWhitelist.push(tokensToWhitelist[i]);
            }
        }

        // console.log("finalTokensToWhitelist length:", finalTokensToWhitelist.length);
        // console.log("tokensToWhitelist: %s", tokensToWhitelist[0]);
        // console.log("tokensToWhitelist: %s",  tokensToWhitelist[1]);
        // console.log("tokensToWhitelist: %s", tokensToWhitelist[2]);
        // console.log("deployerKey: %s", deployerKey);

        vm.startBroadcast(deployerKey); // prank
        // console.log("Deploying contracts...sender: ", msg.sender);
        ProxyFactory proxyFactory = new ProxyFactory(finalTokensToWhitelist, stadiumAddress);
        // console.log("proxyFactory Owner: %s", proxyFactory.owner());
        // console.log("address this: %s", address(this));
        // console.log("address deployerKey: %s", deployerKey);
        // console.log("address factoryAdmin: %s", factoryAdmin);
        proxyFactory.transferOwnership(factoryAdmin);
        // console.log("After transferring, proxyFactory Owner: %s", proxyFactory.owner());

        // deploy distributor - implementation contract
        // 5% as starting fee
        Distributor distributor = new Distributor(address(proxyFactory));
        // no need to deploy proxies in the beginning
        // Proxy proxyA = proxyFactory.deployProxy(address(distributor));
        // Proxy proxyB = proxyFactory.deployProxy(address(distributor));
        // Proxy proxyC= proxyFactory.deployProxy(address(distributor));
        vm.stopBroadcast();

        return (proxyFactory, distributor, config);
    }
}
