
# LooksRare contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Mainnet
Arbitrum
Base
Potentially any EVM compatible L2 (Including ZK L2s)

___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
Tokens that can interact with the contract will be on a whitelist basis.

Mainnet
- LOOKS
- USDC
- USDT
- Any non-rebasing/non-taxable (except USDT) ERC-20 tokens with sufficient liquidity (e.g. MEME, APE)

L2
- Bridged LOOKS
- The chain’s USDC
- The chain’s USDT
- Any non-rebasing/non-taxable (except USDT) ERC-20 tokens with sufficient liquidity

___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
Tokens that can interact with the contract will be on a collection whitelist basis.

1Mainnet: We handpick collections from the top 200 collections by volume that have a floor price of higher than 0.01 ETH.
L2: We don’t plan to support ERC721 on L2 yet, but if we do the selected collections will fulfill the same conditions.

___

### Q: Do you plan to support ERC1155?
No
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
No ERC777s are expected to be whitelisted.
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

No FEE-ON-TRANSFER tokens are expected to be whitelisted.
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

No.
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
Trusted.

There is a possibility that ERC20 and ERC721 collections can have custom logic that allows privileged activity. Our assumption is that the behavior of whitelisted contracts are vetted before whitelisting.

___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
Trusted
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
DEFAULT_ADMIN_ROLE:
cancel(uint256 numberOfRounds) - cancel 1 or more rounds, starting from the current round, regardless of round state. No validations are performed.
togglePaused() - Pause or unpause contract
toggleOutflowAllowed() - Allow or disallow token outflow
updateRoundDuration(uint40 _roundDuration) - Update round duration. Capped at 1 hour
updateSignatureValidityPeriod(uint40 _signatureValidityPeriod) - Update Reservoir oracle signature validity period
updateValuePerEntry(uint96 _valuePerEntry) - Update value (in ETH wei) per entry
updateProtocolFeeRecipient(address _protocolFeeRecipient) - Update address that receives protocol fee
updateProtocolFeeBp(uint16 _protocolFeeBp) - Update fee percentage. Capped at 25%
updateProtocolFeeDiscountBp(uint16 _protocolFeeDiscountBp) - Update discount percentage if fee if paid in LOOKS. Capped at 100%
updateMaximumNumberOfParticipantsPerRound(uint40 _maximumNumberOfParticipantsPerRound) - Update maximum number of participants per round. Minimum value of 2.
updateReservoirOracle(address _reservoirOracle) - Update reservoir oracle address.
updateERC20Oracle(address _erc20Oracle) - Update ERC20 TWAP oracle address
 

OPERATOR:
 updateCurrenciesStatus(address[] calldata currencies, bool isAllowed) - add or remove token/collection addresses from the whitelist

___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
No.
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
For ERC721, transferFrom instead of safeTransferFrom is intentionally used

VRF providers / node operators are expected to be trusted

NFT floor prices provided by Reservoir are expected to be trusted and will be used to value any token id in the same collection.

Contract owners and operators are expected to be trusted

For non ETH entries, the number of entries granted is rounded down

A round that is in the Drawing state can be canceled by 2 ways; Anyone can cancel it if more than 1 day has passed since the round’s drawnAt time, or the DEFAULT_ADMIN_ROLE can cancel the current round in a drawing state (only used in emergency).

If the contract is paused after the current round is in Drawing, the current round will be drawn.

Cutoff time for a round will be 0 if it is drawn immediately as the round is started.

___

### Q: Please provide links to previous audits (if any).
We previously did an audit on YOLO V1 and YOLO V2 is an incremental improvement on the V1 contract so this should still be relevant.
https://github.com/peckshield/publications/blob/master/audit_reports/PeckShield-Audit-Report-LooksRare-YOLO-v1.0.pdf 
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
Chainlink VRF is used to fulfill randomness on mainnet and Arbitrum

Gelato VRF is used to fulfill randomness on Base

We might use other VRF providers on other L2s

We use Reservoir’s NFT data oracle (https://docs.reservoir.tools/reference/getoraclecollectionsflooraskv6) to retrieve an NFT collection’s floor price
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
Yes 
___

### Q: Do you expect to use any of the following tokens with non-standard behaviour with the smart contracts?
No.
___

### Q: Add links to relevant protocol resources
https://looksrare.org/yolo
___



# Audit scope


[contracts-yolo @ 1cfb4cfa42855c831485618f44001fc3c5ed1876](https://github.com/LooksRare/contracts-yolo/tree/1cfb4cfa42855c831485618f44001fc3c5ed1876)
- [contracts-yolo/contracts/YoloV2.sol](contracts-yolo/contracts/YoloV2.sol)
- [contracts-yolo/contracts/interfaces/IYoloV2.sol](contracts-yolo/contracts/interfaces/IYoloV2.sol)

