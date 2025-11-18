// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    /**
     * @param minDelay The minimum delay before execution
     * @param proposers The addresses with proposer role
     * @param executors The addresses with executor role
     */
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
