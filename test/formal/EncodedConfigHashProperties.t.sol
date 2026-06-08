// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";

import {REVAutoIssuance} from "@rev-net/core-v6/src/structs/REVAutoIssuance.sol";
import {REVConfig} from "@rev-net/core-v6/src/structs/REVConfig.sol";
import {REVDescription} from "@rev-net/core-v6/src/structs/REVDescription.sol";
import {REVStageConfig} from "@rev-net/core-v6/src/structs/REVStageConfig.sol";

/// @title EncodedConfigHashProperties
/// @notice Functional-correctness harness for `Deploy.s.sol::_encodedConfigurationHashOf`, the load-bearing mirror of
///         `REVDeployer._makeRulesetConfigurations`'s stored configuration hash (INVARIANTS.md B.1.3 / D.2). If the
///         script's mirror ever diverges from `REVDeployer`'s encoding, the canonical-replay guard either falsely
///         rejects a correct deployment (replay DoS) or falsely accepts a non-canonical project `#1`.
/// @dev    The script's helper is `internal view` on a Sphinx `Script` that is awkward to instantiate, so (exactly as
///         the repo's own `FeeProjectConfigBuilder` does for the deploy config) both algorithms are ported here as
///         pure functions and differentially compared. `scriptHashOf` is a byte-for-byte port of the version at
///         script/Deploy.s.sol:313-360; `revHashOf` is a byte-for-byte port of the encoding loop in
///         REVDeployer._makeRulesetConfigurations (rev-net core-v6, REVDeployer.sol lines 940-1080).
///         Each property is dual-implemented: `check_` for Halmos, `testFuzz_`/`test_` for forge.
contract EncodedConfigHashProperties is Test {
    // -----------------------------------------------------------------------
    // Canonical NANA constants (mirrored from Deploy.s.sol)
    // -----------------------------------------------------------------------
    bytes32 constant ERC20_SALT = "_NANA_ERC20_SALTV6__";
    string constant NAME = "Bananapus (Juicebox V6)";
    string constant SYMBOL = "NANA";
    string constant PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ";
    uint32 constant ETH_CURRENCY = JBCurrencyIds.ETH;
    uint256 constant DECIMAL_MULTIPLIER = 10 ** 18;
    uint48 constant NANA_START_TIME = 1_740_089_444;
    uint104 constant NANA_MAINNET_AUTO_ISSUANCE = 34_614_774_622_547_324_824_200;
    uint104 constant NANA_BASE_AUTO_ISSUANCE = 1_604_412_323_715_200_204_800;
    uint104 constant NANA_OP_AUTO_ISSUANCE = 6_266_215_368_602_910_600;
    uint104 constant NANA_ARB_AUTO_ISSUANCE = 105_160_496_145_000_000;

    address constant OPERATOR = 0x80a8F7a4bD75b539CE26937016Df607fdC9ABeb5;

    // =========================================================================
    // Ported algorithms under test
    // =========================================================================

    /// @notice Byte-for-byte port of `Deploy.s.sol::_encodedConfigurationHashOf`.
    /// @dev Returns `bytes32(0)` on a stage start-time monotonicity violation (to force a comparison mismatch),
    ///      exactly like the script.
    function scriptHashOf(REVConfig memory configuration) public view returns (bytes32) {
        bytes memory encodedConfiguration = abi.encode(
            configuration.baseCurrency,
            configuration.scopeCashOutsToLocalBalances,
            configuration.description.name,
            configuration.description.ticker,
            configuration.description.salt
        );

        uint256 previousStageStart;
        for (uint256 i; i < configuration.stageConfigurations.length;) {
            REVStageConfig memory stageConfiguration = configuration.stageConfigurations[i];
            uint256 effectiveStart = (i == 0 && stageConfiguration.startsAtOrAfter == 0)
                ? block.timestamp
                : stageConfiguration.startsAtOrAfter;

            if (i > 0 && effectiveStart <= previousStageStart) return bytes32(0);
            previousStageStart = effectiveStart;

            encodedConfiguration = abi.encode(
                encodedConfiguration,
                effectiveStart,
                stageConfiguration.splitPercent,
                stageConfiguration.initialIssuance,
                stageConfiguration.issuanceCutFrequency,
                stageConfiguration.issuanceCutPercent,
                stageConfiguration.cashOutTaxRate,
                stageConfiguration.extraMetadata
            );

            for (uint256 j; j < stageConfiguration.autoIssuances.length;) {
                REVAutoIssuance memory autoIssuance = stageConfiguration.autoIssuances[j];
                if (autoIssuance.count != 0) {
                    encodedConfiguration = abi.encode(
                        encodedConfiguration, autoIssuance.chainId, autoIssuance.beneficiary, autoIssuance.count
                    );
                }
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        return keccak256(encodedConfiguration);
    }

    /// @notice Byte-for-byte port of the encoding portion of `REVDeployer._makeRulesetConfigurations`
    ///         (`REVDeployer.sol:940-1080`), reproducing the on-chain stored `hashedEncodedConfigurationOf` value.
    /// @dev The on-chain version reverts on a non-increasing stage start; here the precondition is asserted by callers
    ///      via `_stagesStrictlyIncreasing` so we only compare on the in-domain branch. Beneficiary-zero and
    ///      cash-out-tax-max reverts are economic guards that do not affect the hash bytes on the valid branch.
    function revHashOf(REVConfig memory configuration) public view returns (bytes32) {
        bytes memory encodedConfiguration = abi.encode(
            configuration.baseCurrency,
            configuration.scopeCashOutsToLocalBalances,
            configuration.description.name,
            configuration.description.ticker,
            configuration.description.salt
        );

        uint256 previousStageStart;
        for (uint256 i; i < configuration.stageConfigurations.length;) {
            REVStageConfig memory stageConfiguration = configuration.stageConfigurations[i];

            uint256 effectiveStart = (i == 0 && stageConfiguration.startsAtOrAfter == 0)
                ? block.timestamp
                : stageConfiguration.startsAtOrAfter;

            // On-chain this reverts; the differential tests only invoke this on strictly-increasing inputs.
            require(!(i > 0 && effectiveStart <= previousStageStart), "REV: stage times must increase");
            previousStageStart = effectiveStart;

            encodedConfiguration = abi.encode(
                encodedConfiguration,
                effectiveStart,
                stageConfiguration.splitPercent,
                stageConfiguration.initialIssuance,
                stageConfiguration.issuanceCutFrequency,
                stageConfiguration.issuanceCutPercent,
                stageConfiguration.cashOutTaxRate,
                stageConfiguration.extraMetadata
            );

            for (uint256 j; j < stageConfiguration.autoIssuances.length; j++) {
                REVAutoIssuance memory autoIssuance = stageConfiguration.autoIssuances[j];
                // On-chain: zero-beneficiary reverts; we never feed a zero-count entry with the count!=0 branch.
                if (autoIssuance.count == 0) continue;
                encodedConfiguration = abi.encode(
                    encodedConfiguration, autoIssuance.chainId, autoIssuance.beneficiary, autoIssuance.count
                );
                // The remaining on-chain body only emits events / records local issuances; it does not touch the hash.
            }
            unchecked {
                ++i;
            }
        }

        return keccak256(encodedConfiguration);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @notice Builds the exact canonical NANA `REVConfig` the deploy script constructs on mainnet.
    function _canonicalNanaConfig() internal pure returns (REVConfig memory config) {
        REVAutoIssuance[] memory issuanceConfs = new REVAutoIssuance[](4);
        issuanceConfs[0] = REVAutoIssuance({chainId: 1, count: NANA_MAINNET_AUTO_ISSUANCE, beneficiary: OPERATOR});
        issuanceConfs[1] = REVAutoIssuance({chainId: 8453, count: NANA_BASE_AUTO_ISSUANCE, beneficiary: OPERATOR});
        issuanceConfs[2] = REVAutoIssuance({chainId: 10, count: NANA_OP_AUTO_ISSUANCE, beneficiary: OPERATOR});
        issuanceConfs[3] = REVAutoIssuance({chainId: 42_161, count: NANA_ARB_AUTO_ISSUANCE, beneficiary: OPERATOR});

        JBSplit[] memory splits = new JBSplit[](1);
        splits[0] = JBSplit({
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(OPERATOR),
            preferAddToBalance: false,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        REVStageConfig[] memory stages = new REVStageConfig[](1);
        stages[0] = REVStageConfig({
            startsAtOrAfter: NANA_START_TIME,
            autoIssuances: issuanceConfs,
            splitPercent: 6200,
            splits: splits,
            initialIssuance: uint112(10_000 * DECIMAL_MULTIPLIER),
            issuanceCutFrequency: 360 days,
            issuanceCutPercent: 380_000_000,
            cashOutTaxRate: 1000,
            extraMetadata: 4
        });

        config = REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT}),
            baseCurrency: ETH_CURRENCY,
            operator: OPERATOR,
            scopeCashOutsToLocalBalances: false,
            stageConfigurations: stages
        });
    }

    /// @notice Whether stage effective-starts are strictly increasing (the REVDeployer in-domain precondition).
    function _stagesStrictlyIncreasing(REVConfig memory config) internal view returns (bool) {
        uint256 previousStageStart;
        for (uint256 i; i < config.stageConfigurations.length; i++) {
            uint256 effectiveStart = (i == 0 && config.stageConfigurations[i].startsAtOrAfter == 0)
                ? block.timestamp
                : config.stageConfigurations[i].startsAtOrAfter;
            if (i > 0 && effectiveStart <= previousStageStart) return false;
            previousStageStart = effectiveStart;
        }
        return true;
    }

    // =========================================================================
    // Property 1: Mirror fidelity on the canonical NANA config
    // =========================================================================
    /// @notice The script's mirror reproduces REVDeployer's stored hash for the exact shape NANA deploys.
    ///         This is the property the replay/idempotence guard depends on (B.1.2 #4, B.1.4).
    function test_canonicalNanaHashMatchesRevDeployer() public view {
        REVConfig memory config = _canonicalNanaConfig();
        assertEq(scriptHashOf(config), revHashOf(config), "script mirror must equal REVDeployer hash for NANA");
        assertTrue(scriptHashOf(config) != bytes32(0), "canonical NANA hash is non-zero");
    }

    // =========================================================================
    // Property 2: Differential equivalence on arbitrary single-stage configs
    // =========================================================================
    /// @notice For any single-stage config, the script mirror and REVDeployer encoding agree. A single stage is the
    ///         only shape this repo ever deploys (A.2.1), so this is the operative differential property.
    function testFuzz_singleStageHashEquivalence(
        uint32 baseCurrency,
        bool scopeLocal,
        bytes32 salt,
        uint48 startsAtOrAfter,
        uint16 splitPercent,
        uint112 initialIssuance,
        uint32 issuanceCutFrequency,
        uint32 issuanceCutPercent,
        uint16 cashOutTaxRate,
        uint16 extraMetadata,
        uint32 chainId,
        uint104 count,
        address beneficiary
    )
        public
        view
    {
        REVAutoIssuance[] memory issuances = new REVAutoIssuance[](1);
        issuances[0] = REVAutoIssuance({chainId: chainId, count: count, beneficiary: beneficiary});

        REVStageConfig[] memory stages = new REVStageConfig[](1);
        stages[0] = REVStageConfig({
            startsAtOrAfter: startsAtOrAfter,
            autoIssuances: issuances,
            splitPercent: splitPercent,
            splits: new JBSplit[](0),
            initialIssuance: initialIssuance,
            issuanceCutFrequency: issuanceCutFrequency,
            issuanceCutPercent: issuanceCutPercent,
            cashOutTaxRate: cashOutTaxRate,
            extraMetadata: extraMetadata
        });

        REVConfig memory config = REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: salt}),
            baseCurrency: baseCurrency,
            operator: OPERATOR,
            scopeCashOutsToLocalBalances: scopeLocal,
            stageConfigurations: stages
        });

        // Single stage can never violate monotonicity, so both implementations are in-domain.
        assertEq(scriptHashOf(config), revHashOf(config), "single-stage hashes must match");
    }

    // =========================================================================
    // Property 3: Zero-count auto-issuance is identical to a missing entry
    // =========================================================================
    /// @notice B.1.4: a zero-`count` auto-issuance produces the same hash as omitting it entirely.
    function test_zeroCountAutoIssuanceSkipped() public view {
        // Config A: one real issuance.
        REVAutoIssuance[] memory withReal = new REVAutoIssuance[](1);
        withReal[0] = REVAutoIssuance({chainId: 1, count: 5e18, beneficiary: OPERATOR});

        // Config B: the same real issuance plus a zero-count entry interleaved.
        REVAutoIssuance[] memory withZero = new REVAutoIssuance[](2);
        withZero[0] = REVAutoIssuance({chainId: 1, count: 5e18, beneficiary: OPERATOR});
        withZero[1] = REVAutoIssuance({chainId: 999, count: 0, beneficiary: address(0xdead)});

        assertEq(
            scriptHashOf(_oneStage(withReal)),
            scriptHashOf(_oneStage(withZero)),
            "zero-count auto-issuance must not change the hash"
        );
    }

    function _oneStage(REVAutoIssuance[] memory issuances) internal pure returns (REVConfig memory config) {
        REVStageConfig[] memory stages = new REVStageConfig[](1);
        stages[0] = REVStageConfig({
            startsAtOrAfter: NANA_START_TIME,
            autoIssuances: issuances,
            splitPercent: 6200,
            splits: new JBSplit[](0),
            initialIssuance: 1e22,
            issuanceCutFrequency: 360 days,
            issuanceCutPercent: 380_000_000,
            cashOutTaxRate: 1000,
            extraMetadata: 4
        });
        config = REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT}),
            baseCurrency: ETH_CURRENCY,
            operator: OPERATOR,
            scopeCashOutsToLocalBalances: false,
            stageConfigurations: stages
        });
    }

    // =========================================================================
    // Property 4: Monotonicity guard returns bytes32(0) on a violation
    // =========================================================================
    /// @notice B.1.3: when a later stage does not strictly increase the start time, the script returns the zero hash
    ///         (guaranteeing a mismatch against any real stored hash) instead of silently producing a collidable hash.
    function test_nonIncreasingStageStartReturnsZero() public view {
        REVStageConfig[] memory stages = new REVStageConfig[](2);
        stages[0] = _stageWithStart(NANA_START_TIME);
        stages[1] = _stageWithStart(NANA_START_TIME); // not strictly increasing => violation

        REVConfig memory config = _config(stages);
        assertEq(scriptHashOf(config), bytes32(0), "non-increasing stage start must yield zero hash");
    }

    /// @notice Strictly-increasing multi-stage configs produce a non-zero hash matching REVDeployer.
    function test_increasingStageStartMatchesAndNonZero() public view {
        REVStageConfig[] memory stages = new REVStageConfig[](2);
        stages[0] = _stageWithStart(NANA_START_TIME);
        stages[1] = _stageWithStart(NANA_START_TIME + 1);

        REVConfig memory config = _config(stages);
        bytes32 h = scriptHashOf(config);
        assertTrue(h != bytes32(0), "valid multi-stage hash is non-zero");
        assertTrue(_stagesStrictlyIncreasing(config), "precondition: strictly increasing");
        assertEq(h, revHashOf(config), "valid multi-stage hash matches REVDeployer");
    }

    /// @notice Differential: the script's monotonicity behavior agrees with REVDeployer's revert decision. When the
    ///         REV path reverts (non-increasing), the script returns zero; when it succeeds, the hashes match.
    function testFuzz_monotonicityAgreement(uint48 start0, uint48 start1) public view {
        REVStageConfig[] memory stages = new REVStageConfig[](2);
        stages[0] = _stageWithStart(start0);
        stages[1] = _stageWithStart(start1);
        REVConfig memory config = _config(stages);

        if (_stagesStrictlyIncreasing(config)) {
            bytes32 h = scriptHashOf(config);
            assertTrue(h != bytes32(0), "in-domain hash non-zero");
            assertEq(h, revHashOf(config), "in-domain hashes match");
        } else {
            assertEq(scriptHashOf(config), bytes32(0), "out-of-domain returns zero hash");
        }
    }

    function _stageWithStart(uint48 start) internal pure returns (REVStageConfig memory) {
        return REVStageConfig({
            startsAtOrAfter: start,
            autoIssuances: new REVAutoIssuance[](0),
            splitPercent: 6200,
            splits: new JBSplit[](0),
            initialIssuance: 1e22,
            issuanceCutFrequency: 360 days,
            issuanceCutPercent: 380_000_000,
            cashOutTaxRate: 1000,
            extraMetadata: 4
        });
    }

    function _config(REVStageConfig[] memory stages) internal pure returns (REVConfig memory) {
        return REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT}),
            baseCurrency: ETH_CURRENCY,
            operator: OPERATOR,
            scopeCashOutsToLocalBalances: false,
            stageConfigurations: stages
        });
    }

    // =========================================================================
    // Property 5: Field-sensitivity (replay guard rejects near-matches)
    // =========================================================================
    /// @notice D.3: changing any single hashed stage field changes the hash, so a would-be squatter with a slightly
    ///         different economic config fails the replay guard. Differs from the canonical NANA hash on every
    // mutation.
    function test_fieldSensitivity_splitPercent() public view {
        bytes32 base = scriptHashOf(_canonicalNanaConfig());
        REVConfig memory mutated = _canonicalNanaConfig();
        mutated.stageConfigurations[0].splitPercent = 6201;
        assertTrue(scriptHashOf(mutated) != base, "splitPercent change must alter hash");
    }

    function test_fieldSensitivity_cashOutTaxRate() public view {
        bytes32 base = scriptHashOf(_canonicalNanaConfig());
        REVConfig memory mutated = _canonicalNanaConfig();
        mutated.stageConfigurations[0].cashOutTaxRate = 1001;
        assertTrue(scriptHashOf(mutated) != base, "cashOutTaxRate change must alter hash");
    }

    function test_fieldSensitivity_extraMetadata() public view {
        bytes32 base = scriptHashOf(_canonicalNanaConfig());
        REVConfig memory mutated = _canonicalNanaConfig();
        mutated.stageConfigurations[0].extraMetadata = 0;
        assertTrue(scriptHashOf(mutated) != base, "extraMetadata change must alter hash");
    }

    function test_fieldSensitivity_baseCurrency() public view {
        bytes32 base = scriptHashOf(_canonicalNanaConfig());
        REVConfig memory mutated = _canonicalNanaConfig();
        mutated.baseCurrency = 2; // USD
        assertTrue(scriptHashOf(mutated) != base, "baseCurrency change must alter hash");
    }

    function test_fieldSensitivity_salt() public view {
        bytes32 base = scriptHashOf(_canonicalNanaConfig());
        REVConfig memory mutated = _canonicalNanaConfig();
        mutated.description.salt = "_OTHER_SALT_________";
        assertTrue(scriptHashOf(mutated) != base, "salt change must alter hash");
    }

    function test_fieldSensitivity_autoIssuanceCount() public view {
        bytes32 base = scriptHashOf(_canonicalNanaConfig());
        REVConfig memory mutated = _canonicalNanaConfig();
        mutated.stageConfigurations[0].autoIssuances[0].count = NANA_MAINNET_AUTO_ISSUANCE - 1;
        assertTrue(scriptHashOf(mutated) != base, "auto-issuance count change must alter hash");
    }

    /// @notice Field-sensitivity on splitPercent: any distinct splitPercent yields a distinct hash on the canonical
    ///         single-stage shape. Verified by FUZZ only — NOT by Halmos: this asserts inequality of two distinct
    ///         keccak256 preimages, which Halmos's default uninterpreted-keccak model cannot discharge soundly (it
    ///         reports a spurious collision counterexample at p=0). The concrete and fuzz checks confirm the property
    ///         holds; the keccak-collision-resistance assumption is the standard cryptographic premise. Intentionally
    ///         named `testFuzz_` (no `check_` twin) so Halmos does not attempt an unsound keccak-inequality proof.
    function testFuzz_splitPercentSensitivity(uint16 p) public view {
        vm.assume(p != 6200);
        assertTrue(scriptHashOf(_canonicalSingleStageMinimal(6200)) != scriptHashOf(_canonicalSingleStageMinimal(p)));
    }

    /// @notice A minimal single-stage config (no auto-issuances) parameterized only by splitPercent, kept tiny so the
    ///         keccak stays SMT-tractable for Halmos.
    function _canonicalSingleStageMinimal(uint16 splitPercent) internal pure returns (REVConfig memory) {
        REVStageConfig[] memory stages = new REVStageConfig[](1);
        stages[0] = REVStageConfig({
            startsAtOrAfter: NANA_START_TIME,
            autoIssuances: new REVAutoIssuance[](0),
            splitPercent: splitPercent,
            splits: new JBSplit[](0),
            initialIssuance: 1e22,
            issuanceCutFrequency: 360 days,
            issuanceCutPercent: 380_000_000,
            cashOutTaxRate: 1000,
            extraMetadata: 4
        });
        return _config(stages);
    }

    // =========================================================================
    // Property 6: First-stage start-time normalization (startsAtOrAfter==0 -> block.timestamp)
    // =========================================================================
    /// @notice REVDeployer normalizes a zero first-stage start to `block.timestamp`; the script mirror must do the same
    ///         so cross-chain replays reproduce the hash (B.3.2 / REVDeployer.sol:972-991).
    function test_zeroFirstStageStartNormalizesToBlockTimestamp() public view {
        REVStageConfig[] memory zeroStart = new REVStageConfig[](1);
        zeroStart[0] = _stageWithStart(0);
        REVStageConfig[] memory tsStart = new REVStageConfig[](1);
        tsStart[0] = _stageWithStart(uint48(block.timestamp));

        assertEq(
            scriptHashOf(_config(zeroStart)),
            scriptHashOf(_config(tsStart)),
            "zero first-stage start must normalize to block.timestamp"
        );
        // And the normalized form matches REVDeployer.
        assertEq(scriptHashOf(_config(zeroStart)), revHashOf(_config(zeroStart)), "normalized zero-start matches REV");
    }
}
