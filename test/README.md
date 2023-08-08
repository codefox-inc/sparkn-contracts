# Target Contracts
- `ProxyFactory.sol`
- `Proxy.sol`
- `Distributor.sol`

# Tests' Description
All tests are written in Solidity based on Foundry.    
Tests consist of unit test, integration test, and fuzzing test.   
After their own test setups, tests are done in the individual test cases.

tests notes: 
- Consider both the expected test cases and unexpected test cases
- Make test coverage 100% if possible
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
- `constructor`
  - if commission fee is out of range, then revert
  - if factory address is address(0), then revert
  - if stadium address is address(0), then revert
  - if both addresses both are address(0), then revert
- `getConstants`
  - test the constant values returned are right
  - calls `distribute` will revert

#### `OnlyProxyTest.t.sol`
- `fallback`
  - If calling function doesn't exist, then revert
  - If calling function doesn't exist, then revert (pattern2)
  - If send ether to the proxy address, if sent then revert


### Integration tests
#### `ProxyFactoryTest.t.sol`

- Setup is ok
  - all contracts is existing
  - balances are ok
  - owners are ok
  - whitelisted tokens are ok

- constant values
  - constant values are set correctly

- `constructor`
  - `_whitelistedTokens` is empty, then revert
  - `_whitelistedTokens` is not empty but it has address(0), then revert
  - `_whitelistedTokens` is not empty and it does not have address(0), then set the `_whitelistTokens` correctly
    - all the tokens are set correctly as the mapping value is `true`

- `setContest`
  -   `organizer` is address(0), then revert
  -   `implementation` is address(0), then revert
  -   `closeTime` is less than block.timestamp, then revert
  -   `closeTime` is more than block.timestamp + MAX_CONTEST_DURATION, then revert
  -   contestId is set (`saltToCloseTime[salt] != 0`), then revert
  -   Called by non-owner, then revert
  -   otherwise, set the contest `saltToCloseTime[salt]` correctly, and event is emitted correctly
-   common `modifier` and function are set
    -   `createData`, `createDataToSendToAdmin`, `setUpContestForJasonAndSentJpycv2Token`

- `deployProxyAndDsitribute`
  - "after the contest is set and then tokens has been sent to the proxy address"
  - call it with wrong contest id, then revert
  - close time is not reached, then revert
  - call it with wrong implementation, then revert
  - call it with wrong non-organizer account, then revert
  - call it with wrong data, then revert
  - `testSucceedsWhenConditionsAreMet`: right arguments, then deploy the proxy and distribute the tokens correctly

- `deployProxyAndDistributeBySignature`
  - if data is wrong, then revert
  - if salt is not right, then revert
    - msg.sender is not the owner

- `deployProxyAndDistributeByOwner`
  - "after the contest is set and then tokens has been sent to the proxy address."
    - it reverts if called by non-owner
    - it reverts if called with wrong contest id
    - it reverts if contest is not expired
    - it reverts if called with wrong implementation
    - it reverts if called with wrong orgainizer
    - it reverts if called with wrong data
    - `testSucceedsIfAllConditionsMet`: if all conditions met, then deploy the proxy and distribute the tokens correctly

- `dsitributeByOwner`
  - "after the contest is set and then tokens has been sent to the proxy address. The organizer deployed and distributed the tokens to the winners. we call this function."
    - it reverts if proxy address is zero address
    - it reverts if contest id is not right
    - it reverts if implementation is not right
    - it reverts if organizer argument is not right
    - it reverts if contest is not expired
    - it reverts if data is wrong
    - it reverts if caller is not owner
    - `testSucceedsIfAllConditionsMetDistributeByOwner`: above conditions met, then distribute the tokens correctly. -> owner distribute tokens

- `deployProxyAndDistributeBySignature`
  - "common signature creating function is used"
  - check if signer can be recovered from the signature 
  - check if signer2 can be recovered from the signature 
  - if signature is wrong and recovered address is not right then revert
  - if signature is right but contest is not registered then revert
  - if signature is right but contest is not expired then revert
  - if signature is right but implementation is wrong then revert
  - if signature is right but organizer is wrong then revert
  - `testIfAllConditionsMetThenSucceeds`: if all conditions are met, then it succeeds

- `getProxyAddress`
  - if salt doesn't exist, then revert
  - if salt is not 0, but implementation address is zero, then revert
  - if salt is not 0, and implementation address is not zero, then return the proxy address and it is not zero address 
  - check if the returned calculated proxy addresses matches the real ones. 


#### `ProxyTest.t.sol`
> We should test the proxy contract with the implementation contract here. 
> So we call proxy contract and trigger the logics on the `Distributor` contract.

- setup: deploy contracts: proxyFactory, distributor, mock tokens. And then mint tokens for the test users. Then labels the test users. 

- `constructor`
  - if `commission_fee` >10000, then revert
  - if `factory_address` is address(0), then revert
  - if `stadium_address` is address(0), then revert
  - if above conditions met, then set the immutable variables correctly
- `getConstants`
  - test the constant values are ok
- `distribute`
  - if the msg.sender is not the factory address, then revert
  - if token address is zero, then revert
  - if token address is not whitelisted, then revert
  - if arguments' length is not equal, then revert
  - if winners' length is zero, then revert
  - if total percentage is not correct, then revert
  - if all conditions are met, then call succeeds(with usdc)
  - if all conditions are met, then call succeeds(with jpycv2)
  - if no tokens to send, then revert

### Fuzzing tests


