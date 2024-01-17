// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";

import {PriceOracle} from "../../contracts/PriceOracle.sol";

import {AssertionHelpers} from "./AssertionHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

import {MockERC721} from "./mock/MockERC721.sol";
import {TransferManager} from "./mock/TransferManager.sol";

abstract contract TestHelpers is AssertionHelpers, TestParameters {
    PriceOracle internal priceOracle;
    TransferManager internal transferManager;
    MockERC721 internal mockERC721;

    address public user1 = address(11);
    address public user2 = address(12);
    address public user3 = address(13);
    address public user4 = address(14);
    address public user5 = address(15);
    address public owner = address(69);
    address public operator = address(420);
    address public protocolFeeRecipient = address(888);

    modifier asPrankedUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function _forkMainnet() internal {
        vm.createSelectFork("mainnet", 18_377_799);
    }

    function _deployPriceOracle() internal {
        priceOracle = new PriceOracle(owner, WETH);

        vm.startPrank(owner);
        priceOracle.addOracle(LOOKS, 3_000);
        priceOracle.addOracle(USDC, 500);
        vm.stopPrank();
    }

    function _deployYolo() internal {
        _deployPriceOracle();

        transferManager = new TransferManager(owner);

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
                vrfCoordinator: VRF_COORDINATOR,
                reservoirOracle: RESERVOIR_ORACLE,
                transferManager: address(transferManager),
                erc20Oracle: address(priceOracle),
                weth: WETH,
                signatureValidityPeriod: 90 seconds,
                looks: LOOKS
            })
        );

        // mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();

        address[] memory currencies = new address[](6);
        currencies[0] = address(mockERC721);
        currencies[1] = PUDGY_PENGUINS;
        currencies[2] = NPCERS;
        currencies[3] = GEMESIS;
        currencies[4] = LOOKS;
        currencies[5] = USDC;
        // currencies[1] = address(mockERC20);

        vm.prank(operator);
        yolo.updateCurrenciesStatus(currencies, true);

        vm.prank(owner);
        transferManager.allowOperator(address(yolo));
    }

    function _subscribeYoloToVRF() internal {
        vm.prank(SUBSCRIPTION_ADMIN);
        VRFCoordinatorV2Interface(VRF_COORDINATOR).addConsumer(SUBSCRIPTION_ID, address(yolo));
    }

    function _stubRandomnessRequestExistence(uint256 requestId, bool exists) internal {
        bytes32 slot = bytes32(keccak256(abi.encode(requestId, uint256(9))));
        uint256 value = exists ? 1 : 0;

        vm.store(address(yolo), slot, bytes32(value));
    }

    function _grantApprovalsToTransferManager(address user) internal {
        if (!transferManager.hasUserApprovedOperator(user, address(yolo))) {
            vm.prank(user);
            address[] memory operators = new address[](1);
            operators[0] = address(yolo);
            transferManager.grantApprovals(operators);
        }
    }

    function _emptyDepositsCalldata() internal pure returns (IYoloV2.DepositCalldata[] memory) {}

    function _incrementTimeFromDrawnAt(uint256 roundId, uint256 _seconds) internal {
        (, , , , uint40 drawnAt, , , , , ) = yolo.getRound(roundId);
        vm.warp(drawnAt + _seconds);
    }

    function _fillARoundWithSingleETHDeposit() internal {
        _singleETHDeposits({roundId: 1, numberOfParticipants: MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND});
    }

    function _singleETHDeposits(uint256 roundId, uint256 numberOfParticipants) internal {
        for (uint256 i; i < numberOfParticipants; i++) {
            address user = address(uint160(i + 11));
            uint256 depositAmount = 0.01 ether * (i + 1);
            vm.deal(user, depositAmount);
            vm.prank(user);
            yolo.deposit{value: depositAmount}(roundId, _emptyDepositsCalldata());
        }
    }

    function _playOneRound() internal {
        vm.deal(user1, 1.5 ether);
        vm.deal(user2, 1 ether);

        uint256 roundId = yolo.roundsCount();

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(roundId, _emptyDepositsCalldata());

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(roundId, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(roundId, _emptyDepositsCalldata());

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);
    }

    function _cancelRound() internal {
        vm.warp(block.timestamp + ROUND_DURATION);
        yolo.cancel();
    }

    function _drawRound() internal {
        vm.warp(block.timestamp + ROUND_DURATION);
        yolo.drawWinner();
    }

    function _getWinner(uint256 roundId) internal view returns (address winner) {
        (, , , , , , winner, , , ) = yolo.getRound(roundId);
    }

    function _getDeposits(uint256 roundId) internal view returns (IYoloV2.Deposit[] memory deposits) {
        (, , , , , , , , , deposits) = yolo.getRound(roundId);
    }

    function _getStatus(uint256 roundId) internal view returns (IYoloV2.RoundStatus status) {
        (status, , , , , , , , , ) = yolo.getRound(roundId);
    }

    function _getCutoffTime(uint256 roundId) internal view returns (uint40 cutoffTime) {
        (, , , cutoffTime, , , , , , ) = yolo.getRound(roundId);
    }

    function _deposit_LOOKS_LOOKS_USDC_LOOKS(uint256 roundId, address user) internal asPrankedUser(user) {
        uint256 looksAmount = 1_500 ether;
        uint256 usdcAmount = 3_000e6;

        deal(LOOKS, user, looksAmount);
        deal(USDC, user, usdcAmount);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](4);

        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        depositsCalldata[0].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[0].tokenIdsOrAmounts[0] = looksAmount / 3;

        depositsCalldata[1].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[1].tokenAddress = LOOKS;
        depositsCalldata[1].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[1].tokenIdsOrAmounts[0] = looksAmount / 3;

        depositsCalldata[2].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[2].tokenAddress = USDC;
        depositsCalldata[2].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[2].tokenIdsOrAmounts[0] = usdcAmount;

        depositsCalldata[3].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[3].tokenAddress = LOOKS;
        depositsCalldata[3].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[3].tokenIdsOrAmounts[0] = looksAmount / 3;

        IERC20(LOOKS).approve(address(transferManager), looksAmount);
        IERC20(USDC).approve(address(transferManager), usdcAmount);

        yolo.deposit(roundId, depositsCalldata);
    }

    function _depositCalldata1000LOOKS() internal pure returns (IYoloV2.DepositCalldata[] memory depositsCalldata) {
        depositsCalldata = new IYoloV2.DepositCalldata[](1);

        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        depositsCalldata[0].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[0].tokenIdsOrAmounts[0] = 1_000 ether;
    }
}
