# Background
Nowadays information is spread around the world in an incredible speed. However, in some isolated area the information gap is too substantial to conquer the problems. One of the biggest reasons is neither there are talented people nor incentives to create great ideas. 

We found that there are many problems can be solved by the community in an more innovative and open way if things are done openly and smartly with adequate incentives. 

We think "More problem is solved" is equal to "more value is created".    

For this, we created SPARKN. 

# SPARKN 

SPARKN protocol is a Web3 project that aims to build a marketplace for anyone who wants to solve their problems. 

## Contracts
The contracts in this repository are used as escrow of SPARKN users' assets on chain. 
Our goal is to make sure assets on SPARKN are safe and transparent no matter who is using it. 

These contracts are responsible for the escrow of users' funds and distribute them to the winners of the contests. 
We tried to keep things simple and safe. 
The contracts is created with the philosophy of "supporter first".     
If a contest is created and funded there is no way to refund. All the funds belongs to the persons who wants to help solve the problem, we call them "supporters". 

All the contracts are sitting in the `src/` folder. These are the core contracts of the protocol. 

The contracts are supposed to be deployed to any EVM compatible chains.

## Tests
Tests are in the `test/` folder. More explanations about test cases can be found in the test folder's `README.md` file. 

# How to Start
1. Install dependencies
```bash
$ forge install
```

2. Run tests
```bash
$ make test
```

run a single test file
```bash
forge test --mt <file_name>
```

see test coverage
```bash
forge coverage
```

3. Deploy contracts
```bash
$ forge deploy --network <network>
```

or deploy to local network
```bash
make deploy
```

4. Other things to do

Format the codes
```bash
$ make format
```





# Reference
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/)