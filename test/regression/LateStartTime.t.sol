// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBAccountingContext} from "@bananapus/core-v6/src/structs/JBAccountingContext.sol";
import {JBTerminalConfig} from "@bananapus/core-v6/src/structs/JBTerminalConfig.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {IJBTerminal} from "@bananapus/core-v6/src/interfaces/IJBTerminal.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";
import {JBSuckerDeployerConfig} from "@bananapus/suckers-v6/src/structs/JBSuckerDeployerConfig.sol";
import {REVAutoIssuance} from "@rev-net/core-v6/src/structs/REVAutoIssuance.sol";
import {REVConfig} from "@rev-net/core-v6/src/structs/REVConfig.sol";
import {REVDescription} from "@rev-net/core-v6/src/structs/REVDescription.sol";
import {REVStageConfig} from "@rev-net/core-v6/src/structs/REVStageConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core-v6/src/structs/REVSuckerDeploymentConfig.sol";

import {FeeProjectEdgeCases} from "../FeeProjectEdgeCases.t.sol";

contract LateStartTimeRegressionTest is FeeProjectEdgeCases {
    uint48 internal constant SCRIPT_NANA_START_TIME = 1_740_089_444; // 2025-02-20 22:10:44 UTC
    uint256 internal constant LATE_DEPLOY_TS = 1_774_915_200; // 2026-03-31 00:00:00 UTC

    function test_regression_lateDeploymentStartsWithDecayedIssuance() public {
        vm.warp(LATE_DEPLOY_TS);

        JBAccountingContext[] memory accountingContexts = new JBAccountingContext[](1);
        accountingContexts[0] =
            JBAccountingContext({token: JBConstants.NATIVE_TOKEN, decimals: 18, currency: NATIVE_CURRENCY});

        JBTerminalConfig[] memory terminalConfigs = new JBTerminalConfig[](1);
        terminalConfigs[0] = JBTerminalConfig({
            terminal: IJBTerminal(address(jbMultiTerminal)), accountingContextsToAccept: accountingContexts
        });

        JBSplit[] memory splits = new JBSplit[](1);
        splits[0] = JBSplit({
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(OPERATOR),
            preferAddToBalance: false,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        REVAutoIssuance[] memory autoIssuances = new REVAutoIssuance[](1);
        autoIssuances[0] =
            REVAutoIssuance({chainId: 1, count: MAINNET_AUTO_ISSUANCE, beneficiary: AUTO_ISSUANCE_BENEFICIARY});

        REVStageConfig[] memory stages = new REVStageConfig[](1);
        stages[0] = REVStageConfig({
            startsAtOrAfter: SCRIPT_NANA_START_TIME,
            autoIssuances: autoIssuances,
            splitPercent: SPLIT_PERCENT,
            splits: splits,
            initialIssuance: INITIAL_ISSUANCE,
            issuanceCutFrequency: ISSUANCE_CUT_FREQUENCY,
            issuanceCutPercent: ISSUANCE_CUT_PERCENT,
            cashOutTaxRate: CASH_OUT_TAX_RATE,
            extraMetadata: 4
        });

        REVConfig memory config = REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT}),
            baseCurrency: ETH_CURRENCY,
            splitOperator: OPERATOR,
            stageConfigurations: stages
        });

        REVSuckerDeploymentConfig memory suckerConfig =
            REVSuckerDeploymentConfig({deployerConfigurations: new JBSuckerDeployerConfig[](0), salt: bytes32(0)});

        vm.prank(MULTISIG);
        revDeployer.deployFor({
            revnetId: FEE_PROJECT_ID,
            configuration: config,
            terminalConfigurations: terminalConfigs,
            suckerDeploymentConfiguration: suckerConfig
        });

        vm.prank(PAYER);
        uint256 tokens = jbMultiTerminal.pay{value: 1 ether}({
            projectId: FEE_PROJECT_ID,
            token: JBConstants.NATIVE_TOKEN,
            amount: 1 ether,
            beneficiary: PAYER,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });

        uint256 initialPayerTokens = (uint256(INITIAL_ISSUANCE) * (10_000 - SPLIT_PERCENT)) / 10_000;
        uint256 decayedIssuance =
            (uint256(INITIAL_ISSUANCE) * (1_000_000_000 - uint256(ISSUANCE_CUT_PERCENT))) / 1_000_000_000;
        uint256 decayedPayerTokens = (decayedIssuance * (10_000 - SPLIT_PERCENT)) / 10_000;

        assertEq(tokens, decayedPayerTokens, "late deployment should already use the decayed issuance");
        assertLt(tokens, initialPayerTokens, "late deployment should not mint at the advertised launch issuance");
    }
}
