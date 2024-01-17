// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_OutflowControl_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
    }

    function test_outflowNotAllowed() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit OutflowAllowedUpdated(false);
        yolo.toggleOutflowAllowed();
        assertFalse(yolo.outflowAllowed());
    }

    function test_outflowNotAllowed_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        yolo.toggleOutflowAllowed();
    }

    function test_outflowAllowed() public asPrankedUser(owner) {
        yolo.toggleOutflowAllowed();

        expectEmitCheckAll();
        emit OutflowAllowedUpdated(true);
        yolo.toggleOutflowAllowed();
        assertTrue(yolo.outflowAllowed());
    }

    function test_outflowAllowed_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        yolo.togglePaused();
    }
}
