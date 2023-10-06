# Sparkn - Findings Report

🔗 [Link to the Official Report](https://www.codehawks.com/report/cllcnja1h0001lc08z7w0orxx)

# Table of contents

- ### [Contest Summary](#contest-summary)
- ### [Results Summary](#results-summary)
- ## High Risk Findings
  - [H-01. The same signature can be used in different `distribution` implementation causing that the caller who owns the signature, can distribute on unauthorized implementations](#H-01)
- ## Medium Risk Findings
  - [M-01. The `digest` calculation in `deployProxyAndDistributeBySignature` does not follow EIP-712 specification](#M-01)
  - [M-02. Blacklisted STADIUM_ADDRESS address cause fund stuck in the contract forever](#M-02)
  - [M-03. Malicious/Compromised organiser can reclaw all funds, stealing work from supporters](#M-03)
- ## Low Risk Findings
  - [L-01. If a winner is blacklisted on any of the tokens they can't receive their funds](#L-01)
  - [L-02. Owner can incorrectly pull funds from contests not yet expired](#L-02)
  - [L-03. Lack of checking the existence of the Proxy contract](#L-03)
  - [L-04. Signature missing nonce & expiration deadline](#L-04)
  - [L-05. Precision loss/Rounding to Zero in `_distribute()`](#L-05)
  - [L-06. Potential DOS due to Gas Exhaustion Due to Large Array Iteration in `_distribute` Function](#L-06)
  - [L-07. Centralization Risk for trusted organizers](#L-07)
  - [L-08. DAI Tokens at Risk Due to Lack of address(0) Check in distribute](#L-08)
  - [L-09. Missing Events ](#L-09)
  - [L-10. Using basis points for percentage is not precise enough for realistic use-cases](#L-10)
  - [L-11. Insufficient validation leads to locking up prize tokens forever](#L-11)
  - [L-12. Organizers are not incentivized to deploy and distribute to winners causing that winners may not to be rewarded for a long time and force the protocol owner to manage the distribution](#L-12)

# <a id='contest-summary'></a>Contest Summary

### Sponsor: CodeFox Inc.

### Dates: Aug 21st, 2023 - Aug 29th, 2023

[See more contest details here](https://www.codehawks.com/contests/cllcnja1h0001lc08z7w0orxx)

# <a id='results-summary'></a>Results Summary

### Number of findings:

- High: 1
- Medium: 3
- Low: 12

# High Risk Findings

## <a id='H-01'></a>H-01. The same signature can be used in different `distribution` implementation causing that the caller who owns the signature, can distribute on unauthorized implementations

_Submitted by [pep7siup](/profile/clktaa8x50014mi08472cywse), [carrotsmuggler](/profile/clkdvewih0000l909yza1oaop), [nmirchev8](/profile/clkao1p090000ld08dv6v2xus), [alexfilippov314](/profile/cllj8zfsb0005ji08cjnwcjeb), [Cosine](/profile/clkc7trh30004l208e0okerdn), [0xbepresent](/profile/clk8nnlbx000oml080k0lz7iy), [CMierez](/profile/clk4745x3002ila08qg7e6iht), [dacian](/profile/clk6xnjxv0008jy083fc2mhsb), [sobieski](/profile/clk7551e0001ol408rl4fyi5s), [VanGrim](/profile/clk4qptxe000omr08zq645r4e), [jonatascm](/profile/clk83zqs2000gjp08eg935k0n), [zach030](/profile/clllg9trq0002ml0881bhkegb), [Madalad](/profile/clki3uj3i0000l508carwkhuh), [Agkistrodon](/profile/clllcn5hc0000jp088c4q96z2), [ACai](/profile/cllnqyfu5000wjp08fjbxd4jo), [toshii](/profile/clkkffr6v0008mm0866fnnu0a), [0x4non](/profile/clk3udrho0004mb08dm6y7y17), [alra](/profile/clku0tgdq0012mj08rwqxg012), [Silver Hawks](/team/clls309ju0001l808qq0qtpa4), [honeymewn](/profile/clk4hhuqi0008mk08x47ah4w4), [yixxas](/profile/clk41dbwf003omb08jmsdfb4q), [golanger85](/profile/clk9gmt880000mj08xc8hw7ng), [ubermensch](/profile/clk57krwm000el208ftidfc13), [dipp](/profile/clkwy9h2i0070mj08yhryut5w), [pontifex](/profile/clk3xo3e0000omm08i6ehw2ae), [serialcoder](/profile/clkb309g90008l208so2bzcy6), [maanas](/profile/clkrry2zj001cjm08l5m222l6). Selected submission by: [0xbepresent](/profile/clk8nnlbx000oml080k0lz7iy)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L159

## Summary

The same signature can be used in different `distribute` implementations causing that the caller who owns the signature, to distribute on unauthorized implementations.

## Vulnerability Details

The [ProxyFactory::setContest()](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L105) function helps to configure a `closeTime` to specific `organizer`, `contestId` and `implementation`.

```solidity
File: ProxyFactory.sol
105:     function setContest(address organizer, bytes32 contestId, uint256 closeTime, address implementation)
106:         public
107:         onlyOwner
...
...
113:         bytes32 salt = _calculateSalt(organizer, contestId, implementation);
114:         if (saltToCloseTime[salt] != 0) revert ProxyFactory__ContestIsAlreadyRegistered();
115:         saltToCloseTime[salt] = closeTime;
```

The caller who owns the signature, can distributes to winners using the [deployProxyAndDistributeBySignature()](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L152) function. The problem is that the hash in the code line ([#159](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L159)) does not consider the `implementation` parameter.

```solidity
File: ProxyFactory.sol
152:     function deployProxyAndDistributeBySignature(
153:         address organizer,
154:         bytes32 contestId,
155:         address implementation,
156:         bytes calldata signature,
157:         bytes calldata data
158:     ) public returns (address) {
159:         bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(contestId, data)));
160:         if (ECDSA.recover(digest, signature) != organizer) revert ProxyFactory__InvalidSignature();
161:         bytes32 salt = _calculateSalt(organizer, contestId, implementation);
162:         if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
163:         if (saltToCloseTime[salt] > block.timestamp) revert ProxyFactory__ContestIsNotClosed();
164:         address proxy = _deployProxy(organizer, contestId, implementation);
165:         _distribute(proxy, data);
166:         return proxy;
167:     }
```

For some reason, there could be a different `distribution` implementation to the same `contestId`. Then the caller who owns the signature can distribute even if the organizer does not authorize a signature to the new implementation.

I created a test where the caller who owns a signature can distribute to new `distribute implementation` using the same signature. Test steps:

1. Owner setContest using the implementation `address(distributor)`
2. Organizer creates a signature.
3. Caller distributes prizes using the signature.
4. For some reason there is a new distributor implementation. The Owner set the new distributor for the same `contestId`.
5. The caller can distribute prizes using the same signature created in the step 2 in different distributor implementation.

```solidity
// test/integration/ProxyFactoryTest.t.sol:ProxyFactoryTest
// $ forge test --match-test "testSignatureCanBeUsedToNewImplementation" -vvv
//
    function testSignatureCanBeUsedToNewImplementation() public {
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
        MockERC20(jpycv2Address).transfer(proxyAddress, 10000 ether);
        vm.stopPrank();
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress), 10000 ether);
        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether);
        //
        // 2. Organizer creates a signature
        (bytes32 digest, bytes memory sendingData, bytes memory signature) = createSignatureByASigner(TEST_SIGNER_KEY);
        assertEq(ECDSA.recover(digest, signature), TEST_SIGNER);
        vm.warp(8.01 days);
        //
        // 3. Caller distributes prizes using the signature
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, contestId, address(distributor), signature, sendingData
        );
        // after
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 9500 ether);
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 500 ether);
        //
        // 4. For some reason there is a new distributor implementation.
        // The Owner set the new distributor for the same contestId
        Distributor new_distributor = new Distributor(address(proxyFactory), stadiumAddress);
        vm.startPrank(factoryAdmin);
        proxyFactory.setContest(organizer, contestId, block.timestamp + 8 days, address(new_distributor));
        vm.stopPrank();
        bytes32 newDistributorSalt = keccak256(abi.encode(organizer, contestId, address(new_distributor)));
        address proxyNewDistributorAddress = proxyFactory.getProxyAddress(newDistributorSalt, address(new_distributor));
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyNewDistributorAddress, 10000 ether);
        vm.stopPrank();
        //
        // 5. The caller can distribute prizes using the same signature in different distributor implementation
        vm.warp(20 days);
        proxyFactory.deployProxyAndDistributeBySignature(
            TEST_SIGNER, contestId, address(new_distributor), signature, sendingData
        );
    }
```

## Impact

The caller who owns the signature, can distribute the prizes for a new distribution implementation using the same signature which was created for an old implementation.
The `organizer` must create a new signature if there is a new implementation for the same `contestId`. The authorized signature is for one distribution implementation not for the future distribution implementations.

## Tools used

Manual review

## Recommendations

Include the `distribution implementation` in the [signature hash](https://github.com/Cyfrin/2023-08-sparkn/blob/main/src/ProxyFactory.sol#L159).

```diff
    function deployProxyAndDistributeBySignature(
        address organizer,
        bytes32 contestId,
        address implementation,
        bytes calldata signature,
        bytes calldata data
    ) public returns (address) {
--      bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(contestId, data)));
++      bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(contestId, implementation, data)));
```

# Medium Risk Findings

## <a id='M-01'></a>M-01. The `digest` calculation in `deployProxyAndDistributeBySignature` does not follow EIP-712 specification

_Submitted by [nmirchev8](/profile/clkao1p090000ld08dv6v2xus), [0x6980](/profile/cllkfri9u0000mc082h22s645), [CMierez](/profile/clk4745x3002ila08qg7e6iht), [maanas](/profile/clkrry2zj001cjm08l5m222l6), [T1MOH](/profile/clk8mb22u001smg085mix29s8), [97Sabit](/profile/clk42eeq0007mla08lc11yszp), [arnie](/profile/clk4gbnc30000mh088nl2a5i4), [RugpullDetector](/profile/clknpmzwp0014l608wk9hflu6), [Silver Hawks](/team/clls309ju0001l808qq0qtpa4), [qpzm](/profile/cllu8b144000gjs08aolwd6rr). Selected submission by: [CMierez](/profile/clk4745x3002ila08qg7e6iht)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L159

## Summary

The calculation of the `digest` done in [`ProxyFactory.deployProxyAndDistributeBySignature()`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L159) does not follow the [EIP-712 specification](https://eips.ethereum.org/EIPS/eip-712). It is missing the function's corresponding `typeHash`, as well as the `hashStruct` calculation of the `data` signature parameter, which are both defined in the EIP.

Not following the EIP specification will end up in unexpected integration failures with EIP712-compliant wallets or tooling that perform the encoding in the appropriate way.

## Vulnerability Details

In [`ProxyFactory.deployProxyAndDistributeBySignature()`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L159), the `digest` is calculated as follows:

```solidity
bytes32 digest = _hashTypedDataV4(
    keccak256(
        abi.encode(contestId, data)
    )
);
```

The [EIP-712 specification](https://eips.ethereum.org/EIPS/eip-712#specification) defines the encoding of a message as:

```
"\x19\x01" ‖ domainSeparator ‖ hashStruct(message)
```

In the current implementation, `"\x19\x01"` and `domainSeparator` are correctly calculated and appended as per OpenZeppelin's `_hashTypedDataV4()` function, but `hashStruct(message)` is not respected.

The EIP defines that the `hashStruct` of a message is calculated from the hashing of the **typeHash** and the encoding of the data; and the former is currently missing in the `digest` calculation.

Additionally, the `data` parameter which is being included as part of the signature, is a `bytes` type, which the EIP defines as **Dynamic**. Dynamic types [are encoded as the hash of the contents](https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata); and currently the `data` parameter is being encoded as-is.

## Impact

The data being signed is not being encoded as per the EIP-712 specification, which will result in unexpected integration failures with EIP712-compliant wallets or tooling that perform the encoding in the appropriate way.

After looking at the tests, I would say this error was not caught since the tests themselves follow the same exact implementation for creating the data being signed. Usage of external libraries such as Ethers.js would have likely revealed this issue earlier.

## Tools Used

Manual Review

## Recommendations

### Define and use the `typeHash` of the function.

- Define the `typeHash`

```solidity
bytes32 internal constant DEPLOY_AND_DISTRIBUTE_TYPEHASH = keccak256(
    "DeployAndDistribute(bytes32 contestId,bytes data)"
);
```

- Include it in the `digest` calculation

```solidity
bytes32 digest = _hashTypedDataV4(
    keccak256(
        abi.encode(
            DEPLOY_AND_DISTRIBUTE_TYPEHASH,
            contestId,
            ...
        )
    )
);
```

### Encode the dynamic `data` parameter as per the EIP-712 specification.

```solidity
bytes32 digest = _hashTypedDataV4(
    keccak256(
        abi.encode(
            DEPLOY_AND_DISTRIBUTE_TYPEHASH,
            contestId,
            keccak256(data)
        )
    )
);
```

## <a id='M-02'></a>M-02. Blacklisted STADIUM_ADDRESS address cause fund stuck in the contract forever

_Submitted by [pep7siup](/profile/clktaa8x50014mi08472cywse), [dontonka](/profile/cllks1uim0000lh0855te4x9o), [bronzepickaxe](/profile/clk85kzum0008l9086dj0suek), [imkapadia](/profile/cllf36tub0000mb08a96bksxy), [DevABDee](/profile/clk5eknoz0000l308ney23msz), [thekmj](/profile/clky06cav0014l608rjnjz31m), [InAllHonesty](/profile/clkgm90b9000gms085g528phk), [33BYTEZZZ](/team/cllkeajr60001ky08s6vx5ig7), [Kose](/profile/clk3whc2g0000mg08zp13lp1p), [Madalad](/profile/clki3uj3i0000l508carwkhuh), [castleChain](/profile/clk48to2u004wla08041jl9ld), [Aamirusmani1552](/profile/clk6yhrt6000gmj082jnn4770), [Tripathi](/profile/clk3xe9tk0024l808xjc9wkg4), [0x4non](/profile/clk3udrho0004mb08dm6y7y17), [crippie](/profile/clkitmhs50000l508e5tvl2w2), [Cosine](/profile/clkc7trh30004l208e0okerdn), [Silver Hawks](/team/clls309ju0001l808qq0qtpa4), [0xhals](/profile/clkfub7qh0002l508bt5xdugv), [tsar](/profile/clk9isayj0004l30847ln1e8j), [radeveth](/profile/clk406c5j0008jl08i3ojs45y), [dipp](/profile/clkwy9h2i0070mj08yhryut5w), [MrjoryStewartBaxter](/profile/clk6xkrq00008l708g23xstn9), [serialcoder](/profile/clkb309g90008l208so2bzcy6). Selected submission by: [pep7siup](/profile/clktaa8x50014mi08472cywse)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/tree/main/src/Distributor.sol#L164

## Summary

The vulnerability relates to the immutability of `STADIUM_ADDRESS`. If this address is blacklisted by the token used for rewards, the system becomes unable to make transfers, leading to funds being stuck in the contract indefinitely.

## Vulnerability Details

1. Owner calls `setContest` with the correct `salt`.
2. The Organizer sends USDC as rewards to a pre-determined Proxy address.
3. `STADIUM_ADDRESS` is blacklisted by the USDC operator.
4. When the contest is closed, the Organizer calls `deployProxyAndDistribute` with the registered `contestId` and `implementation` to deploy a proxy and distribute rewards. However, the call to `Distributor._commissionTransfer` reverts at Line 164 due to the blacklisting.
5. USDC held at the Proxy contract becomes stuck forever.

```solidity
// Findings are labeled with '<= FOUND'
// File: src/Distributor.sol
116:    function _distribute(address token, address[] memory winners, uint256[] memory percentages, bytes memory data)
117:        ...
154:        _commissionTransfer(erc20);// <= FOUND
155:        ...
156:    }
				...
163:    function _commissionTransfer(IERC20 token) internal {
164:        token.safeTransfer(STADIUM_ADDRESS, token.balanceOf(address(this)));// <= FOUND: Blacklisted STADIUM_ADDRESS address cause fund stuck in the contract forever
165:    }
```

## Impact

This vulnerability is marked as High severity because a blacklisted `STADIUM_ADDRESS` would lead to funds being locked in the Proxy address permanently. Funds are already held in the Proxy, and the Proxy's `_implementation` cannot be changed once deployed. Even the `ProxyFactory.distributeByOwner()` function cannot rescue the funds due to the revert.

## Tools Used

Manual Review

## Recommendations

It is recommended to allow `STADIUM_ADDRESS` to be updatable by a dedicated admin role to avoid token transfer blacklisting. Moreover, since `STADIUM_ADDRESS` is no longer `immutable`, `storage` collision should be taken into account.

## <a id='M-03'></a>M-03. Malicious/Compromised organiser can reclaw all funds, stealing work from supporters

_Submitted by [0xch13fd357r0y3r](/profile/clk71r4q20000jt08dj5q6woc), [0xdeth](/profile/clk4azr2z0010lb083ci6ih4j), [sv ](/team/cllj8y8f40001ji08wzcyijzr), [InAllHonesty](/profile/clkgm90b9000gms085g528phk), [GoSoul22](/profile/clk7zkyd70002l608iam3ggtg), [0xnevi](/profile/clk3twjk3003imj08kmy05ubk), [savi0ur](/profile/clk3w8t380018kx08f8kzzk3f), [Bughunter101](/profile/clkau4y560006l908gxfcec8y), [SBSecurity](/team/clkuz8xt7001vl608nphmevro), [0x3b](/profile/clk3yiyaq002imf088cd3644k), [cats](/profile/clkpcyd8s0000mm08gto4lwp7), [nisedo](/profile/clk3saar60000l608gsamuvnw), [MrjoryStewartBaxter](/profile/clk6xkrq00008l708g23xstn9), [KiteWeb3](/profile/clk9pzw3j000smh08313lj91l), [Soliditors](/team/clll907ei0001mh08zevvaoze), [DevABDee](/profile/clk5eknoz0000l308ney23msz), [Phantasmagoria](/profile/clki6y71n000gkx088cowa4hq), [Breeje](/profile/clk41ow6c0066la0889fuw52t), [y4y](/profile/cllq879u70000mo08o0n110vi), [VanGrim](/profile/clk4qptxe000omr08zq645r4e), [0xanmol](/profile/clkp3qzse000yl508z8ia3dby), [Madalad](/profile/clki3uj3i0000l508carwkhuh), [FalconHoof](/profile/clkcm5dsf0000mc083q6clddz), [shikhar229169](/profile/clk3yh639002emf08ywok1hzf), [TheSchnilch](/profile/clk89mhkb0002mk080c64z7b8), [0xDetermination](/profile/clkucgb400000lg08vdq5ckvz), [ABA](/profile/clk43rqfo0008mg084q0ema3g), [Aamirusmani1552](/profile/clk6yhrt6000gmj082jnn4770), [zigtur](/profile/clknjcwb00000me08tsnr970w), [ke1caM](/profile/clk46fjfm0014la08xl7mwtis), [t0x1c](/profile/clk7rcevn0004jn08o2n2g1a5), [Stoicov](/profile/clk43h7he008ymb08nk4eu446), [arnie](/profile/clk4gbnc30000mh088nl2a5i4), [0xMosh](/profile/clkab3oww0000kx08tbfkdxab), [SAAJ](/profile/cllq1yz0u0004ju08019ho5a7), [AkiraKodo](/profile/clk8ejhzv000emm08earxxzdr), [owade](/profile/clk9j4mf20002mi08k4758eni), [honeymewn](/profile/clk4hhuqi0008mk08x47ah4w4), [coolboymsk](/profile/cllo0aag70000l008c6vxf8x3), [Maroutis](/profile/clkctygft000il9088nkvgyqk), [0xScourgedev](/profile/clkj0r4v30000l5085winknb6), [0x11singh99](/profile/clkhsr7bn0000l608c9vc7ugr). Selected submission by: [Madalad](/profile/clki3uj3i0000l508carwkhuh)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/main/src/Distributor.sol#L116

## Summary

The contest details state that 'If a contest is created and funded, there is no way to refund. All the funds belong to the persons who wants to help solve the problem, we call them "supporters".' (see More Context section). This is untrue, as the organizer is able to refund all of the contest funds.

## Vulnerability Details

In `Distributor#_distribute`, there is no input validation on the `winners` array. A malicious or compromised organizer can, with little effort, simply pass an array of length one containing a wallet address that they control as the `winners` parameter, and `[10000]` as the `percentages` parameter in order to receive 100% of the funds initially deposited to the contract. Due to the design of the protocol, they would have 7 days after the contest ends (the value of the `EXPIRATION_TIME` constant in the `ProxyFactory` contract) to perform this action without the owner being able to prevent it.

## Impact

Malicious/Compromised organizer can refund 100% of the contest funds, stealing work from sponsors.

## Tools Used

Manual review

## Recommendations

Use a two step procedure for distributing funds:

1. The organizer submits an array of winners and percentages to the `Proxy` contract and they are cached using storage variables
2. The owner of `ProxyFactor` (a trusted admin) checks the arrays to ensure the organizer is not distributing all of the money to themselves, and if satisfied, triggers the distribution of funds

This removes the risk of having to trust the organizer, and although it requires the trust of the admin, they were already a required trusted party and so the mitigation is beneficial overall. Also, this new system adds more truth to the statement from the contest details mentioned in the summary section of this report.

# Low Risk Findings

## <a id='L-01'></a>L-01. If a winner is blacklisted on any of the tokens they can't receive their funds

_Submitted by [ZedBlockchain](/profile/clk6kgukh0008ld088n5wns9l), [Giorgio](/profile/clk3t8gh1000iib08z1nz6equ), [InAllHonesty](/profile/clkgm90b9000gms085g528phk), [B353N](/profile/clk5cw0v6000ymq086uqalsn6), [MrjoryStewartBaxter](/profile/clk6xkrq00008l708g23xstn9), [pep7siup](/profile/clktaa8x50014mi08472cywse), [carrotsmuggler](/profile/clkdvewih0000l909yza1oaop), [kodyvim](/profile/clk9ly60q0004ml084a049be7), [castleChain](/profile/clk48to2u004wla08041jl9ld), [deadrosesxyz](/profile/clktuh7kc002qmd089uzpn87a), [dontonka](/profile/cllks1uim0000lh0855te4x9o), [Proxy](/profile/clk3x79a8000gmg083h7fjmul), [tsvetanovv](/profile/clk3x0ilz001ol808l9uu6vpj), [alymurtazamemon](/profile/clk3q1mog0000jr082dc9tipk), [bronzepickaxe](/profile/clk85kzum0008l9086dj0suek), [0xyPhilic](/profile/clk3wry0p0008mf08lbxjpcks), [oualidpro](/profile/clkn61ppo0008l6086a909pio), [kaliberpoziomka](/profile/clknz2nn10068l908msy0brst), [0x4ka5h](/profile/clkfqchia0000mm08zk59x1l1), [0x3b](/profile/clk3yiyaq002imf088cd3644k), [Arabadzhiev](/profile/clk3ymeds000kla08pkpjujtl), [Lalanda](/profile/clk44x5d0002amg08cqme5xh6), [crippie](/profile/clkitmhs50000l508e5tvl2w2), [Scoffield](/profile/cll10q0wm0000jx088qp7gads), [0xdraiakoo](/profile/clk3xadrc0020l808t9unuqkr), [Soliditors](/team/clll907ei0001mh08zevvaoze), [thekmj](/profile/clky06cav0014l608rjnjz31m), [Stoicov](/profile/clk43h7he008ymb08nk4eu446), [33BYTEZZZ](/team/cllkeajr60001ky08s6vx5ig7), [0xRizwan](/profile/clk7o7bq3000ome08az33iib2), [Polaristow](/profile/clk40hl6t000wmb08y3268i63), [VanGrim](/profile/clk4qptxe000omr08zq645r4e), [TorpedopistolIxc41](/profile/clk5ki3ah0000jq08yaeho8g7), [Madalad](/profile/clki3uj3i0000l508carwkhuh), [Kose](/profile/clk3whc2g0000mg08zp13lp1p), [ohi0b](/profile/clkzvg9p60008jn08qd0qm2x4), [kamui](/profile/clk8h2bxd000sia08o8nz21g2), [Tripathi](/profile/clk3xe9tk0024l808xjc9wkg4), [Maroutis](/profile/clkctygft000il9088nkvgyqk), [aslanbek](/profile/clk49k0iz0000me08szp3rh89), [ke1caM](/profile/clk46fjfm0014la08xl7mwtis), [Bauer](/profile/clkq7w3kv00awmr08rw8dmi8o), [Alhakista](/profile/clkafbp0m0000ld08d8nkb9wr), [Chinmay](/profile/clk56c7d80000mg08mvbluxgj), [trachev](/profile/clk59lxey0000jo08ps29253l), [arnie](/profile/clk4gbnc30000mh088nl2a5i4), [RugpullDetector](/profile/clknpmzwp0014l608wk9hflu6), [tsar](/profile/clk9isayj0004l30847ln1e8j), [0xMosh](/profile/clkab3oww0000kx08tbfkdxab), [Cryptic Snake REACH](/team/clkl8yzo70009mn08l4myjpwk), [Cosine](/profile/clkc7trh30004l208e0okerdn), [Cosmic Bee](/team/clluz5i110001l408fb380hg1), [0xsandy](/profile/clk43kus5009imb0830ko7dxy), [0xhals](/profile/clkfub7qh0002l508bt5xdugv), [smbv1923](/profile/clkp51djq001amy08d2e1slqf), [sm4rty](/profile/clk4170ln003amb088n137st7), [ubermensch](/profile/clk57krwm000el208ftidfc13), [golanger85](/profile/clk9gmt880000mj08xc8hw7ng), [honeymewn](/profile/clk4hhuqi0008mk08x47ah4w4), [radeveth](/profile/clk406c5j0008jl08i3ojs45y), [0xd3g3ns](/team/cllgihgzy0001jj08eo3xmioj), [Bauchibred](/profile/clk9ibj6p0002mh08c603lr2j), [SanketKogekar](/profile/clk3xu7fc0010mm08wnt4txcd), [0xScourgedev](/profile/clkj0r4v30000l5085winknb6), [0xlucky](/profile/cllvmhg1i0008md080shk9pzx). Selected submission by: [Bauchibred](/profile/clk9ibj6p0002mh08c603lr2j)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Distributor.sol#L144-L150

## Summary

Normally this would be a big issue since transfers are done in a loop to all winners _i.e all winners wouldn't be able to get their tokens_, but winners are chosen off chain and from [the Q&A section of SparkN onboarding video](https://www.youtube.com/watch?v=_VqXB1t9Evo) we can see that after picking a set of winners they can later on be changed, that's the set of winners.
This means that, reasonably, after an attempt to send the tokens to winners has been made and it reverts due to one or a few of the users being in the blacklist/blocklist of USDC/USDT, the set of winners can just be re-chosen without the blacklisted users, now whereas that helps other users from having their funds locked in the contract, this unfairly means that the blacklisted users would lose their earned tokens, since their share must be re-shared to other winners to cause [this](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Distributor.sol#L134-L137) not to revert

```solidity
        if (totalPercentage != (10000 - COMMISSION_FEE)) {
            revert Distributor__MismatchedPercentages();
        }
```

## Vulnerability Detail

See summary

Additionally note that, the contest readMe's section has indicated that that general stablecoins would be used... _specifically hinting USDC, DAI, USDT & JPYC_,

Now important is to also keep in mind that https://github.com/d-xo/weird-erc20#tokens-with-blocklists shows that:

> Some tokens (e.g. USDC, USDT) have a contract level admin controlled address blocklist. If an address is blocked, then transfers to and from that address are forbidden.

## Impact

Two impacts, depending on how SparkN decides to sort this out, either:

- All winners funds ends up stuck in contract if sparkN doesn't want to change the percentages of each winner by setting that of blacklisted users to zero and sharing their percentages back in the pool

- Some users would have their funds unfairly given to other users

## Tool used

Manual Audit

## Recommendation

Consider introducing a functionality that allows winners to specify what address they'd like to be paid, that way even a blocklisted account can specify a different address he/she owns, this case also doesn't really sort this as an attacker could just send any blacklisted address to re-grief the whole thing, so a pull over push method could be done to transfer rewards to winners

### Additional Note

With this attack window in mind, if a pull method is going to be used then the `_commisionTransfer()` function needs to be refactored to only send the commision.

## <a id='L-02'></a>L-02. Owner can incorrectly pull funds from contests not yet expired

_Submitted by [meetm](/profile/cll6mnnq9000gmh0882sjbvr5), [klaus](/profile/clkwlspwi002sk008f6i0bjvu), [t0x1c](/profile/clk7rcevn0004jn08o2n2g1a5), [kaliberpoziomka](/profile/clknz2nn10068l908msy0brst), [aviggiano](/profile/clk3yu8m7001kjq08r9a7wgsh), [alexfilippov314](/profile/cllj8zfsb0005ji08cjnwcjeb), [0x4ka5h](/profile/clkfqchia0000mm08zk59x1l1), [bowtiedvirus](/profile/cll8u5m8q0000mp08g99b0vd4), [Scoffield](/profile/cll10q0wm0000jx088qp7gads), [Agkistrodon](/profile/clllcn5hc0000jp088c4q96z2), [maanas](/profile/clkrry2zj001cjm08l5m222l6), [castleChain](/profile/clk48to2u004wla08041jl9ld), [ohi0b](/profile/clkzvg9p60008jn08qd0qm2x4), [Arabadzhiev](/profile/clk3ymeds000kla08pkpjujtl), [igorline](/profile/cllp9c6ff000gle089abjewde), [NoamYakov](/profile/clls526z90002mi08lhixricx), [toshii](/profile/clkkffr6v0008mm0866fnnu0a), [0xMosh](/profile/clkab3oww0000kx08tbfkdxab), [RugpullDetector](/profile/clknpmzwp0014l608wk9hflu6), [Tricko](/profile/clk69ooo50012ms08mzsngte2), [ryanjshaw](/profile/cllbcbf460000ky083lj6avsv), [sonny2k](/profile/clk51hohw0000mr08nfrnlewz), [Silver Hawks](/team/clls309ju0001l808qq0qtpa4), [0xhals](/profile/clkfub7qh0002l508bt5xdugv), [Rotcivegaf](/profile/clk3ziayk002ojq08apo5ojrt), [ubermensch](/profile/clk57krwm000el208ftidfc13), [serialcoder](/profile/clkb309g90008l208so2bzcy6). Selected submission by: [t0x1c](/profile/clk7rcevn0004jn08o2n2g1a5)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/main/src/ProxyFactory.sol#L195-L218

## Summary

Owner can incorrectly pull funds from a closed contest which has not yet expired using `distributeByOwner()`.

## Vulnerability Details

The `distributeByOwner()` function has 5 parameters: `proxy, organizer, contestId, implementation, data`. However, there is no 'linkage' between `proxy` and the remaining params. <br>
In order to check if the contest has expired, it uses `bytes32 salt = _calculateSalt(organizer, contestId, implementation);`. There is no check if this is indeed the salt of the `proxy` address. Hence, the owner can by mistake call `distributeByOwner()` with an incorrect `proxy` address of a contest which is closed, but not yet expired and drain its funds incorrectly.<br>
**PoC:** (run via `forge test --mt test_OwnerCanIncorrectlyPullFundsFromContestsNotYetExpired -vv`)

```js
    function test_OwnerCanIncorrectlyPullFundsFromContestsNotYetExpired() public {
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
        MockERC20(jpycv2Address).transfer(proxyAddress_1, 10000 ether);
        MockERC20(jpycv2Address).transfer(proxyAddress_2, 500 ether);
        vm.stopPrank();

        // before
        assertEq(MockERC20(jpycv2Address).balanceOf(user1), 0 ether, "user1 balance not zero");
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 0 ether, "STADIUM balance not zero");
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_1), 10000 ether, "proxy1 balance not 10000e18");
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_2), 500 ether, "proxy2 balance not 500e18");

        bytes memory data = createData();

        // 9 days later, organizer deploy and distribute -- for contest_1
        vm.warp(9 days);
        vm.prank(organizer);
        proxyFactory.deployProxyAndDistribute(randomId_1, address(distributor), data);
        // sponsor send token to proxy by mistake
        vm.prank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress_1, 11000 ether);

        // 11 days later, organizer deploy and distribute -- for contest_2
        vm.warp(11 days);
        vm.prank(organizer);
        proxyFactory.deployProxyAndDistribute(randomId_2, address(distributor), data);
        // sponsor send token to proxy by mistake
        vm.prank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress_2, 600 ether);

        // create data to send the token to admin
        bytes memory dataToSendToAdmin = createDataToSendToAdmin();

        // 16 days later from the start date, contest_1 has EXPIRED,
        // but contest_2 is only CLOSED, not "EXPIRED".
        // Hence, Owner should NOT be able to distribute rewards from funds reserved for contest_2.
        vm.warp(16 days);
        vm.prank(factoryAdmin);
        // Owner provides `proxyAddress_2` by mistake, but remaining params are for `contest_1`
        proxyFactory.distributeByOwner(proxyAddress_2, organizer, randomId_1, address(distributor), dataToSendToAdmin);
        // above call should have reverted with "ProxyFactory__ContestIsNotExpired()"

        // after
        // STADIUM balance has now become (5% of 10000) + (5% of 500) + 600
        assertEq(MockERC20(jpycv2Address).balanceOf(stadiumAddress), 1125 ether, "STADIUM balance not 1125e18");
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_1), 11000 ether, "proxy1 balance not 11000e18");
        // contest_2 is fully drained
        assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress_2), 0, "proxy2 balance not zero");
    }
```

The above is even more serious if Owner is _trying to return the funds to `sponsor1` using `distributeByOwner()`_. Sponsor1 will get Sponsor2's funds (95% of funds, at the most).<br>
**OR**<br>
If the owner, upon a request from the sponsor, is trying to distribute `contest_1's` extra funds deposited by the sponsor as rewards to its winners. These winners would be completely different from the winners of `contest_2`, but funds from `contest_2` will be redirected to "winner*1s".<br>
<br>
Noteworthy is the fact that once any sponsor deposits extra funds by mistake later on *(after proxy has been deployed via `deployProxyAndDistribute()` or similar functions & the rewards have been distributed once)\_ he can only take the help of the owner to send the funds to any specific address(es).

## Impact

- **Loss of funds** as it can be drained by the owner by mistake from a not-yet-expired contest.
- **Funds/Rewards could be sent to incorrect sponsor/winners**
- **Bypasses intended functionality**.

## Tools Used

Manual review, forge.

## Recommendations

Add the following line inside `distributeByOwner()`:

```
require(getProxyAddress(salt, implementation) == proxy);
```

## <a id='L-03'></a>L-03. Lack of checking the existence of the Proxy contract

_Submitted by [David77](/profile/clll3wigw0008mf08byd7jzzy), [0x6980](/profile/cllkfri9u0000mc082h22s645), [oualidpro](/profile/clkn61ppo0008l6086a909pio), [0x4ka5h](/profile/clkfqchia0000mm08zk59x1l1), [alymurtazamemon](/profile/clk3q1mog0000jr082dc9tipk), [0xker2](/profile/clkiaf26c0016l308ijfsvlh4), [castleChain](/profile/clk48to2u004wla08041jl9ld), [0xRizwan](/profile/clk7o7bq3000ome08az33iib2), [ZanyBonzy](/profile/clk9uu45r0000js08lnm9zbez), [Madalad](/profile/clki3uj3i0000l508carwkhuh), [Tripathi](/profile/clk3xe9tk0024l808xjc9wkg4), [NoamYakov](/profile/clls526z90002mi08lhixricx), [0x4non](/profile/clk3udrho0004mb08dm6y7y17), [0xGovinda732](/profile/clkdw9ev60000jw08m0zcw63e), [XVIronSec](/profile/clkpyocha0014l6081xrbs0wi), [sonny2k](/profile/clk51hohw0000mr08nfrnlewz), [lkjhgf](/profile/cllr55j6j0000mi08p85ybk45), [samshz](/profile/clkqsbvba000gjr096xpoyllk), [0xWeb3boy](/profile/clk570abt000ol508zaw2nolf), [Bube](/profile/clk3y8e9u000cjq08uw5phym7), [Silver Hawks](/team/clls309ju0001l808qq0qtpa4), [TheSchnilch](/profile/clk89mhkb0002mk080c64z7b8), [SAQ](/profile/clkftc56x0006le08usdp7epo), [golanger85](/profile/clk9gmt880000mj08xc8hw7ng), [serialcoder](/profile/clkb309g90008l208so2bzcy6). Selected submission by: [serialcoder](/profile/clkb309g90008l208so2bzcy6)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L217

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L250

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L252

## Summary

If the `ProxyFactory::distributeByOwner()` is executed before the `Proxy` contract has been deployed, the transaction will be executed successfully, but the stuck tokens will not be transferred to a rescue requestor.

## Vulnerability Details

The `distributeByOwner()` is used for recovering the rescue requestor's stuck tokens after a contest expires. The function will [trigger the `_distribute()`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L217) to execute the contest's `Proxy` contract.

The transaction will not be reverted as expected if the `Proxy` has not been deployed before calling the `distributeByOwner()`. In other words, the transaction will be executed successfully, but the stuck tokens will not be transferred to the rescue requestor.

The root cause is that the `_distribute()` will [make a low-level call to the `Proxy` without checking the existence of its contract](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L250).

```solidity
    function distributeByOwner(
        address proxy,
        address organizer,
        bytes32 contestId,
        address implementation,
        bytes calldata data
    ) public onlyOwner {
        if (proxy == address(0)) revert ProxyFactory__ProxyAddressCannotBeZero();
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        // distribute only when it exists and expired
        if (saltToCloseTime[salt] + EXPIRATION_TIME > block.timestamp) revert ProxyFactory__ContestIsNotExpired();
@>      _distribute(proxy, data);
    }

    ...

    function _distribute(address proxy, bytes calldata data) internal {
@>      (bool success,) = proxy.call(data);
        if (!success) revert ProxyFactory__DelegateCallFailed();
@>      emit Distributed(proxy, data);
    }
```

- `The distributeByOwner() triggers the _distribute()`: https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L217

- `The _distribute() makes a low-level call without checking the existence of the Proxy's contract`: https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L250

- `The event Distributed will be emitted regardless of whether the Proxy has a contract`: https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L252

## Impact

The `rescue` transaction will be executed successfully, but the stuck tokens will not be transferred to the rescue requestor. This incident can cause off-chain services to malfunction and confuse the owner (protocol admin) and the rescue requestor.

## Tools Used

Manual Review

## Recommendations

Verify that the target `Proxy`'s address has a contract bytecode before executing the `Proxy` in the `_distribute()`, as below.

```diff
+   import {Address} from "openzeppelin/utils/Address.sol";

    ...

    function _distribute(address proxy, bytes calldata data) internal {
+       if (!Address.isContract(proxy)) revert ProxyFactory__NoProxyContract();
        (bool success,) = proxy.call(data);
        if (!success) revert ProxyFactory__DelegateCallFailed();
        emit Distributed(proxy, data);
    }
```

## <a id='L-04'></a>L-04. Signature missing nonce & expiration deadline

_Submitted by [Daniel526](/profile/clk3zygt00028la08pxdzjdfp), [tsvetanovv](/profile/clk3x0ilz001ol808l9uu6vpj), [Bughunter101](/profile/clkau4y560006l908gxfcec8y), [0xbepresent](/profile/clk8nnlbx000oml080k0lz7iy), [dacian](/profile/clk6xnjxv0008jy083fc2mhsb), [hunterw3b](/profile/clk4rq78j0000l108bpu51153), [VanGrim](/profile/clk4qptxe000omr08zq645r4e), [0xRizwan](/profile/clk7o7bq3000ome08az33iib2), [0xumarkhatab](/profile/clkg9ze220000l708qbo7nfos), [RugpullDetector](/profile/clknpmzwp0014l608wk9hflu6), [0xnevi](/profile/clk3twjk3003imj08kmy05ubk), [Cryptic Snake REACH](/team/clkl8yzo70009mn08l4myjpwk), [qpzm](/profile/cllu8b144000gjs08aolwd6rr), [Bauchibred](/profile/clk9ibj6p0002mh08c603lr2j), [SanketKogekar](/profile/clk3xu7fc0010mm08wnt4txcd). Selected submission by: [dacian](/profile/clk6xnjxv0008jy083fc2mhsb)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/main/src/ProxyFactory.sol#L152-L160

## Summary

The signature used in `ProxyFactory::deployProxyAndDistributeBySignature()` is missing a nonce & expiration deadline.

## Vulnerability Details

The signature used in `ProxyFactory::deployProxyAndDistributeBySignature()` is missing a nonce & expiration deadline.

## Impact

This doesn't appear to currently be directly exploitable as `ProxyFactory::_distribute()` can't be called using the signature but without attempting to deploy the proxy. However the project team has stated they will be upgrading the contracts and that the current code is just an initial version, so best to point this out now as a low finding to prevent it from becoming a medium/high in a future version of the codebase.

## Tools Used

Manual

## Recommendations

Implement a [nonce](https://dacian.me/signature-replay-attacks#heading-missing-nonce-replay) and an [expiration deadline](https://dacian.me/signature-replay-attacks#heading-no-expiration).

## <a id='L-05'></a>L-05. Precision loss/Rounding to Zero in `_distribute()`

_Submitted by [PTolev](/profile/clk3wuu9e000kmf08tbdth8ir), [zach030](/profile/clllg9trq0002ml0881bhkegb), [castleChain](/profile/clk48to2u004wla08041jl9ld), [JPCourses](/profile/clk41wibj006sla08llbkfxxu), [33BYTEZZZ](/team/cllkeajr60001ky08s6vx5ig7), [nadin](/profile/cll90izoa0000l50847viw85l), [0xDetermination](/profile/clkucgb400000lg08vdq5ckvz), [shikhar229169](/profile/clk3yh639002emf08ywok1hzf), [0xumarkhatab](/profile/clkg9ze220000l708qbo7nfos), [IceBear](/profile/cllnrqkdu0008lc08luxl02vh), [smbv1923](/profile/clkp51djq001amy08d2e1slqf), [ubermensch](/profile/clk57krwm000el208ftidfc13), [viking71](/profile/cllofwlzw0000ms08zukr5cfx), [0xlucky](/profile/cllvmhg1i0008md080shk9pzx). Selected submission by: [33BYTEZZZ](/team/cllkeajr60001ky08s6vx5ig7)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Distributor.sol#L144

## Summary

The identified vulnerability is associated with the `_distribute` function in
`Distributor.sol`. In scenarios where the total token amount is low or low values are used for percentages, the function may encounter a precision issue.
This arises due to the division of totalAmount by `BASIS_POINTS` to calculate the distribution amount for each winner. The precision error can lead to incorrect token distribution, affecting the fairness and accuracy of rewards to winners.

## Vulnerability Details

The vulnerability stems from the calculation of `amount` within the distribution loop. The formula `amount = totalAmount * percentages[i] / BASIS_POINTS` involves a division operation that could result in loss of precision(Rounding to Zero) when dealing with small `totalAmount` values or low `percentages[i]`. This imprecision can lead to token amounts being rounded down to zero, resulting in unfair or incomplete rewards for winners.

### Proof Of Concept:

To simulate the vulnerability we need to make changes in the modifier
`setUpContestForJasonAndSentJpycv2Token`:

Code:

```solidity

	modifier setUpContestForJasonAndSentJpycv2Token(address _organizer) {
        vm.startPrank(factoryAdmin);
        bytes32 randomId = keccak256(abi.encode("Jason", "001"));
        proxyFactory.setContest(_organizer, randomId, block.timestamp + 8 days, address(distributor));
        vm.stopPrank();
        bytes32 salt = keccak256(abi.encode(_organizer, randomId, address(distributor)));
        address proxyAddress = proxyFactory.getProxyAddress(salt, address(distributor));
        vm.startPrank(sponsor);
        MockERC20(jpycv2Address).transfer(proxyAddress, 10);
        vm.stopPrank();
        // console.log(MockERC20(jpycv2Address).balanceOf(proxyAddress));
        // assertEq(MockERC20(jpycv2Address).balanceOf(proxyAddress), 10000 ether);
        _;
    }

```

We change the value transferred to the `proxyAddress` to `10` tokens.

Note: We are not using `10 ether` here as ether has 18 decimals which misguides the intended attack.

Now, we create a function called `testPrecisionLoss()` wherein we simulate end of a contest and call the `deployProxyAndDistribute()` function. This makes use of the modified `createData()` function to send in `95` winners, each being rewarded with percentage of `100 BASIS POINTS`, which is equal to `(10000 - COMMISSION_FEE)` i.e. `9500 BASIS POINTS` thus satisfying the conditions in the `_distribute()` function and allowing distribution of funds.

Code:

```
function testPrecisionLoss() public setUpContestForJasonAndSentJpycv2Token(organizer) {
        bytes32 randomId_ = keccak256(abi.encode("Jason", "001"));

        //create data from modified createData() function
				bytes memory data = createData();

        vm.startPrank(organizer);
        console.log("User1 Start Balance -", MockERC20(jpycv2Address).balanceOf(user1));
        console.log("Stadium Balance Before: ",MockERC20(jpycv2Address).balanceOf(stadiumAddress));

        //warping to the time where contest ends and token distribution is allowed
				vm.warp(30 days);

				// distributing the rewards to all 95 winners
        proxyFactory.deployProxyAndDistribute(randomId_, address(distributor), data);

        console.log("Stadium End Balance: ",MockERC20(jpycv2Address).balanceOf(stadiumAddress));
        console.log("User1 After Balance -", MockERC20(jpycv2Address).balanceOf(user1));

        vm.stopPrank();
    }
```

The logs prove the existence of precision loss:

```
Running 1 test for test/integration/ProxyFactoryTest.t.sol:ProxyFactoryTest
[PASS] testPrecisionLoss() (gas: 892788)
Logs:
  0x000000000000000000000000000000000000000E
  User1 Start Balance - 0
  Stadium Balance Before:  0
  Stadium End Balance:  10
  User1 After Balance - 0

Test result: ok. 1 passed; 0 failed; 0 skipped; finished in 6.16ms
```

As we can see, all of the balance gets transferred to the `stadiumAddress` from the contract as the `_commissionTransfer()` function declares:

```
function _commissionTransfer(IERC20 token) internal {
        token.safeTransfer(STADIUM_ADDRESS, token.balanceOf(address(this)));
    }
```

Due to the precision loss(Rounding to Zero), none of the amount gets transferred to any winners and thus, all the "remaining tokens" get sent to the `stadiumAddress`, thus leaving our winners - in this case, user1 - rewarded with 0 balance.

## Impact

The Rounding to Zero vulnerability has the potential to undermine the intended fairness and accuracy of the reward distribution process. In scenarios where the token balance is very small or percentages are low, the distribution algorithm could yield incorrect or negligible rewards to winners. This impacts the trust and credibility of the protocol, potentially leading to user dissatisfaction and decreased participation.

## Tools Used

Manual Review
Foundry
VSCode

## Recommendations

Consider instituting a `predefined minimum threshold` for the `percentage` amount used in the token distribution calculation. This approach ensures that the calculated distribution amount maintains a reasonable and equitable value, even when dealing with low percentages.

Additionally, an alternative strategy involves adopting a `rounding up equation` that consistently rounds the `distribution amount upward` to the nearest integer value.

By incorporating either of these methodologies, the precision vulnerability associated with small values and percentages can be effectively mitigated, resulting in more accurate and reliable token distribution outcomes.

## <a id='L-06'></a>L-06. Potential DOS due to Gas Exhaustion Due to Large Array Iteration in `_distribute` Function

_Submitted by [Kaveyjoe](/profile/cll5ys0qx0000mn08n5fnirm2), [ZedBlockchain](/profile/clk6kgukh0008ld088n5wns9l), [David77](/profile/clll3wigw0008mf08byd7jzzy), [Daniel526](/profile/clk3zygt00028la08pxdzjdfp), [Proxy](/profile/clk3x79a8000gmg083h7fjmul), [0xyPhilic](/profile/clk3wry0p0008mf08lbxjpcks), [nmirchev8](/profile/clkao1p090000ld08dv6v2xus), [imkapadia](/profile/cllf36tub0000mb08a96bksxy), [Lalanda](/profile/clk44x5d0002amg08cqme5xh6), [crippie](/profile/clkitmhs50000l508e5tvl2w2), [getitin](/profile/cllnxlz7l0008ml08fd1j9fwt), [hunterw3b](/profile/clk4rq78j0000l108bpu51153), [thekmj](/profile/clky06cav0014l608rjnjz31m), [33BYTEZZZ](/team/cllkeajr60001ky08s6vx5ig7), [SAAJ](/profile/cllq1yz0u0004ju08019ho5a7), [0xdraiakoo](/profile/clk3xadrc0020l808t9unuqkr), [xfu](/profile/clke2oift0000l508j03apihy), [Tripathi](/profile/clk3xe9tk0024l808xjc9wkg4), [0xch](/profile/cll5o4acg0000jo08cxakmfo9), [JohnnyTime](/profile/clk6vuje90014mm0800cqeo8w), [RugpullDetector](/profile/clknpmzwp0014l608wk9hflu6), [Cosine](/profile/clkc7trh30004l208e0okerdn), [sm4rty](/profile/clk4170ln003amb088n137st7), [leasowillow](/profile/clkntswhk004qmj09tj6fxd4k), [honeymewn](/profile/clk4hhuqi0008mk08x47ah4w4), [radeveth](/profile/clk406c5j0008jl08i3ojs45y), [nervouspika](/profile/clk8s260t000el108iz3yrkhy), [Maroutis](/profile/clkctygft000il9088nkvgyqk), [0xVinylDavyl](/profile/clkeaiat40000l309ruc9obdh), [Bauchibred](/profile/clk9ibj6p0002mh08c603lr2j), [Gordoxyz](/profile/clljq8wzh0000la087rd7en2r), [coditoorgeneral](/profile/clk42qyp20078mb082oahjnx5), [0xScourgedev](/profile/clkj0r4v30000l5085winknb6), [trauki](/profile/cllq1dzsq0000mh08q4ygxk1t). Selected submission by: [Daniel526](/profile/clk3zygt00028la08pxdzjdfp)._

### Relevant GitHub Links

https://github.com/codefox-inc/sparkn-contracts/blob/9063a0851ad6538e23728dcb4ba53dc0f722eb96/src/Distributor.sol#L144-L152

## Summary

The `_distribute` function in the provided contract contains a loop that iterates through arrays of winners and percentages to distribute tokens. If these arrays are very large, this loop could lead to excessive gas consumption, potentially causing transactions to run out of gas and fail.

## Vulnerability Details

The `_distribute` function is responsible for distributing tokens to winners based on their percentages. This function iterates through arrays of winners and percentages, calculating the amount to transfer to each winner based on their percentage. While the function's purpose is to fairly distribute tokens, a potential vulnerability arises when dealing with a large number of winners and percentages.

```solidity
function _distribute(address token, address[] memory winners, uint256[] memory percentages, bytes memory data)
    internal
{
    // ...

    uint256 winnersLength = winners.length;
    for (uint256 i; i < winnersLength;) {
        uint256 amount = totalAmount * percentages[i] / BASIS_POINTS;
        erc20.safeTransfer(winners[i], amount);
        unchecked {
            ++i;
        }
    }

    // ...
}

```

The loop's gas cost increases linearly with the size of the `winners` and `percentages` arrays. If these arrays contain a significant number of elements, the gas consumption of the transaction could exceed the gas limit, causing the transaction to fail due to out-of-gas.

## Impact

The impact of this issue is that transactions attempting to distribute tokens to a large number of winners in a single execution may fail due to running out of gas. Users may experience frustration and inconvenience if their intended distributions cannot be completed successfully.

## Tools Used

Manual

## Recommendations

Implement a batching mechanism that processes a limited number of winners and percentages in each iteration of the loop.

## <a id='L-07'></a>L-07. Centralization Risk for trusted organizers

_Submitted by [0xch13fd357r0y3r](/profile/clk71r4q20000jt08dj5q6woc), [0xdeth](/profile/clk4azr2z0010lb083ci6ih4j), [sv ](/team/cllj8y8f40001ji08wzcyijzr), [InAllHonesty](/profile/clkgm90b9000gms085g528phk), [GoSoul22](/profile/clk7zkyd70002l608iam3ggtg), [0xnevi](/profile/clk3twjk3003imj08kmy05ubk), [savi0ur](/profile/clk3w8t380018kx08f8kzzk3f), [Bughunter101](/profile/clkau4y560006l908gxfcec8y), [SBSecurity](/team/clkuz8xt7001vl608nphmevro), [alymurtazamemon](/profile/clk3q1mog0000jr082dc9tipk), [0x3b](/profile/clk3yiyaq002imf088cd3644k), [cats](/profile/clkpcyd8s0000mm08gto4lwp7), [nisedo](/profile/clk3saar60000l608gsamuvnw), [MrjoryStewartBaxter](/profile/clk6xkrq00008l708g23xstn9), [KiteWeb3](/profile/clk9pzw3j000smh08313lj91l), [Soliditors](/team/clll907ei0001mh08zevvaoze), [0xbepresent](/profile/clk8nnlbx000oml080k0lz7iy), [DevABDee](/profile/clk5eknoz0000l308ney23msz), [Phantasmagoria](/profile/clki6y71n000gkx088cowa4hq), [Breeje](/profile/clk41ow6c0066la0889fuw52t), [FalconHoof](/profile/clkcm5dsf0000mc083q6clddz), [ABA](/profile/clk43rqfo0008mg084q0ema3g), [y4y](/profile/cllq879u70000mo08o0n110vi), [VanGrim](/profile/clk4qptxe000omr08zq645r4e), [0xanmol](/profile/clkp3qzse000yl508z8ia3dby), [Madalad](/profile/clki3uj3i0000l508carwkhuh), [shikhar229169](/profile/clk3yh639002emf08ywok1hzf), [TheSchnilch](/profile/clk89mhkb0002mk080c64z7b8), [0xDetermination](/profile/clkucgb400000lg08vdq5ckvz), [Maroutis](/profile/clkctygft000il9088nkvgyqk), [Aamirusmani1552](/profile/clk6yhrt6000gmj082jnn4770), [zigtur](/profile/clknjcwb00000me08tsnr970w), [ke1caM](/profile/clk46fjfm0014la08xl7mwtis), [t0x1c](/profile/clk7rcevn0004jn08o2n2g1a5), [Stoicov](/profile/clk43h7he008ymb08nk4eu446), [Chinmay](/profile/clk56c7d80000mg08mvbluxgj), [arnie](/profile/clk4gbnc30000mh088nl2a5i4), [MehdiKarimi](/profile/clkh20nf7002ql0089kovmlaw), [0xMosh](/profile/clkab3oww0000kx08tbfkdxab), [SAAJ](/profile/cllq1yz0u0004ju08019ho5a7), [AkiraKodo](/profile/clk8ejhzv000emm08earxxzdr), [owade](/profile/clk9j4mf20002mi08k4758eni), [0xsandy](/profile/clk43kus5009imb0830ko7dxy), [honeymewn](/profile/clk4hhuqi0008mk08x47ah4w4), [coolboymsk](/profile/cllo0aag70000l008c6vxf8x3), [trauki](/profile/cllq1dzsq0000mh08q4ygxk1t), [0xAxe](/profile/clk43mzqn009wmb08j8o79bfh), [0xScourgedev](/profile/clkj0r4v30000l5085winknb6), [0x11singh99](/profile/clkhsr7bn0000l608c9vc7ugr). Selected submission by: [0xAxe](/profile/clk43mzqn009wmb08j8o79bfh)._

## Summary

According to the provided link on "[Centralization Risk for trusted owners](https://github.com/Cyfrin/2023-08-sparkn/issues/1)", I believe that the `Organizer` also carries a centralization risk. As described in the documentation, "[The sponsor `Sponsor` is the person providing financial support. Sponsors can be anyone, including the organizer `Organizer`.](https://github.com/Cyfrin/2023-08-sparkn#roles) This implies that `Organizer = Sponsor`", which could potentially lead to unexpected situations.

## Vulnerability Details & Impact

1. Anyone can become an `organizer`, including the `sponsor`. This gives the `organizer` excessive power since one person can hold multiple roles, which could lead to malicious behavior, such as distributing rewards to acquaintances or oneself, prematurely ending the competition after obtaining a solution, or in the case of `sponsor = organizer`, running away with the funds after obtaining a solution.
2. If `supporters` do not anonymize their submissions, it could result in covert operations.
3. Even though there is the possibility of off-chain identity verification for `organizers`, I still see a significant level of susceptibility to manipulation within this protocol.

## Tools Used

- Manual Review

## Recommendations

- In my understanding, Sparkn is similar to the Immunefi auditing platform.
- My suggestion is to differentiate the roles of organizer and sponsor. Similar to the @codehawks platform, anonymize the solutions submitted by each supporter. The organizer can be any auditing platform (such as @code4rena, @sherlock, @codehawks), while the sponsor should only be the project itself, such as "sparkn" or "Beedle - Oracle free perpetual lending," and should not simultaneously hold the role of organizer.

## <a id='L-08'></a>L-08. DAI Tokens at Risk Due to Lack of address(0) Check in distribute

_Submitted by [ZedBlockchain](/profile/clk6kgukh0008ld088n5wns9l), [carrotsmuggler](/profile/clkdvewih0000l909yza1oaop), [albertwhite](/profile/clkng2y9n0008jx082ult8mge), [castleChain](/profile/clk48to2u004wla08041jl9ld), [SBSecurity](/team/clkuz8xt7001vl608nphmevro), [0xHelium](/profile/clln22yf30000js0896twaqur), [Cosine](/profile/clkc7trh30004l208e0okerdn), [cats](/profile/clkpcyd8s0000mm08gto4lwp7), [MrjoryStewartBaxter](/profile/clk6xkrq00008l708g23xstn9), [Stoicov](/profile/clk43h7he008ymb08nk4eu446), [Batman](/profile/clkc47fv10006l908u64cn5ef), [InAllHonesty](/profile/clkgm90b9000gms085g528phk), [zach030](/profile/clllg9trq0002ml0881bhkegb), [jonatascm](/profile/clk83zqs2000gjp08eg935k0n), [Chin](/profile/cllka5zz20000mg09hkir15l1), [vjacs](/profile/clk8fhnw10000ia08ljkjr8g6), [Maroutis](/profile/clkctygft000il9088nkvgyqk), [Aamirusmani1552](/profile/clk6yhrt6000gmj082jnn4770), [B353N](/profile/clk5cw0v6000ymq086uqalsn6), [MortezaXG38](/profile/clltit0z9000glf086t7tiunv), [Chandr](/profile/clka007jd0000k2086j3juoi9), [xAlismx](/profile/clkbcjoju0000mu08bflruz0u), [419EF](/profile/clkwjwylk007gjw09am1q2c79), [owade](/profile/clk9j4mf20002mi08k4758eni), [serverConnected](/profile/clk7uzeqt0002ml08vadj04ih), [dipp](/profile/clkwy9h2i0070mj08yhryut5w), [tsar](/profile/clk9isayj0004l30847ln1e8j), [OxTenma](/profile/clka2yfju000ek408xoh23vq2), [0xAxe](/profile/clk43mzqn009wmb08j8o79bfh), [0xVinylDavyl](/profile/clkeaiat40000l309ruc9obdh). Selected submission by: [tsar](/profile/clk9isayj0004l30847ln1e8j)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/main/src/Distributor.sol#L147

## Summary

The `distribute` function does not check if the winner is address(0). For some tokens Like USDC and USDT it does check internally if the sender and receiver are not address(0) and revert it (so it's not necessary for the function to check it), but the DAI token does not check for that and will not revert and send tokens to the 0 address.

## Vulnerability Details

Since the dev described that the DAI token will be present in the contract the function `_distribute` should check if any of the winners are address(0).  
 Here is the DAI token code: https://etherscan.io/token/0x6b175474e89094c44da98b954eedeac495271d0f#code , the functions used to transfer the tokens internally does not check for the address(0) as seen here in the DAI contract:

```solidity
function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint wad)
        public returns (bool)
    {
        require(balanceOf[src] >= wad, "Dai/insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad, "Dai/insufficient-allowance");
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }
```

## Impact

DAI tokens could be permanently lost if sent to address(0) because lack of checking

## Tools Used

Manual review, Etherscan

## Recommendations

Add a built in check if any of the winners are 0 address because not all tokens do that check internally, specially DAI which the dev explicitly commented that it is going to be used.

## <a id='L-09'></a>L-09. Missing Events

_Submitted by [ZedBlockchain](/profile/clk6kgukh0008ld088n5wns9l), [SBSecurity](/team/clkuz8xt7001vl608nphmevro), [charlesCheerful](/profile/clk3wmzul0008l808andx29ul), [SAAJ](/profile/cllq1yz0u0004ju08019ho5a7), [97Sabit](/profile/clk42eeq0007mla08lc11yszp), [Sabelo](/profile/clk5g056a000im808d95a9dlu), [mylifechangefast](/profile/cllsv7tc70004mp08s301xpuo), [sm4rty](/profile/clk4170ln003amb088n137st7), [contractsecure](/profile/clk3y89700004jq08hsxugo8k). Selected submission by: [ZedBlockchain](/profile/clk6kgukh0008ld088n5wns9l)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/47c22b818818af4ea7388118dd83fa308ad67b83/src/Distributor.sol#L163

https://github.com/Cyfrin/2023-08-sparkn/blob/47c22b818818af4ea7388118dd83fa308ad67b83/src/ProxyFactory.sol#L58

## Summary

There are some critical functionalities that are missing events

## Vulnerability Details

1. [Distributor.sol line 163 function \_commissionTransfer(IERC20 token)](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Distributor.sol#L163) should emit its own event, especially given that commissions transfers occur after distribution to winners. Its a critical function that can report to offchain tooling the commissions going to STADIUM at every moment

2. ProxyFactory.sol all deploy and distribute functions in the contract emit Distributed event. This is not truly reflective of happenings as they are different and events should reflect differences. The functions should emit specific events related to them e.g

- deployProxyAndDistributeByOwner //should differentiate that organizer not around so owner called this by having event with owner and organizer details emitted
- distributeByOwner // should differentiate that organizer called it , important information like above
- deployProxyAndDistribute
  are all functions with different intricacies and dynamics that can be captured by adding additional event or updating Distributed event to capture these differences

## Impact

This shortchanges various offchain tooling, monitoring, reporting, frontend services that may rely on events to adequately capture real time activities of the contracts. It may even be critical for security monitoring so project can respond adequately if events sufficiently detailed and informative. Any emissions suspicious can allow protocol to react quickly

## Tools Used

Manual Analysis

## Recommendations

Recommended to add events for the cases detailed above e.g
DistributeByOrganizer, DistributedSignature, DistributedOwner or keep Distributed and add other specific events in function e.g BySignatureEvent in function deployProxyAndDistributeBySignature() etc

## <a id='L-10'></a>L-10. Using basis points for percentage is not precise enough for realistic use-cases

_Submitted by [dontonka](/profile/cllks1uim0000lh0855te4x9o), [oualidpro](/profile/clkn61ppo0008l6086a909pio), [Jarx](/profile/clk7emv5a000mlg08jgvzjj8p), [thekmj](/profile/clky06cav0014l608rjnjz31m), [castleChain](/profile/clk48to2u004wla08041jl9ld), [FalconHoof](/profile/clkcm5dsf0000mc083q6clddz), [codeslide](/profile/clk4bsa8h0024lb08plqm66au), [arnie](/profile/clk4gbnc30000mh088nl2a5i4), [usmanfarooq90](/profile/clk47y2ey0038la088eca1es3), [WhiteRose](/profile/cllkz95a3000gl408ipygw90n), [shirochan](/profile/clkq77z1c0000mr08p4ndkhnl), [leasowillow](/profile/clkntswhk004qmj09tj6fxd4k), [SAQ](/profile/clkftc56x0006le08usdp7epo), [honeymewn](/profile/clk4hhuqi0008mk08x47ah4w4), [0xVinylDavyl](/profile/clkeaiat40000l309ruc9obdh). Selected submission by: [thekmj](/profile/clky06cav0014l608rjnjz31m)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/main/src/Distributor.sol#L61

## Summary

Using `10000` for `BASIS_POINTS` is not precise enough for the protocol use case.

## Vulnerability Details

The `Distributor` contract is intended to be used to distribute its own balance (i.e. prize pool) to recipients. The admin is expected to supply the list of winners, along with their percentage share of the prize pool. The contract will then distribute the prize to the recipients.

However, the percentage basis point is defined to be 10000, meaning the smallest possible prize pool denomination is 0.01%. We argue that this is not precise enough.

- Audit contests (e.g. in Code4rena, Sherlock, Codehawks) have prize pools to tens of thousands of USD worth. A standard contest is usually 50,000 USDC in prize. With 10000 as the basis points, winners can only be denominated to \$5 of winnings only.
- SPARKN contest itself has a prize pool of \$15,000. If any auditor's prize is not divisible by \$1.5, then it is not possible to fairly distribute the prize for that auditor.
  - It is common for a contest to have a finding with many duplicates, which payout is less than \$1.
  - It is also common for distributing events (e.g. airdrops, prize distribution) to have a percentage not divisible by 0.01\%.

Therefore it will not be possible to distribute the prize with accuracy in such use-cases.

While it is technically possible to distribute the rewards using more than one sponsor transactions and equal number of distribution transactions, it will significantly complicate the reward calculation. In that case it will be better to just use standard ERC20 transferring to the winners, which defeats the purpose of the protocol to begin with. Therefore submitting as high.

## Impact

It may not be possible to distribute rewards with high enough precision, blocking many realistic use cases.

## Tools Used

Manual review

## Recommendations

Use `10**18` for `BASIS_POINTS` instead of the current value, which should be precise enough.

## <a id='L-11'></a>L-11. Insufficient validation leads to locking up prize tokens forever

_Submitted by [kaliberpoziomka](/profile/clknz2nn10068l908msy0brst), [0xkeesmark](/profile/clk40arb0000gjl08ze5pyblk), [shikhar229169](/profile/clk3yh639002emf08ywok1hzf), [nmirchev8](/profile/clkao1p090000ld08dv6v2xus), [JohnnyTime](/profile/clk6vuje90014mm0800cqeo8w), [JPCourses](/profile/clk41wibj006sla08llbkfxxu), [0xdraiakoo](/profile/clk3xadrc0020l808t9unuqkr), [Tripathi](/profile/clk3xe9tk0024l808xjc9wkg4), [niluke](/profile/clk40349m002ola08t6dkfj92), [ke1caM](/profile/clk46fjfm0014la08xl7mwtis), [0xMosh](/profile/clkab3oww0000kx08tbfkdxab), [TheSchnilch](/profile/clk89mhkb0002mk080c64z7b8), [ryanjshaw](/profile/cllbcbf460000ky083lj6avsv), [sonny2k](/profile/clk51hohw0000mr08nfrnlewz), [TorpedopistolIxc41](/profile/clk5ki3ah0000jq08yaeho8g7), [serialcoder](/profile/clkb309g90008l208so2bzcy6), [0xScourgedev](/profile/clkj0r4v30000l5085winknb6). Selected submission by: [serialcoder](/profile/clkb309g90008l208so2bzcy6)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L109

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L113

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Proxy.sol#L40-L46

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Proxy.sol#L52-L56

## Summary

The `ProxyFactory::setContest()` lacks validating the case of the `implementation` param pointing to a target address with no contract. As a result, all tokens sent to the `Proxy` address will be stuck forever.

## Vulnerability Details

The `Proxy` contract was designed as an escrow for distributing tokens to contest winners. By design, a contest organizer or sponsor must send tokens to an address of the contest's `Proxy` before the `Proxy` gets deployed. The tokens can be permanently stuck in the `Proxy` address if a mistake occurs.

Every contest will be initiated by an owner via the `setContest()`. The function will [verify the `implementation` param against the `address(0)`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L109). However, the verification cannot guarantee that the `Proxy` will function properly.

Specifically, the `setContest()` lacks checking that the `implementation` param must point to an address with a contract bytecode. If an incorrect address is inputted by mistake, such as `address(1)`, the `Proxy` will be bricked, locking away all tokens.

This mistake could not be undone since the [inputted `implementation` param will be used to compute a salt for the `Proxy`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L113). The `implementation` param will no longer be updated after executing the `setContest()`.

```solidity
    function setContest(address organizer, bytes32 contestId, uint256 closeTime, address implementation)
        public
        onlyOwner
    {
@>      if (organizer == address(0) || implementation == address(0)) revert ProxyFactory__NoZeroAddress();
        if (closeTime > block.timestamp + MAX_CONTEST_PERIOD || closeTime < block.timestamp) {
            revert ProxyFactory__CloseTimeNotInRange();
        }
@>      bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] != 0) revert ProxyFactory__ContestIsAlreadyRegistered();
        saltToCloseTime[salt] = closeTime;
        emit SetContest(organizer, contestId, closeTime, implementation);
    }
```

- `The implementation param is checked against the address(0) only`: https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L109

- `The implementation param is used to compute a salt for a contest's Proxy`: https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L113

### Further Explanation

To explain further the vulnerability.

The `Proxy` contract will be deployed and triggered by calling the following functions after sending prize tokens.

1. [`deployProxyAndDistribute()`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L135-L136)
2. [`deployProxyAndDistributeBySignature()`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L164-L165)
3. [`deployProxyAndDistributeByOwner()`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L190-L191)

Below is the `Proxy` contract's snippet. The inputted `implementation` param will be assigned to [the immutable variable `_implementation`](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Proxy.sol#L40-L46) in the `constructor()`. When the `Proxy` is invoked to distribute tokens, the `fallback()` will be triggered to execute the [`delegatecall()` to the target implementation address](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Proxy.sol#L52-L56).

**If an incorrect address was inputted by mistake, the `delegatecall()` will execute nothing and return a success status. In other words, all tokens will be stuck forever in the `Proxy` contract.**

```solidity
    ...

@>  address private immutable _implementation;

    ...

    constructor(address implementation) {
@>      _implementation = implementation;
    }

    ...

    fallback() external {
@>      address implementation = _implementation;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
@>          let result := delegatecall(gas(), implementation, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
```

- `The _implementation is an immutable variable initialized in the Proxy's constructor()`: https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Proxy.sol#L40-L46

- `Proxy executes the delegatecall() to the target implementation address`: https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/Proxy.sol#L52-L56

## Impact

The `setContest()` lacks validating the case of the `implementation` param pointing to a target address with no contract. As a result, all tokens sent to the `Proxy` address will be stuck forever.

To clarify the vulnerability, although only an owner can execute the `setContest()` and the owner is trusted, **the incident can occur by mistake (i.e., this vulnerability is not about any centralization or trust risks; it is about the risks of input mistakes only)**.

The likelihood is considered LOW (since the owner is expected to do due diligence). The impact is considered HIGH. Therefore, the severity is considered MEDIUM.

## Tools Used

Manual Review

## Recommendations

Further validating that the `implementation` param must point to an address with a contract bytecode, as follows.

```diff
+   import {Address} from "openzeppelin/utils/Address.sol";

    ...

    function setContest(address organizer, bytes32 contestId, uint256 closeTime, address implementation)
        public
        onlyOwner
    {
        if (organizer == address(0) || implementation == address(0)) revert ProxyFactory__NoZeroAddress();
+       if (!Address.isContract(implementation)) revert ProxyFactory__NoImplementationContract();
        if (closeTime > block.timestamp + MAX_CONTEST_PERIOD || closeTime < block.timestamp) {
            revert ProxyFactory__CloseTimeNotInRange();
        }
        bytes32 salt = _calculateSalt(organizer, contestId, implementation);
        if (saltToCloseTime[salt] != 0) revert ProxyFactory__ContestIsAlreadyRegistered();
        saltToCloseTime[salt] = closeTime;
        emit SetContest(organizer, contestId, closeTime, implementation);
    }
```

## <a id='L-12'></a>L-12. Organizers are not incentivized to deploy and distribute to winners causing that winners may not to be rewarded for a long time and force the protocol owner to manage the distribution

_Submitted by [0xbepresent](/profile/clk8nnlbx000oml080k0lz7iy), [Chinmay](/profile/clk56c7d80000mg08mvbluxgj), [0xsandy](/profile/clk43kus5009imb0830ko7dxy), [trauki](/profile/cllq1dzsq0000mh08q4ygxk1t). Selected submission by: [0xbepresent](/profile/clk8nnlbx000oml080k0lz7iy)._

### Relevant GitHub Links

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L127

https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L152

## Summary

The organizer can deploy and distribute to winners at any time without restriction about the contest expiration time `EXPIRATION_TIME` causing that the winners to be unable to receive their rewards for a long time.

## Vulnerability Details

The organizer can execute the [deployProxyAndDistribute()](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L127C14-L127C38) function to deploy the `distribute` contract and execute the [distribution](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L136) to winners. The only restriction is that the current time should be [greater than contest close time](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L134) (code line 134).

```solidity
File: ProxyFactory.sol
127:     function deployProxyAndDistribute(bytes32 contestId, address implementation, bytes calldata data)
128:         public
129:         returns (address)
130:     {
131:         bytes32 salt = _calculateSalt(msg.sender, contestId, implementation);
132:         if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
133:         // can set close time to current time and end it immediately if organizer wish
134:         if (saltToCloseTime[salt] > block.timestamp) revert ProxyFactory__ContestIsNotClosed();
...
...
```

In the other hand, the `owner` can execute [deployProxyAndDistributeByOwner()](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L179C14-L179C45) function after the [contest expiration time](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L187) (code line [187](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L187)).

```solidity
File: ProxyFactory.sol
179:     function deployProxyAndDistributeByOwner(
180:         address organizer,
181:         bytes32 contestId,
182:         address implementation,
183:         bytes calldata data
184:     ) public onlyOwner returns (address) {
185:         bytes32 salt = _calculateSalt(organizer, contestId, implementation);
186:         if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
187:         if (saltToCloseTime[salt] + EXPIRATION_TIME > block.timestamp) revert ProxyFactory__ContestIsNotExpired();
...
...
```

The problem is that the `organizer` can execute the [deployProxyAndDistribute()](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L127C14-L127C38) function after the [contest close time](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L134) without restriction of time. The `organizer` can wait indefinitely causing the winners not to be rewarded for a long time and force the owner to execute the distribution manually via `deployProxyAndDistributeByOwner()`.

Additionally, the `organizers` are not incentivized to deploy and distribute to winners.

## Impact

The malicious organizer can wait indefinitely until the `owner` calls [deployProxyAndDistributeByOwner()](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L179C14-L179C45). The bad/malicious behaivour of the `organizer` can cause the winners to be unable receive rewards for a long time AND force the `owner` to execute manually `deployProxyAndDistributeByOwner()`. That affects the protocol because rewards are not assigned in time AND the protocol owner needs to manage manually the deploy and distribution in order to not affect the protocol's reputation and winners.

Additionally the `organizers` are not incentivized to deploy and distribute to winners causing to the protocol owner to execute manually the `deployProxyAndDistributeByOwner()`.

## Tools used

Manual review

## Recommendations

Add a validation that the `organizer` distribution must be between the `saltToCloseTime` and the `EXPIRATION_TIME`. Same in [deployProxyAndDistributeBySignature()](https://github.com/Cyfrin/2023-08-sparkn/blob/0f139b2dc53905700dd29a01451b330f829653e9/src/ProxyFactory.sol#L152C14-L152C49)

```diff
    function deployProxyAndDistribute(bytes32 contestId, address implementation, bytes calldata data)
        public
        returns (address)
    {
        bytes32 salt = _calculateSalt(msg.sender, contestId, implementation);
        if (saltToCloseTime[salt] == 0) revert ProxyFactory__ContestIsNotRegistered();
        // can set close time to current time and end it immediately if organizer wish
        if (saltToCloseTime[salt] > block.timestamp) revert ProxyFactory__ContestIsNotClosed();
++      if (saltToCloseTime[salt] + EXPIRATION_TIME < block.timestamp) revert();
        address proxy = _deployProxy(msg.sender, contestId, implementation);
        _distribute(proxy, data);
        return proxy;
    }
```

Additionally, there should be a penalization to the `organizer` or an incentive to deploy and distribute in time to winners.
