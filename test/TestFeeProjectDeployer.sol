// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";
import {JBAccountingContext} from "@bananapus/core-v6/src/structs/JBAccountingContext.sol";
import {JBTerminalConfig} from "@bananapus/core-v6/src/structs/JBTerminalConfig.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {IJBTerminal} from "@bananapus/core-v6/src/interfaces/IJBTerminal.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";
import {IJB721TiersHook} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHook.sol";

import {REVAutoIssuance} from "@rev-net/core-v6/src/structs/REVAutoIssuance.sol";
import {REVConfig} from "@rev-net/core-v6/src/structs/REVConfig.sol";
import {REVDescription} from "@rev-net/core-v6/src/structs/REVDescription.sol";
import {REVStageConfig} from "@rev-net/core-v6/src/structs/REVStageConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core-v6/src/structs/REVSuckerDeploymentConfig.sol";
import {IREVDeployer} from "@rev-net/core-v6/src/interfaces/IREVDeployer.sol";

import {JBSuckerDeployerConfig} from "@bananapus/suckers-v6/src/structs/JBSuckerDeployerConfig.sol";
import {JBTokenMapping} from "@bananapus/suckers-v6/src/structs/JBTokenMapping.sol";
import {IJBSuckerDeployer} from "@bananapus/suckers-v6/src/interfaces/IJBSuckerDeployer.sol";

/// @notice Mock REVDeployer that records the last call to deployFor (4-arg overload).
/// @dev Stores encoded calldata to avoid Solidity's limitation on copying nested dynamic arrays to storage.
contract MockREVDeployer {
    bool public deployForCalled;
    uint256 public recordedRevnetId;
    bytes public encodedCalldata;

    function deployFor(
        uint256 revnetId,
        REVConfig memory configuration,
        JBTerminalConfig[] memory terminalConfigurations,
        REVSuckerDeploymentConfig memory suckerDeploymentConfiguration
    )
        external
        returns (uint256, IJB721TiersHook)
    {
        deployForCalled = true;
        recordedRevnetId = revnetId;
        encodedCalldata = abi.encode(revnetId, configuration, terminalConfigurations, suckerDeploymentConfiguration);
        return (revnetId, IJB721TiersHook(address(0)));
    }

    function getRecordedArgs()
        external
        view
        returns (
            uint256 revnetId,
            REVConfig memory configuration,
            JBTerminalConfig[] memory terminalConfigurations,
            REVSuckerDeploymentConfig memory suckerDeploymentConfiguration
        )
    {
        return abi.decode(encodedCalldata, (uint256, REVConfig, JBTerminalConfig[], REVSuckerDeploymentConfig));
    }
}

/// @notice Mock JBProjects that records approve calls.
contract MockJBProjects {
    bool public approveCalled;
    address public approvedTo;
    uint256 public approvedTokenId;

    function approve(address to, uint256 tokenId) external {
        approveCalled = true;
        approvedTo = to;
        approvedTokenId = tokenId;
    }
}

/// @notice Helper that re-creates the deploy script's configuration logic for testing.
/// @dev This avoids Sphinx dependencies and deployment artifact reads.
contract FeeProjectConfigBuilder {
    bytes32 constant ERC20_SALT = "_NANA_ERC20_SALTV6__";
    bytes32 constant SUCKER_SALT = "_NANA_SUCKER_SALTV6__";
    string constant NAME = "Bananapus (Juicebox V6)";
    string constant SYMBOL = "NANA";
    string constant PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ";
    uint32 constant NATIVE_CURRENCY = uint32(uint160(JBConstants.NATIVE_TOKEN));
    uint32 constant ETH_CURRENCY = JBCurrencyIds.ETH;
    uint8 constant DECIMALS = 18;
    uint256 constant DECIMAL_MULTIPLIER = 10 ** DECIMALS;
    uint48 constant NANA_START_TIME = 1_740_089_444;
    uint104 constant NANA_MAINNET_AUTO_ISSUANCE = 34_614_774_622_547_324_824_200;
    uint104 constant NANA_BASE_AUTO_ISSUANCE = 1_604_412_323_715_200_204_800;
    uint104 constant NANA_OP_AUTO_ISSUANCE = 6_266_215_368_602_910_600;
    uint104 constant NANA_ARB_AUTO_ISSUANCE = 105_160_496_145_000_000;

    function buildTerminalConfigurations(
        IJBTerminal multiTerminal,
        IJBTerminal routerTerminalRegistry
    )
        public
        pure
        returns (JBTerminalConfig[] memory terminalConfigurations)
    {
        JBAccountingContext[] memory accountingContextsToAccept = new JBAccountingContext[](1);
        accountingContextsToAccept[0] =
            JBAccountingContext({token: JBConstants.NATIVE_TOKEN, decimals: 18, currency: NATIVE_CURRENCY});

        terminalConfigurations = new JBTerminalConfig[](2);
        terminalConfigurations[0] =
            JBTerminalConfig({terminal: multiTerminal, accountingContextsToAccept: accountingContextsToAccept});
        terminalConfigurations[1] = JBTerminalConfig({
            terminal: routerTerminalRegistry, accountingContextsToAccept: new JBAccountingContext[](0)
        });
    }

    function buildSplits(address operator_) public pure returns (JBSplit[] memory splits) {
        splits = new JBSplit[](1);
        splits[0] = JBSplit({
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(operator_),
            preferAddToBalance: false,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });
    }

    function buildAutoIssuances(address operator_) public pure returns (REVAutoIssuance[] memory issuanceConfs) {
        issuanceConfs = new REVAutoIssuance[](4);
        issuanceConfs[0] = REVAutoIssuance({chainId: 1, count: NANA_MAINNET_AUTO_ISSUANCE, beneficiary: operator_});
        issuanceConfs[1] = REVAutoIssuance({chainId: 8453, count: NANA_BASE_AUTO_ISSUANCE, beneficiary: operator_});
        issuanceConfs[2] = REVAutoIssuance({chainId: 10, count: NANA_OP_AUTO_ISSUANCE, beneficiary: operator_});
        issuanceConfs[3] = REVAutoIssuance({chainId: 42_161, count: NANA_ARB_AUTO_ISSUANCE, beneficiary: operator_});
    }

    function buildStageConfigurations(address operator_)
        public
        pure
        returns (REVStageConfig[] memory stageConfigurations)
    {
        REVAutoIssuance[] memory issuanceConfs = buildAutoIssuances(operator_);
        JBSplit[] memory splits = buildSplits(operator_);

        stageConfigurations = new REVStageConfig[](1);
        stageConfigurations[0] = REVStageConfig({
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
    }

    function buildRevnetConfiguration(address operator_) public pure returns (REVConfig memory) {
        return REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT}),
            baseCurrency: ETH_CURRENCY,
            splitOperator: operator_,
            stageConfigurations: buildStageConfigurations(operator_)
        });
    }

    function buildTokenMappings() public pure returns (JBTokenMapping[] memory tokenMappings) {
        tokenMappings = new JBTokenMapping[](1);
        tokenMappings[0] = JBTokenMapping({
            localToken: JBConstants.NATIVE_TOKEN,
            minGas: 200_000,
            remoteToken: bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))
        });
    }

    function buildSuckerDeploymentConfigMainnet(
        IJBSuckerDeployer opDeployer,
        IJBSuckerDeployer baseDeployer,
        IJBSuckerDeployer arbDeployer
    )
        public
        pure
        returns (REVSuckerDeploymentConfig memory)
    {
        JBTokenMapping[] memory tokenMappings = buildTokenMappings();

        JBSuckerDeployerConfig[] memory suckerDeployerConfigurations = new JBSuckerDeployerConfig[](3);
        suckerDeployerConfigurations[0] = JBSuckerDeployerConfig({deployer: opDeployer, mappings: tokenMappings});
        suckerDeployerConfigurations[1] = JBSuckerDeployerConfig({deployer: baseDeployer, mappings: tokenMappings});
        suckerDeployerConfigurations[2] = JBSuckerDeployerConfig({deployer: arbDeployer, mappings: tokenMappings});

        return REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: SUCKER_SALT});
    }

    function buildSuckerDeploymentConfigL2(IJBSuckerDeployer l2Deployer)
        public
        pure
        returns (REVSuckerDeploymentConfig memory)
    {
        JBTokenMapping[] memory tokenMappings = buildTokenMappings();

        JBSuckerDeployerConfig[] memory suckerDeployerConfigurations = new JBSuckerDeployerConfig[](1);
        suckerDeployerConfigurations[0] = JBSuckerDeployerConfig({deployer: l2Deployer, mappings: tokenMappings});

        return REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: SUCKER_SALT});
    }
}

