// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_DepositETHIntoMultipleRounds_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();

        vm.deal(user1, 10 ether);
    }

    function test_depositETHIntoMultipleRounds() public asPrankedUser(user1) {
        expectEmitCheckAll();
        emit MultipleRoundsDeposited({
            depositor: user1,
            startingRoundId: 1,
            amounts: _amounts(),
            entriesCounts: _expectedEntriesCounts()
        });

        yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());

        assertEq(user1.balance, 0);
        assertEq(address(yolo).balance, 10 ether);

        for (uint256 i = 1; i <= 4; i++) {
            (
                IYoloV2.RoundStatus status,
                uint40 maximumNumberOfParticipants,
                uint16 protocolFeeBp,
                uint40 cutoffTime,
                uint40 drawnAt,
                uint40 numberOfParticipants,
                address winner,
                uint96 valuePerEntry,
                uint256 protocolFeeOwed,
                IYoloV2.Deposit[] memory deposits
            ) = yolo.getRound(i);

            assertEq(deposits.length, 1);

            IYoloV2.Deposit memory deposit = deposits[0];
            assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
            assertEq(deposit.tokenAddress, address(0));
            assertEq(deposit.tokenId, 0);
            assertEq(deposit.tokenAmount, 1 ether * i);
            assertEq(deposit.depositor, user1);
            assertFalse(deposit.withdrawn);
            assertEq(deposit.currentEntryIndex, 100 * i);

            if (i == 1) {
                assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
                assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
            } else {
                assertEq(uint8(status), uint8(IYoloV2.RoundStatus.None));
                assertEq(cutoffTime, 0);
            }

            assertEq(maximumNumberOfParticipants, MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND);
            assertEq(valuePerEntry, 0.01 ether);
            assertEq(protocolFeeBp, 300);
            assertEq(drawnAt, 0);
            assertEq(numberOfParticipants, 1);
            assertEq(winner, address(0));
            assertEq(protocolFeeOwed, 0);
        }
    }

    function test_depositETHIntoMultipleRounds_RevertIf_FutureRounds_MaximumNumberOfParticipantsReached() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;

        vm.deal(user1, 10 ether);
        vm.prank(user1);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(amounts);

        vm.prank(owner);
        yolo.updateMaximumNumberOfParticipantsPerRound(2);

        amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;

        vm.deal(user2, 10 ether);
        vm.prank(user2);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(amounts);

        vm.deal(user3, 10 ether);
        vm.prank(user3);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(amounts);

        vm.deal(user4, 10 ether);
        vm.expectRevert(IYoloV2.MaximumNumberOfParticipantsReached.selector);
        vm.prank(user4);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(amounts);
    }

    function test_depositETHIntoMultipleRounds_DrawOpenRound() public {
        for (uint160 i = 11; i < 30; i++) {
            address user = address(i);
            vm.deal(user, 10 ether);

            expectEmitCheckAll();
            emit MultipleRoundsDeposited({
                depositor: user,
                startingRoundId: 1,
                amounts: _amounts(),
                entriesCounts: _expectedEntriesCounts()
            });

            vm.prank(user);
            yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());

            assertEq(user.balance, 0);
        }

        assertEq(address(yolo).balance, 190 ether);

        for (uint256 i = 1; i <= 4; i++) {
            (
                IYoloV2.RoundStatus status,
                uint40 maximumNumberOfParticipants,
                uint16 protocolFeeBp,
                uint40 cutoffTime,
                uint40 drawnAt,
                uint40 numberOfParticipants,
                address winner,
                uint96 valuePerEntry,
                uint256 protocolFeeOwed,
                IYoloV2.Deposit[] memory deposits
            ) = yolo.getRound(i);

            assertEq(deposits.length, 19);

            for (uint256 j; j < 19; j++) {
                IYoloV2.Deposit memory deposit = deposits[j];
                assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
                assertEq(deposit.tokenAddress, address(0));
                assertEq(deposit.tokenId, 0);
                assertEq(deposit.tokenAmount, 1 ether * i);
                assertEq(deposit.depositor, address(11 + uint160(j)));
                assertFalse(deposit.withdrawn);
                assertEq(deposit.currentEntryIndex, 100 * i * (j + 1));
            }

            if (i == 1) {
                assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
                assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
            } else {
                assertEq(uint8(status), uint8(IYoloV2.RoundStatus.None));
                assertEq(cutoffTime, 0);
            }

            assertEq(maximumNumberOfParticipants, MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND);
            assertEq(valuePerEntry, 0.01 ether);
            assertEq(protocolFeeBp, 300);
            assertEq(drawnAt, 0);
            assertEq(numberOfParticipants, 19);
            assertEq(winner, address(0));
            assertEq(protocolFeeOwed, 0);
        }

        address user20 = address(30);
        vm.deal(user20, 1 ether);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        uint256[] memory expectedEntriesCount = new uint256[](1);
        expectedEntriesCount[0] = 100;

        expectEmitCheckAll();
        emit MultipleRoundsDeposited({
            depositor: user20,
            startingRoundId: 1,
            amounts: amounts,
            entriesCounts: expectedEntriesCount
        });

        expectEmitCheckAll();
        emit RandomnessRequested(1, FULFILL_RANDOM_WORDS_REQUEST_ID);

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Drawing);

        _expectChainlinkCall();
        vm.prank(user20);
        yolo.depositETHIntoMultipleRounds{value: 1 ether}(amounts);

        (bool exists, uint40 roundId, uint256 randomWord) = yolo.randomnessRequests(FULFILL_RANDOM_WORDS_REQUEST_ID);

        assertTrue(exists);
        assertEq(roundId, 1);
        assertEq(randomWord, 0);

        (
            IYoloV2.RoundStatus drawingRoundStatus,
            ,
            ,
            ,
            uint40 startingRoundDrawnAt,
            ,
            ,
            ,
            ,
            IYoloV2.Deposit[] memory drawingRoundDeposits
        ) = yolo.getRound(1);
        assertEq(uint8(drawingRoundStatus), uint8(IYoloV2.RoundStatus.Drawing));
        assertEq(startingRoundDrawnAt, block.timestamp);
        assertEq(drawingRoundDeposits.length, 20);

        IYoloV2.Deposit memory drawingRoundLastDeposit = drawingRoundDeposits[19];
        assertEq(uint8(drawingRoundLastDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(drawingRoundLastDeposit.tokenAddress, address(0));
        assertEq(drawingRoundLastDeposit.tokenId, 0);
        assertEq(drawingRoundLastDeposit.tokenAmount, 1 ether);
        assertEq(drawingRoundLastDeposit.depositor, user20);
        assertFalse(drawingRoundLastDeposit.withdrawn);
        assertEq(drawingRoundLastDeposit.currentEntryIndex, 2_000);

        (IYoloV2.RoundStatus roundTwoStatus, , , , uint40 roundTwoDrawnAt, , , , , ) = yolo.getRound(2);
        assertEq(uint8(roundTwoStatus), uint8(IYoloV2.RoundStatus.None));
        assertEq(roundTwoDrawnAt, 0);

        assertEq(address(yolo).balance, 191 ether);
    }

    function test_depositETHIntoMultipleRounds_DrawFirstAndSecondRound() public {
        for (uint160 i = 11; i < 30; i++) {
            address user = address(i);
            vm.deal(user, 10 ether);

            expectEmitCheckAll();
            emit MultipleRoundsDeposited({
                depositor: user,
                startingRoundId: 1,
                amounts: _amounts(),
                entriesCounts: _expectedEntriesCounts()
            });

            vm.prank(user);
            yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());
        }

        address user20 = address(30);
        vm.deal(user20, 10 ether);

        expectEmitCheckAll();
        emit MultipleRoundsDeposited({
            depositor: user20,
            startingRoundId: 1,
            amounts: _amounts(),
            entriesCounts: _expectedEntriesCounts()
        });

        expectEmitCheckAll();
        emit RandomnessRequested(1, FULFILL_RANDOM_WORDS_REQUEST_ID);

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Drawing);

        _expectChainlinkCall();

        vm.prank(user20);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Drawn);

        expectEmitCheckAll();
        emit RoundStatusUpdated(2, IYoloV2.RoundStatus.Drawing);

        _expectChainlinkCall();

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        (
            IYoloV2.RoundStatus status,
            uint40 maximumNumberOfParticipants,
            uint16 protocolFeeBp,
            uint40 cutoffTime,
            uint40 drawnAt,
            uint40 numberOfParticipants,
            address winner,
            uint96 valuePerEntry,
            uint256 protocolFeeOwed,

        ) = yolo.getRound(2);

        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawing));
        assertEq(cutoffTime, 0);
        assertEq(maximumNumberOfParticipants, MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND);
        assertEq(valuePerEntry, 0.01 ether);
        assertEq(protocolFeeBp, 300);
        assertEq(drawnAt, block.timestamp);
        assertEq(numberOfParticipants, 20);
        assertEq(winner, address(0));
        assertEq(protocolFeeOwed, 0);
    }

    function test_depositETHIntoMultipleRounds_DrawFirstAndOpenSecondRound() public {
        for (uint160 i = 11; i < 30; i++) {
            address user = address(i);
            vm.deal(user, 10 ether);

            expectEmitCheckAll();
            emit MultipleRoundsDeposited({
                depositor: user,
                startingRoundId: 1,
                amounts: _amounts(),
                entriesCounts: _expectedEntriesCounts()
            });

            vm.prank(user);
            yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());
        }

        address user20 = address(30);
        vm.deal(user20, 10 ether);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;

        uint256[] memory expectedEntriesCount = new uint256[](1);
        expectedEntriesCount[0] = 1_000;

        expectEmitCheckAll();
        emit MultipleRoundsDeposited({
            depositor: user20,
            startingRoundId: 1,
            amounts: amounts,
            entriesCounts: expectedEntriesCount
        });

        expectEmitCheckAll();
        emit RandomnessRequested(1, FULFILL_RANDOM_WORDS_REQUEST_ID);

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Drawing);

        _expectChainlinkCall();

        vm.prank(user20);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(amounts);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 69_420;

        expectEmitCheckAll();
        emit RoundStatusUpdated(1, IYoloV2.RoundStatus.Drawn);

        expectEmitCheckAll();
        emit RoundStatusUpdated(2, IYoloV2.RoundStatus.Open);

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        {
            (
                IYoloV2.RoundStatus status,
                uint40 maximumNumberOfParticipants,
                uint16 protocolFeeBp,
                uint40 cutoffTime,
                uint40 drawnAt,
                uint40 numberOfParticipants,
                address winner,
                uint96 valuePerEntry,
                uint256 protocolFeeOwed,

            ) = yolo.getRound(2);

            assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
            assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
            assertEq(maximumNumberOfParticipants, MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND);
            assertEq(valuePerEntry, 0.01 ether);
            assertEq(protocolFeeBp, 300);
            assertEq(drawnAt, 0);
            assertEq(numberOfParticipants, 19);
            assertEq(winner, address(0));
            assertEq(protocolFeeOwed, 0);
        }

        expectEmitCheckAll();
        emit RoundStatusUpdated(2, IYoloV2.RoundStatus.Drawing);

        vm.deal(user20, 10 ether);

        // Make sure the round can be drawn.
        vm.prank(user20);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(amounts);

        expectEmitCheckAll();
        emit RoundStatusUpdated(2, IYoloV2.RoundStatus.Drawn);

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(yolo).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID_2, randomWords);

        {
            (
                IYoloV2.RoundStatus status,
                uint40 maximumNumberOfParticipants,
                uint16 protocolFeeBp,
                uint40 cutoffTime,
                uint40 drawnAt,
                uint40 numberOfParticipants,
                address winner,
                uint96 valuePerEntry,
                uint256 protocolFeeOwed,

            ) = yolo.getRound(2);

            assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawn));
            assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
            assertEq(maximumNumberOfParticipants, MAXIMUM_NUMBER_OF_PARTICIPANTS_PER_ROUND);
            assertEq(valuePerEntry, 0.01 ether);
            assertEq(protocolFeeBp, 300);
            assertEq(drawnAt, block.timestamp);
            assertEq(numberOfParticipants, 20);
            assertEq(winner, address(22));
            assertEq(protocolFeeOwed, 1.44 ether);
        }
    }

    function test_depositETHIntoMultipleRounds_RevertIf_CurrentRoundIsNotOpen() public {
        // Transition round to Drawing
        for (uint160 i = 11; i < 31; i++) {
            address user = address(i);
            vm.deal(user, 10 ether);

            expectEmitCheckAll();
            emit MultipleRoundsDeposited({
                depositor: user,
                startingRoundId: 1,
                amounts: _amounts(),
                entriesCounts: _expectedEntriesCounts()
            });

            vm.prank(user);
            yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());
        }

        address user21 = address(31);
        vm.deal(user21, 10 ether);
        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());
    }

    function test_depositETHIntoMultipleRounds_RevertIf_CurrentRoundIsExpired() public asPrankedUser(user1) {
        vm.deal(user1, 20 ether);
        // First deposit required to set the cutoff time
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());

        vm.warp(block.timestamp + ROUND_DURATION);
        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());
    }

    function test_depositETHIntoMultipleRounds_RevertIf_ZeroETHSent() public asPrankedUser(user1) {
        vm.expectRevert(IYoloV2.ZeroDeposits.selector);
        yolo.depositETHIntoMultipleRounds(_amounts());
    }

    function test_depositETHIntoMultipleRounds_RevertIf_ZeroAmountsLength() public asPrankedUser(user1) {
        vm.expectRevert(IYoloV2.ZeroDeposits.selector);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(new uint256[](0));
    }

    function test_depositETHIntoMultipleRounds_RevertIf_InvalidValue() public asPrankedUser(user1) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.depositETHIntoMultipleRounds{value: 6 ether}(_amounts());
    }

    function test_depositETHIntoMultipleRounds_RevertIf_AmountIsNotDivisibleByValuePerEntry()
        public
        asPrankedUser(user1)
    {
        vm.deal(user1, 10.009 ether);
        uint256[] memory amounts = _amounts();
        amounts[0] = 1.009 ether;
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.depositETHIntoMultipleRounds{value: 10.009 ether}(amounts);
    }

    function test_depositETHIntoMultipleRounds_RevertIf_OnePlayerCannotFillUpTheWholeRound_FirstRound() public {
        vm.deal(user1, 1_000 ether);
        for (uint256 i; i < 99; ++i) {
            vm.prank(user1);
            yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());
        }

        vm.expectRevert(IYoloV2.OnePlayerCannotFillUpTheWholeRound.selector);
        vm.prank(user1);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());

        // Does not revert
        vm.deal(user2, 10 ether);
        vm.prank(user2);
        yolo.depositETHIntoMultipleRounds{value: 10 ether}(_amounts());
    }

    function _amounts() private pure returns (uint256[] memory amounts) {
        amounts = new uint256[](4);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;
        amounts[3] = 4 ether;
    }

    function _expectedEntriesCounts() private pure returns (uint256[] memory entriesCounts) {
        entriesCounts = new uint256[](4);
        entriesCounts[0] = 100;
        entriesCounts[1] = 200;
        entriesCounts[2] = 300;
        entriesCounts[3] = 400;
    }
}
