// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";

import {Test} from "forge-std/Test.sol";

abstract contract AssertionHelpers is Test {
    YoloV2 internal yolo;

    event CurrenciesStatusUpdated(address[] currencies, bool isAllowed);
    event Deposited(address depositor, uint256 roundId, uint256 entriesCount);
    event DepositsWithdrawn(address depositor, IYoloV2.WithdrawalCalldata[] withdrawalCalldata);
    event ERC20OracleUpdated(address erc20Oracle);
    event MaximumNumberOfParticipantsPerRoundUpdated(uint40 maximumNumberOfParticipantsPerRound);
    event MultipleRoundsDeposited(
        address depositor,
        uint256 startingRoundId,
        uint256[] amounts,
        uint256[] entriesCounts
    );
    event OutflowAllowedUpdated(bool isAllowed);
    event Paused(address account);
    event PoolAdded(address token, address pool);
    event PoolRemoved(address token);
    event PrizesClaimed(address winner, IYoloV2.WithdrawalCalldata[] withdrawalCalldata);
    event ProtocolFeeBpUpdated(uint16 protocolFeeBp);
    event ProtocolFeeDiscountBpUpdated(uint16 protocolFeeDiscountBp);
    event ProtocolFeePayment(uint256 amount, address currency);
    event ProtocolFeeRecipientUpdated(address protocolFeeRecipient);
    event RandomnessRequested(uint256 roundId, uint256 requestId);
    event ReservoirOracleUpdated(address reservoirOracle);
    event Rollover(
        address depositor,
        IYoloV2.WithdrawalCalldata[] withdrawalCalldata,
        uint256 enteredRoundId,
        uint256 entriesCount
    );
    event RoundDurationUpdated(uint40 roundDuration);
    event RoundsCancelled(uint256 startingRoundId, uint256 numberOfRounds);
    event RoundStatusUpdated(uint256 roundId, IYoloV2.RoundStatus status);
    event SignatureValidityPeriodUpdated(uint40 signatureValidityPeriod);
    event Unpaused(address account);
    event ValuePerEntryUpdated(uint256 valuePerEntry);

    function expectEmitCheckAll() internal {
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true});
    }

    function _expectChainlinkCall() internal {
        vm.expectCall(
            0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            abi.encodeCall(
                VRFCoordinatorV2Interface.requestRandomWords,
                (
                    hex"8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef",
                    uint64(734),
                    uint16(3),
                    500_000,
                    uint32(1)
                )
            )
        );
    }

    function _assertAllPrizesAreWithdrawn(uint256 roundId) internal {
        (, , , , , , , , , IYoloV2.Deposit[] memory prizes) = yolo.getRound(roundId);
        for (uint256 i; i < prizes.length; i++) {
            assertTrue(prizes[i].withdrawn);
        }
    }

    function _assertZeroProtocolFeeOwed(uint256 roundId) internal {
        (, , , , , , , , uint256 protocolFeeOwed, ) = yolo.getRound(roundId);
        assertEq(protocolFeeOwed, 0);
    }
}
