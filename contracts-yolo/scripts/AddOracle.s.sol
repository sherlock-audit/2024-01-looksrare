// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Scripting tool
import {Script} from "forge-std/Script.sol";

// Core contracts
import {PriceOracle} from "../contracts/PriceOracle.sol";

contract AddOracle is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 chainId = block.chainid;

        if (chainId != 5) {
            revert ChainIdInvalid(chainId);
        }

        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        PriceOracle erc20PriceOracle = PriceOracle(0xe2A041F1BaE3b155c62DEE5e053E566D7668434e);
        erc20PriceOracle.addOracle(0x20A5A36ded0E4101C3688CBC405bBAAE58fE9eeC, uint24(3_000));

        vm.stopBroadcast();
    }
}
