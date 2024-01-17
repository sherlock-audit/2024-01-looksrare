// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IYoloV2 {
    /**
     * @notice A round's status
     * @param None The round does not exist
     * @param Open The round is open for deposits
     * @param Drawing The round is being drawn
     * @param Drawn The round has been drawn
     * @param Cancelled The round has been cancelled
     */
    enum RoundStatus {
        None,
        Open,
        Drawing,
        Drawn,
        Cancelled
    }

    /**
     * @dev Giving TokenType a namespace to avoid name conflicts with TransferManager.
     */
    enum YoloV2__TokenType {
        ETH,
        ERC20,
        ERC721
    }

    event CurrenciesStatusUpdated(address[] currencies, bool isAllowed);
    event Deposited(address depositor, uint256 roundId, uint256 entriesCount);
    event ERC20OracleUpdated(address erc20Oracle);
    event MaximumNumberOfParticipantsPerRoundUpdated(uint40 maximumNumberOfParticipantsPerRound);
    event MultipleRoundsDeposited(
        address depositor,
        uint256 startingRoundId,
        uint256[] amounts,
        uint256[] entriesCounts
    );
    event PrizesClaimed(address winner, WithdrawalCalldata[] withdrawalCalldata);
    event DepositsWithdrawn(address depositor, WithdrawalCalldata[] withdrawalCalldata);
    event Rollover(
        address depositor,
        WithdrawalCalldata[] withdrawalCalldata,
        uint256 enteredRoundId,
        uint256 entriesCount
    );
    event ProtocolFeeBpUpdated(uint16 protocolFeeBp);
    event ProtocolFeeDiscountBpUpdated(uint16 protocolFeeDiscountBp);
    event ProtocolFeePayment(uint256 amount, address currency);
    event ProtocolFeeRecipientUpdated(address protocolFeeRecipient);
    event RandomnessRequested(uint256 roundId, uint256 requestId);
    event ReservoirOracleUpdated(address reservoirOracle);
    event RoundDurationUpdated(uint40 roundDuration);
    event RoundsCancelled(uint256 startingRoundId, uint256 numberOfRounds);
    event RoundStatusUpdated(uint256 roundId, RoundStatus status);
    event SignatureValidityPeriodUpdated(uint40 signatureValidityPeriod);
    event ValuePerEntryUpdated(uint256 valuePerEntry);
    event OutflowAllowedUpdated(bool isAllowed);

    error AlreadyWithdrawn();
    error CutoffTimeNotReached();
    error DrawExpirationTimeNotReached();
    error InsufficientParticipants();
    error InvalidCollection();
    error InvalidCurrency();
    error InvalidIndex();
    error InvalidLength();
    error InvalidRoundDuration();
    error InvalidStatus();
    error InvalidTokenType();
    error InvalidValue();
    error MaximumNumberOfDepositsReached();
    error MaximumNumberOfParticipantsReached();
    error MessageIdInvalid();
    error NotOperator();
    error NotOwner();
    error NotWinner();
    error NotDepositor();
    error OnePlayerCannotFillUpTheWholeRound();
    error OutflowNotAllowed();
    error ProtocolFeeNotPaid();
    error RandomnessRequestAlreadyExists();
    error RoundCannotBeClosed();
    error SignatureExpired();
    error ZeroDeposits();
    error ZeroRounds();

    /**
     * @param owner The owner of the contract.
     * @param operator The operator of the contract.
     * @param roundDuration The duration of each round.
     * @param valuePerEntry The value of each entry in ETH.
     * @param protocolFeeRecipient The protocol fee recipient.
     * @param protocolFeeBp The protocol fee basis points.
     * @param protocolFeeDiscountBp The protocol fee discount basis points.
     * @param keyHash Chainlink VRF key hash
     * @param subscriptionId Chainlink VRF subscription ID
     * @param vrfCoordinator Chainlink VRF coordinator address
     * @param reservoirOracle Reservoir off-chain oracle address
     * @param erc20Oracle ERC20 on-chain oracle address
     * @param transferManager Transfer manager
     * @param signatureValidityPeriod The validity period of a Reservoir signature.
     * @param looks LOOKS token address.
     */
    struct ConstructorCalldata {
        address owner;
        address operator;
        uint40 maximumNumberOfParticipantsPerRound;
        uint40 roundDuration;
        uint96 valuePerEntry;
        address protocolFeeRecipient;
        uint16 protocolFeeBp;
        uint16 protocolFeeDiscountBp;
        bytes32 keyHash;
        uint64 subscriptionId;
        address vrfCoordinator;
        address reservoirOracle;
        address transferManager;
        address erc20Oracle;
        address weth;
        uint40 signatureValidityPeriod;
        address looks;
    }

    /**
     * @param id The id of the response.
     * @param payload The payload of the response.
     * @param timestamp The timestamp of the response.
     * @param signature The signature of the response.
     */
    struct ReservoirOracleFloorPrice {
        bytes32 id;
        bytes payload;
        uint256 timestamp;
        bytes signature;
    }

    /**
     * @param tokenType The type of the token.
     * @param tokenAddress The address of the token.
     * @param tokenIdsOrAmounts The ids (ERC-721) or amounts (ERC-20) of the tokens.
     * @param reservoirOracleFloorPrice The Reservoir oracle floor price. Required for ERC-721 deposits.
     */
    struct DepositCalldata {
        YoloV2__TokenType tokenType;
        address tokenAddress;
        uint256[] tokenIdsOrAmounts;
        ReservoirOracleFloorPrice reservoirOracleFloorPrice;
    }

    /*
     * @notice A round
     * @dev The storage layout of a round is as follows:
     * |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
     * | empty (72 bits) | numberOfParticipants (40) bits) | drawnAt (40 bits) | cutoffTime (40 bits) | protcoolFeeBp (16 bits) | maximumNumberOfParticipants (40 bits) | status (8 bits)                                     |
     * |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
     * | valuePerEntry (96 bits) | winner (160 bits)                                                                                                                                                                          |
     * |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
     * | protocolFeeOwed (256 bits)                                                                                                                                                                                           |
     * |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
     * | deposits length (256 bits)                                                                                                                                                                                           |
     * |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
     *
     * @param status The status of the round.
     * @param maximumNumberOfParticipants The maximum number of participants.
     * @param protocolFeeBp The protocol fee basis points.
     * @param cutoffTime The cutoff time of the round.
     * @param drawnAt The time the round was drawn.
     * @param numberOfParticipants The current number of participants.
     * @param winner The winner of the round.
     * @param valuePerEntry The value of each entry in ETH.
     * @param protocolFeeOwed The protocol fee owed in ETH.
     * @param deposits The deposits in the round.
     */
    struct Round {
        RoundStatus status;
        uint40 maximumNumberOfParticipants;
        uint16 protocolFeeBp;
        uint40 cutoffTime;
        uint40 drawnAt;
        uint40 numberOfParticipants;
        address winner;
        uint96 valuePerEntry;
        uint256 protocolFeeOwed;
        Deposit[] deposits;
    }

    /**
     * @notice A deposit in a round.
     * @dev The storage layout of a deposit is as follows:
     * |-------------------------------------------------------------------------------------------|
     * | empty (88 bits) | tokenAddress (160 bits) | tokenType (8 bits)                            |
     * |-------------------------------------------------------------------------------------------|
     * | tokenId (256 bits)                                                                        |
     * |-------------------------------------------------------------------------------------------|
     * | tokenAmount (256 bits)                                                                    |
     * |-------------------------------------------------------------------------------------------|
     * | empty (48 bits) | currentEntryIndex (40 bits) | withdrawn (8 bits) | depositor (160 bits) |
     * |-------------------------------------------------------------------------------------------|
     *
     * @param tokenType The type of the token.
     * @param tokenAddress The address of the token.
     * @param tokenId The id of the token.
     * @param tokenAmount The amount of the token.
     * @param depositor The depositor of the token.
     * @param withdrawn Whether the token has been withdrawn.
     * @param currentEntryIndex The current entry index.
     */
    struct Deposit {
        YoloV2__TokenType tokenType;
        address tokenAddress;
        uint256 tokenId;
        uint256 tokenAmount;
        address depositor;
        bool withdrawn;
        uint40 currentEntryIndex;
    }

    /**
     * @param exists Whether the request exists.
     * @param roundId The id of the round.
     * @param randomWord The random words returned by Chainlink VRF.
     *                   If randomWord == 0, then the request is still pending.
     */
    struct RandomnessRequest {
        bool exists;
        uint40 roundId;
        uint256 randomWord;
    }

    /**
     * @param roundId The id of the round.
     * @param depositIndices The indices of the deposits to be claimed.
     */
    struct WithdrawalCalldata {
        uint256 roundId;
        uint256[] depositIndices;
    }

    /**
     * @notice This is used to accumulate the amount of tokens to be transferred.
     * @param tokenAddress The address of the token.
     * @param amount The amount of tokens accumulated.
     */
    struct TransferAccumulator {
        address tokenAddress;
        uint256 amount;
    }

    /**
     * @notice This function cancels an expired round that does not have at least 2 participants.
     */
    function cancel() external;

    /**
     * @notice This function cancels multiple rounds (current and future) without any validations (can be any state).
     *         Only callable by the contract owner.
     */
    function cancel(uint256 numberOfRounds) external;

    /**
     * @notice Cancels a round after randomness request if the randomness request
     *         does not arrive after a certain amount of time.
     *         Only callable by contract owner.
     */
    function cancelAfterRandomnessRequest() external;

    /**
     * @notice This function allows the winner of a round to withdraw the prizes.
     * @param withdrawalCalldata The rounds and the indices for the rounds for the prizes to claim.
     * @param payWithLOOKS Whether to pay for the protocol fee with LOOKS.
     */
    function claimPrizes(WithdrawalCalldata[] calldata withdrawalCalldata, bool payWithLOOKS) external payable;

    /**
     * @notice This function calculates the ETH payment required to claim the prizes for multiple rounds.
     * @param withdrawalCalldata The rounds and the indices for the rounds for the prizes to claim.
     * @param payWithLOOKS Whether to pay for the protocol fee with LOOKS.
     * @return protocolFeeOwed The protocol fee owed in ETH or LOOKS.
     */
    function getClaimPrizesPaymentRequired(
        WithdrawalCalldata[] calldata withdrawalCalldata,
        bool payWithLOOKS
    ) external view returns (uint256 protocolFeeOwed);

    /**
     * @notice This function allows withdrawal of deposits from a round if the round is cancelled
     * @param withdrawalCalldata The rounds and the indices for the rounds for the prizes to claim.
     */
    function withdrawDeposits(WithdrawalCalldata[] calldata withdrawalCalldata) external;

    /**
     * @notice This function allows players to deposit into a round.
     * @param roundId The open round ID.
     * @param deposits The ERC-20/ERC-721 deposits to be made.
     */
    function deposit(uint256 roundId, DepositCalldata[] calldata deposits) external payable;

    /**
     * @notice This function allows a player to deposit into multiple rounds at once. ETH only.
     * @param amounts The amount of ETH to deposit into each round.
     */
    function depositETHIntoMultipleRounds(uint256[] calldata amounts) external payable;

    /**
     * @notice This function draws a round.
     */
    function drawWinner() external;

    /**
     * @notice This function returns the given round's data.
     * @param roundId The round ID.
     * @return status The status of the round.
     * @return maximumNumberOfParticipants The round's maximum number of participants.
     * @return roundProtocolFeeBp The round's protocol fee in basis points.
     * @return cutoffTime The round's cutoff time.
     * @return drawnAt The time the round was drawn.
     * @return numberOfParticipants The round's current number of participants.
     * @return winner The round's winner.
     * @return roundValuePerEntry The round's value per entry.
     * @return protocolFeeOwed The round's protocol fee owed in ETH.
     * @return deposits The round's deposits.
     */
    function getRound(
        uint256 roundId
    )
        external
        view
        returns (
            IYoloV2.RoundStatus status,
            uint40 maximumNumberOfParticipants,
            uint16 roundProtocolFeeBp,
            uint40 cutoffTime,
            uint40 drawnAt,
            uint40 numberOfParticipants,
            address winner,
            uint96 roundValuePerEntry,
            uint256 protocolFeeOwed,
            Deposit[] memory deposits
        );

    /**
     * @notice This function allows a player to rollover prizes or deposits from a cancelled round to the current round.
     * @param withdrawalCalldata The rounds and the indices for the rounds for the prizes to claim.
     * @param payWithLOOKS Whether to pay for the protocol fee with LOOKS.
     */
    function rolloverETH(WithdrawalCalldata[] calldata withdrawalCalldata, bool payWithLOOKS) external;

    /**
     * @notice This function allows the owner to pause/unpause the contract.
     */
    function togglePaused() external;

    /**
     * @notice This function allows the owner to allow/forbid token outflow.
     */
    function toggleOutflowAllowed() external;

    /**
     * @notice This function allows the owner to update currency statuses (ETH, ERC-20 and NFTs).
     * @param currencies Currency addresses (address(0) for ETH)
     * @param isAllowed Whether the currencies should be allowed in the yolos
     * @dev Only callable by owner.
     */
    function updateCurrenciesStatus(address[] calldata currencies, bool isAllowed) external;

    /**
     * @notice This function allows the owner to update the duration of each round.
     * @param _roundDuration The duration of each round.
     */
    function updateRoundDuration(uint40 _roundDuration) external;

    /**
     * @notice This function allows the owner to update the signature validity period.
     * @param _signatureValidityPeriod The signature validity period.
     */
    function updateSignatureValidityPeriod(uint40 _signatureValidityPeriod) external;

    /**
     * @notice This function allows the owner to update the value of each entry in ETH.
     * @param _valuePerEntry The value of each entry in ETH.
     */
    function updateValuePerEntry(uint96 _valuePerEntry) external;

    /**
     * @notice This function allows the owner to update the protocol fee discount in basis points if paid in LOOKS.
     * @param protocolFeeDiscountBp The protocol fee discount in basis points.
     */
    function updateProtocolFeeDiscountBp(uint16 protocolFeeDiscountBp) external;

    /**
     * @notice This function allows the owner to update the protocol fee in basis points.
     * @param protocolFeeBp The protocol fee in basis points.
     */
    function updateProtocolFeeBp(uint16 protocolFeeBp) external;

    /**
     * @notice This function allows the owner to update the protocol fee recipient.
     * @param protocolFeeRecipient The protocol fee recipient.
     */
    function updateProtocolFeeRecipient(address protocolFeeRecipient) external;

    /**
     * @notice This function allows the owner to update Reservoir oracle's address.
     * @param reservoirOracle Reservoir oracle address.
     */
    function updateReservoirOracle(address reservoirOracle) external;

    /**
     * @notice This function allows the owner to update the maximum number of participants per round.
     * @param _maximumNumberOfParticipantsPerRound The maximum number of participants per round.
     */
    function updateMaximumNumberOfParticipantsPerRound(uint40 _maximumNumberOfParticipantsPerRound) external;

    /**
     * @notice This function allows the owner to update ERC20 oracle's address.
     * @param erc20Oracle ERC20 oracle address.
     */
    function updateERC20Oracle(address erc20Oracle) external;
}
