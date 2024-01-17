// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockVRFCoordinatorV2} from "./mock/MockVRFCoordinatorV2.sol";
import {MockReservoirOracle} from "./mock/MockReservoirOracle.sol";
import {MockPriceOracle} from "./mock/MockPriceOracle.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";
import {MockWETH} from "./mock/MockWETH.sol";
import {TransferManager} from "./mock/TransferManager.sol";

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    // "price":4.62827
    bytes constant reservoirPricePayload =
        hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000403aef02caa94c93";
    bool public callsMustBeValid;

    YoloV2 public yolo;
    MockERC20 public erc20;
    MockERC721 public erc721;
    MockVRFCoordinatorV2 public vrfCoordinatorV2;
    MockReservoirOracle public reservoirOracle;
    MockPriceOracle public priceOracle;
    TransferManager public transferManager;
    address public owner;
    uint256 public valuePerEntry;

    address private constant ETH = address(0);

    uint256 public ghost_ETH_prizesDepositedSum;
    uint256 public ghost_ETH_depositsWithdrawnSum;
    uint256 public ghost_ETH_prizesClaimedSum;
    uint256 public ghost_ETH_entriesSum;

    uint256 public ghost_ERC20_prizesDepositedSum;
    uint256 public ghost_ERC20_depositsWithdrawnSum;
    uint256 public ghost_ERC20_prizesClaimedSum;
    uint256 public ghost_ERC20_entriesSum;

    uint256 public ghost_ERC721_prizesDepositedSum;
    uint256 public ghost_ERC721_depositsWithdrawnSum;
    uint256 public ghost_ERC721_prizesClaimedSum;
    uint256 public ghost_ERC721_entriesSum;

    uint256 public ghost_ETH_feesCollectedSum;

    address[100] internal actors;
    address internal currentActor;

    mapping(bytes => uint256) public calls;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, 99)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier countCall(bytes memory key) {
        calls[key]++;
        _;
    }

    function callSummary() external view {
        console2.log("Call summary:");
        console2.log("-------------------");
        console2.log("Deposit", calls["deposit"]);
        console2.log("Deposit ETH into multiple rounds", calls["depositETHIntoMultipleRounds"]);
        console2.log("Draw winner", calls["drawWinner"]);
        console2.log("Cancel", calls["cancel"]);
        console2.log("Cancel after randomness request", calls["cancelAfterRandomnessRequest"]);
        console2.log("Cancel current round and deposit", calls["cancelCurrentRoundAndDepositToTheNextRound"]);
        console2.log("Claim prizes", calls["claimPrizes"]);
        console2.log("Withdraw deposits", calls["withdrawDeposits"]);
        console2.log("Fulfill random words", calls["fulfillRandomWords"]);
        console2.log("-------------------");

        console2.log("Token flow summary:");
        console2.log("-------------------");
        console2.log("ETH prizes deposited:", ghost_ETH_prizesDepositedSum);
        console2.log("ETH deposits withdrawn:", ghost_ETH_depositsWithdrawnSum);
        console2.log("ETH prizes claimed:", ghost_ETH_prizesClaimedSum);
        console2.log("ETH entries sum:", ghost_ETH_entriesSum);

        console2.log("ERC20 prizes deposited:", ghost_ERC20_prizesDepositedSum);
        console2.log("ERC20 deposits withdrawn:", ghost_ERC20_depositsWithdrawnSum);
        console2.log("ERC20 prizes claimed:", ghost_ERC20_prizesClaimedSum);
        console2.log("ERC20 entries sum:", ghost_ERC20_entriesSum);

        console2.log("ERC721 prizes deposited:", ghost_ERC721_prizesDepositedSum);
        console2.log("ERC721 deposits withdrawn:", ghost_ERC721_depositsWithdrawnSum);
        console2.log("ERC721 prizes claimed:", ghost_ERC721_prizesClaimedSum);
        console2.log("ERC721 entries sum:", ghost_ERC721_entriesSum);

        console2.log("Total entries sum:", ghost_ETH_entriesSum + ghost_ERC20_entriesSum + ghost_ERC721_entriesSum);
        console2.log("ETH fees collected:", ghost_ETH_feesCollectedSum);
        console2.log("-------------------");
    }

    constructor(
        YoloV2 _yolo,
        MockVRFCoordinatorV2 _vrfCoordinatorV2,
        MockReservoirOracle _reservoirOracle,
        MockPriceOracle _priceOracle,
        TransferManager _transferManager,
        MockERC20 _erc20,
        MockERC721 _erc721,
        address _owner
    ) {
        yolo = _yolo;
        vrfCoordinatorV2 = _vrfCoordinatorV2;
        reservoirOracle = _reservoirOracle;
        priceOracle = _priceOracle;
        transferManager = _transferManager;
        erc20 = _erc20;
        erc721 = _erc721;
        owner = _owner;
        // We'll assume the same value per entry for all rounds
        valuePerEntry = yolo.valuePerEntry();

        for (uint256 i; i < 100; i++) {
            actors[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }

        callsMustBeValid = vm.envBool("FOUNDRY_INVARIANT_FAIL_ON_REVERT");
    }

    function deposit(uint256 roundId, uint256 seed) public useActor(seed) countCall("deposit") {
        uint256 roundsCount = yolo.roundsCount();
        // Get currently playing roundId ~90% of the time
        roundId = (callsMustBeValid || seed % 10 != 0) ? roundsCount : bound(roundId, 1, roundsCount);

        if (!_isDepositValid(roundId)) return;

        uint256 ethTotal = valuePerEntry * (seed % 10);
        uint256 erc20Total;

        uint256 depositCount = (seed % 5) + 1; // 1 to 5
        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](depositCount);

        uint256 erc20Amount = ((seed % 10) + 1) * 100 ether;
        for (uint256 i; i < depositCount; i++) {
            if (seed % (i + 1) == 0) {
                depositsCalldata[i].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
                depositsCalldata[i].tokenAddress = address(erc20);
                uint256[] memory erc20Amounts = new uint256[](1);
                erc20Amounts[0] = erc20Amount;
                depositsCalldata[i].tokenIdsOrAmounts = erc20Amounts;

                ghost_ERC20_entriesSum += _getEntriesForERC20(roundId, erc20Amount);

                erc20Total += erc20Amount;
            } else {
                uint256 tokenId = erc721.totalSupply();
                erc721.mint(currentActor, tokenId);
                erc721.approve(address(transferManager), tokenId);

                depositsCalldata[i].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
                depositsCalldata[i].tokenAddress = address(erc721);
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = tokenId;
                depositsCalldata[i].tokenIdsOrAmounts = tokenIds;
                depositsCalldata[i].reservoirOracleFloorPrice = _createReservoirOracleFloorPrice(
                    address(erc721),
                    reservoirPricePayload
                );

                ghost_ERC721_entriesSum += _getEntriesForERC721(roundId);

                ghost_ERC721_prizesDepositedSum += 1;
            }
        }

        erc20.mint(currentActor, erc20Total);
        erc20.approve(address(transferManager), erc20Total);
        _grantApprovalsToTransferManager();
        if (ethTotal != 0) {
            vm.deal(currentActor, ethTotal);
            yolo.deposit{value: ethTotal}(roundId, depositsCalldata);
            uint256 entriesCount = ethTotal / valuePerEntry;

            ghost_ETH_prizesDepositedSum += ethTotal;
            ghost_ETH_entriesSum += entriesCount;
        } else {
            yolo.deposit(roundId, depositsCalldata);
        }

        ghost_ERC20_prizesDepositedSum += erc20Total;
    }

    function depositETHIntoMultipleRounds(
        uint256 seed
    ) public useActor(seed) countCall("depositETHIntoMultipleRounds") {
        uint256 roundId = yolo.roundsCount();
        if (!_isDepositValid(roundId)) return;

        uint256 startingEthValue = valuePerEntry * ((seed % 10) + 1);
        uint256 totalEthValue;

        uint256 depositCount = (seed % 5) + 1; // 1 to 5
        uint256[] memory amounts = new uint256[](depositCount);
        for (uint256 i; i < depositCount; i++) {
            uint256 amount = startingEthValue * (i + 1);
            amounts[i] = amount;
            totalEthValue += amount;
        }

        vm.deal(currentActor, totalEthValue);
        yolo.depositETHIntoMultipleRounds{value: totalEthValue}(amounts);
        uint256 entriesCount = totalEthValue / valuePerEntry;

        ghost_ETH_prizesDepositedSum += totalEthValue;
        ghost_ETH_entriesSum += entriesCount;
    }

    function drawWinner(uint256 seed) public countCall("drawWinner") {
        uint256 roundId = yolo.roundsCount();

        (IYoloV2.RoundStatus status, , , uint40 cutoffTime, , uint40 numberOfParticipants, , , , ) = yolo.getRound(
            roundId
        );

        // Success rate control
        if (seed % 10 != 0) {
            vm.warp(cutoffTime);
        }

        if (callsMustBeValid) {
            if (status != IYoloV2.RoundStatus.Open) return;
            if (block.timestamp < cutoffTime) return;
            if (numberOfParticipants < 2) return;
        }

        yolo.drawWinner();
    }

    function fulfillRandomWords(uint256 randomWord) public countCall("fulfillRandomWords") {
        vrfCoordinatorV2.fulfillRandomWords(randomWord);
    }

    function claimPrizes(uint256 roundId, uint256 seed) public countCall("claimPrizes") {
        uint256 roundsCount = yolo.roundsCount();
        roundId = bound(roundId, 1, roundsCount);

        (
            IYoloV2.RoundStatus status,
            ,
            ,
            ,
            ,
            ,
            address winner,
            ,
            uint256 protocolFeeOwed,
            IYoloV2.Deposit[] memory deposits
        ) = yolo.getRound(roundId);

        if (callsMustBeValid) {
            if (status != IYoloV2.RoundStatus.Drawn) return;
        }

        uint256 claimCount = (seed % deposits.length) + 1;

        uint256[] memory prizesIndices = new uint256[](claimCount);
        uint256 ethAmount;
        for (uint256 i; i < claimCount; i++) {
            prizesIndices[i] = i;
            IYoloV2.Deposit memory prize = deposits[i];

            if (callsMustBeValid) {
                if (prize.withdrawn) return;
            }

            if (prize.tokenType == IYoloV2.YoloV2__TokenType.ETH) {
                ethAmount += prize.tokenAmount;
            } else if (prize.tokenType == IYoloV2.YoloV2__TokenType.ERC20) {
                ghost_ERC20_prizesClaimedSum += prize.tokenAmount;
            } else if (prize.tokenType == IYoloV2.YoloV2__TokenType.ERC721) {
                ghost_ERC721_prizesClaimedSum += 1;
            }
        }

        ghost_ETH_prizesClaimedSum += (ethAmount > protocolFeeOwed) ? ethAmount - protocolFeeOwed : 0;
        ghost_ETH_feesCollectedSum += protocolFeeOwed;

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = roundId;
        withdrawalCalldata[0].depositIndices = prizesIndices;

        uint256 paymentRequired = yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false);
        vm.deal(winner, paymentRequired);
        vm.prank(winner);
        yolo.claimPrizes{value: paymentRequired}(withdrawalCalldata, false);
    }

    function cancel(uint256 seed) public countCall("cancel") {
        uint256 roundId = yolo.roundsCount();
        if (!_isCancelValid(roundId, seed % 2 != 0)) return;

        yolo.cancel();
    }

    function cancelCurrentRoundAndDepositToTheNextRound(
        uint256 seed
    ) public useActor(seed) countCall("cancelCurrentRoundAndDepositToTheNextRound") {
        // Prepare cancel
        uint256 roundId = yolo.roundsCount();
        if (!_isCancelValid(roundId, seed % 4 != 0)) return;

        // Prepare deposit
        uint256 ethTotal = valuePerEntry * (seed % 10);
        uint256 erc20Total;

        uint256 depositCount = (seed % 5) + 1; // 1 to 5
        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](depositCount);

        uint256 erc20Amount = ((seed % 10) + 1) * 100 ether;
        for (uint256 i; i < depositCount; i++) {
            if (seed % (i + 1) == 0) {
                depositsCalldata[i].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
                depositsCalldata[i].tokenAddress = address(erc20);
                uint256[] memory erc20Amounts = new uint256[](1);
                erc20Amounts[0] = erc20Amount;
                depositsCalldata[i].tokenIdsOrAmounts = erc20Amounts;

                ghost_ERC20_entriesSum += _getEntriesForERC20(roundId, erc20Amount);

                erc20Total += erc20Amount;
            } else {
                uint256 tokenId = erc721.totalSupply();
                erc721.mint(currentActor, tokenId);
                erc721.approve(address(transferManager), tokenId);

                depositsCalldata[i].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
                depositsCalldata[i].tokenAddress = address(erc721);
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = tokenId;
                depositsCalldata[i].tokenIdsOrAmounts = tokenIds;
                depositsCalldata[i].reservoirOracleFloorPrice = _createReservoirOracleFloorPrice(
                    address(erc721),
                    reservoirPricePayload
                );

                ghost_ERC721_entriesSum += _getEntriesForERC721(roundId);

                ghost_ERC721_prizesDepositedSum += 1;
            }
        }

        erc20.mint(currentActor, erc20Total);
        erc20.approve(address(transferManager), erc20Total);
        _grantApprovalsToTransferManager();
        if (ethTotal != 0) {
            vm.deal(currentActor, ethTotal);
            yolo.cancelCurrentRoundAndDepositToTheNextRound{value: ethTotal}(depositsCalldata);
            uint256 entriesCount = ethTotal / valuePerEntry;

            ghost_ETH_prizesDepositedSum += ethTotal;
            ghost_ETH_entriesSum += entriesCount;
        } else {
            yolo.cancelCurrentRoundAndDepositToTheNextRound(depositsCalldata);
        }

        ghost_ERC20_prizesDepositedSum += erc20Total;
    }

    function cancelAfterRandomnessRequest(uint256 seed) public countCall("cancelAfterRandomnessRequest") {
        uint256 roundId = yolo.roundsCount();

        (IYoloV2.RoundStatus status, , , , uint40 drawnAt, , , , , ) = yolo.getRound(roundId);

        // Success rate control
        if (seed % 2 != 0) {
            vm.warp(block.timestamp + 1 days);
        }
        address caller = (callsMustBeValid || seed % 10 != 0) ? owner : actors[bound(seed, 0, 99)];

        if (callsMustBeValid) {
            if (status != IYoloV2.RoundStatus.Drawing) return;
            if (block.timestamp < drawnAt + 1 days) return;
        }

        vm.prank(caller);
        yolo.cancelAfterRandomnessRequest();
    }

    function withdrawDeposits(uint256 roundId, uint256 seed) public countCall("withdrawDeposits") {
        uint256 roundsCount = yolo.roundsCount();
        roundId = bound(roundId, 1, roundsCount);

        (IYoloV2.RoundStatus status, , , , , , , , , IYoloV2.Deposit[] memory deposits) = yolo.getRound(roundId);

        if (callsMustBeValid && status != IYoloV2.RoundStatus.Cancelled) return;
        if (callsMustBeValid && deposits.length == 0) return;

        IYoloV2.Deposit memory randomDeposit = deposits[seed % deposits.length];
        address withdrawer = randomDeposit.depositor;

        uint256 withdrawerDepositCount;
        for (uint256 i; i < deposits.length; i++) {
            if (deposits[i].depositor == withdrawer && !(callsMustBeValid && deposits[i].withdrawn)) {
                withdrawerDepositCount++;
            }
        }
        if (callsMustBeValid && withdrawerDepositCount == 0) return;

        uint256[] memory depositsIndices = new uint256[](withdrawerDepositCount);
        for (uint256 i; i < deposits.length; i++) {
            IYoloV2.Deposit memory singleDeposit = deposits[i];
            if (deposits[i].depositor == withdrawer && !(callsMustBeValid && deposits[i].withdrawn)) {
                depositsIndices[--withdrawerDepositCount] = i;

                if (singleDeposit.tokenType == IYoloV2.YoloV2__TokenType.ETH) {
                    ghost_ETH_depositsWithdrawnSum += singleDeposit.tokenAmount;
                } else if (singleDeposit.tokenType == IYoloV2.YoloV2__TokenType.ERC20) {
                    ghost_ERC20_depositsWithdrawnSum += singleDeposit.tokenAmount;
                } else if (singleDeposit.tokenType == IYoloV2.YoloV2__TokenType.ERC721) {
                    ghost_ERC721_depositsWithdrawnSum += 1;
                }
            }
        }

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = roundId;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        address caller = (callsMustBeValid || seed % 10 != 0) ? withdrawer : actors[bound(seed, 0, 99)];

        vm.prank(caller);
        yolo.withdrawDeposits(withdrawalsCalldata);
    }

    function _getEntriesForERC20(uint256 roundId, uint256 erc20Amount) private view returns (uint256 entriesCount) {
        uint256 price = yolo.prices(address(erc20), roundId);
        if (price == 0) {
            price = priceOracle.getTWAP(address(erc20), uint32(3_600));
        }
        entriesCount = ((price * erc20Amount) / (10 ** erc20.decimals())) / valuePerEntry;
    }

    function _getEntriesForERC721(uint256 roundId) private view returns (uint256 entriesCount) {
        uint256 price = yolo.prices(address(erc721), roundId);
        if (price == 0) {
            (, price) = abi.decode(reservoirPricePayload, (address, uint256));
        }
        entriesCount = price / valuePerEntry;
    }

    function _isCancelValid(uint256 roundId, bool warp) private returns (bool) {
        (IYoloV2.RoundStatus status, , , uint40 cutoffTime, , uint40 numberOfParticipants, , , , ) = yolo.getRound(
            roundId
        );

        // Success rate control
        if (warp) {
            vm.warp(cutoffTime);
        }

        if (callsMustBeValid) {
            if (
                status != IYoloV2.RoundStatus.Open ||
                cutoffTime == 0 ||
                block.timestamp < cutoffTime ||
                numberOfParticipants > 1
            ) return false;
        }

        return true;
    }

    function _isDepositValid(uint256 roundId) private view returns (bool) {
        (IYoloV2.RoundStatus status, , , uint40 cutoffTime, , , , , , ) = yolo.getRound(roundId);

        if (callsMustBeValid) {
            if (status != IYoloV2.RoundStatus.Open || block.timestamp >= cutoffTime) return false;
        }

        return true;
    }

    function _grantApprovalsToTransferManager() private {
        if (!transferManager.hasUserApprovedOperator(currentActor, address(yolo))) {
            address[] memory operators = new address[](1);
            operators[0] = address(yolo);
            transferManager.grantApprovals(operators);
        }
    }

    function _createReservoirOracleFloorPrice(
        address collection,
        bytes memory payload
    ) private view returns (IYoloV2.ReservoirOracleFloorPrice memory floorPrice) {
        bytes32 RESERVOIR_ORACLE_MESSAGE_TYPEHASH = keccak256(
            "Message(bytes32 id,bytes payload,uint256 timestamp,uint256 chainId)"
        );

        bytes32 RESERVOIR_ORACLE_ID_TYPEHASH = keccak256(
            "ContractWideCollectionPrice(uint8 kind,uint256 twapSeconds,address contract,bool onlyNonFlaggedTokens)"
        );

        floorPrice.timestamp = block.timestamp;
        floorPrice.payload = payload;

        bytes32 expectedMessageId = keccak256(
            abi.encode(RESERVOIR_ORACLE_ID_TYPEHASH, uint8(1), 3_600, collection, false)
        );
        floorPrice.id = expectedMessageId;

        // Generate the message hash to be signed
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(
                    abi.encode(
                        RESERVOIR_ORACLE_MESSAGE_TYPEHASH,
                        expectedMessageId,
                        keccak256(payload),
                        floorPrice.timestamp,
                        block.chainid
                    )
                )
            )
        );
        // Use private key (69) of the owner of MockReservoirOracle to create signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(69, messageHash);
        floorPrice.signature = abi.encodePacked(r, s, v);
    }
}

