// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_ClaimPrizes_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_claimPrizes() public {
        _playMultipleRounds();

        address winner = _getWinner(1);

        vm.deal(winner, 0);
        deal(LOOKS, winner, 0);
        deal(USDC, winner, 0);

        vm.startPrank(winner);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 0;
        prizesIndices[1] = 1;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        expectEmitCheckAll();
        emit ProtocolFeePayment(0.4428 ether, address(0));

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), 0);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 9_856.29827618503808471 ether);

        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(winner.balance, 2.5572 ether);
        assertEq(protocolFeeRecipient.balance, 0.4428 ether);
        assertEq(address(yolo).balance, 0);

        prizesIndices[0] = 2;
        prizesIndices[1] = 3;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), 0);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 0);

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        yolo.claimPrizes(withdrawalCalldata, false);

        _assertPrizesAreClaimed(winner);

        uint256[] memory lastPrizeIndices = new uint256[](1);
        lastPrizeIndices[0] = 4;
        withdrawalCalldata[0].depositIndices = lastPrizeIndices;
        withdrawalCalldata[1].depositIndices = lastPrizeIndices;

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), 0);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 0);

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(IERC20(USDC).balanceOf(winner), 2_000e6);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 0);

        vm.stopPrank();

        _assertAllPrizesAreWithdrawn(1);
        _assertAllPrizesAreWithdrawn(2);

        _assertZeroProtocolFeeOwed(1);
        _assertZeroProtocolFeeOwed(2);
    }

    function test_claimPrizes_ProtocolFeeIsZero() public {
        // change protocolFeeBp to 0 for round 1
        bytes32 slot;
        assembly {
            mstore(0x00, 1)
            mstore(0x20, 7)
            slot := keccak256(0x00, 0x40)
        }
        uint256 value = uint256(vm.load(address(yolo), slot));
        value &= 0xffffffffffffffffffffffffffffffffffffffffffffffff0000ffffffffffff;
        vm.store(address(yolo), slot, bytes32(value));

        // change protocolFeeBp for YoloV2 to 0 before round 2 starts
        vm.prank(owner);
        yolo.updateProtocolFeeBp(0);
        _playMultipleRounds();

        address winner = _getWinner(1);

        vm.deal(winner, 0);
        deal(LOOKS, winner, 0);
        deal(USDC, winner, 0);

        vm.startPrank(winner);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 0;
        prizesIndices[1] = 1;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), 0);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 0);

        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(winner.balance, 3 ether);
        assertEq(protocolFeeRecipient.balance, 0 ether);
        assertEq(address(yolo).balance, 0);

        prizesIndices[0] = 2;
        prizesIndices[1] = 3;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), 0);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 0);

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        yolo.claimPrizes(withdrawalCalldata, false);

        _assertPrizesAreClaimed(winner);

        uint256[] memory lastPrizeIndices = new uint256[](1);
        lastPrizeIndices[0] = 4;
        withdrawalCalldata[0].depositIndices = lastPrizeIndices;
        withdrawalCalldata[1].depositIndices = lastPrizeIndices;

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), 0);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 0);

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(IERC20(USDC).balanceOf(winner), 2_000e6);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 0);

        vm.stopPrank();

        _assertAllPrizesAreWithdrawn(1);
        _assertAllPrizesAreWithdrawn(2);

        _assertZeroProtocolFeeOwed(1);
        _assertZeroProtocolFeeOwed(2);
    }

    function test_claimPrizes_PrizesCannotCoverFees() public {
        _playMultipleRounds();

        uint256 protocolFeeOwed;
        (, , , , , , address winner, , uint256 protocolFeeOwedRound1, ) = yolo.getRound(1);
        (, , , , , , , , uint256 protocolFeeOwedRound2, ) = yolo.getRound(2);
        protocolFeeOwed = protocolFeeOwedRound1 + protocolFeeOwedRound2;
        vm.deal(winner, protocolFeeOwed);
        assertGt(protocolFeeOwedRound1, 0);
        assertGt(protocolFeeOwedRound2, 0);
        deal(LOOKS, winner, 0);

        vm.startPrank(winner);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 2;
        prizesIndices[1] = 3;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), protocolFeeOwed);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 9_856.298276185038084710 ether);

        expectEmitCheckAll();
        emit ProtocolFeePayment(0.4428 ether, address(0));

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        yolo.claimPrizes{value: protocolFeeOwed}(withdrawalCalldata, false);

        assertEq(protocolFeeRecipient.balance, protocolFeeOwed);
        assertEq(winner.balance, 0);
        assertEq(address(yolo).balance, 3 ether);

        _assertPrizesAreClaimed(winner);

        vm.stopPrank();

        IYoloV2.Deposit[] memory prizes = _getDeposits(1);
        assertTrue(prizes[2].withdrawn);
        assertTrue(prizes[3].withdrawn);

        prizes = _getDeposits(2);
        assertTrue(prizes[2].withdrawn);
        assertTrue(prizes[3].withdrawn);

        _assertZeroProtocolFeeOwed(1);
        _assertZeroProtocolFeeOwed(2);
    }

    function test_claimPrizes_PayWithLOOKS() public {
        _playMultipleRounds();

        uint256 protocolFeeOwed;
        (, , , , , , address winner, , uint256 protocolFeeOwedRound1, ) = yolo.getRound(1);
        (, , , , , , , , uint256 protocolFeeOwedRound2, ) = yolo.getRound(2);
        protocolFeeOwed = protocolFeeOwedRound1 + protocolFeeOwedRound2;
        assertEq(protocolFeeOwed, 0.4428 ether, "This is the protocol fee owed in ETH");
        assertGt(protocolFeeOwedRound1, 0);
        assertGt(protocolFeeOwedRound2, 0);

        uint256 protocolFeeOwedInLooks = 9_856.298276185038084710 ether;
        deal(LOOKS, winner, protocolFeeOwedInLooks);

        _grantApprovalsToTransferManager(winner);

        vm.startPrank(winner);

        IERC20(LOOKS).approve(address(transferManager), protocolFeeOwedInLooks);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 2;
        prizesIndices[1] = 3;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), protocolFeeOwed);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), protocolFeeOwedInLooks);

        expectEmitCheckAll();
        emit ProtocolFeePayment(protocolFeeOwedInLooks, LOOKS);

        expectEmitCheckAll();
        emit PrizesClaimed(winner, withdrawalCalldata);

        yolo.claimPrizes(withdrawalCalldata, true);

        assertEq(IERC20(LOOKS).balanceOf(protocolFeeRecipient), protocolFeeOwedInLooks);

        _assertPrizesAreClaimed(winner);

        vm.stopPrank();

        IYoloV2.Deposit[] memory prizes = _getDeposits(1);
        assertTrue(prizes[2].withdrawn);
        assertTrue(prizes[3].withdrawn);

        prizes = _getDeposits(2);
        assertTrue(prizes[2].withdrawn);
        assertTrue(prizes[3].withdrawn);

        _assertZeroProtocolFeeOwed(1);
        _assertZeroProtocolFeeOwed(2);
    }

    function test_claimPrizes_LOOKS_LOOKS_USDC_LOOKS() public {
        _grantApprovalsToTransferManager(user1);
        _grantApprovalsToTransferManager(user2);

        _deposit_LOOKS_LOOKS_USDC_LOOKS(1, user1);
        _deposit_LOOKS_LOOKS_USDC_LOOKS(1, user2);

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        uint256[] memory depositsIndices = new uint256[](8);
        depositsIndices[1] = 1;
        depositsIndices[2] = 2;
        depositsIndices[3] = 3;
        depositsIndices[4] = 4;
        depositsIndices[5] = 5;
        depositsIndices[6] = 6;
        depositsIndices[7] = 7;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = depositsIndices;

        uint256 protocolFee = 0.1158 ether;

        expectEmitCheckAll();
        emit ProtocolFeePayment(protocolFee, address(0));

        expectEmitCheckAll();
        emit PrizesClaimed(user2, withdrawalCalldata);

        vm.deal(user2, protocolFee);

        vm.prank(user2);
        yolo.claimPrizes{value: protocolFee}(withdrawalCalldata, false);

        assertEq(IERC20(LOOKS).balanceOf(user2), 3_000 ether);
        assertEq(IERC20(USDC).balanceOf(user2), 6_000e6);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 0);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 0);

        _assertAllPrizesAreWithdrawn(1);
    }

    function test_claimPrizes_MultipleRounds_LOOKS_LOOKS_USDC_LOOKS() public {
        _grantApprovalsToTransferManager(user1);
        _grantApprovalsToTransferManager(user2);

        _deposit_LOOKS_LOOKS_USDC_LOOKS(1, user1);
        _deposit_LOOKS_LOOKS_USDC_LOOKS(1, user2);

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        _deposit_LOOKS_LOOKS_USDC_LOOKS(2, user1);
        _deposit_LOOKS_LOOKS_USDC_LOOKS(2, user2);

        _drawRound();

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID_2, randomWords);

        uint256[] memory depositsIndices = new uint256[](8);
        depositsIndices[1] = 1;
        depositsIndices[2] = 2;
        depositsIndices[3] = 3;
        depositsIndices[4] = 4;
        depositsIndices[5] = 5;
        depositsIndices[6] = 6;
        depositsIndices[7] = 7;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = depositsIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = depositsIndices;

        uint256 protocolFee = 0.2316 ether;

        expectEmitCheckAll();
        emit ProtocolFeePayment(protocolFee, address(0));

        expectEmitCheckAll();
        emit PrizesClaimed(user2, withdrawalCalldata);

        vm.deal(user2, protocolFee);

        vm.prank(user2);
        yolo.claimPrizes{value: protocolFee}(withdrawalCalldata, false);

        assertEq(IERC20(LOOKS).balanceOf(user2), 6_000 ether);
        assertEq(IERC20(USDC).balanceOf(user2), 12_000e6);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 0);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 0);

        _assertAllPrizesAreWithdrawn(1);
        _assertAllPrizesAreWithdrawn(2);
    }

    function test_claimPrizes_RevertIf_OutflowNotAllowed() public {
        _playMultipleRounds();

        address winner = _getWinner(1);

        vm.prank(owner);
        yolo.toggleOutflowAllowed();

        vm.startPrank(winner);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 0;
        prizesIndices[1] = 1;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        vm.expectRevert(IYoloV2.OutflowNotAllowed.selector);
        yolo.claimPrizes(withdrawalCalldata, false);

        vm.stopPrank();
    }

    function test_claimPrizes_PrizesCannotCoverFees_RevertIf_ProtocolFeeNotPaid() public {
        _playMultipleRounds();

        uint256 protocolFeeOwed;
        (, , , , , , address winner, , uint256 protocolFeeOwedRound1, ) = yolo.getRound(1);
        (, , , , , , , , uint256 protocolFeeOwedRound2, ) = yolo.getRound(2);
        protocolFeeOwed = protocolFeeOwedRound1 + protocolFeeOwedRound2;
        vm.deal(winner, protocolFeeOwed);
        assertGt(protocolFeeOwedRound1, 0);
        assertGt(protocolFeeOwedRound2, 0);

        vm.startPrank(winner);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 2;
        prizesIndices[1] = 3;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false), protocolFeeOwed);
        assertEq(yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true), 9_856.298276185038084710 ether);

        vm.expectRevert(IYoloV2.ProtocolFeeNotPaid.selector);
        yolo.claimPrizes{value: protocolFeeOwed - 1}(withdrawalCalldata, false);

        vm.stopPrank();
    }

    function test_claimPrizes_RevertIf_InvalidStatus() public {
        _playMultipleRounds();

        address winner = _getWinner(2);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 0;
        prizesIndices[1] = 1;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 2;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 3;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        vm.startPrank(winner);

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false);

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true);

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.claimPrizes(withdrawalCalldata, false);

        vm.stopPrank();
    }

    function test_claimPrizes_RevertIf_InvalidIndex() public {
        _playMultipleRounds();

        address winner = _getWinner(2);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 2;
        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 0;
        prizesIndices[1] = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 3;
        prizesIndices[0] = 0;
        prizesIndices[1] = 5;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        vm.startPrank(winner);

        vm.expectRevert(IYoloV2.InvalidIndex.selector);
        yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, false);

        vm.expectRevert(IYoloV2.InvalidIndex.selector);
        yolo.getClaimPrizesPaymentRequired(withdrawalCalldata, true);

        vm.expectRevert(IYoloV2.InvalidIndex.selector);
        yolo.claimPrizes(withdrawalCalldata, false);

        vm.stopPrank();
    }

    function test_claimPrizes_RevertIf_NotWinner() public {
        _playMultipleRounds();

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 0;
        prizesIndices[1] = 1;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        vm.expectRevert(IYoloV2.NotWinner.selector);
        yolo.claimPrizes(withdrawalCalldata, false);
    }

    function test_claimPrizes_RevertIf_AlreadyWithdrawn() public {
        _playMultipleRounds();

        address winner = _getWinner(1);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 2;
        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 0;
        prizesIndices[1] = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 3;
        prizesIndices[0] = 0;
        prizesIndices[1] = 0;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        vm.startPrank(winner);

        vm.expectRevert(IYoloV2.AlreadyWithdrawn.selector);
        yolo.claimPrizes(withdrawalCalldata, false);

        vm.stopPrank();
    }

    function testFuzz_claimPrizes_RevertIf_AlreadyWithdrawn_DuplicatedIndex(uint256 index) public {
        vm.assume(index < 5);

        _playMultipleRounds();

        address winner = _getWinner(1);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = index;
        prizesIndices[1] = index;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        vm.prank(winner);
        vm.expectRevert(IYoloV2.AlreadyWithdrawn.selector);
        yolo.claimPrizes(withdrawalCalldata, false);
    }

    function test_claimPrizes_RevertIf_InvalidLength_WithdrawalCalldataLengthIsZero() public {
        _playMultipleRounds();

        address winner = _getWinner(1);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](0);

        vm.prank(winner);
        vm.expectRevert(IYoloV2.InvalidLength.selector);
        yolo.claimPrizes(withdrawalCalldata, false);
    }

    function test_claimPrizes_RevertIf_InvalidLength_DepositIndicesLengthIsZero() public {
        _playMultipleRounds();

        address winner = _getWinner(1);

        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;

        vm.prank(winner);
        vm.expectRevert(IYoloV2.InvalidLength.selector);
        yolo.claimPrizes(withdrawalCalldata, false);
    }

    function test_claimPrizes_PayWithLOOKS_RevertIf_InvalidValue() public {
        _playMultipleRounds();

        (, , , , , , address winner, , uint256 protocolFeeOwedRound1, ) = yolo.getRound(1);
        (, , , , , , , , uint256 protocolFeeOwedRound2, ) = yolo.getRound(2);
        uint256 protocolFeeOwed = protocolFeeOwedRound1 + protocolFeeOwedRound2;

        vm.deal(winner, protocolFeeOwed);
        uint256 protocolFeeOwedInLooks = 9_856.298276185038084710 ether;
        deal(LOOKS, winner, protocolFeeOwedInLooks);

        _grantApprovalsToTransferManager(winner);

        vm.startPrank(winner);

        IERC20(LOOKS).approve(address(transferManager), protocolFeeOwedInLooks);

        uint256[] memory prizesIndices = new uint256[](2);
        prizesIndices[0] = 2;
        prizesIndices[1] = 3;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = prizesIndices;

        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.claimPrizes{value: protocolFeeOwed}(withdrawalCalldata, true);

        vm.stopPrank();
    }

    function _playMultipleRounds() private {
        _playARound({
            roundId: 1,
            ethAmount: 0.5 ether,
            pudgyId: 8623,
            looksAmount: 1000 ether,
            usdcAmount: 1000e6,
            requestId: FULFILL_RANDOM_WORDS_REQUEST_ID,
            pudgyPenguinsDepositsCalldata: _pudgyPenguinsDepositsCalldata(8623)
        });
        _playARound({
            roundId: 2,
            ethAmount: 0.5 ether,
            pudgyId: 8624,
            looksAmount: 1000 ether,
            usdcAmount: 1000e6,
            requestId: FULFILL_RANDOM_WORDS_REQUEST_ID_2,
            pudgyPenguinsDepositsCalldata: _pudgyPenguinsDepositsCalldata2(8624)
        });
    }

    function _playARound(
        uint256 roundId,
        uint256 ethAmount,
        uint256 pudgyId,
        uint256 looksAmount,
        uint256 usdcAmount,
        uint256 requestId,
        IYoloV2.DepositCalldata[] memory pudgyPenguinsDepositsCalldata
    ) private {
        // 1st user deposits 1 ether by default
        vm.deal(user1, 1 ether);

        // 2nd user deposits ether
        vm.deal(user2, ethAmount);

        vm.prank(user1);
        yolo.deposit{value: 1 ether}(roundId, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: ethAmount}(roundId, _emptyDepositsCalldata());

        // 3rd user deposits 1 Pudgy Penguins
        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(pudgyId);
        vm.prank(penguOwner);
        IERC721(PUDGY_PENGUINS).transferFrom(penguOwner, user3, pudgyId);
        IYoloV2.DepositCalldata[] memory depositsCalldata = pudgyPenguinsDepositsCalldata;
        _grantApprovalsToTransferManager(user3);
        vm.startPrank(user3);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);
        yolo.deposit(roundId, depositsCalldata);
        vm.stopPrank();

        // 4th user deposits LOOKS
        deal(LOOKS, user4, looksAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = looksAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        _grantApprovalsToTransferManager(user4);

        vm.startPrank(user4);
        IERC20(LOOKS).approve(address(transferManager), looksAmount);
        yolo.deposit(roundId, depositsCalldata);
        vm.stopPrank();

        // 5th user deposits USDC
        deal(USDC, user5, usdcAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = USDC;
        amounts = new uint256[](1);
        amounts[0] = usdcAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        _grantApprovalsToTransferManager(user5);

        vm.startPrank(user5);
        IERC20(USDC).approve(address(transferManager), usdcAmount);
        yolo.deposit(roundId, depositsCalldata);
        vm.stopPrank();

        _drawRound();

        uint256[] memory randomWords = new uint256[](1);
        //Winner will be the same every round, given the same entry count
        randomWords[0] = 2345782359082359082359082359239741234971239412349234892349234;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(requestId, randomWords);
    }

    function _assertPrizesAreClaimed(address winner) private {
        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(8623), winner);
        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(8624), winner);
        assertEq(IERC20(LOOKS).balanceOf(winner), 2_000 ether);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 0);
    }
}
