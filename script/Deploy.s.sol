// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@bananapus/core-v5/script/helpers/CoreDeploymentLib.sol";
import "@bananapus/721-hook-v5/script/helpers/Hook721DeploymentLib.sol";
import "@bananapus/suckers-v5/script/helpers/SuckerDeploymentLib.sol";
import "@rev-net/core-v5/script/helpers/RevnetCoreDeploymentLib.sol";
import "@bananapus/buyback-hook-v5/script/helpers/BuybackDeploymentLib.sol";
import "@bananapus/swap-terminal-v5/script/helpers/SwapTerminalDeploymentLib.sol";

import {JBConstants} from "@bananapus/core-v5/src/libraries/JBConstants.sol";
import {JBAccountingContext} from "@bananapus/core-v5/src/structs/JBAccountingContext.sol";
import {JBTerminalConfig} from "@bananapus/core-v5/src/structs/JBTerminalConfig.sol";
import {JBSuckerDeployerConfig} from "@bananapus/suckers-v5/src/structs/JBSuckerDeployerConfig.sol";
import {JBTokenMapping} from "@bananapus/suckers-v5/src/structs/JBTokenMapping.sol";
import {REVAutoIssuance} from "@rev-net/core-v5/src/structs/REVAutoIssuance.sol";
import {REVBuybackHookConfig} from "@rev-net/core-v5/src/structs/REVBuybackHookConfig.sol";
import {REVBuybackPoolConfig} from "@rev-net/core-v5/src/structs/REVBuybackPoolConfig.sol";
import {REVConfig} from "@rev-net/core-v5/src/structs/REVConfig.sol";
import {REVCroptopAllowedPost} from "@rev-net/core-v5/src/structs/REVCroptopAllowedPost.sol";
import {REVDescription} from "@rev-net/core-v5/src/structs/REVDescription.sol";
import {REVLoanSource} from "@rev-net/core-v5/src/structs/REVLoanSource.sol";
import {REVStageConfig} from "@rev-net/core-v5/src/structs/REVStageConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core-v5/src/structs/REVSuckerDeploymentConfig.sol";
import {IJBTerminal} from "@bananapus/core-v5/src/interfaces/IJBTerminal.sol";
import {JBSplit} from "@bananapus/core-v5/src/structs/JBSplit.sol";
import {IJBSplitHook} from "@bananapus/core-v5/src/interfaces/IJBSplitHook.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

struct FeeProjectConfig {
    REVConfig configuration;
    JBTerminalConfig[] terminalConfigurations;
    REVBuybackHookConfig buybackHookConfiguration;
    REVSuckerDeploymentConfig suckerDeploymentConfiguration;
}