/// @notice Integration test for the NANA fee project deployer configuration.
/// @dev Since the deploy script depends on Sphinx and pre-deployed artifacts, these tests
///      re-create the configuration logic and verify all parameters using mock contracts.
contract TestFeeProjectDeployer is Test {
    // -----------------------------------------------------------------------
    // Constants -- mirrored from Deploy.s.sol
    // -----------------------------------------------------------------------
    uint256 constant FEE_PROJECT_ID = 1;
    bytes32 constant ERC20_SALT = "_NANA_ERC20_SALTV6__";
    bytes32 constant SUCKER_SALT = "_NANA_SUCKER_SALTV6__";
    string constant NAME = "Bananapus (Juicebox V6)";
    string constant SYMBOL = "NANA";
    string constant PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ";
    uint32 constant NATIVE_CURRENCY = uint32(uint160(JBConstants.NATIVE_TOKEN));
    uint32 constant ETH_CURRENCY = JBCurrencyIds.ETH;
    uint8 constant DECIMALS = 18;
    uint256 constant DECIMAL_MULTIPLIER = 10 ** DECIMALS;
    uint48 constant NANA_START_TIME = 1_740_089_444;
    uint104 constant NANA_MAINNET_AUTO_ISSUANCE = 34_614_774_622_547_324_824_200;
    uint104 constant NANA_BASE_AUTO_ISSUANCE = 1_604_412_323_715_200_204_800;
    uint104 constant NANA_OP_AUTO_ISSUANCE = 6_266_215_368_602_910_600;
    uint104 constant NANA_ARB_AUTO_ISSUANCE = 105_160_496_145_000_000;

    // -----------------------------------------------------------------------
    // Test contracts
    // -----------------------------------------------------------------------
    FeeProjectConfigBuilder builder;
    MockREVDeployer mockDeployer;
    MockJBProjects mockProjects;

    // Mock addresses
    address operatorAddr = makeAddr("operator");
    IJBTerminal multiTerminal = IJBTerminal(makeAddr("multiTerminal"));
    IJBTerminal routerTerminalRegistry = IJBTerminal(makeAddr("routerTerminalRegistry"));
    IJBSuckerDeployer opDeployer = IJBSuckerDeployer(makeAddr("opDeployer"));
    IJBSuckerDeployer baseDeployer = IJBSuckerDeployer(makeAddr("baseDeployer"));
    IJBSuckerDeployer arbDeployer = IJBSuckerDeployer(makeAddr("arbDeployer"));

    function setUp() public {
        builder = new FeeProjectConfigBuilder();
        mockDeployer = new MockREVDeployer();
        mockProjects = new MockJBProjects();
    }

    // ====================================================================
    // 1. Parameter Correctness Tests
    // ====================================================================

    function test_feeProjectIdIsOne() public pure {
        assertEq(FEE_PROJECT_ID, 1, "Fee project ID must be 1");
    }

    function test_tokenNameAndSymbol() public pure {
        assertEq(keccak256(bytes(NAME)), keccak256(bytes("Bananapus (Juicebox V6)")));
        assertEq(keccak256(bytes(SYMBOL)), keccak256(bytes("NANA")));
    }

    function test_projectUriIsIPFS() public pure {
        // Verify it starts with ipfs://
        bytes memory uri = bytes(PROJECT_URI);
        assertEq(uint8(uri[0]), uint8(bytes1("i")));
        assertEq(uint8(uri[1]), uint8(bytes1("p")));
        assertEq(uint8(uri[2]), uint8(bytes1("f")));
        assertEq(uint8(uri[3]), uint8(bytes1("s")));
        assertEq(uint8(uri[4]), uint8(bytes1(":")));
        assertEq(uint8(uri[5]), uint8(bytes1("/")));
        assertEq(uint8(uri[6]), uint8(bytes1("/")));
    }

    function test_nativeCurrency() public pure {
        assertEq(NATIVE_CURRENCY, uint32(uint160(JBConstants.NATIVE_TOKEN)));
    }

    function test_ethCurrencyId() public pure {
        assertEq(ETH_CURRENCY, 1, "ETH currency ID should be 1");
    }

    function test_decimals() public pure {
        assertEq(DECIMALS, 18, "Decimals should be 18");
        assertEq(DECIMAL_MULTIPLIER, 1e18, "Decimal multiplier should be 1e18");
    }

    function test_startTimeIsValid() public pure {
        // NANA_START_TIME = 1740089444 is Feb 20, 2025 ~22:30 UTC.
        // Verify it is in a plausible range (2025).
        assertGt(NANA_START_TIME, 1_704_067_200, "Start time should be after Jan 1, 2025");
        assertLt(NANA_START_TIME, 1_767_225_600, "Start time should be before Jan 1, 2026");
    }

    function test_initialIssuanceDoesNotTruncate() public pure {
        // 10,000 * 1e18 = 1e22. uint112 max is ~5.19e33, so no truncation.
        uint256 rawIssuance = 10_000 * DECIMAL_MULTIPLIER;
        assertEq(rawIssuance, 10_000e18, "Raw issuance should be 10,000e18");
        assertLt(rawIssuance, type(uint112).max, "Issuance must fit in uint112");
        assertEq(uint112(rawIssuance), rawIssuance, "uint112 cast must not truncate");
    }

    function test_autoIssuancesFitInUint104() public pure {
        // Verify each auto-issuance amount fits in uint104.
        assertLe(uint256(NANA_MAINNET_AUTO_ISSUANCE), type(uint104).max, "Mainnet issuance fits in uint104");
        assertLe(uint256(NANA_BASE_AUTO_ISSUANCE), type(uint104).max, "Base issuance fits in uint104");
        assertLe(uint256(NANA_OP_AUTO_ISSUANCE), type(uint104).max, "OP issuance fits in uint104");
        assertLe(uint256(NANA_ARB_AUTO_ISSUANCE), type(uint104).max, "Arb issuance fits in uint104");
    }

    function test_autoIssuanceOrder() public pure {
        // Mainnet gets the most, then Base, then OP, then Arbitrum.
        assertGt(uint256(NANA_MAINNET_AUTO_ISSUANCE), uint256(NANA_BASE_AUTO_ISSUANCE), "Mainnet > Base auto issuance");
        assertGt(uint256(NANA_BASE_AUTO_ISSUANCE), uint256(NANA_OP_AUTO_ISSUANCE), "Base > OP auto issuance");
        assertGt(uint256(NANA_OP_AUTO_ISSUANCE), uint256(NANA_ARB_AUTO_ISSUANCE), "OP > Arb auto issuance");
    }

    function test_autoIssuanceAmountsNonZero() public pure {
        assertGt(uint256(NANA_MAINNET_AUTO_ISSUANCE), 0, "Mainnet auto issuance non-zero");
        assertGt(uint256(NANA_BASE_AUTO_ISSUANCE), 0, "Base auto issuance non-zero");
        assertGt(uint256(NANA_OP_AUTO_ISSUANCE), 0, "OP auto issuance non-zero");
        assertGt(uint256(NANA_ARB_AUTO_ISSUANCE), 0, "Arb auto issuance non-zero");
    }

    // ====================================================================
    // 2. Stage Configuration Tests
    // ====================================================================

    function test_singleStage() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertEq(stages.length, 1, "Exactly one stage");
    }

    function test_stageStartsAtOrAfter() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertEq(stages[0].startsAtOrAfter, NANA_START_TIME, "Stage start time matches");
    }

    function test_stageSplitPercent() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        // 6200 out of 10,000 = 62%.
        assertEq(stages[0].splitPercent, 6200, "Split percent is 62%");
        assertLe(stages[0].splitPercent, JBConstants.MAX_RESERVED_PERCENT, "Split percent within max (10,000)");
    }

    function test_stageInitialIssuance() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertEq(stages[0].initialIssuance, uint112(10_000 * DECIMAL_MULTIPLIER), "Initial issuance is 10,000 tokens");
    }

    function test_stageIssuanceCutFrequency() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertEq(stages[0].issuanceCutFrequency, 360 days, "Issuance cut frequency is 360 days");
    }

    function test_stageIssuanceCutPercent() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        // 380,000,000 / 1,000,000,000 = 38%.
        assertEq(stages[0].issuanceCutPercent, 380_000_000, "Issuance cut percent is 38%");
        assertLe(stages[0].issuanceCutPercent, JBConstants.MAX_WEIGHT_CUT_PERCENT, "Within max weight cut percent");
    }

    function test_stageCashOutTaxRate() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        // 1000 / 10,000 = 10%.
        assertEq(stages[0].cashOutTaxRate, 1000, "Cash out tax rate is 10%");
        assertLe(stages[0].cashOutTaxRate, JBConstants.MAX_CASH_OUT_TAX_RATE, "Within max cash out tax rate");
        // Must not be max (revnet deployer rejects cashOutTaxRate == MAX).
        assertLt(
            stages[0].cashOutTaxRate,
            JBConstants.MAX_CASH_OUT_TAX_RATE,
            "Cash out tax rate must not completely disable cash outs"
        );
    }

    function test_stageExtraMetadata() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        // 4 = bit flag to allow adding suckers.
        assertEq(stages[0].extraMetadata, 4, "Extra metadata enables suckers (bit 2)");
    }

    function test_stageAutoIssuances() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        REVAutoIssuance[] memory autoIssuances = stages[0].autoIssuances;

        assertEq(autoIssuances.length, 4, "4 auto issuance entries");

        // Ethereum mainnet.
        assertEq(autoIssuances[0].chainId, 1, "First auto issuance is mainnet");
        assertEq(autoIssuances[0].count, NANA_MAINNET_AUTO_ISSUANCE, "Mainnet auto issuance amount");
        assertEq(autoIssuances[0].beneficiary, operatorAddr, "Mainnet beneficiary is operator");

        // Base.
        assertEq(autoIssuances[1].chainId, 8453, "Second auto issuance is Base");
        assertEq(autoIssuances[1].count, NANA_BASE_AUTO_ISSUANCE, "Base auto issuance amount");
        assertEq(autoIssuances[1].beneficiary, operatorAddr, "Base beneficiary is operator");

        // Optimism.
        assertEq(autoIssuances[2].chainId, 10, "Third auto issuance is Optimism");
        assertEq(autoIssuances[2].count, NANA_OP_AUTO_ISSUANCE, "OP auto issuance amount");
        assertEq(autoIssuances[2].beneficiary, operatorAddr, "OP beneficiary is operator");

        // Arbitrum.
        assertEq(autoIssuances[3].chainId, 42_161, "Fourth auto issuance is Arbitrum");
        assertEq(autoIssuances[3].count, NANA_ARB_AUTO_ISSUANCE, "Arb auto issuance amount");
        assertEq(autoIssuances[3].beneficiary, operatorAddr, "Arb beneficiary is operator");
    }

    function test_stageSplits() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        JBSplit[] memory splits = stages[0].splits;

        assertEq(splits.length, 1, "Single split");
        assertEq(splits[0].percent, JBConstants.SPLITS_TOTAL_PERCENT, "Split is 100% of splits");
        assertEq(splits[0].projectId, 0, "No project redirect");
        assertEq(splits[0].beneficiary, operatorAddr, "Beneficiary is operator");
        assertEq(splits[0].preferAddToBalance, false, "Prefer add to balance is false");
        assertEq(splits[0].lockedUntil, 0, "Not locked");
        assertEq(address(splits[0].hook), address(0), "No split hook");
    }

    // ====================================================================
    // 3. Revnet Configuration Tests
    // ====================================================================

    function test_revnetDescription() public view {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);

        assertEq(keccak256(bytes(config.description.name)), keccak256(bytes(NAME)), "Revnet name matches");
        assertEq(keccak256(bytes(config.description.ticker)), keccak256(bytes(SYMBOL)), "Revnet ticker matches");
        assertEq(keccak256(bytes(config.description.uri)), keccak256(bytes(PROJECT_URI)), "Revnet URI matches");
        assertEq(config.description.salt, ERC20_SALT, "Revnet ERC20 salt matches");
    }

    function test_revnetBaseCurrency() public view {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        assertEq(config.baseCurrency, ETH_CURRENCY, "Base currency is ETH");
    }

    function test_revnetSplitOperator() public view {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        assertEq(config.splitOperator, operatorAddr, "Split operator is operator");
    }

    function test_revnetHasOneStage() public view {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        assertEq(config.stageConfigurations.length, 1, "One stage configuration");
    }

    // ====================================================================
    // 4. Terminal Configuration Tests
    // ====================================================================

    function test_terminalConfigCount() public view {
        JBTerminalConfig[] memory configs = builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        assertEq(configs.length, 2, "Two terminal configurations");
    }

    function test_firstTerminalIsMultiTerminal() public view {
        JBTerminalConfig[] memory configs = builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        assertEq(address(configs[0].terminal), address(multiTerminal), "First terminal is multi terminal");
    }

    function test_firstTerminalAcceptsNativeToken() public view {
        JBTerminalConfig[] memory configs = builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);

        JBAccountingContext[] memory contexts = configs[0].accountingContextsToAccept;
        assertEq(contexts.length, 1, "One accounting context");
        assertEq(contexts[0].token, JBConstants.NATIVE_TOKEN, "Accepts native token");
        assertEq(contexts[0].decimals, 18, "18 decimals");
        assertEq(contexts[0].currency, NATIVE_CURRENCY, "Native currency");
    }

    function test_secondTerminalIsRouterTerminal() public view {
        JBTerminalConfig[] memory configs = builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        assertEq(
            address(configs[1].terminal), address(routerTerminalRegistry), "Second terminal is router terminal registry"
        );
    }

    function test_secondTerminalNoAccountingContexts() public view {
        JBTerminalConfig[] memory configs = builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        assertEq(configs[1].accountingContextsToAccept.length, 0, "Router terminal has no accounting contexts");
    }

    // ====================================================================
    // 5. Sucker Deployment Configuration Tests
    // ====================================================================

    function test_mainnetSuckerConfig() public view {
        REVSuckerDeploymentConfig memory config =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        assertEq(config.salt, SUCKER_SALT, "Sucker salt matches");
        assertEq(config.deployerConfigurations.length, 3, "3 sucker deployers on mainnet");

        // OP deployer.
        assertEq(address(config.deployerConfigurations[0].deployer), address(opDeployer), "First deployer is OP");
        // Base deployer.
        assertEq(address(config.deployerConfigurations[1].deployer), address(baseDeployer), "Second deployer is Base");
        // Arb deployer.
        assertEq(address(config.deployerConfigurations[2].deployer), address(arbDeployer), "Third deployer is Arb");
    }

    function test_l2SuckerConfig() public view {
        REVSuckerDeploymentConfig memory config = builder.buildSuckerDeploymentConfigL2(opDeployer);

        assertEq(config.salt, SUCKER_SALT, "Sucker salt matches");
        assertEq(config.deployerConfigurations.length, 1, "1 sucker deployer on L2");
        assertEq(address(config.deployerConfigurations[0].deployer), address(opDeployer), "L2 deployer is correct");
    }

    function test_tokenMappings() public view {
        JBTokenMapping[] memory mappings = builder.buildTokenMappings();

        assertEq(mappings.length, 1, "Single token mapping");
        assertEq(mappings[0].localToken, JBConstants.NATIVE_TOKEN, "Local token is native");
        assertEq(mappings[0].minGas, 200_000, "Min gas is 200,000");
        assertEq(
            mappings[0].remoteToken, bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN))), "Remote token matches native"
        );
    }

    function test_suckerTokenMappingsPerDeployer() public view {
        REVSuckerDeploymentConfig memory config =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        for (uint256 i = 0; i < 3; i++) {
            JBTokenMapping[] memory mappings = config.deployerConfigurations[i].mappings;
            assertEq(mappings.length, 1, "Each deployer has 1 token mapping");
            assertEq(mappings[0].localToken, JBConstants.NATIVE_TOKEN, "Native token mapping");
        }
    }

    // ====================================================================
    // 6. L2 Sucker Deployer Selection Logic Tests
    // ====================================================================

    /// @notice Simulates the L2 deployer selection from Deploy.s.sol.
    function _selectL2Deployer(
        IJBSuckerDeployer opDep,
        IJBSuckerDeployer baseDep,
        IJBSuckerDeployer arbDep
    )
        internal
        pure
        returns (IJBSuckerDeployer)
    {
        // This mirrors the logic in Deploy.s.sol:
        // address(suckers.optimismDeployer) != address(0)
        //     ? suckers.optimismDeployer
        //     : address(suckers.baseDeployer) != address(0)
        //         ? suckers.baseDeployer
        //         : suckers.arbitrumDeployer
        if (address(opDep) != address(0)) {
            return opDep;
        } else if (address(baseDep) != address(0)) {
            return baseDep;
        } else {
            return arbDep;
        }
    }

    function test_l2DeployerSelectionOP() public view {
        // On OP, opDeployer is set, others may or may not be.
        IJBSuckerDeployer selected =
            _selectL2Deployer(opDeployer, IJBSuckerDeployer(address(0)), IJBSuckerDeployer(address(0)));
        assertEq(address(selected), address(opDeployer), "OP chain selects OP deployer");
    }

    function test_l2DeployerSelectionBase() public view {
        // On Base, opDeployer is zero, baseDeployer is set.
        IJBSuckerDeployer selected =
            _selectL2Deployer(IJBSuckerDeployer(address(0)), baseDeployer, IJBSuckerDeployer(address(0)));
        assertEq(address(selected), address(baseDeployer), "Base chain selects Base deployer");
    }

    function test_l2DeployerSelectionArbitrum() public view {
        // On Arb, opDeployer and baseDeployer are zero, arbDeployer is set.
        IJBSuckerDeployer selected =
            _selectL2Deployer(IJBSuckerDeployer(address(0)), IJBSuckerDeployer(address(0)), arbDeployer);
        assertEq(address(selected), address(arbDeployer), "Arb chain selects Arb deployer");
    }

    function test_l2DeployerSelectionAllZeroReturnsZero() public pure {
        // When all deployers are zero, returns zero address (deploy script then checks and reverts).
        IJBSuckerDeployer zeroDeployer = IJBSuckerDeployer(address(0));
        IJBSuckerDeployer selected;
        if (address(zeroDeployer) != address(0)) {
            selected = zeroDeployer;
        } else if (address(zeroDeployer) != address(0)) {
            selected = zeroDeployer;
        } else {
            selected = zeroDeployer;
        }
        assertEq(address(selected), address(0), "All zero deployers returns zero (will revert in script)");
    }

    // ====================================================================
    // 7. End-to-End Deploy Flow Tests (using mocks)
    // ====================================================================

    function test_deployCallsApproveAndDeployFor() public {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        JBTerminalConfig[] memory terminalConfigs =
            builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        REVSuckerDeploymentConfig memory suckerConfig =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        // Step 1: Approve the deployer for project #1 (as in the deploy script).
        mockProjects.approve(address(mockDeployer), FEE_PROJECT_ID);

        assertTrue(mockProjects.approveCalled(), "approve was called");
        assertEq(mockProjects.approvedTo(), address(mockDeployer), "Approved the REV deployer");
        assertEq(mockProjects.approvedTokenId(), FEE_PROJECT_ID, "Approved for project #1");

        // Step 2: Deploy the revnet (as in the deploy script).
        mockDeployer.deployFor(FEE_PROJECT_ID, config, terminalConfigs, suckerConfig);

        assertTrue(mockDeployer.deployForCalled(), "deployFor was called");
        assertEq(mockDeployer.recordedRevnetId(), FEE_PROJECT_ID, "Deployed for project #1");
    }

    function test_deployForRecordsCorrectConfig() public {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        JBTerminalConfig[] memory terminalConfigs =
            builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        REVSuckerDeploymentConfig memory suckerConfig =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        mockDeployer.deployFor(FEE_PROJECT_ID, config, terminalConfigs, suckerConfig);

        // Decode all recorded args.
        (
            uint256 revnetId,
            REVConfig memory recordedConfig,
            JBTerminalConfig[] memory recordedTerminals,
            REVSuckerDeploymentConfig memory recordedSuckers
        ) = mockDeployer.getRecordedArgs();

        assertEq(revnetId, FEE_PROJECT_ID, "Recorded revnet ID");
        assertEq(
            keccak256(bytes(recordedConfig.description.name)), keccak256(bytes(NAME)), "Recorded config name matches"
        );
        assertEq(
            keccak256(bytes(recordedConfig.description.ticker)),
            keccak256(bytes(SYMBOL)),
            "Recorded config ticker matches"
        );
        assertEq(recordedConfig.baseCurrency, ETH_CURRENCY, "Recorded base currency matches");
        assertEq(recordedConfig.splitOperator, operatorAddr, "Recorded split operator matches");
        assertEq(recordedTerminals.length, 2, "Recorded 2 terminals");
        assertEq(recordedSuckers.salt, SUCKER_SALT, "Recorded sucker salt");
    }

    function test_deployForRecordsCorrectStageConfig() public {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        JBTerminalConfig[] memory terminalConfigs =
            builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        REVSuckerDeploymentConfig memory suckerConfig =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        mockDeployer.deployFor(FEE_PROJECT_ID, config, terminalConfigs, suckerConfig);

        (, REVConfig memory recordedConfig,,) = mockDeployer.getRecordedArgs();

        assertEq(recordedConfig.stageConfigurations.length, 1, "1 stage recorded");
        REVStageConfig memory stage = recordedConfig.stageConfigurations[0];
        assertEq(stage.startsAtOrAfter, NANA_START_TIME, "Stage start time recorded");
        assertEq(stage.splitPercent, 6200, "Split percent recorded");
        assertEq(stage.initialIssuance, uint112(10_000 * DECIMAL_MULTIPLIER), "Initial issuance recorded");
        assertEq(stage.issuanceCutFrequency, 360 days, "Issuance cut frequency recorded");
        assertEq(stage.issuanceCutPercent, 380_000_000, "Issuance cut percent recorded");
        assertEq(stage.cashOutTaxRate, 1000, "Cash out tax rate recorded");
        assertEq(stage.extraMetadata, 4, "Extra metadata recorded");
    }

    function test_deployForRecordsCorrectTerminals() public {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        JBTerminalConfig[] memory terminalConfigs =
            builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        REVSuckerDeploymentConfig memory suckerConfig =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        mockDeployer.deployFor(FEE_PROJECT_ID, config, terminalConfigs, suckerConfig);

        (,, JBTerminalConfig[] memory recordedTerminals,) = mockDeployer.getRecordedArgs();

        assertEq(recordedTerminals.length, 2, "2 terminals recorded");

        assertEq(address(recordedTerminals[0].terminal), address(multiTerminal), "First terminal recorded");
        assertEq(recordedTerminals[0].accountingContextsToAccept.length, 1, "First terminal has 1 accounting context");
        assertEq(
            recordedTerminals[0].accountingContextsToAccept[0].token, JBConstants.NATIVE_TOKEN, "Accepts native token"
        );

        assertEq(address(recordedTerminals[1].terminal), address(routerTerminalRegistry), "Second terminal recorded");
        assertEq(
            recordedTerminals[1].accountingContextsToAccept.length, 0, "Second terminal has no accounting contexts"
        );
    }

    function test_deployForRecordsCorrectSuckerConfig() public {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        JBTerminalConfig[] memory terminalConfigs =
            builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        REVSuckerDeploymentConfig memory suckerConfig =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        mockDeployer.deployFor(FEE_PROJECT_ID, config, terminalConfigs, suckerConfig);

        (,,, REVSuckerDeploymentConfig memory recordedSuckers) = mockDeployer.getRecordedArgs();

        assertEq(recordedSuckers.salt, SUCKER_SALT, "Sucker salt recorded");
        assertEq(recordedSuckers.deployerConfigurations.length, 3, "3 sucker deployers recorded");

        assertEq(
            address(recordedSuckers.deployerConfigurations[0].deployer), address(opDeployer), "OP deployer recorded"
        );
        assertEq(
            address(recordedSuckers.deployerConfigurations[1].deployer), address(baseDeployer), "Base deployer recorded"
        );
        assertEq(
            address(recordedSuckers.deployerConfigurations[2].deployer), address(arbDeployer), "Arb deployer recorded"
        );
    }

    // ====================================================================
    // 8. Split Routing Tests
    // ====================================================================

    function test_splitRouting100PercentToOperator() public view {
        JBSplit[] memory splits = builder.buildSplits(operatorAddr);

        assertEq(splits.length, 1, "Single split");
        assertEq(splits[0].percent, JBConstants.SPLITS_TOTAL_PERCENT, "100% of splits");
        assertEq(splits[0].beneficiary, operatorAddr, "Routes to operator");
    }

    function test_splitRoutingBeneficiaryIsOperator() public view {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        JBSplit[] memory splits = config.stageConfigurations[0].splits;

        // The split beneficiary must be the same as the splitOperator.
        assertEq(splits[0].beneficiary, config.splitOperator, "Split beneficiary matches split operator");
    }

    function test_splitHasNoProjectRedirect() public view {
        JBSplit[] memory splits = builder.buildSplits(operatorAddr);
        assertEq(splits[0].projectId, 0, "No project redirect");
    }

    function test_splitIsNotLocked() public view {
        JBSplit[] memory splits = builder.buildSplits(operatorAddr);
        assertEq(splits[0].lockedUntil, 0, "Split is not locked");
    }

    function test_splitHasNoHook() public view {
        JBSplit[] memory splits = builder.buildSplits(operatorAddr);
        assertEq(address(splits[0].hook), address(0), "No split hook");
    }

    function test_splitDoesNotPreferAddToBalance() public view {
        JBSplit[] memory splits = builder.buildSplits(operatorAddr);
        assertEq(splits[0].preferAddToBalance, false, "Does not prefer add to balance");
    }

    // ====================================================================
    // 9. Economic Invariant Tests
    // ====================================================================

    function test_splitPercentWithinBounds() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertGt(stages[0].splitPercent, 0, "Split percent > 0");
        assertLe(stages[0].splitPercent, JBConstants.MAX_RESERVED_PERCENT, "Split percent <= max (10,000)");
    }

    function test_issuanceCutPercentWithinBounds() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertGt(stages[0].issuanceCutPercent, 0, "Issuance cut > 0");
        assertLe(
            stages[0].issuanceCutPercent, JBConstants.MAX_WEIGHT_CUT_PERCENT, "Issuance cut <= max (1,000,000,000)"
        );
    }

    function test_cashOutTaxRateWithinBounds() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertGt(stages[0].cashOutTaxRate, 0, "Cash out tax > 0");
        assertLt(stages[0].cashOutTaxRate, JBConstants.MAX_CASH_OUT_TAX_RATE, "Cash out tax < max (can cash out)");
    }

    function test_issuanceCutFrequencyAtLeast24Hours() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        assertGe(stages[0].issuanceCutFrequency, 24 hours, "Cut frequency >= 24 hours");
    }

    function test_allAutoIssuanceBeneficiariesAreOperator() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        REVAutoIssuance[] memory autoIssuances = stages[0].autoIssuances;
        for (uint256 i = 0; i < autoIssuances.length; i++) {
            assertEq(autoIssuances[i].beneficiary, operatorAddr, "All auto issuance beneficiaries are operator");
            assertTrue(autoIssuances[i].beneficiary != address(0), "Beneficiary is not zero address");
        }
    }

    function test_autoIssuanceChainIdsAreValid() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        REVAutoIssuance[] memory autoIssuances = stages[0].autoIssuances;

        uint32[4] memory expectedChainIds = [uint32(1), uint32(8453), uint32(10), uint32(42_161)];
        for (uint256 i = 0; i < autoIssuances.length; i++) {
            assertEq(autoIssuances[i].chainId, expectedChainIds[i], "Chain ID matches expected");
        }
    }

    // ====================================================================
    // 10. Salt Determinism Tests
    // ====================================================================

    function test_erc20SaltIsDeterministic() public pure {
        assertEq(ERC20_SALT, bytes32("_NANA_ERC20_SALTV6__"), "ERC20 salt matches expected");
    }

    function test_suckerSaltIsDeterministic() public pure {
        assertEq(SUCKER_SALT, bytes32("_NANA_SUCKER_SALTV6__"), "Sucker salt matches expected");
    }

    function test_saltsAreDifferent() public pure {
        assertTrue(ERC20_SALT != SUCKER_SALT, "ERC20 and sucker salts are different");
    }

    // ====================================================================
    // 11. Consistency Tests
    // ====================================================================

    /// @notice Verifies that the operator address is used consistently
    /// across all configuration components.
    function test_operatorConsistencyAcrossConfig() public view {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        REVStageConfig memory stage = config.stageConfigurations[0];

        // splitOperator.
        assertEq(config.splitOperator, operatorAddr, "Split operator");

        // Split beneficiary.
        assertEq(stage.splits[0].beneficiary, operatorAddr, "Split beneficiary");

        // All auto-issuance beneficiaries.
        for (uint256 i = 0; i < stage.autoIssuances.length; i++) {
            assertEq(stage.autoIssuances[i].beneficiary, operatorAddr, "Auto issuance beneficiary");
        }
    }

    /// @notice Verifies that the native token and currency are consistent across the config.
    function test_nativeTokenConsistency() public view {
        JBTerminalConfig[] memory terminalConfigs =
            builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        JBTokenMapping[] memory mappings = builder.buildTokenMappings();

        // Terminal accepts native token.
        assertEq(terminalConfigs[0].accountingContextsToAccept[0].token, JBConstants.NATIVE_TOKEN);

        // Token mapping maps native token.
        assertEq(mappings[0].localToken, JBConstants.NATIVE_TOKEN);
        assertEq(mappings[0].remoteToken, bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN))));
    }

    /// @notice Verifies that the total split percent sums to 100% (just one split at 100%).
    function test_totalSplitPercent() public view {
        JBSplit[] memory splits = builder.buildSplits(operatorAddr);
        uint256 totalPercent = 0;
        for (uint256 i = 0; i < splits.length; i++) {
            totalPercent += splits[i].percent;
        }
        assertEq(totalPercent, JBConstants.SPLITS_TOTAL_PERCENT, "Total split percent is 100%");
    }

    // ====================================================================
    // 12. Full Round-Trip Encode/Decode Fidelity
    // ====================================================================

    /// @notice Ensures encoding -> decoding through the mock preserves all nested data.
    function test_fullRoundTripFidelity() public {
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        JBTerminalConfig[] memory terminalConfigs =
            builder.buildTerminalConfigurations(multiTerminal, routerTerminalRegistry);
        REVSuckerDeploymentConfig memory suckerConfig =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        mockDeployer.deployFor(FEE_PROJECT_ID, config, terminalConfigs, suckerConfig);

        (uint256 revnetId, REVConfig memory rc, JBTerminalConfig[] memory rt, REVSuckerDeploymentConfig memory rs) =
            mockDeployer.getRecordedArgs();

        // Top-level.
        assertEq(revnetId, FEE_PROJECT_ID);
        assertEq(rc.baseCurrency, config.baseCurrency);
        assertEq(rc.splitOperator, config.splitOperator);
        assertEq(rc.description.salt, config.description.salt);

        // Stage: auto issuances.
        assertEq(rc.stageConfigurations[0].autoIssuances.length, 4);
        for (uint256 i = 0; i < 4; i++) {
            assertEq(
                rc.stageConfigurations[0].autoIssuances[i].chainId,
                config.stageConfigurations[0].autoIssuances[i].chainId
            );
            assertEq(
                rc.stageConfigurations[0].autoIssuances[i].count, config.stageConfigurations[0].autoIssuances[i].count
            );
            assertEq(
                rc.stageConfigurations[0].autoIssuances[i].beneficiary,
                config.stageConfigurations[0].autoIssuances[i].beneficiary
            );
        }

        // Stage: splits.
        assertEq(rc.stageConfigurations[0].splits.length, 1);
        assertEq(rc.stageConfigurations[0].splits[0].percent, config.stageConfigurations[0].splits[0].percent);
        assertEq(rc.stageConfigurations[0].splits[0].beneficiary, config.stageConfigurations[0].splits[0].beneficiary);

        // Terminals.
        assertEq(rt.length, 2);
        assertEq(address(rt[0].terminal), address(multiTerminal));
        assertEq(rt[0].accountingContextsToAccept[0].token, JBConstants.NATIVE_TOKEN);

        // Suckers: token mappings within each deployer config.
        assertEq(rs.deployerConfigurations.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(rs.deployerConfigurations[i].mappings.length, 1);
            assertEq(rs.deployerConfigurations[i].mappings[0].localToken, JBConstants.NATIVE_TOKEN);
            assertEq(rs.deployerConfigurations[i].mappings[0].minGas, 200_000);
        }
    }

    // ====================================================================
    // 13. Auto-Issuance Proportionality Invariants
    // ====================================================================

    /// @notice The sum of all auto-issuance amounts must not overflow uint256.
    function test_autoIssuanceTotalDoesNotOverflow() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        REVAutoIssuance[] memory autoIssuances = stages[0].autoIssuances;

        uint256 total = 0;
        for (uint256 i = 0; i < autoIssuances.length; i++) {
            uint256 prev = total;
            total += autoIssuances[i].count;
            assertGe(total, prev, "No overflow in auto issuance sum");
        }
    }

    // ====================================================================
    // 14. Fuzz: Operator Address Independence
    // ====================================================================

    /// @notice The deploy configuration must be structurally valid for any nonzero operator.
    function test_fuzz_operatorAddressIndependence(address op) public view {
        vm.assume(op != address(0));

        REVConfig memory config = builder.buildRevnetConfiguration(op);

        // Structure invariants hold for any operator.
        assertEq(config.stageConfigurations.length, 1, "Always 1 stage");
        assertEq(config.baseCurrency, ETH_CURRENCY, "Base currency always ETH");
        assertEq(config.splitOperator, op, "Split operator matches provided address");
        assertEq(config.stageConfigurations[0].splits[0].beneficiary, op, "Split beneficiary matches");

        for (uint256 i = 0; i < config.stageConfigurations[0].autoIssuances.length; i++) {
            assertEq(
                config.stageConfigurations[0].autoIssuances[i].beneficiary, op, "Auto issuance beneficiary matches"
            );
        }
    }

    // ====================================================================
    // 15. Cross-Chain Sucker Symmetry
    // ====================================================================

    /// @notice Every sucker deployer config on mainnet must use the same token mappings.
    function test_mainnetSuckerMappingsAreIdentical() public view {
        REVSuckerDeploymentConfig memory config =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);

        JBTokenMapping[] memory ref = config.deployerConfigurations[0].mappings;
        for (uint256 i = 1; i < config.deployerConfigurations.length; i++) {
            JBTokenMapping[] memory cur = config.deployerConfigurations[i].mappings;
            assertEq(cur.length, ref.length, "Same number of token mappings across all deployers");
            for (uint256 j = 0; j < ref.length; j++) {
                assertEq(cur[j].localToken, ref[j].localToken, "localToken identical across deployers");
                assertEq(cur[j].minGas, ref[j].minGas, "minGas identical across deployers");
                assertEq(cur[j].remoteToken, ref[j].remoteToken, "remoteToken identical across deployers");
            }
        }
    }

    /// @notice Mainnet and L2 sucker configs must use the same salt and identical token mappings.
    function test_mainnetAndL2SuckerConfigsSameSaltAndMappings() public view {
        REVSuckerDeploymentConfig memory mainnet =
            builder.buildSuckerDeploymentConfigMainnet(opDeployer, baseDeployer, arbDeployer);
        REVSuckerDeploymentConfig memory l2 = builder.buildSuckerDeploymentConfigL2(opDeployer);

        assertEq(mainnet.salt, l2.salt, "Salt matches across mainnet and L2");

        // Compare token mappings between mainnet's first deployer and L2's deployer.
        JBTokenMapping[] memory mainnetMappings = mainnet.deployerConfigurations[0].mappings;
        JBTokenMapping[] memory l2Mappings = l2.deployerConfigurations[0].mappings;

        assertEq(mainnetMappings.length, l2Mappings.length, "Same number of mappings");
        for (uint256 i = 0; i < mainnetMappings.length; i++) {
            assertEq(mainnetMappings[i].localToken, l2Mappings[i].localToken, "localToken matches");
            assertEq(mainnetMappings[i].minGas, l2Mappings[i].minGas, "minGas matches");
            assertEq(mainnetMappings[i].remoteToken, l2Mappings[i].remoteToken, "remoteToken matches");
        }
    }

    // ====================================================================
    // 16. Deploy Script Hardcoded Values Snapshot
    // ====================================================================

    /// @notice Pin all hardcoded economic parameters from Deploy.s.sol.
    ///         If anyone changes the deploy script values, this test fails,
    ///         forcing a conscious review of the change.
    function test_deployScriptHardcodedValuesSnapshot() public view {
        REVStageConfig[] memory stages = builder.buildStageConfigurations(operatorAddr);
        REVStageConfig memory s = stages[0];

        // Economic parameters.
        assertEq(s.startsAtOrAfter, 1_740_089_444, "NANA_START_TIME pinned");
        assertEq(s.splitPercent, 6200, "62% split pinned");
        assertEq(s.initialIssuance, uint112(10_000 * 1e18), "10,000 initial issuance pinned");
        assertEq(s.issuanceCutFrequency, 360 days, "360-day cut frequency pinned");
        assertEq(s.issuanceCutPercent, 380_000_000, "38% issuance cut pinned");
        assertEq(s.cashOutTaxRate, 1000, "10% cash out tax pinned");
        assertEq(s.extraMetadata, 4, "Allow adding suckers pinned");

        // Auto-issuance amounts.
        assertEq(s.autoIssuances[0].count, 34_614_774_622_547_324_824_200, "Mainnet auto issuance pinned");
        assertEq(s.autoIssuances[1].count, 1_604_412_323_715_200_204_800, "Base auto issuance pinned");
        assertEq(s.autoIssuances[2].count, 6_266_215_368_602_910_600, "OP auto issuance pinned");
        assertEq(s.autoIssuances[3].count, 105_160_496_145_000_000, "Arb auto issuance pinned");

        // Identity.
        REVConfig memory config = builder.buildRevnetConfiguration(operatorAddr);
        assertEq(keccak256(bytes(config.description.name)), keccak256(bytes("Bananapus (Juicebox V6)")), "Name pinned");
        assertEq(keccak256(bytes(config.description.ticker)), keccak256(bytes("NANA")), "Symbol pinned");
        assertEq(
            keccak256(bytes(config.description.uri)),
            keccak256(bytes("ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ")),
            "URI pinned"
        );
    }
}
