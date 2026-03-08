// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@bananapus/core-v6/script/helpers/CoreDeploymentLib.sol";
import "@bananapus/suckers-v6/script/helpers/SuckerDeploymentLib.sol";
import "@rev-net/core-v6/script/helpers/RevnetCoreDeploymentLib.sol";
import "@bananapus/router-terminal-v6/script/helpers/RouterTerminalDeploymentLib.sol";

import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";
import {JBAccountingContext} from "@bananapus/core-v6/src/structs/JBAccountingContext.sol";
import {JBTerminalConfig} from "@bananapus/core-v6/src/structs/JBTerminalConfig.sol";
import {JBSuckerDeployerConfig} from "@bananapus/suckers-v6/src/structs/JBSuckerDeployerConfig.sol";
import {JBTokenMapping} from "@bananapus/suckers-v6/src/structs/JBTokenMapping.sol";
import {REVAutoIssuance} from "@rev-net/core-v6/src/structs/REVAutoIssuance.sol";
import {REVConfig} from "@rev-net/core-v6/src/structs/REVConfig.sol";
import {REVDescription} from "@rev-net/core-v6/src/structs/REVDescription.sol";
import {REVStageConfig} from "@rev-net/core-v6/src/structs/REVStageConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core-v6/src/structs/REVSuckerDeploymentConfig.sol";
import {IJBTerminal} from "@bananapus/core-v6/src/interfaces/IJBTerminal.sol";
import {JBSplit} from "@bananapus/core-v6/src/structs/JBSplit.sol";
import {IJBSplitHook} from "@bananapus/core-v6/src/interfaces/IJBSplitHook.sol";

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

contract DeployScript is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the sucker contracts for the chain we are deploying to.
    SuckerDeployment suckers;
    /// @notice tracks the deployment of the router terminal.
    RouterTerminalDeployment routerTerminal;

    bytes32 ERC20_SALT = "_NANA_ERC20_SALTV6__";
    bytes32 SUCKER_SALT = "_NANA_SUCKER_SALTV6__";
    string NAME = "Bananapus (Juicebox V6)";
    string SYMBOL = "NANA";
    string PROJECT_URI = "ipfs://QmWCgCaryfsJYBu5LczFuBz3UKK5VEU3BZFYp2mHJTLeRQ";
    uint32 NATIVE_CURRENCY = uint32(uint160(JBConstants.NATIVE_TOKEN));
    uint32 ETH_CURRENCY = JBCurrencyIds.ETH;
    uint8 DECIMALS = 18;
    uint256 DECIMAL_MULTIPLIER = 10 ** DECIMALS;
    uint48 NANA_START_TIME = 1_740_089_444;
    uint104 NANA_MAINNET_AUTO_ISSUANCE = 34_614_774_622_547_324_824_200;
    uint104 NANA_BASE_AUTO_ISSUANCE = 1_604_412_323_715_200_204_800;
    uint104 NANA_OP_AUTO_ISSUANCE = 6_266_215_368_602_910_600;
    uint104 NANA_ARB_AUTO_ISSUANCE = 105_160_496_145_000_000;

    address OPERATOR;

    function configureSphinx() public override {
        // TODO: Update to contain revnet devs.
        sphinxConfig.projectName = "nana-core-v6";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core-v6/deployments/"))
        );
        // Get the deployment addresses for the suckers contracts for this chain.
        suckers = SuckerDeploymentLib.getDeployment(
            vm.envOr("NANA_SUCKERS_DEPLOYMENT_PATH", string("node_modules/@bananapus/suckers-v6/deployments/"))
        );
        // Get the deployment addresses for the revnet core contracts for this chain.
        revnet = RevnetCoreDeploymentLib.getDeployment(
            vm.envOr("REVNET_CORE_DEPLOYMENT_PATH", string("node_modules/@rev-net/core-v6/deployments/"))
        );
        // Get the deployment addresses for the swap terminal contracts for this chain.
        routerTerminal = RouterTerminalDeploymentLib.getDeployment(
            vm.envOr(
                "NANA_ROUTER_TERMINAL_DEPLOYMENT_PATH",
                string("node_modules/@bananapus/router-terminal-v6/deployments/")
            )
        );

        // Set the operator address to be the multisig.
        OPERATOR = safeAddress();

        // Perform the deployment transactions.
        deploy();
    }

    function deploy() public sphinx {
        uint256 FEE_PROJECT_ID = 1;

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
            terminal: IJBTerminal(address(routerTerminal.registry)),
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
        issuanceConfs[0] = REVAutoIssuance({chainId: 1, count: NANA_MAINNET_AUTO_ISSUANCE, beneficiary: OPERATOR});
        issuanceConfs[1] = REVAutoIssuance({chainId: 8453, count: NANA_BASE_AUTO_ISSUANCE, beneficiary: OPERATOR});
        issuanceConfs[2] = REVAutoIssuance({chainId: 10, count: NANA_OP_AUTO_ISSUANCE, beneficiary: OPERATOR});
        issuanceConfs[3] = REVAutoIssuance({chainId: 42_161, count: NANA_ARB_AUTO_ISSUANCE, beneficiary: OPERATOR});
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

        // The project's revnet configuration
        REVConfig memory revnetConfiguration = REVConfig({
            description: REVDescription({name: NAME, ticker: SYMBOL, uri: PROJECT_URI, salt: ERC20_SALT}),
            baseCurrency: ETH_CURRENCY,
            splitOperator: OPERATOR,
            stageConfigurations: stageConfigurations
        });

        // Organize the instructions for how this project will connect to other chains.
        JBTokenMapping[] memory tokenMappings = new JBTokenMapping[](1);
        tokenMappings[0] = JBTokenMapping({
            localToken: JBConstants.NATIVE_TOKEN,
            minGas: 200_000,
            remoteToken: bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN))),
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

        // Approve the basic deployer to configure the project.
        core.projects.approve({to: address(revnet.basic_deployer), tokenId: FEE_PROJECT_ID});

        // Deploy the NANA fee project.
        revnet.basic_deployer
            .deployFor({
                revnetId: FEE_PROJECT_ID,
                configuration: revnetConfiguration,
                terminalConfigurations: terminalConfigurations,
                suckerDeploymentConfiguration: suckerDeploymentConfiguration
            });
    }
}
