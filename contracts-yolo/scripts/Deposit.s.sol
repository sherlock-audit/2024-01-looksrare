// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Scripting tool
import {Script} from "forge-std/Script.sol";

// Core contracts
import {IYoloV2} from "../contracts/interfaces/IYoloV2.sol";

contract Deposit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IYoloV2 yolo = IYoloV2(0xd158b5cCaFbE55A4E030912525E84EAc95a2015D);

        yolo.deposit{value: 0.01 ether}({roundId: 1, deposits: new IYoloV2.DepositCalldata[](0)});

        vm.stopBroadcast();
    }
}
