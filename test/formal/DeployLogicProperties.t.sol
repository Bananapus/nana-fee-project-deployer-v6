// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

/// @title DeployLogicProperties
/// @notice Functional-correctness harness for the two pieces of branching logic in `Deploy.s.sol` that are not pure
///         configuration assembly: the L2 sucker-deployer fallback selection (`Deploy.s.sol:228-241`) and the
///         canonical-shape boolean conjunction (`_feeProjectIsCanonical`, `Deploy.s.sol:281-307`). Both are ported
///         here as pure functions and verified symbolically (Halmos `check_`) and by fuzz (`testFuzz_`).
/// @dev    Each property is dual-implemented: `check_` for Halmos and `testFuzz_` for forge.
contract DeployLogicProperties is Test {
    // =========================================================================
    // L2 sucker-deployer selection (Deploy.s.sol:230-240)
    // =========================================================================
    /// @notice Port of the script's L2 deployer fallback:
    ///         `op != 0 ? op : base != 0 ? base : arb`. The script then reverts if the result is zero.
    function selectL2Deployer(address op, address base, address arb) public pure returns (address) {
        return op != address(0) ? op : base != address(0) ? base : arb;
    }

    /// @notice Selection priority is exactly OP > Base > Arbitrum, and the result is zero only when all three are zero.
    ///         This is the property that backs the explicit "L2 > L1 Sucker is not configured" revert (A.3.2 / D.6):
    ///         the script reverts iff `selectL2Deployer == 0`, i.e. iff no L2->L1 deployer exists.
    function check_l2DeployerSelection(address op, address base, address arb) public pure {
        address selected = selectL2Deployer(op, base, arb);

        if (op != address(0)) {
            assert(selected == op); // OP always wins when present.
        } else if (base != address(0)) {
            assert(selected == base); // Base wins when OP absent.
        } else {
            assert(selected == arb); // Otherwise Arbitrum (possibly zero).
        }

        // The selected deployer is always one of the three candidates.
        assert(selected == op || selected == base || selected == arb);

        // Zero result iff every candidate is zero (this is exactly the revert condition).
        bool allZero = op == address(0) && base == address(0) && arb == address(0);
        assert((selected == address(0)) == allZero);
    }

    function testFuzz_l2DeployerSelection(address op, address base, address arb) public pure {
        address selected = selectL2Deployer(op, base, arb);

        if (op != address(0)) {
            assertEq(selected, op, "OP preferred");
        } else if (base != address(0)) {
            assertEq(selected, base, "Base second");
        } else {
            assertEq(selected, arb, "Arbitrum last");
        }

        bool allZero = op == address(0) && base == address(0) && arb == address(0);
        assertEq(selected == address(0), allZero, "zero result iff all candidates zero (revert condition)");
    }

    // =========================================================================
    // Canonical-shape conjunction (_feeProjectIsCanonical, Deploy.s.sol:281-307)
    // =========================================================================
    /// @notice Port of `_feeProjectIsCanonical`'s control flow reduced to its boolean essence: the result is the AND
    ///         of nine independent property checks. Each `c_i` represents one on-chain comparison's pass/fail.
    function isCanonical(
        bool ownerIsRevnetOwner,
        bool controllerIsCore,
        bool feeRevnetIdMatches,
        bool configHashMatches,
        bool operatorRecognized,
        bool symbolMatches,
        bool uriMatches,
        bool reservedSplitCanonical,
        bool terminalConfigCanonical
    )
        public
        pure
        returns (bool)
    {
        if (!ownerIsRevnetOwner) return false;
        if (!controllerIsCore) return false;
        if (!feeRevnetIdMatches) return false;
        if (!configHashMatches) return false;
        if (!operatorRecognized) return false;
        if (!symbolMatches) return false;
        if (!uriMatches) return false;
        if (!reservedSplitCanonical) return false;
        if (!terminalConfigCanonical) return false;
        return true;
    }

    /// @notice The guard is the conjunction of all nine checks: true iff every check passes (B.1.2). Symbolically
    ///         verifies that the sequential early-return structure is equivalent to a 9-way AND — i.e. any single
    ///         failing check forces a non-canonical (revert) verdict, and no near-match slips through (D.3).
    function check_canonicalIsConjunction(
        bool c1,
        bool c2,
        bool c3,
        bool c4,
        bool c5,
        bool c6,
        bool c7,
        bool c8,
        bool c9
    )
        public
        pure
    {
        bool result = isCanonical(c1, c2, c3, c4, c5, c6, c7, c8, c9);
        bool all = c1 && c2 && c3 && c4 && c5 && c6 && c7 && c8 && c9;
        assert(result == all);
        // Contrapositive: any single false check => not canonical.
        if (!c1 || !c2 || !c3 || !c4 || !c5 || !c6 || !c7 || !c8 || !c9) {
            assert(!result);
        }
    }

    function testFuzz_canonicalIsConjunction(
        bool c1,
        bool c2,
        bool c3,
        bool c4,
        bool c5,
        bool c6,
        bool c7,
        bool c8,
        bool c9
    )
        public
        pure
    {
        bool result = isCanonical(c1, c2, c3, c4, c5, c6, c7, c8, c9);
        bool all = c1 && c2 && c3 && c4 && c5 && c6 && c7 && c8 && c9;
        assertEq(result, all, "canonical guard is the AND of all nine checks");
    }

    // =========================================================================
    // Native-currency derivation (Deploy.s.sol:76)
    // =========================================================================
    /// @notice NATIVE_CURRENCY = uint32(uint160(NATIVE_TOKEN)). The accounting-context currency must be the low 32 bits
    ///         of the native sentinel address (A.1.4), distinct from the ruleset base currency (ETH = 1). This pins the
    ///         token-keyed currency derivation the canonical terminal check relies on.
    function check_nativeCurrencyDerivation(address token) public pure {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 derived = uint32(uint160(token));
        // The derivation isolates exactly the low 32 bits.
        assert(uint256(derived) == (uint256(uint160(token)) & 0xFFFFFFFF));
    }

    function testFuzz_nativeCurrencyDerivation(address token) public pure {
        // forge-lint: disable-next-line(unsafe-typecast)
        assertEq(uint256(uint32(uint160(token))), uint256(uint160(token)) & 0xFFFFFFFF, "low 32 bits isolated");
    }

    /// @notice The concrete NANA native sentinel (0x...EEEe) yields a specific 32-bit currency, and that currency is
    /// NOT the ETH base-currency id (1). This is the gotcha the canonical terminal check encodes: base currency
    ///         (ETH=1) != accounting-context currency (token-keyed).
    function test_nativeCurrencyIsNotEthBaseCurrency() public pure {
        address nativeToken = 0x000000000000000000000000000000000000EEEe;
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 nativeCurrency = uint32(uint160(nativeToken));
        assertEq(nativeCurrency, 0x0000EEEe, "native currency is low 32 bits of the sentinel");
        assertTrue(nativeCurrency != 1, "native accounting currency differs from ETH base-currency id (1)");
    }
}
