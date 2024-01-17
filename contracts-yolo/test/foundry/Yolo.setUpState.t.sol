// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_SetUpState_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
    }

    function test_setUpState() public {
        assertTrue(yolo.hasRole(yolo.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(yolo.hasRole(yolo.OPERATOR_ROLE(), operator));
        assertEq(yolo.maximumNumberOfParticipantsPerRound(), 20);
        assertEq(yolo.roundDuration(), ROUND_DURATION);
        assertEq(yolo.signatureValidityPeriod(), 90 seconds);
        assertEq(yolo.valuePerEntry(), 0.01 ether);
        assertEq(yolo.protocolFeeRecipient(), protocolFeeRecipient);
        assertEq(yolo.protocolFeeBp(), 300);
        assertEq(yolo.protocolFeeDiscountBp(), 7_500);
        assertEq(yolo.reservoirOracle(), RESERVOIR_ORACLE);
        assertEq(address(yolo.erc20Oracle()), address(priceOracle));

        assertEq(yolo.roundsCount(), 1);
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
        ) = yolo.getRound(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Open));
        assertEq(cutoffTime, 0);
        assertEq(drawnAt, 0);
        assertEq(protocolFeeBp, 300);
        assertEq(protocolFeeOwed, 0);
        assertEq(numberOfParticipants, 0);
        assertEq(winner, address(0));
        assertEq(maximumNumberOfParticipants, 20);
        assertEq(valuePerEntry, 0.01 ether);
        assertEq(deposits.length, 0);
    }

    function test_updateCurrenciesStatus() public asPrankedUser(operator) {
        address[] memory currencies = new address[](1);
        currencies[0] = address(1);

        expectEmitCheckAll();
        emit CurrenciesStatusUpdated(currencies, true);

        yolo.updateCurrenciesStatus(currencies, true);
        assertEq(yolo.isCurrencyAllowed(address(1)), 1);
    }

    function test_updateCurrenciesStatus_RevertIf_NotOperator() public {
        address[] memory currencies = new address[](1);
        currencies[0] = address(1);

        vm.expectRevert(IYoloV2.NotOperator.selector);
        yolo.updateCurrenciesStatus(currencies, false);
    }

    function test_updateRoundDuration() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit RoundDurationUpdated(1 hours);

        yolo.updateRoundDuration(1 hours);
        assertEq(yolo.roundDuration(), 1 hours);
    }

    function test_updateRoundDuration_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateRoundDuration(1 hours);
    }

    function test_updateRoundDuration_RevertIf_InvalidRoundDuration() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidRoundDuration.selector);
        yolo.updateRoundDuration(1 hours + 1 seconds);
    }

    function test_updateSignatureValidityPeriod() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit SignatureValidityPeriodUpdated(5 minutes);

        yolo.updateSignatureValidityPeriod(5 minutes);
        assertEq(yolo.signatureValidityPeriod(), 5 minutes);
    }

    function test_updateSignatureValidityPeriod_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateSignatureValidityPeriod(5 minutes);
    }

    function test_updateValuePerEntry() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit ValuePerEntryUpdated(0.005 ether);

        yolo.updateValuePerEntry(0.005 ether);
        assertEq(yolo.valuePerEntry(), 0.005 ether);
    }

    function test_updateValuePerEntry_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateValuePerEntry(0.005 ether);
    }

    function test_updateValuePerEntry_RevertIf_InvalidValue() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.updateValuePerEntry(0);
    }

    function test_updateProtocolFeeRecipient() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit ProtocolFeeRecipientUpdated(address(1));

        yolo.updateProtocolFeeRecipient(address(1));
        assertEq(yolo.protocolFeeRecipient(), address(1));
    }

    function test_updateProtocolFeeRecipient_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateProtocolFeeRecipient(address(1));
    }

    function test_updateProtocolFeeRecipient_RevertIf_InvalidValue() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.updateProtocolFeeRecipient(address(0));
    }

    function test_updateProtocolFeeBp() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit ProtocolFeeBpUpdated(2_409);

        yolo.updateProtocolFeeBp(2_409);
        assertEq(yolo.protocolFeeBp(), 2_409);
    }

    function test_updateProtocolFeeBp_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateProtocolFeeBp(2_409);
    }

    function test_updateProtocolFeeBp_RevertIf_InvalidValue() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.updateProtocolFeeBp(2_501);
    }

    function test_updateProtocolFeeDiscountBp() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit ProtocolFeeDiscountBpUpdated(10_000);

        yolo.updateProtocolFeeDiscountBp(10_000);
        assertEq(yolo.protocolFeeDiscountBp(), 10_000);
    }

    function test_updateProtocolFeeDiscountBp_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateProtocolFeeDiscountBp(10_000);
    }

    function test_updateProtocolFeeDiscountBp_RevertIf_InvalidValue() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.updateProtocolFeeDiscountBp(10_001);
    }

    function test_updateMaximumNumberOfParticipantsPerRound() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit MaximumNumberOfParticipantsPerRoundUpdated(50);

        yolo.updateMaximumNumberOfParticipantsPerRound(50);
        assertEq(yolo.maximumNumberOfParticipantsPerRound(), 50);
    }

    function test_updateMaximumNumberOfParticipantsPerRound_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateMaximumNumberOfParticipantsPerRound(50);
    }

    function test_updateMaximumNumberOfParticipantsPerRound_RevertIf_InvalidValue() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.updateMaximumNumberOfParticipantsPerRound(1);
    }

    function test_updateReservoirOracle() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit ReservoirOracleUpdated(address(1));

        yolo.updateReservoirOracle(address(1));
        assertEq(yolo.reservoirOracle(), address(1));
    }

    function test_updateReservoirOracle_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateReservoirOracle(address(1));
    }

    function test_updateReservoirOracle_RevertIf_InvalidValue() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.updateReservoirOracle(address(0));
    }

    function test_updateERC20Oracle() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit ERC20OracleUpdated(address(1));

        yolo.updateERC20Oracle(address(1));
        assertEq(address(yolo.erc20Oracle()), address(1));
    }

    function test_updateERC20Oracle_RevertIf_NotOwner() public {
        vm.expectRevert(IYoloV2.NotOwner.selector);
        yolo.updateERC20Oracle(address(1));
    }

    function test_updateERC20Oracle_RevertIf_InvalidValue() public asPrankedUser(owner) {
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.updateERC20Oracle(address(0));
    }
}
