// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract MockVRFCoordinatorV2 {
    VRFConsumerBaseV2 public yolo;
    uint256 public requestCount;
    uint256[] public requestIds;

    function setYolo(address _yolo) external {
        yolo = VRFConsumerBaseV2(_yolo);
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId) {
        requestId = uint256(
            keccak256(abi.encodePacked(keyHash, subId, requestConfirmations, callbackGasLimit, numWords, requestCount))
        );
        requestIds.push(requestId);
        requestCount++;
    }

    function fulfillRandomWords(uint256 randomWord) external returns (uint256 requestId) {
        uint256 requestsInQueue = requestIds.length;
        if (requestsInQueue == 0) {
            return 0;
        }

        requestId = requestIds[requestsInQueue - 1];
        if (requestId == 0) return requestId;

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        yolo.rawFulfillRandomWords(requestId, randomWords);

        requestIds.pop();
    }
}
