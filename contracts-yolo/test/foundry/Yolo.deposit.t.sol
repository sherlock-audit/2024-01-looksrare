// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";

import {YoloV2} from "../../contracts/YoloV2.sol";
import {IYoloV2} from "../../contracts/interfaces/IYoloV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Yolo_Deposit_Test is TestHelpers {
    function setUp() public {
        _forkMainnet();
        _deployYolo();
        _subscribeYoloToVRF();
    }

    function test_deposit() public {
        vm.deal(user2, 1 ether);
        vm.deal(user3, 0.49 ether);

        expectEmitCheckAll();
        emit Deposited({depositor: user2, roundId: 1, entriesCount: 100});

        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        IYoloV2.Deposit[] memory deposits = _getDeposits(1);
        assertEq(deposits.length, 1);

        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 1 ether);
        assertEq(deposit.depositor, user2);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 100);

        assertEq(yolo.depositCount(1, user2), 1);
        (, , , uint40 cutoffTime, , uint40 numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);
        assertEq(numberOfParticipants, 1);

        expectEmitCheckAll();
        emit Deposited({depositor: user3, roundId: 1, entriesCount: 49});

        vm.prank(user3);
        yolo.deposit{value: 0.49 ether}(1, _emptyDepositsCalldata());

        deposits = _getDeposits(1);
        assertEq(deposits.length, 2);

        deposit = deposits[1];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 0.49 ether);
        assertEq(deposit.depositor, user3);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 149);

        assertEq(yolo.depositCount(1, user3), 1);
        (, , , , , numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 2);

        // 3rd user deposits 1 Pudgy Penguins
        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(8623);

        IYoloV2.DepositCalldata[] memory depositsCalldata = _pudgyPenguinsDepositsCalldata(8_623);

        _grantApprovalsToTransferManager(penguOwner);

        vm.startPrank(penguOwner);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);

        expectEmitCheckAll();
        emit Deposited({depositor: penguOwner, roundId: 1, entriesCount: 522});

        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        deposits = _getDeposits(1);
        assertEq(deposits.length, 3);

        deposit = deposits[2];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
        assertEq(deposit.tokenAddress, PUDGY_PENGUINS);
        assertEq(deposit.tokenId, 8623);
        assertEq(deposit.tokenAmount, 0);
        assertEq(deposit.depositor, penguOwner);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 671);

        assertEq(yolo.depositCount(1, penguOwner), 1);
        (, , , , , numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 3);

        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(8623), address(yolo));

        uint256 looksAmount = 1_000 ether;

        // 4th user deposits 1,000 LOOKS
        deal(LOOKS, user4, looksAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = looksAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        _grantApprovalsToTransferManager(user4);

        vm.startPrank(user4);
        IERC20(LOOKS).approve(address(transferManager), looksAmount);

        expectEmitCheckAll();
        emit Deposited({depositor: user4, roundId: 1, entriesCount: 3});

        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        deposits = _getDeposits(1);
        assertEq(deposits.length, 4);

        deposit = deposits[3];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(deposit.tokenAddress, LOOKS);
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, looksAmount);
        assertEq(deposit.depositor, user4);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 674);

        assertEq(yolo.depositCount(1, user4), 1);
        (, , , , , numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 4);

        assertEq(yolo.prices(LOOKS, 1), 33684085101692);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), looksAmount);

        uint256 usdcAmount = 1_234e6;

        // 5th user deposits 1,234 USDC
        deal(USDC, user5, usdcAmount);

        depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = USDC;
        amounts = new uint256[](1);
        amounts[0] = usdcAmount;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        _grantApprovalsToTransferManager(user5);

        vm.startPrank(user5);
        IERC20(USDC).approve(address(transferManager), usdcAmount);

        expectEmitCheckAll();
        emit Deposited({depositor: user5, roundId: 1, entriesCount: 78});

        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        deposits = _getDeposits(1);
        assertEq(deposits.length, 5);

        deposit = deposits[4];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(deposit.tokenAddress, USDC);
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, usdcAmount);
        assertEq(deposit.depositor, user5);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 752);

        assertEq(yolo.depositCount(1, user5), 1);
        (, , , , , numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 5);

        assertEq(yolo.prices(USDC, 1), 635032386273720);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), usdcAmount);

        assertEq(address(yolo).balance, 1.49 ether);
    }

    function test_deposit_MultipleERC721s() public {
        uint256 tokenIdOne = 1018;
        uint256 tokenIdTwo = 2953;

        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(tokenIdOne);

        address anotherPenguOwner = IERC721(PUDGY_PENGUINS).ownerOf(tokenIdTwo);
        vm.prank(anotherPenguOwner);
        IERC721(PUDGY_PENGUINS).transferFrom(anotherPenguOwner, penguOwner, tokenIdTwo);

        vm.deal(penguOwner, 1 ether);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = PUDGY_PENGUINS;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenIdOne;
        tokenIds[1] = tokenIdTwo;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirPudgyPenguinsFloorPrice();

        _grantApprovalsToTransferManager(penguOwner);

        vm.startPrank(penguOwner);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);

        expectEmitCheckAll();
        emit Deposited({depositor: penguOwner, roundId: 1, entriesCount: 1_144});

        yolo.deposit{value: 1 ether}(1, depositsCalldata);
        vm.stopPrank();

        IYoloV2.Deposit[] memory deposits = _getDeposits(1);
        assertEq(deposits.length, 3);

        IYoloV2.Deposit memory ethDeposit = deposits[0];
        assertEq(uint8(ethDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(ethDeposit.tokenAddress, address(0));
        assertEq(ethDeposit.tokenId, 0);
        assertEq(ethDeposit.tokenAmount, 1 ether);
        assertEq(ethDeposit.depositor, penguOwner);
        assertFalse(ethDeposit.withdrawn);
        assertEq(ethDeposit.currentEntryIndex, 100);

        IYoloV2.Deposit memory penguinDeposit = deposits[1];
        assertEq(uint8(penguinDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
        assertEq(penguinDeposit.tokenAddress, PUDGY_PENGUINS);
        assertEq(penguinDeposit.tokenId, tokenIdOne);
        assertEq(penguinDeposit.tokenAmount, 0);
        assertEq(penguinDeposit.depositor, penguOwner);
        assertFalse(penguinDeposit.withdrawn);
        assertEq(penguinDeposit.currentEntryIndex, 622);

        IYoloV2.Deposit memory penguinDepositTwo = deposits[2];
        assertEq(uint8(penguinDepositTwo.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
        assertEq(penguinDepositTwo.tokenAddress, PUDGY_PENGUINS);
        assertEq(penguinDepositTwo.tokenId, tokenIdTwo);
        assertEq(penguinDepositTwo.tokenAmount, 0);
        assertEq(penguinDepositTwo.depositor, penguOwner);
        assertFalse(penguinDepositTwo.withdrawn);
        assertEq(penguinDepositTwo.currentEntryIndex, 1_144);

        assertEq(yolo.depositCount(1, penguOwner), 1);
        (, , , uint40 cutoffTime, , uint40 numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 1);
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);

        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(tokenIdOne), address(yolo));
        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(tokenIdTwo), address(yolo));
    }

    function test_deposit_MultipleERC721s_FirstDeposit_EntriesCountPerERC721IsOne() public {
        {
            uint256 tokenIdOne = 48_736;
            uint256 tokenIdTwo = 47_599;
            uint256 tokenIdThree = 43_824;

            address tokenOwner = IERC721(GEMESIS).ownerOf(tokenIdOne);

            address tokenTwoOwner = IERC721(GEMESIS).ownerOf(tokenIdTwo);
            vm.prank(tokenTwoOwner);
            IERC721(GEMESIS).transferFrom(tokenTwoOwner, tokenOwner, tokenIdTwo);

            address tokenThreeOwner = IERC721(GEMESIS).ownerOf(tokenIdThree);
            vm.prank(tokenThreeOwner);
            IERC721(GEMESIS).transferFrom(tokenThreeOwner, tokenOwner, tokenIdThree);

            IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
            depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
            depositsCalldata[0].tokenAddress = GEMESIS;
            uint256[] memory tokenIds = new uint256[](3);
            tokenIds[0] = tokenIdOne;
            tokenIds[1] = tokenIdTwo;
            tokenIds[2] = tokenIdThree;
            depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
            depositsCalldata[0].reservoirOracleFloorPrice = _reservoirGemesisFloorPrice();

            _grantApprovalsToTransferManager(tokenOwner);

            vm.startPrank(tokenOwner);
            IERC721(GEMESIS).setApprovalForAll(address(transferManager), true);

            expectEmitCheckAll();
            emit Deposited({depositor: tokenOwner, roundId: 1, entriesCount: 3});

            yolo.deposit(1, depositsCalldata);
            vm.stopPrank();

            IYoloV2.Deposit[] memory deposits = _getDeposits(1);
            assertEq(deposits.length, 3);

            IYoloV2.Deposit memory firstDeposit = deposits[0];
            assertEq(uint8(firstDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
            assertEq(firstDeposit.tokenAddress, GEMESIS);
            assertEq(firstDeposit.tokenId, tokenIdOne);
            assertEq(firstDeposit.tokenAmount, 0);
            assertEq(firstDeposit.depositor, tokenOwner);
            assertFalse(firstDeposit.withdrawn);
            assertEq(firstDeposit.currentEntryIndex, 1);

            IYoloV2.Deposit memory secondDeposit = deposits[1];
            assertEq(uint8(secondDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
            assertEq(secondDeposit.tokenAddress, GEMESIS);
            assertEq(secondDeposit.tokenId, tokenIdTwo);
            assertEq(secondDeposit.tokenAmount, 0);
            assertEq(secondDeposit.depositor, tokenOwner);
            assertFalse(secondDeposit.withdrawn);
            assertEq(secondDeposit.currentEntryIndex, 2);

            IYoloV2.Deposit memory thirdDeposit = deposits[2];
            assertEq(uint8(thirdDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
            assertEq(thirdDeposit.tokenAddress, GEMESIS);
            assertEq(thirdDeposit.tokenId, tokenIdThree);
            assertEq(thirdDeposit.tokenAmount, 0);
            assertEq(thirdDeposit.depositor, tokenOwner);
            assertFalse(thirdDeposit.withdrawn);
            assertEq(thirdDeposit.currentEntryIndex, 3);

            assertEq(yolo.depositCount(1, tokenOwner), 1);
            (, , , , , uint40 numberOfParticipants, , , , ) = yolo.getRound(1);
            assertEq(numberOfParticipants, 1);

            assertEq(IERC721(GEMESIS).ownerOf(tokenIdOne), address(yolo));
            assertEq(IERC721(GEMESIS).ownerOf(tokenIdTwo), address(yolo));
            assertEq(IERC721(GEMESIS).ownerOf(tokenIdThree), address(yolo));
        }

        // -----------------------------------------------------------------------------
        // Second deposit for the round

        {
            uint256 tokenIdOne = 48_737;
            uint256 tokenIdTwo = 47_600;
            uint256 tokenIdThree = 43_825;

            address tokenOwner = IERC721(GEMESIS).ownerOf(tokenIdOne);

            address tokenTwoOwner = IERC721(GEMESIS).ownerOf(tokenIdTwo);
            vm.prank(tokenTwoOwner);
            IERC721(GEMESIS).transferFrom(tokenTwoOwner, tokenOwner, tokenIdTwo);

            address tokenThreeOwner = IERC721(GEMESIS).ownerOf(tokenIdThree);
            vm.prank(tokenThreeOwner);
            IERC721(GEMESIS).transferFrom(tokenThreeOwner, tokenOwner, tokenIdThree);

            IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
            depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
            depositsCalldata[0].tokenAddress = GEMESIS;
            uint256[] memory tokenIds = new uint256[](3);
            tokenIds[0] = tokenIdOne;
            tokenIds[1] = tokenIdTwo;
            tokenIds[2] = tokenIdThree;
            depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
            depositsCalldata[0].reservoirOracleFloorPrice = _reservoirGemesisFloorPrice();

            _grantApprovalsToTransferManager(tokenOwner);

            vm.startPrank(tokenOwner);
            IERC721(GEMESIS).setApprovalForAll(address(transferManager), true);

            expectEmitCheckAll();
            emit Deposited({depositor: tokenOwner, roundId: 1, entriesCount: 3});

            yolo.deposit(1, depositsCalldata);
            vm.stopPrank();

            IYoloV2.Deposit[] memory deposits = _getDeposits(1);
            assertEq(deposits.length, 6);

            IYoloV2.Deposit memory fourthDeposit = deposits[3];
            assertEq(uint8(fourthDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
            assertEq(fourthDeposit.tokenAddress, GEMESIS);
            assertEq(fourthDeposit.tokenId, tokenIdOne);
            assertEq(fourthDeposit.tokenAmount, 0);
            assertEq(fourthDeposit.depositor, tokenOwner);
            assertFalse(fourthDeposit.withdrawn);
            assertEq(fourthDeposit.currentEntryIndex, 4);

            IYoloV2.Deposit memory fifthDeposit = deposits[4];
            assertEq(uint8(fifthDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
            assertEq(fifthDeposit.tokenAddress, GEMESIS);
            assertEq(fifthDeposit.tokenId, tokenIdTwo);
            assertEq(fifthDeposit.tokenAmount, 0);
            assertEq(fifthDeposit.depositor, tokenOwner);
            assertFalse(fifthDeposit.withdrawn);
            assertEq(fifthDeposit.currentEntryIndex, 5);

            IYoloV2.Deposit memory sixthDeposit = deposits[5];
            assertEq(uint8(sixthDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
            assertEq(sixthDeposit.tokenAddress, GEMESIS);
            assertEq(sixthDeposit.tokenId, tokenIdThree);
            assertEq(sixthDeposit.tokenAmount, 0);
            assertEq(sixthDeposit.depositor, tokenOwner);
            assertFalse(sixthDeposit.withdrawn);
            assertEq(sixthDeposit.currentEntryIndex, 6);

            assertEq(yolo.depositCount(1, tokenOwner), 1);
            (, , , , , uint40 numberOfParticipants, , , , ) = yolo.getRound(1);
            assertEq(numberOfParticipants, 2);

            assertEq(IERC721(GEMESIS).ownerOf(tokenIdOne), address(yolo));
            assertEq(IERC721(GEMESIS).ownerOf(tokenIdTwo), address(yolo));
            assertEq(IERC721(GEMESIS).ownerOf(tokenIdThree), address(yolo));
        }
    }

    function test_deposit_Multiple() public {
        uint256 tokenIdOne = 1018;
        uint256 tokenIdTwo = 2953;

        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(tokenIdOne);

        address anotherPenguOwner = IERC721(PUDGY_PENGUINS).ownerOf(tokenIdTwo);
        vm.prank(anotherPenguOwner);
        IERC721(PUDGY_PENGUINS).transferFrom(anotherPenguOwner, penguOwner, tokenIdTwo);

        vm.deal(penguOwner, 1 ether);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](5);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = PUDGY_PENGUINS;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenIdOne;
        tokenIds[1] = tokenIdTwo;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirPudgyPenguinsFloorPrice();

        depositsCalldata[1].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[1].tokenAddress = LOOKS;
        depositsCalldata[1].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[1].tokenIdsOrAmounts[0] = 1_000 ether;

        depositsCalldata[2].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[2].tokenAddress = LOOKS;
        depositsCalldata[2].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[2].tokenIdsOrAmounts[0] = 500 ether;

        depositsCalldata[3].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[3].tokenAddress = USDC;
        depositsCalldata[3].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[3].tokenIdsOrAmounts[0] = 1_234e6;

        depositsCalldata[4].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[4].tokenAddress = LOOKS;
        depositsCalldata[4].tokenIdsOrAmounts = new uint256[](1);
        depositsCalldata[4].tokenIdsOrAmounts[0] = 69_420 ether;

        deal(LOOKS, penguOwner, 70_920 ether);
        deal(USDC, penguOwner, 1_234e6);

        _grantApprovalsToTransferManager(penguOwner);

        vm.startPrank(penguOwner);
        IERC20(LOOKS).approve(address(transferManager), 70_920 ether);
        IERC20(USDC).approve(address(transferManager), 1_234e6);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);

        expectEmitCheckAll();
        emit Deposited({depositor: penguOwner, roundId: 1, entriesCount: 1_459});

        yolo.deposit{value: 1 ether}(1, depositsCalldata);
        vm.stopPrank();

        IYoloV2.Deposit[] memory deposits = _getDeposits(1);
        assertEq(deposits.length, 7);

        IYoloV2.Deposit memory ethDeposit = deposits[0];
        assertEq(uint8(ethDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(ethDeposit.tokenAddress, address(0));
        assertEq(ethDeposit.tokenId, 0);
        assertEq(ethDeposit.tokenAmount, 1 ether);
        assertEq(ethDeposit.depositor, penguOwner);
        assertFalse(ethDeposit.withdrawn);
        assertEq(ethDeposit.currentEntryIndex, 100);

        IYoloV2.Deposit memory penguinDeposit = deposits[1];
        assertEq(uint8(penguinDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
        assertEq(penguinDeposit.tokenAddress, PUDGY_PENGUINS);
        assertEq(penguinDeposit.tokenId, tokenIdOne);
        assertEq(penguinDeposit.tokenAmount, 0);
        assertEq(penguinDeposit.depositor, penguOwner);
        assertFalse(penguinDeposit.withdrawn);
        assertEq(penguinDeposit.currentEntryIndex, 622);

        IYoloV2.Deposit memory penguinDepositTwo = deposits[2];
        assertEq(uint8(penguinDepositTwo.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
        assertEq(penguinDepositTwo.tokenAddress, PUDGY_PENGUINS);
        assertEq(penguinDepositTwo.tokenId, tokenIdTwo);
        assertEq(penguinDepositTwo.tokenAmount, 0);
        assertEq(penguinDepositTwo.depositor, penguOwner);
        assertFalse(penguinDepositTwo.withdrawn);
        assertEq(penguinDepositTwo.currentEntryIndex, 1_144);

        IYoloV2.Deposit memory looksDeposit = deposits[3];
        assertEq(uint8(looksDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(looksDeposit.tokenAddress, LOOKS);
        assertEq(looksDeposit.tokenId, 0);
        assertEq(looksDeposit.tokenAmount, 1_000 ether);
        assertEq(looksDeposit.depositor, penguOwner);
        assertFalse(looksDeposit.withdrawn);
        assertEq(looksDeposit.currentEntryIndex, 1_147);

        looksDeposit = deposits[4];
        assertEq(uint8(looksDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(looksDeposit.tokenAddress, LOOKS);
        assertEq(looksDeposit.tokenId, 0);
        assertEq(looksDeposit.tokenAmount, 500 ether);
        assertEq(looksDeposit.depositor, penguOwner);
        assertFalse(looksDeposit.withdrawn);
        assertEq(looksDeposit.currentEntryIndex, 1_148);

        IYoloV2.Deposit memory usdcDeposit = deposits[5];
        assertEq(uint8(usdcDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(usdcDeposit.tokenAddress, USDC);
        assertEq(usdcDeposit.tokenId, 0);
        assertEq(usdcDeposit.tokenAmount, 1_234e6);
        assertEq(usdcDeposit.depositor, penguOwner);
        assertFalse(usdcDeposit.withdrawn);
        assertEq(usdcDeposit.currentEntryIndex, 1_226);

        looksDeposit = deposits[6];
        assertEq(uint8(looksDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(looksDeposit.tokenAddress, LOOKS);
        assertEq(looksDeposit.tokenId, 0);
        assertEq(looksDeposit.tokenAmount, 69_420 ether);
        assertEq(looksDeposit.depositor, penguOwner);
        assertFalse(looksDeposit.withdrawn);
        assertEq(looksDeposit.currentEntryIndex, 1_459);

        assertEq(yolo.depositCount(1, penguOwner), 1);
        (, , , , , uint40 numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 1);

        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(tokenIdOne), address(yolo));
        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(tokenIdTwo), address(yolo));

        assertEq(yolo.prices(LOOKS, 1), 33684085101692);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 70_920 ether);

        assertEq(yolo.prices(USDC, 1), 635032386273720);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 1_234e6);

        assertEq(address(yolo).balance, 1 ether);
    }

    function test_deposit_ERC20_PriceReuse() public {
        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](2);

        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        uint256[] memory looksAmount = new uint256[](1);
        looksAmount[0] = 1_000 ether;
        depositsCalldata[0].tokenIdsOrAmounts = looksAmount;

        depositsCalldata[1].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[1].tokenAddress = USDC;
        uint256[] memory usdcAmount = new uint256[](1);
        usdcAmount[0] = 1_234e6;
        depositsCalldata[1].tokenIdsOrAmounts = usdcAmount;

        deal(LOOKS, user4, looksAmount[0]);
        deal(USDC, user4, usdcAmount[0]);

        _grantApprovalsToTransferManager(user4);

        vm.startPrank(user4);
        IERC20(LOOKS).approve(address(transferManager), looksAmount[0]);
        IERC20(USDC).approve(address(transferManager), usdcAmount[0]);
        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        IYoloV2.Deposit[] memory deposits = _getDeposits(1);
        assertEq(deposits.length, 2);

        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(deposit.tokenAddress, LOOKS);
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, looksAmount[0]);
        assertEq(deposit.depositor, user4);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 3);

        deposit = deposits[1];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(deposit.tokenAddress, USDC);
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, usdcAmount[0]);
        assertEq(deposit.depositor, user4);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 81);

        assertEq(yolo.depositCount(1, user4), 1);
        (, , , uint40 cutoffTime, , uint40 numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 1);
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);

        assertEq(yolo.prices(LOOKS, 1), 33684085101692);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), looksAmount[0]);

        assertEq(yolo.prices(USDC, 1), 635032386273720);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), usdcAmount[0]);

        depositsCalldata[0].tokenIdsOrAmounts[0] = 69_420 ether;
        depositsCalldata[1].tokenIdsOrAmounts[0] = 3_388e6;

        deal(LOOKS, user5, depositsCalldata[0].tokenIdsOrAmounts[0]);
        deal(USDC, user5, depositsCalldata[1].tokenIdsOrAmounts[0]);

        _grantApprovalsToTransferManager(user5);

        vm.startPrank(user5);
        IERC20(LOOKS).approve(address(transferManager), 69_420 ether);
        IERC20(USDC).approve(address(transferManager), 3_388e6);
        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        deposits = _getDeposits(1);
        assertEq(deposits.length, 4);

        deposit = deposits[2];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(deposit.tokenAddress, LOOKS);
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 69_420 ether);
        assertEq(deposit.depositor, user5);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 314);

        deposit = deposits[3];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC20));
        assertEq(deposit.tokenAddress, USDC);
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 3_388e6);
        assertEq(deposit.depositor, user5);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 529);

        assertEq(yolo.depositCount(1, user5), 1);
        (, , , cutoffTime, , numberOfParticipants, , , , ) = yolo.getRound(1);
        assertEq(numberOfParticipants, 2);
        assertEq(cutoffTime, block.timestamp + ROUND_DURATION);

        assertEq(yolo.prices(LOOKS, 1), 33684085101692);
        assertEq(IERC20(LOOKS).balanceOf(address(yolo)), 70_420 ether);

        assertEq(yolo.prices(USDC, 1), 635032386273720);
        assertEq(IERC20(USDC).balanceOf(address(yolo)), 4_622e6);
    }

    function test_deposit_ERC721_PriceReuse() public {
        uint256 tokenIdOne = 1018;
        uint256 tokenIdTwo = 2953;

        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(tokenIdOne);
        address penguTwoOwner = IERC721(PUDGY_PENGUINS).ownerOf(tokenIdTwo);

        IYoloV2.DepositCalldata[] memory depositsCalldata = _pudgyPenguinsDepositsCalldata(tokenIdOne);

        _grantApprovalsToTransferManager(penguOwner);

        vm.startPrank(penguOwner);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);

        expectEmitCheckAll();
        emit Deposited({depositor: penguOwner, roundId: 1, entriesCount: 522});

        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        depositsCalldata = _pudgyPenguinsDepositsCalldata(tokenIdTwo);

        _grantApprovalsToTransferManager(penguTwoOwner);

        vm.startPrank(penguTwoOwner);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);

        expectEmitCheckAll();
        emit Deposited({depositor: penguTwoOwner, roundId: 1, entriesCount: 522});

        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        IYoloV2.Deposit[] memory deposits = _getDeposits(1);
        assertEq(deposits.length, 2);

        IYoloV2.Deposit memory penguinDeposit = deposits[0];
        assertEq(uint8(penguinDeposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
        assertEq(penguinDeposit.tokenAddress, PUDGY_PENGUINS);
        assertEq(penguinDeposit.tokenId, tokenIdOne);
        assertEq(penguinDeposit.tokenAmount, 0);
        assertEq(penguinDeposit.depositor, penguOwner);
        assertFalse(penguinDeposit.withdrawn);
        assertEq(penguinDeposit.currentEntryIndex, 522);

        IYoloV2.Deposit memory penguinDepositTwo = deposits[1];
        assertEq(uint8(penguinDepositTwo.tokenType), uint8(IYoloV2.YoloV2__TokenType.ERC721));
        assertEq(penguinDepositTwo.tokenAddress, PUDGY_PENGUINS);
        assertEq(penguinDepositTwo.tokenId, tokenIdTwo);
        assertEq(penguinDepositTwo.tokenAmount, 0);
        assertEq(penguinDepositTwo.depositor, penguTwoOwner);
        assertFalse(penguinDepositTwo.withdrawn);
        assertEq(penguinDepositTwo.currentEntryIndex, 1_044);

        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(tokenIdOne), address(yolo));
        assertEq(IERC721(PUDGY_PENGUINS).ownerOf(tokenIdTwo), address(yolo));
    }

    function test_deposit_FirstDepositHasOnlyOneEntry() public {
        vm.deal(user2, 0.01 ether);
        vm.deal(user3, 0.1 ether);

        expectEmitCheckAll();
        emit Deposited({depositor: user2, roundId: 1, entriesCount: 1});

        vm.prank(user2);
        yolo.deposit{value: 0.01 ether}(1, _emptyDepositsCalldata());

        IYoloV2.Deposit[] memory deposits = _getDeposits(1);
        assertEq(deposits.length, 1);

        IYoloV2.Deposit memory deposit = deposits[0];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 0.01 ether);
        assertEq(deposit.depositor, user2);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 1);

        expectEmitCheckAll();
        emit Deposited({depositor: user3, roundId: 1, entriesCount: 10});

        vm.prank(user3);
        yolo.deposit{value: 0.1 ether}(1, _emptyDepositsCalldata());

        deposits = _getDeposits(1);
        assertEq(deposits.length, 2);

        deposit = deposits[1];
        assertEq(uint8(deposit.tokenType), uint8(IYoloV2.YoloV2__TokenType.ETH));
        assertEq(deposit.tokenAddress, address(0));
        assertEq(deposit.tokenId, 0);
        assertEq(deposit.tokenAmount, 0.1 ether);
        assertEq(deposit.depositor, user3);
        assertFalse(deposit.withdrawn);
        assertEq(deposit.currentEntryIndex, 11);

        assertEq(address(yolo).balance, 0.11 ether);
    }

    function test_deposit_TriggersDrawWinnerByMaximumNumberOfDeposits() public {
        for (uint256 i; i < 10; i++) {
            address user = address(uint160(i + 69));
            uint256 depositAmount = 0.01 ether * (i + 1);

            for (uint256 j; j < 10; j++) {
                vm.deal(user, depositAmount);
                vm.prank(user);
                yolo.deposit{value: depositAmount}(1, _emptyDepositsCalldata());
            }
        }

        IYoloV2.RoundStatus status = _getStatus(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawing));
    }

    function test_deposit_TriggersDrawWinnerByMaximumNumberOfParticipants() public {
        _fillARoundWithSingleETHDeposit();
        IYoloV2.RoundStatus status = _getStatus(1);
        assertEq(uint8(status), uint8(IYoloV2.RoundStatus.Drawing));
    }

    function test_deposit_RevertIf_ZeroDeposits() public {
        vm.expectRevert(IYoloV2.ZeroDeposits.selector);
        vm.prank(user2);
        yolo.deposit(1, _emptyDepositsCalldata());
    }

    function test_deposit_RevertIf_InvalidTokenType() public {
        address[] memory currencies = new address[](1);
        currencies[0] = address(0);

        vm.prank(operator);
        yolo.updateCurrenciesStatus(currencies, true);

        vm.deal(user2, 1 ether);

        IYoloV2.DepositCalldata[] memory deposits = new IYoloV2.DepositCalldata[](1);
        deposits[0].tokenType = IYoloV2.YoloV2__TokenType.ETH;

        vm.expectRevert(IYoloV2.InvalidTokenType.selector);
        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, deposits);
    }

    function test_deposit_RevertIf_InvalidStatus() public {
        vm.deal(user2, 1 ether);

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        vm.prank(user2);
        yolo.deposit{value: 1 ether}(2, _emptyDepositsCalldata());
    }

    function test_deposit_RevertIf_PassedCutoffTime() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        // First deposit sets cutoff time
        vm.prank(user1);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());

        vm.warp(block.timestamp + ROUND_DURATION);

        vm.expectRevert(IYoloV2.InvalidStatus.selector);
        vm.prank(user2);
        yolo.deposit{value: 1 ether}(1, _emptyDepositsCalldata());
    }

    function test_deposit_RevertIf_InvalidValue_ETH() public {
        vm.deal(user2, 0.491 ether);

        vm.expectRevert(IYoloV2.InvalidValue.selector);
        vm.prank(user2);
        yolo.deposit{value: 0.491 ether}(1, _emptyDepositsCalldata());

        // Smaller than valuePerEntry
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        vm.prank(user2);
        yolo.deposit{value: 0.009 ether}(1, _emptyDepositsCalldata());
    }

    function test_deposit_RevertIf_InvalidValue_ERC721() public {
        uint256 tokenId = 3780;
        address nftOwner = IERC721(NPCERS).ownerOf(tokenId);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = NPCERS;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirNPCersFloorPrice();

        vm.expectRevert(IYoloV2.InvalidValue.selector);
        vm.prank(nftOwner);
        yolo.deposit(1, depositsCalldata);
    }

    function test_deposit_RevertIf_InvalidValue_ERC20() public {
        deal(LOOKS, user4, 1 ether);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        depositsCalldata[0].tokenIdsOrAmounts = amounts;

        _grantApprovalsToTransferManager(user4);

        vm.startPrank(user4);
        IERC20(LOOKS).approve(address(transferManager), 1 ether);
        vm.expectRevert(IYoloV2.InvalidValue.selector);
        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();
    }

    function test_deposit_RevertIf_InvalidCurrency() public {
        uint256 tokenId = 8623;
        address nftOwner = IERC721(PUDGY_PENGUINS).ownerOf(tokenId);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = PUDGY_PENGUINS;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirPudgyPenguinsFloorPriceUSDC();

        vm.expectRevert(IYoloV2.InvalidCurrency.selector);
        vm.prank(nftOwner);
        yolo.deposit(1, depositsCalldata);
    }

    function test_deposit_RevertIf_SignatureExpired() public {
        uint256 tokenId = 3780;
        address nftOwner = IERC721(NPCERS).ownerOf(tokenId);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = NPCERS;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirNPCersFloorPrice();

        vm.warp(depositsCalldata[0].reservoirOracleFloorPrice.timestamp + 91 seconds);

        vm.expectRevert(IYoloV2.SignatureExpired.selector);
        vm.prank(nftOwner);
        yolo.deposit(1, depositsCalldata);
    }

    function test_deposit_RevertIf_InvalidCollection() public {
        uint256 tokenId = 3780;
        address nftOwner = IERC721(NPCERS).ownerOf(tokenId);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = NPCERS;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirNPCersFloorPrice();

        address[] memory currencies = new address[](1);
        currencies[0] = NPCERS;

        vm.prank(operator);
        yolo.updateCurrenciesStatus(currencies, false);

        vm.expectRevert(IYoloV2.InvalidCollection.selector);
        vm.prank(nftOwner);
        yolo.deposit(1, depositsCalldata);
    }

    // Spot price instead of TWAP
    function test_deposit_RevertIf_MessageIdInvalid() public {
        uint256 tokenId = 3780;
        address nftOwner = IERC721(NPCERS).ownerOf(tokenId);

        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);
        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC721;
        depositsCalldata[0].tokenAddress = NPCERS;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        depositsCalldata[0].tokenIdsOrAmounts = tokenIds;
        depositsCalldata[0].reservoirOracleFloorPrice = _reservoirNPCersSpotFloorPrice();

        vm.expectRevert(IYoloV2.MessageIdInvalid.selector);
        vm.prank(nftOwner);
        yolo.deposit(1, depositsCalldata);
    }

    function test_deposit_RevertIf_InvalidLength_ERC20() public {
        IYoloV2.DepositCalldata[] memory depositsCalldata = new IYoloV2.DepositCalldata[](1);

        depositsCalldata[0].tokenType = IYoloV2.YoloV2__TokenType.ERC20;
        depositsCalldata[0].tokenAddress = LOOKS;

        vm.prank(user4);
        vm.expectRevert(IYoloV2.InvalidLength.selector);
        yolo.deposit(1, depositsCalldata);

        depositsCalldata[0].tokenIdsOrAmounts = new uint256[](2);
        depositsCalldata[0].tokenIdsOrAmounts[0] = 1_000 ether;
        depositsCalldata[0].tokenIdsOrAmounts[1] = 1_000 ether;

        vm.prank(user4);
        vm.expectRevert(IYoloV2.InvalidLength.selector);
        yolo.deposit(1, depositsCalldata);
    }

    function test_deposit_RevertIf_MaximumNumberOfDepositsReached() public {
        for (uint256 i; i < 99; i++) {
            address user = address(uint160((i % 19) + 69));
            uint256 depositAmount = 0.01 ether * (i + 1);
            vm.deal(user, depositAmount);
            vm.prank(user);
            yolo.deposit{value: depositAmount}(1, _emptyDepositsCalldata());
        }

        vm.deal(user2, 1 ether);
        deal(LOOKS, user2, 1_000 ether);

        _grantApprovalsToTransferManager(user2);

        vm.startPrank(user2);
        IERC20(LOOKS).approve(address(transferManager), 1_000 ether);
        vm.expectRevert(IYoloV2.MaximumNumberOfDepositsReached.selector);
        yolo.deposit{value: 1 ether}(1, _depositCalldata1000LOOKS());
        vm.stopPrank();
    }

    function test_deposit_RevertIf_OnePlayerCannotFillUpTheWholeRound_ETH() public {
        vm.deal(user1, 1_000 ether);

        for (uint256 i; i < 99; ++i) {
            vm.prank(user1);
            yolo.deposit{value: 10 ether}({roundId: 1, deposits: new IYoloV2.DepositCalldata[](0)});
        }

        vm.expectRevert(IYoloV2.OnePlayerCannotFillUpTheWholeRound.selector);
        vm.prank(user1);
        yolo.deposit{value: 10 ether}({roundId: 1, deposits: new IYoloV2.DepositCalldata[](0)});

        // Does not revert
        vm.deal(user2, 10 ether);
        vm.prank(user2);
        yolo.deposit{value: 10 ether}({roundId: 1, deposits: new IYoloV2.DepositCalldata[](0)});
    }

    function test_deposit_RevertIf_OnePlayerCannotFillUpTheWholeRound_ERC20() public {
        vm.deal(user1, 990 ether);

        for (uint256 i; i < 99; ++i) {
            vm.prank(user1);
            yolo.deposit{value: 10 ether}({roundId: 1, deposits: new IYoloV2.DepositCalldata[](0)});
        }

        deal(LOOKS, user1, 1_000 ether);
        _grantApprovalsToTransferManager(user1);

        vm.startPrank(user1);

        IERC20(LOOKS).approve(address(transferManager), 1_000 ether);
        vm.expectRevert(IYoloV2.OnePlayerCannotFillUpTheWholeRound.selector);
        yolo.deposit(1, _depositCalldata1000LOOKS());

        vm.stopPrank();

        // Does not revert
        deal(LOOKS, user2, 1_000 ether);
        _grantApprovalsToTransferManager(user2);

        vm.startPrank(user2);

        IERC20(LOOKS).approve(address(transferManager), 1_000 ether);
        yolo.deposit(1, _depositCalldata1000LOOKS());

        vm.stopPrank();
    }

    function test_deposit_RevertIf_OnePlayerCannotFillUpTheWholeRound_ERC721() public {
        address penguOwner = IERC721(PUDGY_PENGUINS).ownerOf(8623);

        vm.deal(penguOwner, 990 ether);

        for (uint256 i; i < 99; ++i) {
            vm.prank(penguOwner);
            yolo.deposit{value: 10 ether}({roundId: 1, deposits: new IYoloV2.DepositCalldata[](0)});
        }

        IYoloV2.DepositCalldata[] memory depositsCalldata = _pudgyPenguinsDepositsCalldata(8_623);

        _grantApprovalsToTransferManager(penguOwner);

        vm.startPrank(penguOwner);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);
        vm.expectRevert(IYoloV2.OnePlayerCannotFillUpTheWholeRound.selector);
        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();

        address penguOwnerTwo = IERC721(PUDGY_PENGUINS).ownerOf(8624);

        depositsCalldata = _pudgyPenguinsDepositsCalldata(8_624);

        _grantApprovalsToTransferManager(penguOwnerTwo);

        vm.startPrank(penguOwnerTwo);
        IERC721(PUDGY_PENGUINS).setApprovalForAll(address(transferManager), true);
        yolo.deposit(1, depositsCalldata);
        vm.stopPrank();
    }
}
