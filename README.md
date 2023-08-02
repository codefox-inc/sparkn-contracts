# Taibow Stadium
Taibow Stadium is a Web3 project that aims to build a marketplace for anyone who wants to solve their problems. 
The contracts in this repository are used to escrow Taibow stadium users' assets on chain. 
Our goal is to make sure assets on Taibow stadium are safe and transparent no matter who is using it. 



# How to Start
1. Install dependencies
```bash
$ forge install
```

2. Run tests
```bash
$ make test
```
run a single test
```bash
forge test --mt <test_name>
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

Clean up the repository
```bash
$ make clean
```




# Reference
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/)