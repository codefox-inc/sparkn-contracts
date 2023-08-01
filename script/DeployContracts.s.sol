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
    address public stadiumAddress = makeAddr("stadium");
    address public factoryAdmin = makeAddr("factoryAdmin");

    function run() external returns (ProxyFactory, Distributor, HelperConfig) {
        // set up config
        HelperConfig config = new HelperConfig();
        // get the addresses of the tokens to whitelist
        (address jpycv1Address, address jpycv2Aaddress, address usdcAddress, uint256 deployerKey) =
            config.activeNetworkConfig();
        address[] memory tokensToWhitelist = new address[](3);
        tokensToWhitelist[0] = jpycv1Address;
        tokensToWhitelist[1] = jpycv2Aaddress;
        tokensToWhitelist[2] = usdcAddress;

        console.log("tokensToWhitelist: %s", tokensToWhitelist[0]);
        console.log("tokensToWhitelist: %s",  tokensToWhitelist[1]);
        console.log("tokensToWhitelist: %s", tokensToWhitelist[2]);
        console.log("deployerKey: %s", deployerKey);


        vm.startBroadcast(deployerKey); // prank
        ProxyFactory proxyFactory = new ProxyFactory(tokensToWhitelist);
        console.log("proxyFactory Owner: %s", proxyFactory.owner());
        console.log("address this: %s", address(this));
        console.log("address deployerKey: %s", deployerKey);
        console.log("address factoryAdmin: %s", factoryAdmin);
        proxyFactory.transferOwnership(factoryAdmin);
        console.log("After transferring, proxyFactory Owner: %s", proxyFactory.owner());

        // deploy distributor - implementation contract
        // 5% as starting fee
        Distributor distributor = new Distributor(address(proxyFactory), stadiumAddress, 500);
        // no need to deploy proxies in the beginning
        // Proxy proxyA = proxyFactory.deployProxy(address(distributor));
        // Proxy proxyB = proxyFactory.deployProxy(address(distributor));
        // Proxy proxyC= proxyFactory.deployProxy(address(distributor));
        vm.stopBroadcast();

        return (proxyFactory, distributor, config);
    }
}
