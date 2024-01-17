// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Scripting tool
import {Script} from "forge-std/Script.sol";

// Core contracts
import {Yolo} from "../contracts/Yolo.sol";

contract UpdateRoundDuration is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 chainId = block.chainid;

        if (chainId != 5) {
            revert ChainIdInvalid(chainId);
        }

        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Yolo yolo = Yolo(0x897eAe2EeE3E9fdc45A680Ebd0B350732EFE68B6);
        yolo.updateRoundDuration(1 weeks);

        vm.stopBroadcast();
    }
}