contract YoloV2_Invariants is TestHelpers {
    Handler public handler;
    MockERC20 mockERC20;

    function setUp() public {
        // 69 as the private key for owner
        owner = vm.addr(69);

        MockVRFCoordinatorV2 vrfCoordinatorV2 = new MockVRFCoordinatorV2();
        MockWETH weth = new MockWETH();
        transferManager = new TransferManager(owner);
        MockPriceOracle priceOracle = new MockPriceOracle(owner, address(weth));
        MockReservoirOracle reservoirOracle = new MockReservoirOracle(owner);
        mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();

        yolo = new YoloV2(
            IYoloV2.ConstructorCalldata({
                owner: owner,
                operator: operator,
                maximumNumberOfParticipantsPerRound: MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND,
                roundDuration: ROUND_DURATION,
                valuePerEntry: 0.01 ether,
                protocolFeeRecipient: protocolFeeRecipient,
                protocolFeeBp: 300,
                protocolFeeDiscountBp: 7_500,
                keyHash: KEY_HASH,
                subscriptionId: SUBSCRIPTION_ID,
                vrfCoordinator: address(vrfCoordinatorV2),
                reservoirOracle: address(reservoirOracle),
                transferManager: address(transferManager),
                erc20Oracle: address(priceOracle),
                weth: address(weth),
                signatureValidityPeriod: 90 seconds,
                looks: LOOKS
            })
        );

        vrfCoordinatorV2.setYolo(address(yolo));

        vm.startPrank(owner);
        priceOracle.addOracle(address(mockERC20), 500);
        transferManager.allowOperator(address(yolo));
        vm.stopPrank();

        address[] memory currencies = new address[](2);
        currencies[0] = address(mockERC20);
        currencies[1] = address(mockERC721);
        vm.prank(operator);
        yolo.updateCurrenciesStatus(currencies, true);

        handler = new Handler(
            yolo,
            vrfCoordinatorV2,
            reservoirOracle,
            priceOracle,
            transferManager,
            mockERC20,
            mockERC721,
            owner
        );
        targetContract(address(handler));
        excludeContract(yolo.protocolFeeRecipient());
    }

    /**
     * Invariant A: YoloV2 contract ERC20 balance >= ∑ERC20 prizes deposited - (∑deposits withdrawn in ERC20 + ∑prizes claimed in ERC20)
     */
    function invariant_A() public {
        assertGe(
            mockERC20.balanceOf(address(yolo)),
            handler.ghost_ERC20_prizesDepositedSum() -
                handler.ghost_ERC20_depositsWithdrawnSum() -
                handler.ghost_ERC20_prizesClaimedSum()
        );
    }

    /**
     * Invariant B: ∑ETH prizes deposited >= ∑ETH prizes withdrawn + ∑ETH prizes claimed
     */
    function invariant_B() public {
        assertGe(
            handler.ghost_ETH_prizesDepositedSum(),
            handler.ghost_ETH_depositsWithdrawnSum() + handler.ghost_ETH_prizesClaimedSum()
        );
    }

    /**
     * Invariant C: Protocol fee recipient balance >= ∑ETH fees collected
     */
    function invariant_C() public {
        assertGe(yolo.protocolFeeRecipient().balance, handler.ghost_ETH_feesCollectedSum());
    }

    /**
     * Invariant D: YoloV2 recorded entries >= Total entries
     */
    function invariant_D() public {
        uint256 roundsCount = yolo.roundsCount();
        uint256 entryCount;
        for (uint256 i = 1; i <= roundsCount; i++) {
            IYoloV2.Deposit[] memory deposits = _getDeposits(i);
            entryCount += deposits.length != 0 ? deposits[deposits.length - 1].currentEntryIndex + 1 : 0;
        }

        assertGe(entryCount, handler.ghost_ERC20_entriesSum());
    }

    /**
     * Invariant E: ∑ERC721 tokens deposited >= ∑ERC721 tokens withdrawn + ∑ERC721 tokens claimed
     */
    function invariant_E() public {
        assertGe(
            handler.ghost_ERC721_prizesDepositedSum(),
            handler.ghost_ERC721_prizesClaimedSum() + handler.ghost_ERC721_depositsWithdrawnSum()
        );
    }

    /**
     * Invariant F: For each round with an ERC721 token as prize in states Open or Drawing, collection.ownerOf(tokenID) == address(yolo)
     */
    function invariant_F() public {
        uint256 yoloCount = yolo.roundsCount();
        for (uint256 roundId; roundId < yoloCount; roundId++) {
            (IYoloV2.RoundStatus status, , , , , , , , , IYoloV2.Deposit[] memory deposits) = yolo.getRound(roundId);
            if (status == IYoloV2.RoundStatus.Open || status == IYoloV2.RoundStatus.Drawing) {
                for (uint256 i; i < deposits.length; i++) {
                    IYoloV2.Deposit memory deposit = deposits[i];
                    if (deposit.tokenType == IYoloV2.YoloV2__TokenType.ERC721) {
                        assertEq(MockERC721(deposit.tokenAddress).ownerOf(deposit.tokenId), address(yolo));
                    }
                }
            }
        }
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
