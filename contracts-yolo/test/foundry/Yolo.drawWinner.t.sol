// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_DrawWinner_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_drawWinner() public {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 0.49 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user3);
        yolo.deposit{value: 0.49 ether}(1, _emptyDepositsCalldata());

        uint256 currentTime = block.timestamp + ROUND_DURATION;
        vm.warp(currentTime);

        expectEmitCheckAll();
        emit RandomnessRequested(1, FULFILL_RANDOM_WORDS_REQUEST_ID);

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Drawing);

        _expectChainlinkCall();

        yolo.drawWinner();

        (bool exists, uint40 roundId, uint256 randomWord) = yolo.randomnessRequests(FULFILL_RANDOM_WORDS_REQUEST_ID);

        assertTrue(exists);
        assertEq(roundId, 1);
        assertEq(randomWord, 0);

        (IYoloV2.RoundStatus status, , , , uint40 drawnAt, , , , , ) = yolo.getRound(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawing));
        assertEq(drawnAt, currentTime);
    }

    function test_drawWinner_RevertIf_InsufficientParticipants() public {
        vm.deal(user2, 1 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.expectRevert(IYoloV2.InsufficientParticipants.selector);
        _drawRound();
    }

    function test_drawWinner_RevertIf_InvalidStatus() public {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 0.49 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user3);
        yolo.deposit{value: 0.49 ether}(1, _emptyDepositsCalldata());

        _drawRound();

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.drawWinner();
    }

    function test_drawWinner_RevertIf_CutoffTimeNotReached() public {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 0.49 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user3);
        yolo.deposit{value: 0.49 ether}(1, _emptyDepositsCalldata());

        vm.warp(block.timestamp + 9 minutes + 59 seconds);

        vm.expectRevert(IYoloV2.CutoffTimeNotReached.selector);
        yolo.drawWinner();
    }

    function test_drawWinners_RevertIf_RandomnessRequestAlreadyExists() public {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 0.49 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user3);
        yolo.deposit{value: 0.49 ether}(1, _emptyDepositsCalldata());

        vm.warp(block.timestamp + ROUND_DURATION);

        _expectChainlinkCall();

        _stubRandomnessRequestExistence(FULFILL_RANDOM_WORDS_REQUEST_ID, true);

        vm.expectRevert(IYoloV2.RandomnessRequestAlreadyExists.selector);
        yolo.drawWinner();
    }
}
