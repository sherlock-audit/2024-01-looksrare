// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_Cancel_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_cancel() public {
        vm.deal(user2, 1 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Cancelled);

        expectEmitCheckAll();
        emit RoundStatusUpdated(2, IYoloV2.RoundStatus.Open);

        _cancelRound();

        IYoloV2.RoundStatus status = _getStatus(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Cancelled));

        (status, , , , , , , , , ) = yolo.getRound(2);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
    }

    function test_cancel_RevertIf_OutflowNotAllowed() public {
        vm.deal(user2, 1 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(owner);
        yolo.toggleOutflowAllowed();

        vm.expectRevert(IYoloV2.OutflowNotAllowed.selector);
        _cancelRound();
    }

    function test_cancel_RevertIf_RoundCannotBeClosed() public {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user3);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.warp(block.timestamp + ROUND_DURATION);

        vm.expectRevert(IYoloV2.RoundCannotBeClosed.selector);
        _cancelRound();
    }

    function test_cancel_RevertIf_InvalidStatus() public {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user3);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        _drawRound();

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.cancel();
    }

    function test_cancel_RevertIf_CutoffTimeNotReached_CutoffTimeIsZero() public {
        vm.warp(block.timestamp + ROUND_DURATION);
        vm.expectRevert(IYoloV2.CutoffTimeNotReached.selector);
        yolo.cancel();
    }

    function test_cancel_RevertIf_CutoffTimeNotReached() public {
        vm.deal(user2, 1 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.warp(block.timestamp + 9 minutes + 59 seconds);

        vm.expectRevert(IYoloV2.CutoffTimeNotReached.selector);
        yolo.cancel();
    }
}
