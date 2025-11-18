// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor _governor;
    Box _box;
    TimeLock _timelock; // Is this just initializing the variables? I will learn later...
    GovToken _govToken;

    address public user = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] _proposers;
    address[] _executors;

    uint256[] _values;
    bytes[] _calldatas;
    address[] _targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 1; // how many blocks til a vote is active
    uint256 public constant VOTING_PERIOD = 50400; // how many blocks til a vote is closed

    function setUp() public {
        _govToken = new GovToken();
        _govToken.mint(user, INITIAL_SUPPLY);

        vm.startPrank(user);
        _govToken.delegate(user);
        _timelock = new TimeLock(MIN_DELAY, _proposers, _executors);
        _governor = new MyGovernor(_govToken, _timelock);

        bytes32 proposerRole = _timelock.PROPOSER_ROLE();
        bytes32 executorRole = _timelock.EXECUTOR_ROLE();
        bytes32 adminRole = _timelock.TIMELOCK_ADMIN_ROLE();

        _timelock.grantRole(proposerRole, address(_governor));
        _timelock.grantRole(executorRole, address(0));
        _timelock.revokeRole(adminRole, user);

        vm.stopPrank();

        _box = new Box();
        _box.transferOwnership(address(_timelock)); // timelock owns the DAO...DAO owns the timelock...
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        _box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "store(uint256)",
            valueToStore
        );

        _values.push(0);
        _calldatas.push(encodedFunctionCall);
        _targets.push(address(_box));

        // 1. Propose to the DAO

        uint256 proposalId = _governor.propose(
            _targets,
            _values,
            _calldatas,
            description
        );

        // View the state

        console.log("Proposal State: ", uint256(_governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State: ", uint256(_governor.state(proposalId)));

        // 2. Vote on the proposal

        string memory reason = "cuz blue frog is cool";

        uint8 voteWay = 1; // voting yes
        vm.prank(user);

        _governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the TX

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        _governor.queue(_targets, _values, _calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute the TX

        _governor.execute(_targets, _values, _calldatas, descriptionHash);

        console.log("Box value: ", _box.getNumber());
        assert(_box.getNumber() == valueToStore);
    }
}
