// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pausable} from "@looksrare/contracts-libs/contracts/Pausable.sol";
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_Pausable_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
    }

    function test_pause() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit Paused(owner);
        yolo.togglePaused();
        assertTrue(yolo.paused());
    }

    function test_pause_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        yolo.togglePaused();
    }

    function test_unpause() public asPrankedUser(owner) {
        yolo.togglePaused();
        expectEmitCheckAll();
        emit Unpaused(owner);
        yolo.togglePaused();
        assertFalse(yolo.paused());
    }

    function test_unpause_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        yolo.togglePaused();
    }

    function test_paused_CurrentRoundStillDraws_AndNextRoundWillStillOpen() public {
        _subscribeYoloToVRF();
        _fillARoundWithSingleETHDeposit();

        vm.prank(owner);
        yolo.togglePaused();

        assertTrue(yolo.paused());

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        assertEq(uint8(IYoloV2.RoundStatus.Drawn), uint8(_getStatus({roundId: 1})));
        assertEq(uint8(IYoloV2.RoundStatus.Open), uint8(_getStatus({roundId: 2})));

        uint256[] memory prizesIndices = new uint256[](20);
        for (uint256 i; i < prizesIndices.length; i++) {
            prizesIndices[i] = i;
        }
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;

        address winner = _getWinner({roundId: 1});
        vm.deal(winner, 0);
        vm.prank(winner);
        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(winner.balance, 2.037 ether);
    }

    function test_paused_CurrentRoundStillDraws_AndNextRoundIsFull_RoundWillNotDraw() public {
        _subscribeYoloToVRF();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        for (uint160 i = 11; i <= 30; i++) {
            address user = address(i);
            vm.deal(user, 3 ether);

            vm.prank(user);
            yolo.depositETHIntoMultipleRounds{value: 3 ether}(amounts);
        }

        vm.prank(owner);
        yolo.togglePaused();
        assertTrue(yolo.paused());

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        assertEq(uint8(IYoloV2.RoundStatus.Drawn), uint8(_getStatus({roundId: 1})));
        assertEq(uint8(IYoloV2.RoundStatus.Open), uint8(_getStatus({roundId: 2})));

        vm.prank(owner);
        yolo.togglePaused();
        assertFalse(yolo.paused());

        uint256 cutoffTime = _getCutoffTime({roundId: 2});
        assertNotEq(cutoffTime, 0);

        vm.warp(cutoffTime);

        yolo.drawWinner();

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID_2, randomWords);

        assertEq(uint8(IYoloV2.RoundStatus.Drawn), uint8(_getStatus({roundId: 2})));
        assertEq(uint8(IYoloV2.RoundStatus.Open), uint8(_getStatus({roundId: 3})));

        uint256[] memory prizesIndices = new uint256[](20);
        for (uint256 i; i < prizesIndices.length; i++) {
            prizesIndices[i] = i;
        }
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = prizesIndices;

        address winner = _getWinner({roundId: 1});
        vm.deal(winner, 0);
        vm.prank(winner);
        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(winner.balance, 19.4 ether);

        withdrawalCalldata[0].roundId = 2;
        // Same winner
        winner = _getWinner({roundId: 2});
        vm.deal(winner, 0);
        vm.prank(winner);
        yolo.claimPrizes(withdrawalCalldata, false);

        assertEq(winner.balance, 38.8 ether);
    }

    function test_paused_CurrentRoundStillDraws_AndNextRoundIsFull_OwnerCancel_NextRoundIsCancelled() public {
        _subscribeYoloToVRF();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        for (uint160 i = 11; i <= 30; i++) {
            address user = address(i);
            vm.deal(user, 3 ether);

            vm.prank(user);
            yolo.depositETHIntoMultipleRounds{value: 3 ether}(amounts);
        }

        vm.prank(owner);
        yolo.togglePaused();
        assertTrue(yolo.paused());

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        assertEq(uint8(IYoloV2.RoundStatus.Drawn), uint8(_getStatus({roundId: 1})));
        assertEq(uint8(IYoloV2.RoundStatus.Open), uint8(_getStatus({roundId: 2})));

        // In a production environment, these have to be run in an atomic tx
        vm.startPrank(owner);
        yolo.togglePaused();
        yolo.cancel({numberOfRounds: 2});
        assertFalse(yolo.paused());
        vm.stopPrank();

        assertEq(uint8(IYoloV2.RoundStatus.Cancelled), uint8(_getStatus({roundId: 2})));
        assertEq(uint8(IYoloV2.RoundStatus.Cancelled), uint8(_getStatus({roundId: 3})));
        assertEq(uint8(IYoloV2.RoundStatus.Open), uint8(_getStatus({roundId: 4})));

        for (uint160 i = 11; i <= 30; i++) {
            address user = address(i);

            uint256[] memory depositsIndices = new uint256[](1);
            depositsIndices[0] = i - 11;

            IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
            withdrawalsCalldata[0].roundId = 2;
            withdrawalsCalldata[0].depositIndices = depositsIndices;

            vm.prank(user);
            yolo.withdrawDeposits(withdrawalsCalldata);

            assertEq(user.balance, 2 ether);
        }
    }
}
