// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {JBAccountingContext} from "@bananapus/core-v6/src/structs/JBAccountingContext.sol";

/// @notice Test-only stand-in for the router terminal registry.
/// @dev REVDeployer registers this terminal without accounting contexts; the no-op keeps the fork fixture focused on
/// fee-project behavior while preserving the distinct canonical terminal addresses expected by Revnet.
contract MockRouterTerminalRegistry {
    /// @notice Accept the empty accounting-context registration used by `REVDeployer`.
    function addAccountingContextsFor(uint256, JBAccountingContext[] calldata) external {}

    /// @notice Report no surplus because the router terminal registry does not custody funds in this fixture.
    function currentSurplusOf(uint256, address[] calldata, uint256, uint256) external pure returns (uint256) {
        return 0;
    }
}
