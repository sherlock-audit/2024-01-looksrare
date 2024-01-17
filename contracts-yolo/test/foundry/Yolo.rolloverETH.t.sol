// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_RolloverETH_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_rolloverETH() public {
        _playOneRound();

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = new uint256[](1);

        expectEmitCheckAll();
        emit ProtocolFeePayment(0.06 ether, address(0));

        expectEmitCheckAll();
        emit Rollover(user1, withdrawalCalldata, 3, 144);

        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);

        assertEq(user1.balance, 0);
        assertEq(address(yolo).balance, 2.44 ether);
        assertEq(protocolFeeRecipient.balance, 0.06 ether);

        IYoloV2.Deposit[] memory deposits = _getDeposits(3);
        assertEq(deposits.length, 1);
        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 1.44 ether);
        assertEq(deposit.depositor, user1);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 144);

        deposits = _getDeposits(1);
        assertTrue(deposits[0].withdrawn);
        assertTrue(deposits[1].withdrawn);
        assertFalse(deposits[2].withdrawn);

        _assertAllPrizesAreWithdrawn(2);

        _assertZeroProtocolFeeOwed(1);
        _assertZeroProtocolFeeOwed(2);

        uint256 cutoffTime = _getCutoffTime({roundId: 3});
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
    }

    function test_rolloverETH_PayForProtocolFeesWithLOOKS() public {
        _playOneRound();

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = new uint256[](1);

        uint256 protocolFeeOwedInLooks = 1_335.541771840791068388 ether;
        deal(LOOKS, user1, protocolFeeOwedInLooks);

        _grantApprovalsToTransferManager(user1);

        vm.startPrank(user1);

        IERC20(LOOKS).approve(address(transferManager), protocolFeeOwedInLooks);

        expectEmitCheckAll();
        emit ProtocolFeePayment(protocolFeeOwedInLooks, LOOKS);

        expectEmitCheckAll();
        emit Rollover(user1, withdrawalCalldata, 3, 150);

        yolo.rolloverETH(withdrawalCalldata, true);

        vm.stopPrank();

        assertEq(user1.balance, 0);
        assertEq(address(yolo).balance, 2.5 ether);
        assertEq(protocolFeeRecipient.balance, 0);

        assertEq(IERC20(LOOKS).balanceOf(user1), 0);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 0);
        assertEq(IERC20(LOOKS).balanceOf(protocolFeeRecipient), protocolFeeOwedInLooks);

        IYoloV2.Deposit[] memory deposits = _getDeposits(3);
        assertEq(deposits.length, 1);
        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 1.5 ether);
        assertEq(deposit.depositor, user1);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 150);

        deposits = _getDeposits(1);
        assertTrue(deposits[0].withdrawn);
        assertTrue(deposits[1].withdrawn);
        assertFalse(deposits[2].withdrawn);

        _assertAllPrizesAreWithdrawn(2);

        _assertZeroProtocolFeeOwed(1);
        _assertZeroProtocolFeeOwed(2);

        uint256 cutoffTime = _getCutoffTime({roundId: 3});
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
    }

    function test_rolloverETH_RefundExtraETH() public {
        vm.deal(user1, 0.1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 0.1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 110;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        expectEmitCheckAll();
        emit ProtocolFeePayment(0.033 ether, address(0));

        expectEmitCheckAll();
        emit Rollover(user1, withdrawalCalldata, 2, 6);

        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);

        assertEq(user1.balance, 0.007 ether);
        assertEq(address(yolo).balance, 1.06 ether);
        assertEq(protocolFeeRecipient.balance, 0.033 ether);

        IYoloV2.Deposit[] memory deposits = _getDeposits(2);
        assertEq(deposits.length, 1);
        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 0.06 ether);
        assertEq(deposit.depositor, user1);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 6);

        deposits = _getDeposits(1);
        assertTrue(deposits[0].withdrawn);
        assertFalse(deposits[1].withdrawn);

        _assertZeroProtocolFeeOwed(1);

        uint256 cutoffTime = _getCutoffTime({roundId: 2});
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
    }

    function test_rolloverETH_DepositIndicesFromTheSameRoundIsSplitIntoDifferentArrays() public {
        _playOneRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](1);
        withdrawalCalldata[1].roundId = 1;
        withdrawalCalldata[1].depositIndices = new uint256[](1);
        withdrawalCalldata[0].depositIndices[0] = 1;

        expectEmitCheckAll();
        emit ProtocolFeePayment(0.06 ether, address(0));

        expectEmitCheckAll();
        emit Rollover(user1, withdrawalCalldata, 2, 94);

        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);

        assertEq(user1.balance, 0.5 ether);
        assertEq(address(yolo).balance, 1.94 ether);
        assertEq(protocolFeeRecipient.balance, 0.06 ether);

        IYoloV2.Deposit[] memory deposits = _getDeposits(2);
        assertEq(deposits.length, 1);
        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 0.94 ether);
        assertEq(deposit.depositor, user1);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 94);

        deposits = _getDeposits(1);
        assertTrue(deposits[0].withdrawn);
        assertTrue(deposits[1].withdrawn);
        assertFalse(deposits[2].withdrawn);

        _assertZeroProtocolFeeOwed(1);

        uint256 cutoffTime = _getCutoffTime({roundId: 2});
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
    }

    function test_rolloverETH_NextClaimPrizesDoesNotChargeProtocolFee() public {
        vm.deal(user1, 0.1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 0.1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 110;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.startPrank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);

        withdrawalCalldata[0].depositIndices[0] = 1;
        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(user1.balance, 1.007 ether);
        assertEq(address(yolo).balance, 0.06 ether);
        assertEq(protocolFeeRecipient.balance, 0.033 ether);

        _assertAllPrizesAreWithdrawn(1);
        _assertZeroProtocolFeeOwed(1);

        uint256 cutoffTime = _getCutoffTime({roundId: 2});
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
    }

    function test_rolloverETH_NoProtocolFeeChargedAfterClaimPrizes() public {
        vm.deal(user1, 0.1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 0.1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 110;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.startPrank(user1);
        yolo.claimPrizes(withdrawalCalldata, false);

        withdrawalCalldata[0].depositIndices[0] = 1;
        yolo.rolloverETH(withdrawalCalldata, false);

        assertEq(user1.balance, 0.067 ether);
        assertEq(address(yolo).balance, 1 ether);
        assertEq(protocolFeeRecipient.balance, 0.033 ether);

        _assertAllPrizesAreWithdrawn(1);
        _assertZeroProtocolFeeOwed(1);

        uint256 cutoffTime = _getCutoffTime({roundId: 2});
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
    }

    function test_rolloverETH_DrawWinner_ReachedMaximumNumberOfDeposits() public {
        uint256 depositAmount = 0.01 ether;
        vm.deal(user1, depositAmount);
        vm.prank(user1);
        yolo.deposit{value: depositAmount}(1, _emptyDepositsCalldata());

        _cancelRound();

        for (uint160 i; i < 99; i++) {
            vm.deal(user2, depositAmount);
            vm.prank(user2);
            yolo.deposit{value: depositAmount}(2, _emptyDepositsCalldata());
        }

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);

        IYoloV2.RoundStatus status = _getStatus(2);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawing));
    }

    function test_rolloverETH_DrawWinner_ReachedMaximumNumberOfParticipants() public {
        address user = address(69);
        uint256 depositAmount = 0.01 ether;
        vm.deal(user, depositAmount);
        vm.prank(user);
        yolo.deposit{value: depositAmount}(1, _emptyDepositsCalldata());

        _cancelRound();

        _singleETHDeposits({roundId: 2, numberOfParticipants: MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND - 1});

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.prank(user);
        yolo.rolloverETH(withdrawalCalldata, false);

        IYoloV2.RoundStatus status = _getStatus(2);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawing));
    }

    function test_rolloverETH_RevertIf_ProtocolFeeNotPaid() public {
        vm.deal(user1, 0.01 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 0.01 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 101;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.expectRevert(IYoloV2.ProtocolFeeNotPaid.selector);
        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_InvalidValue() public {
        vm.deal(user1, 0.04 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 0.04 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.expectRevert(IYoloV2.InvalidValue.selector);
        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_InvalidLength_DepositIndices() public {
        _playOneRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;

        vm.expectRevert(IYoloV2.InvalidLength.selector);
        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_InvalidLength_WithdrawalCalldata() public {
        _playOneRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](0);

        vm.expectRevert(IYoloV2.InvalidLength.selector);
        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_AlreadyWithdrawn() public {
        _playOneRound();

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = new uint256[](1);

        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);

        vm.prank(user1);
        vm.expectRevert(IYoloV2.AlreadyWithdrawn.selector);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_AlreadyWithdrawn_DuplicatedRoundIdsAndDepositIndices() public {
        _playOneRound();

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;
        withdrawalCalldata[1].roundId = 1;
        withdrawalCalldata[1].depositIndices = new uint256[](2);
        withdrawalCalldata[1].depositIndices[1] = 1;

        vm.expectRevert(IYoloV2.AlreadyWithdrawn.selector);
        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_InvalidIndex() public asPrankedUser(user1) {
        vm.deal(user1, 1.5 ether);

        yolo.deposit{value: 0.5 ether}(1, _emptyDepositsCalldata());

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();
        withdrawalCalldata[0].depositIndices[0] = 1;

        vm.expectRevert(IYoloV2.InvalidIndex.selector);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_NotDepositor() public {
        vm.deal(user1, 1.5 ether);

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(1, _emptyDepositsCalldata());

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.expectRevert(IYoloV2.NotDepositor.selector);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_NotWinner() public {
        _playOneRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;

        vm.prank(user2);
        vm.expectRevert(IYoloV2.NotWinner.selector);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_InvalidTokenType_ERC721() public {
        vm.deal(user1, 1.19 ether);

        uint256 penguId = 8_623;
        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(penguId);
        IYoloV2.DepositCalldata[] memory depositsCalldata = _pudgyPenguinsDepositsCalldata(penguId);

        _grantApprovalsToTransferManager(user1);

        vm.prank(penguOwner);
        IERC721(PUDGY_PENGUINS).transferFrom(penguOwner, user1, penguId);

        vm.startPrank(user1);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);
        yolo.deposit{value: 0.5 ether}(1, depositsCalldata);

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;

        vm.expectRevert(IYoloV2.InvalidTokenType.selector);
        yolo.rolloverETH(withdrawalCalldata, false);

        vm.stopPrank();
    }

    function test_rolloverETH_RevertIf_InvalidTokenType_ERC20() public {
        vm.deal(user1, 1.19 ether);

        _grantApprovalsToTransferManager(user1);

        vm.startPrank(user1);

        uint256 looksAmount = 1_000 ether;
        deal(LOOKS, user1, looksAmount);

        IYoloV2.DepositCalldata[] memory depositsCalldata = _depositCalldata1000LOOKS();

        IERC20(LOOKS).approve(address(transferManager), looksAmount);

        yolo.deposit{value: 0.5 ether}(1, depositsCalldata);

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;

        vm.expectRevert(IYoloV2.InvalidTokenType.selector);
        yolo.rolloverETH(withdrawalCalldata, false);

        vm.stopPrank();
    }

    function test_rolloverETH_RevertIf_InvalidStatus_RoundStatusIsOpen() public {
        _playOneRound();

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](1);
        withdrawalCalldata[1].roundId = 2; // Round 2 is Open
        withdrawalCalldata[1].depositIndices = new uint256[](1);

        vm.prank(user1);
        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_InvalidStatus_RoundStatusIsNone() public {
        _playOneRound();

        vm.deal(user1, 10 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;

        vm.prank(user1);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(amounts);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](1);
        withdrawalCalldata[1].roundId = 3; // Round 3 is not yet open
        withdrawalCalldata[1].depositIndices = new uint256[](1);

        vm.prank(user1);
        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_InvalidStatus_CurrentRoundIsNotOpen() public {
        _playOneRound();

        vm.prank(user1);
        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        vm.deal(user2, 1 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(2, _emptyDepositsCalldata());

        // Can't rollover into round 2 as it is drawing
        _drawRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = _singleRoundRolloverWithdrawalData();

        vm.prank(user1);
        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function test_rolloverETH_RevertIf_OnePlayerCannotFillUpTheWholeRound() public {
        _playOneRound();

        vm.deal(user2, 0.5 ether);
        vm.prank(user2);
        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        _cancelRound();

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](2);
        withdrawalCalldata[0].depositIndices[1] = 1;

        vm.deal(user1, 990 ether);
        for (uint256 i; i < 99; ++i) {
            vm.prank(user1);
            yolo.deposit{value: 10 ether}({roundId: 3, deposits: new IYoloV2.DepositCalldata[](0)});
        }

        vm.expectRevert(IYoloV2.OnePlayerCannotFillUpTheWholeRound.selector);
        vm.prank(user1);
        yolo.rolloverETH(withdrawalCalldata, false);

        // Does not revert
        withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 2;
        withdrawalCalldata[0].depositIndices = new uint256[](1);

        vm.prank(user2);
        yolo.rolloverETH(withdrawalCalldata, false);
    }

    function _singleRoundRolloverWithdrawalData()
        private
        pure
        returns (IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata)
    {
        withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = new uint256[](1);
    }
}
