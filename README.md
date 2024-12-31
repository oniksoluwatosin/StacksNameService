# StacksID: Decentralized Naming System for Stacks

StacksID is a decentralized naming system built on the Stacks blockchain, providing a scalable and user-friendly way to manage blockchain identities and associated data.

## Features

- Register and manage domain names on the Stacks blockchain
- Set primary addresses for easy cryptocurrency transfers
- Add custom records to domains (e.g., social media handles, websites)
- Create and manage subdomains
- Implement name locking for enhanced security
- Built-in marketplace for buying and selling domain names

## Smart Contract

The core of StacksID is a Clarity smart contract that manages all naming operations. You can find the contract in `contracts/sns.clar`.

## Getting Started

1. Clone this repository
2. Install dependencies: `npm install`
3. Run tests: `npm test`

## Usage

To interact with the StacksID contract, you can use the Stacks CLI or create a frontend application that interfaces with the contract.

Example of registering a name using the Stacks CLI:

```bash
stacks-cli contract-call --contract-address ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM --contract-name sns --function-name register-name --fee 1000 --nonce 1 --stx-private-key <your_private_key> --network mainnet --name "myname"
