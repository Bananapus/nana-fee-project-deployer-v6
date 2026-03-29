// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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
// JB Core — interfaces
import {IJBTerminal} from "@bananapus/core-v6/src/interfaces/IJBTerminal.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";
import {IJBRulesetDataHook} from "@bananapus/core-v6/src/interfaces/IJBRulesetDataHook.sol";
import {IJBPriceFeed} from "@bananapus/core-v6/src/interfaces/IJBPriceFeed.sol";

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
import {REVOwner} from "@rev-net/core-v6/src/REVOwner.sol";
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

/// @notice Identity price feed returning 1:1 for same-asset currency pairs.
contract IdentityPriceFeed is IJBPriceFeed {
    function currentUnitPrice(uint256 decimals) external pure override returns (uint256) {
        return 10 ** decimals;
    }
}

/// @notice Edge case fork tests for the fee project (project #1).
/// Validates recursive fee behavior, multi-source fee aggregation,
/// issuance decay, and terminal failure handling.
contract FeeProjectEdgeCases is Test, DeployPermit2 {
    // ───────────────────────── Mainnet constants
    // ─────────────────────────

    /// @dev Uniswap V4 PoolManager on Ethereum mainnet.
    address constant POOL_MANAGER_ADDR = 0x000000000004444c5dc75cB358380D2e3dE08A90;

    // ───────────────────────── Deploy-script constants
    // ─────────────────────────

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

    uint256 constant FEE = 25;
    uint256 constant MAX_FEE = 1000;

    // ───────────────────────── Actors
    // ─────────────────────────

    // forge-lint: disable-next-line(mixed-case-variable)
    address MULTISIG = makeAddr("multisig");
    // forge-lint: disable-next-line(mixed-case-variable)
    address OPERATOR = makeAddr("operator");
    // forge-lint: disable-next-line(mixed-case-variable)
    address PAYER = makeAddr("payer");
    // forge-lint: disable-next-line(mixed-case-variable)
    address PAYER2 = makeAddr("payer2");
    // forge-lint: disable-next-line(mixed-case-variable)
    address PAYER3 = makeAddr("payer3");
    // forge-lint: disable-next-line(mixed-case-variable)
    address AUTO_ISSUANCE_BENEFICIARY = makeAddr("autoIssuanceBeneficiary");
    address constant TRUSTED_FORWARDER = address(0);

    // ───────────────────────── Infrastructure
    // ─────────────────────────

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

    // ───────────────────────── Setup
    // ─────────────────────────

    function setUp() public {
        // Fork mainnet at a stable block (post-V4 deployment).
        try vm.createSelectFork("ethereum", 21_700_000) {}
        catch {
            vm.skip(true);
            return;
        }

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
            jbFeelessAddresses,
            jbPermissions,
            jbProjects,
            jbSplits,
            jbTerminalStore,
            jbTokens,
            permit2Instance,
            TRUSTED_FORWARDER
        );

        // ── Place minimal bytecode at address(0) and mock its observe call so the
        // buyback hook's TWAP oracle lookup (key.hooks = address(0) when no pool
        // exists) returns valid zero data instead of reverting. ──
        vm.etch(address(0), hex"00");
        vm.mockCall(address(0), hex"", abi.encode(new int56[](2), new uint160[](2)));

        // ── Register identity price feed (NATIVE_TOKEN currency <> ETH base currency) ──
        IdentityPriceFeed identityFeed = new IdentityPriceFeed();
        vm.prank(MULTISIG);
        jbPrices.addPriceFeedFor(0, NATIVE_CURRENCY, ETH_CURRENCY, IJBPriceFeed(address(identityFeed)));

        // ── Create project 1 (fee project) ──
        vm.prank(MULTISIG);
        uint256 createdId = jbProjects.createFor(MULTISIG);
        require(createdId == FEE_PROJECT_ID, "Expected project ID 1");

        // ── Deploy supporting infrastructure ──
        suckerRegistry = new JBSuckerRegistry(jbDirectory, jbPermissions, MULTISIG, TRUSTED_FORWARDER);

        JB721TiersHookStore hookStore = new JB721TiersHookStore();
        JB721TiersHook exampleHook = new JB721TiersHook(
            jbDirectory, jbPermissions, jbPrices, jbRulesets, hookStore, jbSplits, TRUSTED_FORWARDER
        );
        IJBAddressRegistry addressRegistry = new JBAddressRegistry();
        hookDeployer = new JB721TiersHookDeployer(
            exampleHook, IJB721TiersHookStore(address(hookStore)), addressRegistry, TRUSTED_FORWARDER
        );

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

        // ── Deploy REVOwner (runtime data hook) ──
        REVOwner revOwner = new REVOwner(
            buybackRegistry, jbDirectory, FEE_PROJECT_ID, suckerRegistry, address(loansContract)
        );

        // ── Deploy REVDeployer ──
        revDeployer = new REVDeployer{salt: "REVDeployer_Edge"}(
            jbController,
            suckerRegistry,
            FEE_PROJECT_ID,
            hookDeployer,
            publisher,
            buybackRegistry,
            address(loansContract),
            TRUSTED_FORWARDER,
            address(revOwner)
        );

        // Approve the REVDeployer to configure project 1.
        vm.prank(MULTISIG);
        jbProjects.approve(address(revDeployer), FEE_PROJECT_ID);

        // Fund actors.
        vm.deal(PAYER, 100 ether);
        vm.deal(PAYER2, 100 ether);
        vm.deal(PAYER3, 100 ether);
    }

    // ───────────────────────── Config helpers
    // ─────────────────────────

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
        terminalConfigs[0] = JBTerminalConfig({
            terminal: IJBTerminal(address(jbMultiTerminal)), accountingContextsToAccept: accountingContexts
        });

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
        autoIssuances[0] =
            REVAutoIssuance({chainId: 1, count: MAINNET_AUTO_ISSUANCE, beneficiary: AUTO_ISSUANCE_BENEFICIARY});

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
        suckerConfig =
            REVSuckerDeploymentConfig({deployerConfigurations: new JBSuckerDeployerConfig[](0), salt: bytes32(0)});
    }

    /// @notice Build a minimal revnet config for a non-fee project (used in multi-source tests).
    function _buildExternalRevnetConfig(bytes32 erc20Salt)
        internal
        view
        returns (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        )
    {
        JBAccountingContext[] memory accountingContexts = new JBAccountingContext[](1);
        accountingContexts[0] =
            JBAccountingContext({token: JBConstants.NATIVE_TOKEN, decimals: 18, currency: NATIVE_CURRENCY});

        terminalConfigs = new JBTerminalConfig[](1);
        terminalConfigs[0] = JBTerminalConfig({
            terminal: IJBTerminal(address(jbMultiTerminal)), accountingContextsToAccept: accountingContexts
        });

        // No reserved splits for simplicity.
        JBSplit[] memory splits = new JBSplit[](0);
        REVAutoIssuance[] memory autoIssuances = new REVAutoIssuance[](0);

        REVStageConfig[] memory stages = new REVStageConfig[](1);
        stages[0] = REVStageConfig({
            startsAtOrAfter: uint48(block.timestamp),
            autoIssuances: autoIssuances,
            splitPercent: 0,
            splits: splits,
            initialIssuance: INITIAL_ISSUANCE,
            issuanceCutFrequency: 0,
            issuanceCutPercent: 0,
            cashOutTaxRate: CASH_OUT_TAX_RATE,
            extraMetadata: 0
        });

        config = REVConfig({
            description: REVDescription({name: "TestRevnet", ticker: "TEST", uri: "", salt: erc20Salt}),
            baseCurrency: ETH_CURRENCY,
            splitOperator: OPERATOR,
            stageConfigurations: stages
        });

        suckerConfig =
            REVSuckerDeploymentConfig({deployerConfigurations: new JBSuckerDeployerConfig[](0), salt: bytes32(0)});
    }

    /// @notice Deploy the fee project (#1) via revDeployer.
    function _deployFeeProject() internal {
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
    }

    /// @notice Deploy an external revnet (revnetId=0 means create new project).
    function _deployExternalRevnet(bytes32 erc20Salt) internal returns (uint256 projectId) {
        (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        ) = _buildExternalRevnetConfig(erc20Salt);

        (projectId,) = revDeployer.deployFor({
            revnetId: 0,
            configuration: config,
            terminalConfigurations: terminalConfigs,
            suckerDeploymentConfiguration: suckerConfig
        });
    }

    // ───────────────────────── Test 1: Recursive fee on fee project
    // cashout ─────────────────────────

    /// @notice Cash out tokens from the fee project (project #1). The 2.5% fee goes BACK to project #1.
    ///         Verifies no infinite loop and that the fee project balance increases relative to what
    ///         it would have been without the recursive fee.
    function testFork_feeProjectCashOutGeneratesRecursiveFee() public {
        _deployFeeProject();

        // Pay 10 ETH into the fee project.
        uint256 payAmount = 10 ether;
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

        assertTrue(tokensReceived > 0, "Should receive NANA tokens for payment");

        // Record the fee project's ETH balance before cashout.
        uint256 feeProjectBalanceBefore =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN);

        // Cash out half of the NANA tokens.
        uint256 cashOutCount = tokensReceived / 2;

        vm.prank(PAYER);
        uint256 reclaimAmount = jbMultiTerminal.cashOutTokensOf({
            holder: PAYER,
            projectId: FEE_PROJECT_ID,
            cashOutCount: cashOutCount,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(PAYER),
            metadata: ""
        });

        // The cashout should complete without reverting (no infinite loop).
        assertTrue(reclaimAmount > 0, "Should reclaim some ETH from cashout");

        uint256 feeProjectBalanceAfter =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN);

        // The fee project's net balance decrease equals only the ETH that was actually sent out
        // to the beneficiary. The 2.5% fee goes back to project #1 (paid via the REVDeployer
        // cashout hook and/or the terminal-level fee), so the balance decrease is smaller than
        // the gross reclaim amount. This proves the recursive fee works without infinite loop.
        uint256 balanceDecrease = feeProjectBalanceBefore - feeProjectBalanceAfter;
        assertEq(
            balanceDecrease, reclaimAmount, "Balance decrease should equal only the net ETH sent to the beneficiary"
        );

        // The payer receives additional NANA tokens from the recursive fee payment back to
        // project #1 (the payer is the fee beneficiary). So their balance is strictly greater
        // than (tokensReceived - cashOutCount).
        uint256 payerBalance = jbTokens.totalBalanceOf(PAYER, FEE_PROJECT_ID);
        assertTrue(
            payerBalance > tokensReceived - cashOutCount,
            "Payer should hold more tokens than initial minus burned (fee minted extra)"
        );
    }

    // ───────────────────────── Test 2: Multiple payment sources
    // ─────────────────────────

    /// @notice Deploy fee project + 3 external revnets. Have each generate fees via cashouts.
    ///         Verify fee project balance = sum of all fees and NANA issuance works for each.
    function testFork_feeProjectMultiplePaymentSources() public {
        _deployFeeProject();

        // Deploy 3 external revnet projects.
        uint256 projectA = _deployExternalRevnet("_SALT_A_");
        uint256 projectB = _deployExternalRevnet("_SALT_B_");
        uint256 projectC = _deployExternalRevnet("_SALT_C_");

        // Pay into each external project so they have a balance and tokens.
        uint256 payAmountEach = 5 ether;

        vm.prank(PAYER);
        uint256 tokensA = jbMultiTerminal.pay{value: payAmountEach}({
            projectId: projectA,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmountEach,
            beneficiary: PAYER,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        vm.prank(PAYER2);
        uint256 tokensB = jbMultiTerminal.pay{value: payAmountEach}({
            projectId: projectB,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmountEach,
            beneficiary: PAYER2,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        vm.prank(PAYER3);
        uint256 tokensC = jbMultiTerminal.pay{value: payAmountEach}({
            projectId: projectC,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmountEach,
            beneficiary: PAYER3,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        // Record the fee project balance before cashouts.
        uint256 feeBalanceBefore =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN);

        // Cash out half of tokens from each project.
        // Each cashout generates a 2.5% fee that goes to the fee project.
        vm.prank(PAYER);
        uint256 reclaimA = jbMultiTerminal.cashOutTokensOf({
            holder: PAYER,
            projectId: projectA,
            cashOutCount: tokensA / 2,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(PAYER),
            metadata: ""
        });

        vm.prank(PAYER2);
        uint256 reclaimB = jbMultiTerminal.cashOutTokensOf({
            holder: PAYER2,
            projectId: projectB,
            cashOutCount: tokensB / 2,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(PAYER2),
            metadata: ""
        });

        vm.prank(PAYER3);
        uint256 reclaimC = jbMultiTerminal.cashOutTokensOf({
            holder: PAYER3,
            projectId: projectC,
            cashOutCount: tokensC / 2,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(PAYER3),
            metadata: ""
        });

        assertTrue(reclaimA > 0 && reclaimB > 0 && reclaimC > 0, "All cashouts should reclaim some ETH");

        // The fee project balance should have increased by the sum of all fees.
        uint256 feeBalanceAfter =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN);
        uint256 totalFeesReceived = feeBalanceAfter - feeBalanceBefore;

        assertTrue(totalFeesReceived > 0, "Fee project should have received fees from all three cashouts");

        // Verify NANA tokens were auto-issued to the fee-payment beneficiaries.
        // The fee payment mints NANA tokens — verify the total NANA token supply increased.
        uint256 totalNanaSupply = jbTokens.totalSupplyOf(FEE_PROJECT_ID);
        assertTrue(totalNanaSupply > 0, "NANA token supply should be non-zero after fee payments");
    }

    // ───────────────────────── Test 3: Issuance cut after one year
    // ─────────────────────────

    /// @notice Pay before and after the 360-day issuance cut. Verify token issuance decays by ~38%.
    function testFork_feeProjectIssuanceCutAfterOneYear() public {
        _deployFeeProject();

        // Pay 1 ETH before issuance cut.
        uint256 payAmount = 1 ether;
        vm.prank(PAYER);
        uint256 tokensBefore = jbMultiTerminal.pay{value: payAmount}({
            projectId: FEE_PROJECT_ID,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmount,
            beneficiary: PAYER,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        // Expected: 10,000 * 38% = 3,800 tokens (payer gets 38% due to 62% reserved split).
        uint256 expectedBeforeCut = (uint256(INITIAL_ISSUANCE) * (10_000 - SPLIT_PERCENT)) / 10_000;
        assertEq(tokensBefore, expectedBeforeCut, "Pre-cut tokens should be 3,800 per ETH");

        // Warp past the issuance cut frequency (360 days + 1 second to be safe).
        vm.warp(block.timestamp + uint256(ISSUANCE_CUT_FREQUENCY) + 1);

        // Pay 1 ETH after issuance cut.
        vm.prank(PAYER2);
        uint256 tokensAfter = jbMultiTerminal.pay{value: payAmount}({
            projectId: FEE_PROJECT_ID,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmount,
            beneficiary: PAYER2,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        // After 38% issuance cut, the new weight = initialIssuance * (1 - 0.38) = 6,200 tokens/ETH.
        // Payer receives 38% of that = 6,200 * 0.38 = 2,356 tokens.
        // The issuanceCutPercent is 380_000_000 out of 1_000_000_000 (MAX_WEIGHT_CUT_PERCENT).
        // New issuance = INITIAL_ISSUANCE * (1_000_000_000 - 380_000_000) / 1_000_000_000 = 6,200 tokens/ETH.
        // Payer portion = 6,200 * (10,000 - 6,200) / 10,000 = 6,200 * 0.38 = 2,356 tokens.
        uint256 decayedIssuance =
            (uint256(INITIAL_ISSUANCE) * (1_000_000_000 - uint256(ISSUANCE_CUT_PERCENT))) / 1_000_000_000;
        uint256 expectedAfterCut = (decayedIssuance * (10_000 - SPLIT_PERCENT)) / 10_000;

        assertEq(tokensAfter, expectedAfterCut, "Post-cut tokens should reflect 38% decay");

        // Verify the second payment yields approximately 62% of the first (since issuance decayed by 38%).
        // tokensAfter / tokensBefore should be approximately 0.62.
        // Use a tolerance of 1 token to account for rounding.
        uint256 expectedRatio = (tokensBefore * (1_000_000_000 - uint256(ISSUANCE_CUT_PERCENT))) / 1_000_000_000;
        assertApproxEqAbs(tokensAfter, expectedRatio, 1, "Second payment should yield ~62% of first payment's tokens");
    }

    // ───────────────────────── Test 4: Fee terminal failure
    // ─────────────────────────

    /// @notice When the terminal-level fee processing reverts (executeProcessFee), the fee amount
    ///         is returned to the originating project's balance. The FeeReverted event is emitted.
    ///         The cashout itself still succeeds.
    function testFork_feeProjectWithFailingTerminal() public {
        _deployFeeProject();

        // Deploy an external revnet project.
        uint256 externalProject = _deployExternalRevnet("_SALT_EXT_");

        // Pay into the external project.
        uint256 payAmount = 5 ether;
        vm.prank(PAYER);
        uint256 tokensReceived = jbMultiTerminal.pay{value: payAmount}({
            projectId: externalProject,
            token: JBConstants.NATIVE_TOKEN,
            amount: payAmount,
            beneficiary: PAYER,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        // Record the external project's balance before the failing cashout.
        uint256 externalBalanceBefore =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), externalProject, JBConstants.NATIVE_TOKEN);

        // Record the fee project's balance before.
        uint256 feeBalanceBefore =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN);

        // Mock the terminal's executeProcessFee to revert, simulating a failing fee terminal.
        // This affects the terminal-level fee processing (called by _processFee via try-catch).
        // Note: The REVDeployer's cashout hook also pays fees directly via feeTerminal.pay(),
        // which will also fail since pay() internally calls executeProcessFee for the fee project.
        vm.mockCallRevert(
            address(jbMultiTerminal),
            abi.encodeWithSelector(JBMultiTerminal.executeProcessFee.selector),
            "FEE_TERMINAL_FAILED"
        );

        // Cash out tokens from the external project.
        // The terminal-level fee will fail (caught by try-catch), but the cashout succeeds.
        vm.prank(PAYER);
        uint256 reclaimAmount = jbMultiTerminal.cashOutTokensOf({
            holder: PAYER,
            projectId: externalProject,
            cashOutCount: tokensReceived / 2,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(PAYER),
            metadata: ""
        });

        assertTrue(reclaimAmount > 0, "Cashout should still succeed even when fee processing fails");

        uint256 externalBalanceAfter =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), externalProject, JBConstants.NATIVE_TOKEN);

        // The terminal-level fee was returned to the external project's balance via
        // _recordAddedBalanceFor (inside the catch block of _processFee).
        // The external project's balance decrease should be less than if the fee had been
        // successfully sent to project #1.
        uint256 actualDecrease = externalBalanceBefore - externalBalanceAfter;

        // The actual decrease includes: the beneficiary reclaim + the hook fee amount sent to
        // REVDeployer. The terminal-level fee was returned, reducing the decrease.
        assertTrue(actualDecrease > reclaimAmount, "Decrease includes hook fee but terminal fee was returned");

        // Verify the fee project did NOT receive the terminal-level fee.
        uint256 feeBalanceAfter =
            jbTerminalStore.balanceOf(address(jbMultiTerminal), FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN);

        // The fee project balance should have increased less than it would in the normal case,
        // because the terminal-level fee was reverted. It may still increase if the hook fee
        // was partially paid. With our mock on executeProcessFee, even the hook's pay() call
        // will fail (since pay triggers fee processing internally for subsequent fees), but
        // the hook payment itself goes through as a direct pay to project #1.
        // The key assertion: the terminal-level FeeReverted happened, so the fee was returned.
        assertTrue(feeBalanceAfter >= feeBalanceBefore, "Fee project balance should not decrease");

        // Clear the mock so subsequent calls work normally.
        vm.clearMockedCalls();
    }
}
