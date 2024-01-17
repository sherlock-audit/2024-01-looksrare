// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_FulfillRandomWords_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function testFuzz_fulfillRandomWords(uint256 randomWord) public {
        // We will test winningDepositIndex to be 0 in another test.
        vm.assume(randomWord % 210 != 0);

        _fillARoundWithSingleETHDeposit();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        expectEmitCheckAll();
        emit RoundStatusUpdated(2, IYoloV2.RoundStatus.Open);

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        (
            IYoloV2.RoundStatus status,
            ,
            ,
            ,
            ,
            ,
            address winner,
            ,
            uint256 protocolFeeOwed,
            IYoloV2.Deposit[] memory deposits
        ) = yolo.getRound(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawn));
        assertNotEq(winner, address(0));
        assertNotEq(winner, deposits[0].depositor);
        assertEq(protocolFeeOwed, 0.063 ether);

        (
            IYoloV2.RoundStatus status2,
            uint40 maximumNumberOfParticipants,
            uint16 protocolFeeBp,
            uint40 cutoffTime,
            uint40 drawnAt,
            uint40 numberOfParticipants,
            address winner2,
            uint96 valuePerEntry,
            uint256 protocolFeeOwed2,

        ) = yolo.getRound(2);
        assertEq(uint8(status2), uint8(IYoloV2.RoundStatus.Open));
        assertEq(cutoffTime, 0);
        assertEq(drawnAt, 0);
        assertEq(protocolFeeBp, 300);
        assertEq(protocolFeeOwed2, 0);
        assertEq(numberOfParticipants, 0);
        assertEq(winner2, address(0));
        assertEq(maximumNumberOfParticipants, 20);
        assertEq(valuePerEntry, 0.01 ether);
    }

    function test_fulfillRandomWords_MaximumNumberOfDepositsGasConsumedLessThanCallbackGasLimit() public {
        vm.prank(owner);
        yolo.updateMaximumNumberOfParticipantsPerRound(100);

        // Current round maximum number of participants is still 20.
        _fillARoundWithSingleETHDeposit();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        for (uint256 i; i < 100; i++) {
            address user = address(uint160(i + 11));
            uint256 depositAmount = 0.01 ether * (i + 1);
            vm.deal(user, depositAmount);
            vm.prank(user);
            yolo.deposit{value: depositAmount}(2, _emptyDepositsCalldata());
        }

        uint256 gasBefore = gasleft();
        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID_2, randomWords);
        uint256 gasAfter = gasleft();

        assertLt(gasBefore - gasAfter, 500_000, "Gas consumed is greater than callback gas limit");
    }

    function testFuzz_fulfillRandomWords_WinningDepositIndexIsZero(uint256 randomWord) public {
        vm.assume(randomWord % 210 == 0);

        _fillARoundWithSingleETHDeposit();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        (
            IYoloV2.RoundStatus status,
            ,
            ,
            ,
            ,
            ,
            address winner,
            ,
            uint256 protocolFeeOwed,
            IYoloV2.Deposit[] memory deposits
        ) = yolo.getRound(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawn));
        assertEq(winner, deposits[0].depositor);
        assertEq(protocolFeeOwed, 0.063 ether);

        (
            IYoloV2.RoundStatus status2,
            uint40 maximumNumberOfParticipants,
            uint16 protocolFeeBp,
            uint40 cutoffTime,
            uint40 drawnAt,
            uint40 numberOfParticipants,
            address winner2,
            uint96 valuePerEntry,
            uint256 protocolFeeOwed2,

        ) = yolo.getRound(2);
        assertEq(uint8(status2), uint8(IYoloV2.RoundStatus.Open));
        assertEq(cutoffTime, 0);
        assertEq(drawnAt, 0);
        assertEq(protocolFeeBp, 300);
        assertEq(protocolFeeOwed2, 0);
        assertEq(numberOfParticipants, 0);
        assertEq(winner2, address(0));
        assertEq(maximumNumberOfParticipants, 20);
        assertEq(valuePerEntry, 0.01 ether);
    }
}
