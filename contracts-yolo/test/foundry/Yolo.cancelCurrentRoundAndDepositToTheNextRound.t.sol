// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_CancelCurrentRoundAndDepositToTheNextRound_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_cancelCurrentRoundAndDepositToTheNextRound() public {
        vm.deal(user1, 0.6 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 0.49 ether);

        vm.prank(user1);
        yolo.deposit{value: 0.6 ether}(1, _emptyDepositsCalldata());

        expectEmitCheckAll();
        emit Deposited({depositor: user2, roundId: 2, entriesCount: 100});

        vm.warp(block.timestamp + ROUND_DURATION);

        vm.prank(user2);
        yolo.cancelCurrentRoundAndDepositToTheNextRound{value: 1 ether}(_emptyDepositsCalldata());

        IYoloV2.Deposit[] memory deposits = _getDeposits(1);
        assertEq(deposits.length, 1);

        deposits = _getDeposits(2);
        assertEq(deposits.length, 1);

        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 1 ether);
        assertEq(deposit.depositor, user2);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 100);

        assertEq(yolo.depositCount(2, user2), 1);
        (, , , , , uint40 numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 1);

        (, , , , , numberOfParticipants, , , , ) = yolo.getRound(2);
        assertEq(numberOfParticipants, 1);

        vm.prank(user3);
        vm.expectRevert(IYoloV2.CutoffTimeNotReached.selector);
        yolo.cancelCurrentRoundAndDepositToTheNextRound{value: 0.49 ether}(_emptyDepositsCalldata());
    }
}
