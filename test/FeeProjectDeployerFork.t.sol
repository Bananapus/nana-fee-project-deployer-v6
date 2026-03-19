// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

// JB Core — contracts
import {JBPermissions} from "@bananapus/core-v6/src/JBPermissions.sol";
import {JBProjects} from "@bananapus/core-v6/src/JBProjects.sol";
import {JBDirectory} from "@bananapus/core-v6/src/JBDirectory.sol";
import {JBRulesets} from "@bananapus/core-v6/src/JBRulesets.sol";
import {JBTokens} from "@bananapus/core-v6/src/JBTokens.sol";
import {JBERC20} from "@bananapus/core-v6/src/JBERC20.sol";
import {JBSplits} from "@bananapus/core-v6/src/JBSplits.sol";
import {JBPrices} from "@bananapus/core-v6/src/JBPrices.sol";
import {JBController} from "@bananapus/core-v6/src/JBController.sol";
import {JBFundAccessLimits} from "@bananapus/core-v6/src/JBFundAccessLimits.sol";
import {JBFeelessAddresses} from "@bananapus/core-v6/src/JBFeelessAddresses.sol";
import {JBTerminalStore} from "@bananapus/core-v6/src/JBTerminalStore.sol";
import {JBMultiTerminal} from "@bananapus/core-v6/src/JBMultiTerminal.sol";

// JB Core — structs & libraries
import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";
import {JBAccountingContext} from "@bananapus/core-v6/src/structs/JBAccountingContext.sol";
import {JBTerminalConfig} from "@bananapus/core-v6/src/structs/JBTerminalConfig.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {JBRuleset} from "@bananapus/core-v6/src/structs/JBRuleset.sol";

// JB Core — interfaces
import {IJBTerminal} from "@bananapus/core-v6/src/interfaces/IJBTerminal.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";
import {IJBRulesetDataHook} from "@bananapus/core-v6/src/interfaces/IJBRulesetDataHook.sol";

// 721 Hook
import {JB721TiersHook} from "@bananapus/721-hook-v6/src/JB721TiersHook.sol";
import {JB721TiersHookDeployer} from "@bananapus/721-hook-v6/src/JB721TiersHookDeployer.sol";
import {JB721TiersHookStore} from "@bananapus/721-hook-v6/src/JB721TiersHookStore.sol";
import {IJB721TiersHookStore} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHookStore.sol";
import {IJB721TiersHookDeployer} from "@bananapus/721-hook-v6/src/interfaces/IJB721TiersHookDeployer.sol";

// Address Registry
import {JBAddressRegistry} from "@bananapus/address-registry-v6/src/JBAddressRegistry.sol";
import {IJBAddressRegistry} from "@bananapus/address-registry-v6/src/interfaces/IJBAddressRegistry.sol";

// Buyback Hook
import {JBBuybackHook} from "@bananapus/buyback-hook-v6/src/JBBuybackHook.sol";
import {JBBuybackHookRegistry} from "@bananapus/buyback-hook-v6/src/JBBuybackHookRegistry.sol";
import {IJBBuybackHookRegistry} from "@bananapus/buyback-hook-v6/src/interfaces/IJBBuybackHookRegistry.sol";

// Suckers
import {JBSuckerRegistry} from "@bananapus/suckers-v6/src/JBSuckerRegistry.sol";
import {IJBSuckerRegistry} from "@bananapus/suckers-v6/src/interfaces/IJBSuckerRegistry.sol";
import {JBSuckerDeployerConfig} from "@bananapus/suckers-v6/src/structs/JBSuckerDeployerConfig.sol";

// Croptop
import {CTPublisher} from "@croptop/core-v6/src/CTPublisher.sol";

// Revnet
import {REVDeployer} from "@rev-net/core-v6/src/REVDeployer.sol";
import {REVLoans} from "@rev-net/core-v6/src/REVLoans.sol";
import {REVAutoIssuance} from "@rev-net/core-v6/src/structs/REVAutoIssuance.sol";
import {REVConfig} from "@rev-net/core-v6/src/structs/REVConfig.sol";
import {REVDescription} from "@rev-net/core-v6/src/structs/REVDescription.sol";
import {REVStageConfig} from "@rev-net/core-v6/src/structs/REVStageConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core-v6/src/structs/REVSuckerDeploymentConfig.sol";

// Uniswap (for buyback hook)
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

// Permit2
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {DeployPermit2} from "@uniswap/permit2/test/utils/DeployPermit2.sol";

