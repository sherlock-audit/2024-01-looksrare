// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_CancelAfterRandomnessRequest_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_cancelAfterRandomnessRequest() public {
        _depositAndDrawWinner();
        _incrementTimeFromDrawnAt({roundId: 1, _seconds: 86_401});

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Cancelled);

        yolo.cancelAfterRandomnessRequest();

        IYoloV2.RoundStatus status = _getStatus(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Cancelled));

        (status, , , , , , , , , ) = yolo.getRound(2);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
    }

    function test_cancelAfterRandomnessRequest_RevertIf_OutflowNotAllowed() public {
        _depositAndDrawWinner();
        _incrementTimeFromDrawnAt({roundId: 1, _seconds: 86_401});

        vm.prank(owner);
        yolo.toggleOutflowAllowed();

        vm.expectRevert(IYoloV2.OutflowNotAllowed.selector);
        yolo.cancelAfterRandomnessRequest();
    }

    function test_cancelAfterRandomnessRequest_RevertIf_InvalidStatus() public {
        _deposit();

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.cancelAfterRandomnessRequest();
    }

    function test_cancelAfterRandomnessRequest_RevertIf_DrawExpirationTimeNotReached() public {
        _depositAndDrawWinner();
        _incrementTimeFromDrawnAt({roundId: 1, _seconds: 86_399});

        vm.expectRevert(IYoloV2.DrawExpirationTimeNotReached.selector);
        yolo.cancelAfterRandomnessRequest();
    }

    function _deposit() private {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 0.49 ether);

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user3);
        yolo.deposit{value: 0.49 ether}(1, _emptyDepositsCalldata());
    }

    function _depositAndDrawWinner() private {
        _deposit();
        _drawRound();
    }
}