contract DeployScript is Script, Sphinx {
    /// @notice tracks the deployment of the buyback hook.
    BuybackDeployment buybackHook;
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;
    /// @notice tracks the deployment of the 721 hook contracts for the chain we are deploying to.
    Hook721Deployment hook;
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the sucker contracts for the chain we are deploying to.
    SuckerDeployment suckers;
    /// @notice tracks the deployment of the swap terminal.
    SwapTerminalDeployment swapTerminal;

    FeeProjectConfig feeProjectConfig;

    bytes32 ERC20_SALT = "_NANA_ERC20_SALT_";
    bytes32 SUCKER_SALT = "_NANA_SUCKER_SALT_";
    string NAME = "Bananapus (Juicebox V5)";
    string SYMBOL = "NANA";
    string PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ";
    uint32 NATIVE_CURRENCY = uint32(uint160(JBConstants.NATIVE_TOKEN));
    uint32 ETH_CURRENCY = 1; // JBCurrencyIds.ETH.
    uint8 DECIMALS = 18;
    uint256 DECIMAL_MULTIPLIER = 10 ** DECIMALS;
    uint256 NANA_START_TIME = 1739836991;
    uint256 NANA_MAINNET_AUTO_ISSUANCE_ = 957932309500316260835082;
    uint256 NANA_BASE_AUTO_ISSUANCE_ = 1000000000000000000000000;
    uint256 NANA_OP_AUTO_ISSUANCE_ = 1000000000000000000000000;
    uint256 NANA_ARB_AUTO_ISSUANCE_ = 1000000000000000000000000;

    address OPERATOR;
    address TRUSTED_FORWARDER;

    function configureSphinx() public override {
        sphinxConfig.projectName = "nana-core-v5";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core-v5/deployments/"))
        );
        // Get the deployment addresses for the suckers contracts for this chain.
        suckers = SuckerDeploymentLib.getDeployment(
            vm.envOr("NANA_SUCKERS_DEPLOYMENT_PATH", string("node_modules/@bananapus/suckers-v5/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        revnet = RevnetCoreDeploymentLib.getDeployment(
            vm.envOr("REVNET_CORE_DEPLOYMENT_PATH", string("node_modules/@rev-net/core-v5/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        hook = Hook721DeploymentLib.getDeployment(
            vm.envOr("NANA_721_DEPLOYMENT_PATH", string("node_modules/@bananapus/721-hook-v5/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        buybackHook = BuybackDeploymentLib.getDeployment(
            vm.envOr("NANA_BUYBACK_HOOK_DEPLOYMENT_PATH", string("node_modules/@bananapus/buyback-hook-v5/deployments/"))
        );
        // Get the deployment addresses for the 721 hook contracts for this chain.
        swapTerminal = SwapTerminalDeploymentLib.getDeployment(
            vm.envOr("NANA_SWAP_TERMINAL_DEPLOYMENT_PATH", string("node_modules/@bananapus/swap-terminal-v5/deployments/"))
        );

        // Set the operator address to be the multisig.
        OPERATOR = safeAddress();
        TRUSTED_FORWARDER = core.controller.trustedForwarder();

        feeProjectConfig = getNANARevnetConfig();

        // Perform the deployment transactions.
        deploy();
    }

    function getNANARevnetConfig() internal view returns (FeeProjectConfig memory) {
        // The tokens that the project accepts and stores.
        JBAccountingContext[] memory accountingContextsToAccept = new JBAccountingContext[](1);

        // Accept the chain's native currency through the multi terminal.
        accountingContextsToAccept[0] =
            JBAccountingContext({token: JBConstants.NATIVE_TOKEN, decimals: 18, currency: NATIVE_CURRENCY});

        // The terminals that the project will accept funds through.
        JBTerminalConfig[] memory terminalConfigurations = new JBTerminalConfig[](2);
        terminalConfigurations[0] =
            JBTerminalConfig({terminal: core.terminal, accountingContextsToAccept: accountingContextsToAccept});
        terminalConfigurations[1] = JBTerminalConfig({
            terminal: IJBTerminal(address(swapTerminal.swap_terminal)),
            accountingContextsToAccept: new JBAccountingContext[](0)
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

        REVAutoIssuance[] memory issuanceConfs = new REVAutoIssuance[](4);
        issuanceConfs[0] = REVAutoIssuance({
            chainId: 1,
            count: NANA_MAINNET_AUTO_ISSUANCE_,
            beneficiary: OPERATOR
        });
        issuanceConfs[1] = REVAutoIssuance({
            chainId: 8453,
            count: NANA_BASE_AUTO_ISSUANCE_,
            beneficiary: OPERATOR
        });
        issuanceConfs[2] = REVAutoIssuance({
            chainId: 10,
            count: NANA_OP_AUTO_ISSUANCE_,
            beneficiary: OPERATOR
        });
        issuanceConfs[3] = REVAutoIssuance({
            chainId: 42161,
            count: NANA_ARB_AUTO_ISSUANCE_,
            beneficiary: OPERATOR
        });
        // The project's revnet stage configurations.
        REVStageConfig[] memory stageConfigurations = new REVStageConfig[](1);
        stageConfigurations[0] = REVStageConfig({
            startsAtOrAfter: NANA_START_TIME,
            autoIssuances: issuanceConfs,
            splitPercent: 6200, // 62%
            splits: splits,
            initialIssuance: uint112(10_000 * DECIMAL_MULTIPLIER),
            issuanceCutFrequency: 360 days,
            issuanceCutPercent: 380_000_000, // 38%
            cashOutTaxRate: 1000, // 0.1
            extraMetadata: 4 // Allow adding suckers.
        });

        REVConfig memory revnetConfiguration;
        {
            REVLoanSource[] memory _loanSources = new REVLoanSource[](1);
            _loanSources[0] = REVLoanSource({token: JBConstants.NATIVE_TOKEN, terminal: core.terminal});

            // The project's revnet configuration
            revnetConfiguration = REVConfig({
                description: REVDescription(NAME, SYMBOL, PROJECT_URI, ERC20_SALT),
                baseCurrency: ETH_CURRENCY,
                splitOperator: OPERATOR,
                stageConfigurations: stageConfigurations,
                loanSources: _loanSources,
                loans: address(revnet.loans)
            });
        }

        // The project's buyback hook configuration.
        REVBuybackPoolConfig[] memory buybackPoolConfigurations = new REVBuybackPoolConfig[](1);
        buybackPoolConfigurations[0] = REVBuybackPoolConfig({
            token: JBConstants.NATIVE_TOKEN,
            fee: 10_000,
            twapWindow: 2 days,
            twapSlippageTolerance: 9000
        });
        REVBuybackHookConfig memory buybackHookConfiguration =
            REVBuybackHookConfig({hook: buybackHook.hook, poolConfigurations: buybackPoolConfigurations});

        // Organize the instructions for how this project will connect to other chains.
        JBTokenMapping[] memory tokenMappings = new JBTokenMapping[](1);
        tokenMappings[0] = JBTokenMapping({
            localToken: JBConstants.NATIVE_TOKEN,
            remoteToken: JBConstants.NATIVE_TOKEN,
            minGas: 200_000,
            minBridgeAmount: 0.01 ether
        });

        JBSuckerDeployerConfig[] memory suckerDeployerConfigurations;
        if (block.chainid == 1 || block.chainid == 11_155_111) {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](3);
            // OP
            suckerDeployerConfigurations[0] =
                JBSuckerDeployerConfig({deployer: suckers.optimismDeployer, mappings: tokenMappings});

            suckerDeployerConfigurations[1] =
                JBSuckerDeployerConfig({deployer: suckers.baseDeployer, mappings: tokenMappings});

            suckerDeployerConfigurations[2] =
                JBSuckerDeployerConfig({deployer: suckers.arbitrumDeployer, mappings: tokenMappings});
        } else {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](1);
            // L2 -> Mainnet
            suckerDeployerConfigurations[0] = JBSuckerDeployerConfig({
                deployer: address(suckers.optimismDeployer) != address(0)
                    ? suckers.optimismDeployer
                    : address(suckers.baseDeployer) != address(0) ? suckers.baseDeployer : suckers.arbitrumDeployer,
                mappings: tokenMappings
            });

            if (address(suckerDeployerConfigurations[0].deployer) == address(0)) {
                revert("L2 > L1 Sucker is not configured");
            }
        }

        // Specify all sucker deployments.
        REVSuckerDeploymentConfig memory suckerDeploymentConfiguration =
            REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: SUCKER_SALT});

        return FeeProjectConfig({
            configuration: revnetConfiguration,
            terminalConfigurations: terminalConfigurations,
            buybackHookConfiguration: buybackHookConfiguration,
            suckerDeploymentConfiguration: suckerDeploymentConfiguration
        });
    }

    function deploy() public sphinx {
        uint256 FEE_PROJECT_ID = 1;

        // Approve the basic deployer to configure the project.
        core.projects.approve(address(revnet.basic_deployer), FEE_PROJECT_ID);

        // Deploy the NANA fee project.
        revnet.basic_deployer.deployFor({
            revnetId: FEE_PROJECT_ID,
            configuration: feeProjectConfig.configuration,
            terminalConfigurations: feeProjectConfig.terminalConfigurations,
            buybackHookConfiguration: feeProjectConfig.buybackHookConfiguration,
            suckerDeploymentConfiguration: feeProjectConfig.suckerDeploymentConfiguration
        });
    }
}