/// @notice Fork test for the fee project deployer flow.
/// Deploys the full JB core + REVDeployer infrastructure on a mainnet fork and
/// exercises the fee-project configuration matching the production deploy script.
contract FeeProjectDeployerForkTest is Test, DeployPermit2 {
    // ───────────────────────── Mainnet constants ─────────────────────────

    /// @dev Uniswap V4 PoolManager on Ethereum mainnet.
    address constant POOL_MANAGER_ADDR = 0x000000000004444c5dc75cB358380D2e3dE08A90;

    // ───────────────────────── Deploy-script constants ─────────────────────────

    uint256 constant FEE_PROJECT_ID = 1;
    string constant NAME = "Bananapus (Juicebox V6)";
    string constant SYMBOL = "NANA";
    string constant PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ";
    bytes32 constant ERC20_SALT = "_NANA_ERC20_SALTV6__";

    // forge-lint: disable-next-line(mixed-case-variable)
    uint32 NATIVE_CURRENCY = uint32(uint160(JBConstants.NATIVE_TOKEN));
    // forge-lint: disable-next-line(mixed-case-variable)
    uint32 ETH_CURRENCY = JBCurrencyIds.ETH;
    uint8 constant DECIMALS = 18;
    uint256 constant DECIMAL_MULTIPLIER = 10 ** DECIMALS;

    // forge-lint: disable-next-line(unsafe-typecast)
    uint112 constant INITIAL_ISSUANCE = uint112(10_000 * DECIMAL_MULTIPLIER);
    uint32 constant ISSUANCE_CUT_FREQUENCY = 360 days;
    uint32 constant ISSUANCE_CUT_PERCENT = 380_000_000; // 38%
    uint16 constant CASH_OUT_TAX_RATE = 1000; // 10%
    uint16 constant SPLIT_PERCENT = 6200; // 62%
    uint104 constant MAINNET_AUTO_ISSUANCE = 34_614_774_622_547_324_824_200;

    // ───────────────────────── Actors ─────────────────────────

    // forge-lint: disable-next-line(mixed-case-variable)
    address MULTISIG = makeAddr("multisig");
    // forge-lint: disable-next-line(mixed-case-variable)
    address OPERATOR = makeAddr("operator");
    // forge-lint: disable-next-line(mixed-case-variable)
    address PAYER = makeAddr("payer");
    // forge-lint: disable-next-line(mixed-case-variable)
    address AUTO_ISSUANCE_BENEFICIARY = makeAddr("autoIssuanceBeneficiary");
    address constant TRUSTED_FORWARDER = address(0);

    // ───────────────────────── Infrastructure ─────────────────────────

    // JB Core
    JBPermissions jbPermissions;
    JBProjects jbProjects;
    JBDirectory jbDirectory;
    JBRulesets jbRulesets;
    JBTokens jbTokens;
    JBPrices jbPrices;
    JBSplits jbSplits;
    JBFundAccessLimits jbFundAccessLimits;
    JBFeelessAddresses jbFeelessAddresses;
    JBController jbController;
    JBTerminalStore jbTerminalStore;
    JBMultiTerminal jbMultiTerminal;
    IPermit2 permit2Instance;

    // Revnet
    REVDeployer revDeployer;

    // Supporting
    IJBSuckerRegistry suckerRegistry;
    IJB721TiersHookDeployer hookDeployer;
    CTPublisher publisher;
    IJBBuybackHookRegistry buybackRegistry;
    REVLoans loansContract;

    // ───────────────────────── Setup ─────────────────────────

    function setUp() public {
        // Fork mainnet at a stable block (post-V4 deployment).
        vm.createSelectFork("ethereum", 21_700_000);

        // Verify the PoolManager is live.
        require(POOL_MANAGER_ADDR.code.length > 0, "PoolManager not deployed at expected address");

        // ── Deploy JB Core ──
        jbPermissions = new JBPermissions(TRUSTED_FORWARDER);
        jbProjects = new JBProjects(MULTISIG, address(0), TRUSTED_FORWARDER);
        jbDirectory = new JBDirectory(jbPermissions, jbProjects, MULTISIG);
        JBERC20 jbErc20 = new JBERC20();
        jbTokens = new JBTokens(jbDirectory, jbErc20);
        jbRulesets = new JBRulesets(jbDirectory);
        jbPrices = new JBPrices(jbDirectory, jbPermissions, jbProjects, MULTISIG, TRUSTED_FORWARDER);
        jbSplits = new JBSplits(jbDirectory);
        jbFundAccessLimits = new JBFundAccessLimits(jbDirectory);
        jbFeelessAddresses = new JBFeelessAddresses(MULTISIG);

        jbController = new JBController(
            jbDirectory,
            jbFundAccessLimits,
            jbPermissions,
            jbPrices,
            jbProjects,
            jbRulesets,
            jbSplits,
            jbTokens,
            address(0), // omnichainRulesetOperator
            TRUSTED_FORWARDER
        );

        vm.prank(MULTISIG);
        jbDirectory.setIsAllowedToSetFirstController(address(jbController), true);

        jbTerminalStore = new JBTerminalStore(jbDirectory, jbPrices, jbRulesets);

        vm.prank(MULTISIG);
        permit2Instance = IPermit2(deployPermit2());

        jbMultiTerminal = new JBMultiTerminal(
            jbFeelessAddresses, jbPermissions, jbProjects, jbSplits, jbTerminalStore, jbTokens, permit2Instance,
            TRUSTED_FORWARDER
        );

        // ── Create project 1 (fee project) ──
        vm.prank(MULTISIG);
        uint256 createdId = jbProjects.createFor(MULTISIG);
        require(createdId == FEE_PROJECT_ID, "Expected project ID 1");

        // ── Deploy supporting infrastructure ──
        suckerRegistry = new JBSuckerRegistry(jbDirectory, jbPermissions, MULTISIG, TRUSTED_FORWARDER);

        JB721TiersHookStore hookStore = new JB721TiersHookStore();
        JB721TiersHook exampleHook =
            new JB721TiersHook(jbDirectory, jbPermissions, jbPrices, jbRulesets, hookStore, jbSplits, TRUSTED_FORWARDER);
        IJBAddressRegistry addressRegistry = new JBAddressRegistry();
        hookDeployer = new JB721TiersHookDeployer(exampleHook, IJB721TiersHookStore(address(hookStore)), addressRegistry, TRUSTED_FORWARDER);

        publisher = new CTPublisher(jbDirectory, jbPermissions, FEE_PROJECT_ID, TRUSTED_FORWARDER);

        // Deploy buyback hook with the real PoolManager.
        JBBuybackHook buybackHook = new JBBuybackHook(
            jbDirectory,
            jbPermissions,
            jbPrices,
            jbProjects,
            jbTokens,
            IPoolManager(POOL_MANAGER_ADDR),
            IHooks(address(0)), // oracleHook
            TRUSTED_FORWARDER
        );

        JBBuybackHookRegistry registry = new JBBuybackHookRegistry(
            jbPermissions,
            jbProjects,
            address(this), // owner
            TRUSTED_FORWARDER
        );
        registry.setDefaultHook(IJBRulesetDataHook(address(buybackHook)));
        buybackRegistry = IJBBuybackHookRegistry(address(registry));

        loansContract = new REVLoans({
            controller: jbController,
            projects: jbProjects,
            revId: FEE_PROJECT_ID,
            owner: address(this),
            permit2: permit2Instance,
            trustedForwarder: TRUSTED_FORWARDER
        });

        // ── Deploy REVDeployer ──
        revDeployer = new REVDeployer{salt: "REVDeployer_Fork"}(
            jbController,
            suckerRegistry,
            FEE_PROJECT_ID,
            hookDeployer,
            publisher,
            buybackRegistry,
            address(loansContract),
            TRUSTED_FORWARDER
        );

        // Approve the REVDeployer to configure project 1.
        vm.prank(MULTISIG);
        jbProjects.approve(address(revDeployer), FEE_PROJECT_ID);

        // Fund the payer.
        vm.deal(PAYER, 100 ether);
    }

    // ───────────────────────── Config helpers ─────────────────────────

    /// @notice Build the fee project REVConfig matching the deploy script.
    function _buildFeeProjectConfig()
        internal
        view
        returns (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        )
    {
        // Terminal configuration: accept native ETH.
        JBAccountingContext[] memory accountingContexts = new JBAccountingContext[](1);
        accountingContexts[0] =
            JBAccountingContext({token: JBConstants.NATIVE_TOKEN, decimals: 18, currency: NATIVE_CURRENCY});

        terminalConfigs = new JBTerminalConfig[](1);
        terminalConfigs[0] =
            JBTerminalConfig({terminal: IJBTerminal(address(jbMultiTerminal)), accountingContextsToAccept: accountingContexts});

        // Reserved splits: 100% of reserved tokens go to OPERATOR.
        JBSplit[] memory splits = new JBSplit[](1);
        splits[0] = JBSplit({
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(OPERATOR),
            preferAddToBalance: false,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // Auto-issuance: only configure for mainnet (chainId=1).
        REVAutoIssuance[] memory autoIssuances = new REVAutoIssuance[](1);
        autoIssuances[0] = REVAutoIssuance({
            chainId: 1,
            count: MAINNET_AUTO_ISSUANCE,
            beneficiary: AUTO_ISSUANCE_BENEFICIARY
        });

        // Stage configuration matching the deploy script.
        REVStageConfig[] memory stages = new REVStageConfig[](1);
        stages[0] = REVStageConfig({
            startsAtOrAfter: uint48(block.timestamp),
            autoIssuances: autoIssuances,
            splitPercent: SPLIT_PERCENT,
            splits: splits,
            initialIssuance: INITIAL_ISSUANCE,
            issuanceCutFrequency: ISSUANCE_CUT_FREQUENCY,
            issuanceCutPercent: ISSUANCE_CUT_PERCENT,
            cashOutTaxRate: CASH_OUT_TAX_RATE,
            extraMetadata: 0
        });

        config = REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT}),
            baseCurrency: ETH_CURRENCY,
            splitOperator: OPERATOR,
            stageConfigurations: stages
        });

        // Empty sucker deployment (no cross-chain setup for this test).
        suckerConfig = REVSuckerDeploymentConfig({
            deployerConfigurations: new JBSuckerDeployerConfig[](0),
            salt: bytes32(0)
        });
    }

    // ───────────────────────── Test 1: Deploy succeeds ─────────────────────────

    /// @notice Fork mainnet, deploy full JB+REV infrastructure, deploy fee project.
    ///         Verifies the deployment does not revert.
    function testFork_FeeProjectDeploySucceeds() public {
        (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        ) = _buildFeeProjectConfig();

        // Deploy fee project via the 4-arg overload (matches deploy script).
        vm.prank(MULTISIG);
        (uint256 deployedId,) = revDeployer.deployFor({
            revnetId: FEE_PROJECT_ID,
            configuration: config,
            terminalConfigurations: terminalConfigs,
            suckerDeploymentConfiguration: suckerConfig
        });

        // Verify the deployed ID matches.
        assertEq(deployedId, FEE_PROJECT_ID, "Deployed project ID should be 1");

        // Verify the controller was set for the project.
        // controllerOf returns IERC165; cast to address for the zero check.
        assertTrue(
            address(jbDirectory.controllerOf(FEE_PROJECT_ID)) != address(0),
            "Controller should be set for the fee project"
        );

        // Verify the terminal is configured.
        IJBTerminal[] memory terminals = jbDirectory.terminalsOf(FEE_PROJECT_ID);
        assertTrue(terminals.length > 0, "At least one terminal should be configured");
    }

    // ───────────────────────── Test 2: Accepts payments ─────────────────────────

    /// @notice Pay ETH to the deployed fee project and verify NANA tokens are minted at the
    ///         correct weight (10,000 tokens/ETH with 62% reserved).
    function testFork_FeeProjectAcceptsPayments() public {
        // Deploy the fee project.
        (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        ) = _buildFeeProjectConfig();

        vm.prank(MULTISIG);
        revDeployer.deployFor({
            revnetId: FEE_PROJECT_ID,
            configuration: config,
            terminalConfigurations: terminalConfigs,
            suckerDeploymentConfiguration: suckerConfig
        });

        // Pay 1 ETH to the fee project.
        uint256 payAmount = 1 ether;
        vm.prank(PAYER);
        uint256 tokensReceived = jbMultiTerminal.pay{value: payAmount}({
            projectId: FEE_PROJECT_ID,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmount,
            beneficiary: PAYER,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        // With initialIssuance = 10,000 tokens/ETH and splitPercent = 62%,
        // the payer receives (100% - 62%) = 38% of the total issuance.
        // Expected: 10,000 * 0.38 = 3,800 tokens for 1 ETH.
        uint256 expectedPayerTokens = (uint256(INITIAL_ISSUANCE) * (10_000 - SPLIT_PERCENT)) / 10_000;
        assertEq(tokensReceived, expectedPayerTokens, "Payer should receive 38% of 10,000 tokens per ETH");

        // Verify the payer's token balance matches.
        uint256 payerBalance = jbTokens.totalBalanceOf(PAYER, FEE_PROJECT_ID);
        assertEq(payerBalance, expectedPayerTokens, "Payer balance should match tokens received");

        // Verify tokens are non-zero.
        assertTrue(tokensReceived > 0, "Payer should receive some tokens");
    }

    // ───────────────────────── Test 3: Auto-issuance ─────────────────────────

    /// @notice Deploy with auto-issuance for mainnet (chainId=1). Call autoIssueFor after stage
    ///         starts. Verify beneficiary receives the auto-issued tokens.
    function testFork_FeeProjectAutoIssuance() public {
        // Deploy the fee project.
        (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        ) = _buildFeeProjectConfig();

        vm.prank(MULTISIG);
        revDeployer.deployFor({
            revnetId: FEE_PROJECT_ID,
            configuration: config,
            terminalConfigurations: terminalConfigs,
            suckerDeploymentConfiguration: suckerConfig
        });

        // The stage started at block.timestamp, so auto-issuance should be available now.
        // The stageId is the rulesetId which equals the timestamp at which the stage was queued.
        // For the first stage, it matches the start time. We need to find the actual rulesetId.

        // Get the current ruleset to find the stageId.
        (JBRuleset memory currentRuleset,) = jbController.currentRulesetOf(FEE_PROJECT_ID);
        uint256 stageId = currentRuleset.id;

        // Verify auto-issuance is available for the beneficiary.
        uint256 autoIssuanceAmount =
            revDeployer.amountToAutoIssue(FEE_PROJECT_ID, stageId, AUTO_ISSUANCE_BENEFICIARY);
        assertEq(
            autoIssuanceAmount,
            MAINNET_AUTO_ISSUANCE,
            "Auto-issuance amount should match configured value"
        );

        // Record the beneficiary's balance before auto-issuance.
        uint256 balanceBefore = jbTokens.totalBalanceOf(AUTO_ISSUANCE_BENEFICIARY, FEE_PROJECT_ID);

        // Call autoIssueFor.
        revDeployer.autoIssueFor(FEE_PROJECT_ID, stageId, AUTO_ISSUANCE_BENEFICIARY);

        // Verify the beneficiary received the tokens.
        uint256 balanceAfter = jbTokens.totalBalanceOf(AUTO_ISSUANCE_BENEFICIARY, FEE_PROJECT_ID);
        assertEq(
            balanceAfter - balanceBefore,
            MAINNET_AUTO_ISSUANCE,
            "Beneficiary should receive the auto-issued tokens"
        );

        // Verify the auto-issuance slot is now zero (consumed).
        uint256 remaining = revDeployer.amountToAutoIssue(FEE_PROJECT_ID, stageId, AUTO_ISSUANCE_BENEFICIARY);
        assertEq(remaining, 0, "Auto-issuance should be fully consumed");
    }

    // ───────────────────────── Test 4: Reserved splits ─────────────────────────

    /// @notice Pay ETH. Verify 62% of new tokens route to the operator via reserved split
    ///         distribution.
    function testFork_FeeProjectReservedSplits() public {
        // Deploy the fee project.
        (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        ) = _buildFeeProjectConfig();

        vm.prank(MULTISIG);
        revDeployer.deployFor({
            revnetId: FEE_PROJECT_ID,
            configuration: config,
            terminalConfigurations: terminalConfigs,
            suckerDeploymentConfiguration: suckerConfig
        });

        // Record operator's balance before payment.
        uint256 operatorBalanceBefore = jbTokens.totalBalanceOf(OPERATOR, FEE_PROJECT_ID);

        // Pay 1 ETH to the fee project.
        uint256 payAmount = 1 ether;
        vm.prank(PAYER);
        jbMultiTerminal.pay{value: payAmount}({
            projectId: FEE_PROJECT_ID,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmount,
            beneficiary: PAYER,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        // Check pending reserved tokens before distribution.
        uint256 pendingReserved = jbController.pendingReservedTokenBalanceOf(FEE_PROJECT_ID);
        assertTrue(pendingReserved > 0, "There should be pending reserved tokens");

        // Distribute reserved tokens to splits.
        uint256 distributed = jbController.sendReservedTokensToSplitsOf(FEE_PROJECT_ID);

        // The total issuance for 1 ETH is 10,000 tokens.
        // 62% = 6,200 tokens go to reserved splits.
        // The reserved split sends 100% to the OPERATOR.
        uint256 expectedReserved = (uint256(INITIAL_ISSUANCE) * SPLIT_PERCENT) / 10_000;
        assertEq(distributed, expectedReserved, "Distributed reserved tokens should be 62% of total issuance");

        // Verify the operator received the reserved tokens.
        uint256 operatorBalanceAfter = jbTokens.totalBalanceOf(OPERATOR, FEE_PROJECT_ID);
        assertEq(
            operatorBalanceAfter - operatorBalanceBefore,
            expectedReserved,
            "Operator should receive 62% of total issuance as reserved tokens"
        );
    }
}
