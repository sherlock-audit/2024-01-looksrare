# @looksrare/contracts-yolo

[![Tests](https://github.com/LooksRare/contracts-yolo/actions/workflows/tests.yaml/badge.svg)](https://github.com/LooksRare/contracts-yolo/actions/workflows/tests.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Description

This project contains the smart contracts used for LooksRare's Yolo protocol. The main contract `YoloV2`
allows anyone to deposit their ETH/ERC-20/ERC-721 to receive entries for the current open round. When the round's time runs out, the smart contract requests for randomness from Chainlink to draw the winner. The winner can take all the deposits of that round. There is always an open round at any time as long as a closeable round is transitioned on time.

## Deployments

| Network          | Yolo                                                                                                                               | YoloV2                                                                                                                             | PriceOracle                                                                                                                        |
| :--------------- | :--------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum         | [0x00000000007767d79f9F4aA1Ff0d71b8E2E4a231](https://etherscan.io/address/0x00000000007767d79f9F4aA1Ff0d71b8E2E4a231#code)         | -                                                                                                                                  | [0x00000000000A95dBfC66D37F3FC5E597C0b03Daf](https://etherscan.io/address/0x00000000000A95dBfC66D37F3FC5E597C0b03Daf#code)         |
| Arbitrum         | [0x00000000001232ADE8b210ac82a04eb7EB1c175B](https://arbiscan.io/address/0x00000000001232ADE8b210ac82a04eb7EB1c175B#code)          | -                                                                                                                                  | [0x000000000006C1bc5F4d75106072E3Fd92378DB7](https://arbiscan.io/address/0x000000000006C1bc5F4d75106072E3Fd92378DB7#code)          |
| Base             | [0x00000000007324650D238fd9829E370734dDDFC2](https://basescan.org/address/0x00000000007324650D238fd9829E370734dDDFC2#code)         | -                                                                                                                                  | [0x00000000001725AD5E2aB41f2f39D44c50A68751](https://basescan.org/address/0x00000000001725AD5E2aB41f2f39D44c50A68751#code)         |
| Arbitrum Sepolia | [0x0bCD9359a0B8f6577092a80195E1585FF595b1b3](https://sepolia.arbiscan.io/address/0x0bCD9359a0B8f6577092a80195E1585FF595b1b3)       | [0xCD91A9ebfe081C4D670f608A812fC84a081E2a20](https://sepolia.arbiscan.io/address/0xCD91A9ebfe081C4D670f608A812fC84a081E2a20#code)  | [0x58e19875bad53d77f84f667c90e0a8bf376e0851](https://sepolia.arbiscan.io/address/0x58e19875bad53d77f84f667c90e0a8bf376e0851#code)  |
| Sepolia          | [0xD7Af15a95351c8ae6B628f6571CFD24d56e06E21](https://sepolia.etherscan.io/address/0xD7Af15a95351c8ae6B628f6571CFD24d56e06E21#code) | [0xce69a4cF5687F4d8B44E8C96a8bB9c8d7Ebe09Cf](https://sepolia.etherscan.io/address/0xce69a4cF5687F4d8B44E8C96a8bB9c8d7Ebe09Cf#code) | [0x5282Dec40c65cf3cf5d5d0E377EDff7C1083F327](https://sepolia.etherscan.io/address/0x5282Dec40c65cf3cf5d5d0E377EDff7C1083F327#code) |

### Yolo states

Each round consists of the following states:

1. `None`
   There is no round at the provided ID.

2. `Open`
   The round is open for deposits.

3. `Drawing`
   When a round's maximum number of deposits/participants are reached before the cutoff time or when a round has at least 2 participants by the time when the round's cutoff time is reached, the smart contract calls Chainlink VRF to draw a random number to determine the winner. The state `Drawing` represents the intermediary state of waiting for Chainlink VRF's callback.

4. `Drawn`
   A round is considered drawn after the randomness response comes back. The winner can withdraw prizes at this stage.

5. `Cancelled`
   A round can be cancelled when there are less than 2 participants by the time when the round's cutoff time is reached. The only participant can withdraw his deposits if there are any.
   A new round will also be open as the current round is being cancelled.

### Protocol fees

The contract owner can set a protocol fee recipient and a protocol fee basis points (up to 25%) per round.
The fee is in ETH and will be taken from the deposits before transferring to the winner. If there aren't
any ETH deposits for the round or the ETH deposits are insufficient to cover the fees, the winner has to pay for
the fee (or the difference) before he can withdraw the prizes.

Alternatively, the winner can choose to pay with LOOKS with a discount. It is always paid by the winner's wallet instead of being deducted from the prizes.

### How do we value an ERC-721/ERC-20 token?

The price of each token/collection is valid for a round only. The first deposit of the token/collection
is required to retrieve the price, then subsequent deposits of the same round will use the same price stored in the smart contract.

#### ERC-721

We retrieve the collection's 1 hour TWAP floor price from [Reservoir](https://docs.reservoir.tools/reference/getoraclecollectionsflooraskv6), signed by Reservoir's off-chain oracle.
The smart contract verifies the signature and its freshness before accepting the price.

#### ERC-20

We retrieve the token's 1 hour TWAP price in ETH from Uniswap V3.

### Batch operations

#### Deposit into multiple rounds (ETH only)

Players can deposit ETH into multiple rounds in a single transaction. Once there is at least one deposit in a round, the value per entry, maximum number
of participants and protocol fee basis points are locked in. ERC-20/ERC-721 are not supported as their values fluctuate and their prices will become stale.

#### Rollover deposits/prizes (ETH only)

Players can roll over ETH from previous rounds to the current open round in a single transaction. ERC-20/ERC-721 are not supported as it complicates the logic, mainly the price retrieval from off-chain sources (ERC-721).

#### Claim prizes / withdraw deposits

Both prizes and deposits from cancelled rounds can be withdrawn in batch.

### Misc. rules

1. If the deposit is an ERC-20/ERC-721 then it must be allowed by the contract owner (LooksRare's multi-sig).
2. The cutoff time of each round is only set on the first deposit or when there are already deposits in the round and it's being transitioned to `Open`.

## Coverage

```
forge coverage -vvvvv --report lcov
LCOV_EXCLUDE=("test/*" "contracts/libraries/*" "contracts/Yolo.sol")
echo $LCOV_EXCLUDE | xargs lcov --output-file lcov-filtered.info --remove lcov.info
genhtml lcov-filtered.info --output-directory out
open out/index.html
```

## Tests
Set an dotenv file with :
```
FOUNDRY_INVARIANT_FAIL_ON_REVERT=true
export MAINNET_RPC_URL=https://rpc.ankr.com/eth
```
then
```
yarn install --ignore-scripts
forge test
```