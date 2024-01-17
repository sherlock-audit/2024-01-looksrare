// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_OwnerCancel_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_ownerCancel_OneRound() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        expectEmitCheckAll();
        emit RoundsCancelled({startingRoundId: 1, numberOfRounds: 1});

        expectEmitCheckAll();
        emit RoundStatusUpdated({roundId: 2, status: IYoloV2.RoundStatus.Open});

        vm.prank(owner);
        yolo.cancel({numberOfRounds: 1});

        IYoloV2.RoundStatus status = _getStatus(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Cancelled));

        status = _getStatus(2);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
    }

    function test_ownerCancel_MultipleRounds() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 ether;
        amounts[1] = 0.5 ether;

        vm.prank(user1);
        yolo.depositETHIntoMultipleRounds{value: 1 ether}(amounts);

        vm.prank(user2);
        yolo.depositETHIntoMultipleRounds{value: 1 ether}(amounts);

        expectEmitCheckAll();
        emit RoundsCancelled({startingRoundId: 1, numberOfRounds: 2});

        expectEmitCheckAll();
        emit RoundStatusUpdated({roundId: 3, status: IYoloV2.RoundStatus.Open});

        vm.prank(owner);
        yolo.cancel({numberOfRounds: 2});

        IYoloV2.RoundStatus status = _getStatus(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Cancelled));

        status = _getStatus(2);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Cancelled));

        status = _getStatus(3);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
    }

    function test_ownerCancel_OneRound_NextRoundShouldRun() public {
        vm.deal(user1, 2 ether);
        vm.deal(user2, 2 ether);

        vm.prank(user1);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(owner);
        yolo.cancel({numberOfRounds: 1});

        _playOneRound();

        (IYoloV2.RoundStatus status, , , , , , address winner, , , ) = yolo.getRound(2);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawn));
        assertEq(winner, user1);
    }

    function test_ownerCancel_MultipleRounds_NextRoundShouldRun() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 ether;
        amounts[1] = 0.5 ether;

        vm.prank(user1);
        yolo.depositETHIntoMultipleRounds{value: 1 ether}(amounts);

        vm.prank(user2);
        yolo.depositETHIntoMultipleRounds{value: 1 ether}(amounts);

        vm.prank(owner);
        yolo.cancel({numberOfRounds: 2});

        _playOneRound();

        (IYoloV2.RoundStatus status, , , , , , address winner, , , ) = yolo.getRound(3);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawn));
        assertEq(winner, user1);
    }

    function test_ownerCancel_OneRound_PlayersCanWithdraw() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(owner);
        yolo.cancel({numberOfRounds: 1});

        uint256[] memory depositsIndices = new uint256[](1);

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user1, withdrawalsCalldata);

        vm.prank(user1);
        yolo.withdrawDeposits(withdrawalsCalldata);

        assertEq(address(user1).balance, 1 ether);

        withdrawalsCalldata[0].depositIndices[0] = 1;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user2, withdrawalsCalldata);

        vm.prank(user2);
        yolo.withdrawDeposits(withdrawalsCalldata);

        assertEq(address(user2).balance, 1 ether);
    }

    function test_ownerCancel_MultipleRounds_PlayersCanWithdraw() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 ether;
        amounts[1] = 0.5 ether;

        vm.prank(user1);
        yolo.depositETHIntoMultipleRounds{value: 1 ether}(amounts);

        vm.prank(user2);
        yolo.depositETHIntoMultipleRounds{value: 1 ether}(amounts);

        vm.prank(owner);
        yolo.cancel({numberOfRounds: 2});

        uint256[] memory depositsIndices = new uint256[](1);

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;
        withdrawalsCalldata[1].roundId = 2;
        withdrawalsCalldata[1].depositIndices = depositsIndices;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user1, withdrawalsCalldata);

        vm.prank(user1);
        yolo.withdrawDeposits(withdrawalsCalldata);

        assertEq(address(user1).balance, 1 ether);

        withdrawalsCalldata[0].depositIndices[0] = 1;
        withdrawalsCalldata[1].depositIndices[0] = 1;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user2, withdrawalsCalldata);

        vm.prank(user2);
        yolo.withdrawDeposits(withdrawalsCalldata);

        assertEq(address(user2).balance, 1 ether);
    }

    function test_ownerCancel_RevertIf_NotOwner() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        yolo.cancel({numberOfRounds: 1});
    }

    function test_ownerCancel_RevertIf_ZeroRounds() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.expectRevert(IYoloV2.ZeroRounds.selector);
        vm.prank(owner);
        yolo.cancel({numberOfRounds: 0});
    }
}
