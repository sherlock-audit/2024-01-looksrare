// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_WithdrawDeposits_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_withdrawDeposits() public {
        _travelToRoundEndTimestamp();

        yolo.cancel();

        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(8_623), address(yolo));
        assertEq(user2.balance, 0 ether);
        assertEq(IERC20(LOOKS).balanceOf(user2), 0);
        assertEq(IERC20(USDC).balanceOf(user2), 0);

        uint256[] memory depositsIndices = new uint256[](4);
        depositsIndices[0] = 0;
        depositsIndices[1] = 1;
        depositsIndices[2] = 2;
        depositsIndices[3] = 3;

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user2, withdrawalsCalldata);

        vm.prank(user2);
        yolo.withdrawDeposits(withdrawalsCalldata);

        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(8_623), user2);
        assertEq(user2.balance, 1 ether);
        assertEq(IERC20(LOOKS).balanceOf(user2), 1_000 ether);
        assertEq(IERC20(USDC).balanceOf(user2), 1_234e6);

        _assertAllPrizesAreWithdrawn(1);
    }

    function test_withdrawDeposits_OnCancelAfterRandomnessRequest() public {
        _drawARoundWithMultipleUsers({roundId: 1});

        _incrementTimeFromDrawnAt({roundId: 1, _seconds: 86_401});

        vm.prank(owner);
        yolo.cancelAfterRandomnessRequest();

        uint256[] memory depositsIndices = new uint256[](2);
        depositsIndices[0] = 0;
        depositsIndices[1] = 1;

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user2, withdrawalsCalldata);

        vm.prank(user2);
        yolo.withdrawDeposits(withdrawalsCalldata);

        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(8_623), user2);
        assertEq(IERC20(USDC).balanceOf(user2), 1_234e6);

        assertEq(user3.balance, 0);
        assertEq(IERC20(LOOKS).balanceOf(user3), 0);
    }

    function test_withdrawDeposits_MultipleRounds() public {
        vm.deal(user1, 1 ether);

        uint256 penguId = 8_623;
        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(penguId);
        IYoloV2.DepositCalldata[] memory depositsCalldata = _pudgyPenguinsDepositsCalldata(penguId);

        _grantApprovalsToTransferManager(user1);

        vm.prank(penguOwner);
        IERC721(PUDGY_PENGUINS).transferFrom(penguOwner, user1, penguId);

        vm.startPrank(user1);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);
        yolo.deposit{value: 0.5 ether}(1, depositsCalldata);

        vm.warp(block.timestamp + ROUND_DURATION);
        yolo.cancel();

        yolo.deposit{value: 0.5 ether}(2, _emptyDepositsCalldata());

        vm.warp(block.timestamp + ROUND_DURATION);
        yolo.cancel();

        uint256 looksAmount = 1_000 ether;
        uint256 usdcAmount = 3_000e6;

        deal(LOOKS, user1, looksAmount);
        deal(USDC, user1, usdcAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](2);

        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        depositsCalldata[0].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[0].tokenIdsOrAmounts[0] = looksAmount / 2;

        depositsCalldata[1].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[1].tokenAddress = USDC;
        depositsCalldata[1].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[1].tokenIdsOrAmounts[0] = usdcAmount / 2;

        IERC20(LOOKS).approve(address(transferManager), looksAmount);
        IERC20(USDC).approve(address(transferManager), usdcAmount);

        yolo.deposit(3, depositsCalldata);

        vm.warp(block.timestamp + ROUND_DURATION);
        yolo.cancel();

        yolo.deposit(4, depositsCalldata);

        vm.warp(block.timestamp + ROUND_DURATION);
        yolo.cancel();

        uint256[] memory depositsIndices = new uint256[](2);
        depositsIndices[1] = 1;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](4);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = depositsIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = new uint256[](1);
        withdrawalCalldata[2].roundId = 3;
        withdrawalCalldata[2].depositIndices = depositsIndices;
        withdrawalCalldata[3].roundId = 4;
        withdrawalCalldata[3].depositIndices = depositsIndices;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user1, withdrawalCalldata);

        yolo.withdrawDeposits(withdrawalCalldata);

        vm.stopPrank();

        assertEq(user1.balance, 1 ether);
        assertEq(IERC20(LOOKS).balanceOf(user1), looksAmount);
        assertEq(IERC20(USDC).balanceOf(user1), usdcAmount);
        assertEq(address(yolo).balance, 0);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 0);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 0);
        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(penguId), user1);

        _assertAllPrizesAreWithdrawn(1);
        _assertAllPrizesAreWithdrawn(2);
        _assertAllPrizesAreWithdrawn(3);
        _assertAllPrizesAreWithdrawn(4);
    }

    function test_withdrawDeposits_LOOKS_LOOKS_USDC_LOOKS() public {
        _grantApprovalsToTransferManager(user1);

        _deposit_LOOKS_LOOKS_USDC_LOOKS(1, user1);
        _cancelRound();

        vm.startPrank(user1);

        uint256[] memory depositsIndices = new uint256[](4);
        depositsIndices[1] = 1;
        depositsIndices[2] = 2;
        depositsIndices[3] = 3;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = depositsIndices;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user1, withdrawalCalldata);

        yolo.withdrawDeposits(withdrawalCalldata);

        vm.stopPrank();

        assertEq(IERC20(LOOKS).balanceOf(user1), 1_500 ether);
        assertEq(IERC20(USDC).balanceOf(user1), 3_000e6);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 0);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 0);

        _assertAllPrizesAreWithdrawn(1);
    }

    function test_withdrawDeposits_MultipleRounds_LOOKS_LOOKS_USDC_LOOKS() public {
        _grantApprovalsToTransferManager(user1);

        for (uint256 roundId = 1; roundId <= 2; roundId++) {
            _deposit_LOOKS_LOOKS_USDC_LOOKS(roundId, user1);
            _cancelRound();
        }

        vm.startPrank(user1);

        uint256[] memory depositsIndices = new uint256[](4);
        depositsIndices[1] = 1;
        depositsIndices[2] = 2;
        depositsIndices[3] = 3;
        IYoloV2.WithdrawalCalldata[] memory withdrawalCalldata = new IYoloV2.WithdrawalCalldata[](2);
        withdrawalCalldata[0].roundId = 1;
        withdrawalCalldata[0].depositIndices = depositsIndices;
        withdrawalCalldata[1].roundId = 2;
        withdrawalCalldata[1].depositIndices = depositsIndices;

        expectEmitCheckAll();
        emit DepositsWithdrawn(user1, withdrawalCalldata);

        yolo.withdrawDeposits(withdrawalCalldata);

        vm.stopPrank();

        assertEq(IERC20(LOOKS).balanceOf(user1), 3_000 ether);
        assertEq(IERC20(USDC).balanceOf(user1), 6_000e6);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 0);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 0);

        _assertAllPrizesAreWithdrawn(1);
        _assertAllPrizesAreWithdrawn(2);
    }

    function test_withdrawDeposits_RevertIf_OutflowNotAllowed() public {
        _travelToRoundEndTimestamp();

        yolo.cancel();

        vm.prank(owner);
        yolo.toggleOutflowAllowed();

        uint256[] memory depositsIndices = new uint256[](4);
        depositsIndices[0] = 0;
        depositsIndices[1] = 1;
        depositsIndices[2] = 2;
        depositsIndices[3] = 3;

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        vm.expectRevert(IYoloV2.OutflowNotAllowed.selector);
        vm.prank(user2);
        yolo.withdrawDeposits(withdrawalsCalldata);
    }

    function test_withdrawDeposits_RevertIf_InvalidStatus() public {
        _depositARoundWithSingleUser({roundId: 1});

        uint256[] memory depositsIndices = new uint256[](1);
        depositsIndices[0] = 0;

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.withdrawDeposits(withdrawalsCalldata);
    }

    function test_withdrawDeposits_RevertIf_InvalidIndex() public {
        _travelToRoundEndTimestamp();

        yolo.cancel();

        uint256[] memory depositsIndices = new uint256[](1);
        depositsIndices[0] = 4;

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        vm.expectRevert(IYoloV2.InvalidIndex.selector);
        yolo.withdrawDeposits(withdrawalsCalldata);
    }

    function test_withdrawDeposits_RevertIf_NotDepositor() public {
        _travelToRoundEndTimestamp();

        yolo.cancel();

        uint256[] memory depositsIndices = new uint256[](1);
        depositsIndices[0] = 0;

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        vm.expectRevert(IYoloV2.NotDepositor.selector);
        yolo.withdrawDeposits(withdrawalsCalldata);
    }

    function test_withdrawDeposits_RevertIf_InvalidLength_WithdrawalCalldataLengthIsZero() public {
        _travelToRoundEndTimestamp();

        yolo.cancel();

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](0);

        vm.prank(user2);
        vm.expectRevert(IYoloV2.InvalidLength.selector);
        yolo.withdrawDeposits(withdrawalsCalldata);
    }

    function test_withdrawDeposits_RevertIf_InvalidLength_DepositIndicesLengthIsZero() public {
        _travelToRoundEndTimestamp();

        yolo.cancel();

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;

        vm.prank(user2);
        vm.expectRevert(IYoloV2.InvalidLength.selector);
        yolo.withdrawDeposits(withdrawalsCalldata);
    }

    function test_withdrawDeposits_RevertIf_AlreadyWithdrawn() public {
        _travelToRoundEndTimestamp();

        yolo.cancel();

        uint256[] memory depositsIndices = new uint256[](1);
        depositsIndices[0] = 0;

        IYoloV2.WithdrawalCalldata[] memory withdrawalsCalldata = new IYoloV2.WithdrawalCalldata[](1);
        withdrawalsCalldata[0].roundId = 1;
        withdrawalsCalldata[0].depositIndices = depositsIndices;

        vm.startPrank(user2);
        yolo.withdrawDeposits(withdrawalsCalldata);

        vm.expectRevert(IYoloV2.AlreadyWithdrawn.selector);
        yolo.withdrawDeposits(withdrawalsCalldata);
        vm.stopPrank();
    }

    function _depositARoundWithSingleUser(uint256 roundId) private {
        _grantApprovalsToTransferManager(user2);

        // Deposit 1 pudgy penguin
        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(8_623);
        IYoloV2.DepositCalldata[] memory depositsCalldata = _pudgyPenguinsDepositsCalldata(8_623);

        vm.prank(penguOwner);
        IERC721(PUDGY_PENGUINS).transferFrom(penguOwner, user2, 8_623);

        vm.startPrank(user2);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);
        yolo.deposit(roundId, depositsCalldata);

        // Deposit 1 ether
        vm.deal(user2, 1 ether);

        yolo.deposit{value: 1 ether}(roundId, _emptyDepositsCalldata());

        // Deposit 1,000 LOOKS
        uint256 looksAmount = 1_000 ether;

        deal(LOOKS, user2, looksAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = looksAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        IERC20(LOOKS).approve(address(transferManager), looksAmount);
        yolo.deposit(roundId, depositsCalldata);

        uint256 usdcAmount = 1_234e6;

        // Deposit 1,234 USDC
        deal(USDC, user2, usdcAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = USDC;
        amounts = new uint256[](1);
        amounts[0] = usdcAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        IERC20(USDC).approve(address(transferManager), usdcAmount);
        yolo.deposit(roundId, depositsCalldata);
        vm.stopPrank();
    }

    function _drawARoundWithMultipleUsers(uint256 roundId) private {
        // 1st user deposits 1 Pudgy Penguin and 1,234 USDC
        _grantApprovalsToTransferManager(user2);

        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(8_623);
        IYoloV2.DepositCalldata[] memory depositsCalldata = _pudgyPenguinsDepositsCalldata(8_623);

        vm.prank(penguOwner);
        IERC721(PUDGY_PENGUINS).transferFrom(penguOwner, user2, 8_623);

        vm.startPrank(user2);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);
        yolo.deposit(roundId, depositsCalldata);

        uint256 usdcAmount = 1_234e6;

        deal(USDC, user2, usdcAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = usdcAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        IERC20(USDC).approve(address(transferManager), usdcAmount);
        yolo.deposit(roundId, depositsCalldata);
        vm.stopPrank();

        // 2nd user deposits 1 ether and 1,000 LOOKS
        _grantApprovalsToTransferManager(user3);

        vm.deal(user3, 1 ether);

        vm.startPrank(user3);
        yolo.deposit{value: 1 ether}(roundId, _emptyDepositsCalldata());

        uint256 looksAmount = 1_000 ether;

        deal(LOOKS, user3, looksAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        amounts = new uint256[](1);
        amounts[0] = looksAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        IERC20(LOOKS).approve(address(transferManager), looksAmount);
        yolo.deposit(roundId, depositsCalldata);
        vm.stopPrank();

        _drawRound();
    }

    function _travelToRoundEndTimestamp() private {
        _depositARoundWithSingleUser({roundId: 1});

        uint256 currentTime = block.timestamp + ROUND_DURATION;
        vm.warp(currentTime);
    }
}
