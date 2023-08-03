# Test Description
## 1. Test setup
## `HelperConfig.s.sol`
Prepare the configuration parameter for deployment.
The configuration is based on the network. 

If the network is Anvil, 
- it will deploy mock ERC20 tokens or not it will write the network's specific token addresses into the `activeNetworkConfig`. 
- it will get the default Anvil private key as the deployer's private key. Or not it will get the private key from the env file. 

Script was written to support the following networks:
- Anvil
- Polygon
- Sepolia(not yet supported)

## `DeployContracts.s.sol`
Deploy the contracts based on the network. 

If the network is Anvil, 
- it will deploy mock ERC20 tokens and then the ProxyFactory, Distributor contracts. 
- or not it will use the token addresses on the network to deploy the ProxyFactory, Distributor contracts.



## 2. Test Cases
### Unit tests
#### `OnlyDistributorTest.t.sol` 

#### `OnlyProxyTest.t.sol`


### Integration tests
#### `ProxyFactoryTest.t.sol`
> Consider both the expected test cases and unexpected test cases

- Setup is ok
- constant value is set correctly
- owner is set correctly
- `constructor`
  - `_whitelistedTokens` is empty, then revert
  - `_whitelistedTokens` is not empty but it has address(0), then revert
  - `_whitelistedTokens` is not empty and it does not have address(0), then set the `_whitelistTokens` correctly
    - all the tokens are set correctly as the mapping value is `true`
- `setContest`
  -   `organizer` is address(0), then revert
  -   `implementation` is address(0), then revert
  -   `closeTime` is more than block.timestamp + MAX_CONTEST_DURATION, then revert
  -   `closeTime` is less than block.timestamp, then revert
  -   `saltToCloseTime[salt] != 0`, then revert
  -   Called by non-owner, then revert
  -   otherwise, set the contest `saltToCloseTime[salt]` correctly
  -   event emitted correctly
- `deployProxyAndDsitribute`
  - after the contest is set and then tokens has been sent to the proxy address. 
  - call it with wrong contest id, then revert
  - call it with wrong implementation, then revert
  - call it with wrong non-organizer account, then revert
  - call it with wrong data, then revert
  - right arguments, then deploy the proxy and distribute the tokens correctly
- `deployProxyAndDistributeBySignature`
  - if data is wrong, then revert
  - if salt is not right, then revert
    - msg.sender is not the owner
- `deployProxyAndDsitributeByOwner`
  - after the contest is set and then tokens has been sent to the proxy address. 
    - if proxy is address(0), then revert
    - if salt to closetime doens't exist, then revert
    - if salt to closetime is not ready, then revert
    - if all conditions met, then deploy the proxy and distribute the tokens correctly

- `dsitributeByOwner`
  - after the contest is set and then tokens has been sent to the proxy address. The organizer deployed and distributed the tokens to the winners. we call this function. 
    - if proxy is address(0), then revert
    - if salt is not there, then revert
    - if close time is not ready, then revert
    - if data is wrong, then revert
    - if caller is not owner, then revert
    - above conditions met, then distribute the tokens correctly. -> rescue tokens
- `getProxyAddress`
  - if salt is 0, then revert
  - if salt is not 0, but implementation address is zero, then revert
  - if salt is not 0, and implementation address is not zero, then return the proxy address correctly
  - check if the calculated proxy addresses matches the real ones. 
- `_deployProxy`
  - if the salt is used then revert
  - otherwise, deploy the proxy correctly
- `_distribute`
  - if the proxy is not deployed, then revert
  - if the data is not right, then revert
  - otherwise, distribute the tokens correctly
- `_calculateSalt`
  - internal function, no need to test


#### `ProxyTest.t.sol`
> Consider both the expected test cases and unexpected test cases
> We should test the proxy contract with the implementation contract here. 
> So we call proxy contract and trigger the logics on the `Distributor` contract.

- `constructor`
  - if `commission_fee` >10000, then revert
  - if `factory_address` is address(0), then revert
  - if `stadium_address` is address(0), then revert
  - if above conditions met, then set the immutable variables correctly
- 

### Fuzzing tests


