// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CoreDeployment, CoreDeploymentLib} from "@bananapus/core-v6/script/helpers/CoreDeploymentLib.sol";
import {SuckerDeployment, SuckerDeploymentLib} from "@bananapus/suckers-v6/script/helpers/SuckerDeploymentLib.sol";
import {
    RevnetCoreDeployment,
    RevnetCoreDeploymentLib
} from "@rev-net/core-v6/script/helpers/RevnetCoreDeploymentLib.sol";
import {
    RouterTerminalDeployment,
    RouterTerminalDeploymentLib
} from "@bananapus/router-terminal-v6/script/helpers/RouterTerminalDeploymentLib.sol";

import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";
import {JBSplitGroupIds} from "@bananapus/core-v6/src/libraries/JBSplitGroupIds.sol";
import {JBAccountingContext} from "@bananapus/core-v6/src/structs/JBAccountingContext.sol";
import {JBRuleset} from "@bananapus/core-v6/src/structs/JBRuleset.sol";
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

import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

contract DeployScript is Script, Sphinx {
    error DeployScript_FeeProjectNotCanonical(uint256 projectId);

    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;
    /// @notice tracks the deployment of the revnet contracts for the chain we are deploying to.
    RevnetCoreDeployment revnet;
    /// @notice tracks the deployment of the sucker contracts for the chain we are deploying to.
    SuckerDeployment suckers;
    /// @notice tracks the deployment of the router terminal.
    RouterTerminalDeployment routerTerminal;

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

    address operator;

    function configureSphinx() public override {
        // Safe owners and threshold are resolved by the Sphinx project config.
        sphinxConfig.projectName = "nana-fee-project";
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
        // Get the deployment addresses for the router terminal contracts for this chain.
        routerTerminal = RouterTerminalDeploymentLib.getDeployment(
            vm.envOr(
                "NANA_ROUTER_TERMINAL_DEPLOYMENT_PATH",
                string("node_modules/@bananapus/router-terminal-v6/deployments/")
            )
        );

        // Set the operator address to the canonical NANA operator.
        operator = 0x80a8F7a4bD75b539CE26937016Df607fdC9ABeb5;

        // Perform the deployment transactions.
        deploy();
    }

    function deploy() public sphinx {
        uint256 feeProjectId = 1;

        // The tokens that the project accepts and stores.
        JBAccountingContext[] memory accountingContextsToAccept = new JBAccountingContext[](1);

        // Accept the chain's native currency through the multi terminal.
        accountingContextsToAccept[0] =
            JBAccountingContext({token: JBConstants.NATIVE_TOKEN, decimals: 18, currency: NATIVE_CURRENCY});

        JBSplit[] memory splits = new JBSplit[](1);
        splits[0] = JBSplit({
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(operator),
            preferAddToBalance: false,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // All chains in a set (mainnet or testnet) must write the same auto-issuance entries so the ruleset hash
        // matches across chains. Use block.chainid only to pick which set of chain IDs to use.
        bool isTestnet = block.chainid == 11_155_111 || block.chainid == 11_155_420 || block.chainid == 84_532
            || block.chainid == 421_614;

        REVAutoIssuance[] memory issuanceConfs = new REVAutoIssuance[](4);
        issuanceConfs[0] = REVAutoIssuance({
            chainId: isTestnet ? uint32(11_155_111) : uint32(1),
            count: NANA_MAINNET_AUTO_ISSUANCE,
            beneficiary: operator
        });
        issuanceConfs[1] = REVAutoIssuance({
            chainId: isTestnet ? uint32(84_532) : uint32(8453), count: NANA_BASE_AUTO_ISSUANCE, beneficiary: operator
        });
        issuanceConfs[2] = REVAutoIssuance({
            chainId: isTestnet ? uint32(11_155_420) : uint32(10), count: NANA_OP_AUTO_ISSUANCE, beneficiary: operator
        });
        issuanceConfs[3] = REVAutoIssuance({
            chainId: isTestnet ? uint32(421_614) : uint32(42_161), count: NANA_ARB_AUTO_ISSUANCE, beneficiary: operator
        });
        // The project's revnet stage configurations.
        REVStageConfig[] memory stageConfigurations = new REVStageConfig[](1);
        stageConfigurations[0] = REVStageConfig({
            startsAtOrAfter: NANA_START_TIME,
            autoIssuances: issuanceConfs,
            splitPercent: 6200, // 62%
            splits: splits,
            // forge-lint: disable-next-line(unsafe-typecast)
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
            operator: operator,
            scopeCashOutsToLocalBalances: false,
            stageConfigurations: stageConfigurations
        });

        // Organize the instructions for how this project will connect to other chains.
        JBTokenMapping[] memory tokenMappings = new JBTokenMapping[](1);
        tokenMappings[0] = JBTokenMapping({
            localToken: JBConstants.NATIVE_TOKEN,
            minGas: 200_000,
            remoteToken: bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))
        });

        JBSuckerDeployerConfig[] memory suckerDeployerConfigurations;
        if (block.chainid == 1 || block.chainid == 11_155_111) {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](3);
            // OP
            suckerDeployerConfigurations[0] =
                JBSuckerDeployerConfig({deployer: suckers.optimismDeployer, peer: bytes32(0), mappings: tokenMappings});

            suckerDeployerConfigurations[1] =
                JBSuckerDeployerConfig({deployer: suckers.baseDeployer, peer: bytes32(0), mappings: tokenMappings});

            suckerDeployerConfigurations[2] =
                JBSuckerDeployerConfig({deployer: suckers.arbitrumDeployer, peer: bytes32(0), mappings: tokenMappings});
        } else {
            suckerDeployerConfigurations = new JBSuckerDeployerConfig[](1);
            // L2 -> Mainnet
            suckerDeployerConfigurations[0] = JBSuckerDeployerConfig({
                deployer: address(suckers.optimismDeployer) != address(0)
                    ? suckers.optimismDeployer
                    : address(suckers.baseDeployer) != address(0) ? suckers.baseDeployer : suckers.arbitrumDeployer,
                peer: bytes32(0),
                mappings: tokenMappings
            });

            if (address(suckerDeployerConfigurations[0].deployer) == address(0)) {
                revert("L2 > L1 Sucker is not configured");
            }
        }

        // Specify all sucker deployments.
        REVSuckerDeploymentConfig memory suckerDeploymentConfiguration =
            REVSuckerDeploymentConfig({deployerConfigurations: suckerDeployerConfigurations, salt: SUCKER_SALT});

        bytes32 expectedConfigurationHash = _encodedConfigurationHashOf({configuration: revnetConfiguration});

        // Skip deployment only if the fee project is already the canonical NANA revnet.
        if (address(core.controller.DIRECTORY().controllerOf(feeProjectId)) != address(0)) {
            if (!_feeProjectIsCanonical({
                    feeProjectId: feeProjectId,
                    expectedConfigurationHash: expectedConfigurationHash,
                    expectedOperator: operator
                })) revert DeployScript_FeeProjectNotCanonical(feeProjectId);
            return;
        }

        // Approve the basic deployer to configure the project.
        core.projects.approve({to: address(revnet.basicDeployer), tokenId: feeProjectId});

        // Deploy the NANA fee project.
        revnet.basicDeployer
            .deployFor({
                revnetId: feeProjectId,
                configuration: revnetConfiguration,
                accountingContextsToAccept: accountingContextsToAccept,
                suckerDeploymentConfiguration: suckerDeploymentConfiguration
            });
    }

    function _feeProjectIsCanonical(
        uint256 feeProjectId,
        bytes32 expectedConfigurationHash,
        address expectedOperator
    )
        internal
        view
        returns (bool)
    {
        // `REVDeployer.deployFor` permanently forwards the project NFT to the REVOwner contract, which is the
        // project's authoritative owner after deployment. A re-run against an already-deployed fee project must
        // recognize ownership by that contract as canonical (so the script cleanly no-ops on replay).
        if (core.projects.ownerOf(feeProjectId) != address(revnet.owner)) return false;
        if (address(core.controller.DIRECTORY().controllerOf(feeProjectId)) != address(core.controller)) return false;
        if (revnet.basicDeployer.FEE_REVNET_ID() != feeProjectId) return false;
        if (revnet.basicDeployer.hashedEncodedConfigurationOf(feeProjectId) != expectedConfigurationHash) {
            return false;
        }
        if (!revnet.owner.isOperatorOf({revnetId: feeProjectId, addr: expectedOperator})) return false;
        if (!_projectTokenSymbolIs({projectId: feeProjectId, expectedSymbol: SYMBOL})) return false;
        if (keccak256(bytes(core.controller.uriOf(feeProjectId))) != keccak256(bytes(PROJECT_URI))) return false;
        if (!_reservedSplitIsCanonical({projectId: feeProjectId, expectedBeneficiary: payable(expectedOperator)})) {
            return false;
        }
        if (!_nativeTerminalConfigIsCanonical(feeProjectId)) return false;
        return true;
    }

    function _encodedConfigurationHashOf(REVConfig memory configuration) internal view returns (bytes32) {
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

    function _reservedSplitIsCanonical(
        uint256 projectId,
        address payable expectedBeneficiary
    )
        internal
        view
        returns (bool)
    {
        (JBRuleset memory ruleset,) = core.controller.currentRulesetOf(projectId);
        JBSplit[] memory reservedSplits =
            core.controller.SPLITS().splitsOf(projectId, ruleset.id, JBSplitGroupIds.RESERVED_TOKENS);

        if (reservedSplits.length != 1) return false;

        JBSplit memory split = reservedSplits[0];
        if (split.percent != JBConstants.SPLITS_TOTAL_PERCENT) return false;
        if (split.projectId != 0) return false;
        if (split.beneficiary != expectedBeneficiary) return false;
        if (split.preferAddToBalance) return false;
        if (split.lockedUntil != 0) return false;
        if (address(split.hook) != address(0)) return false;

        return true;
    }

    function _nativeTerminalConfigIsCanonical(uint256 projectId) internal view returns (bool) {
        if (core.controller.DIRECTORY().primaryTerminalOf(projectId, JBConstants.NATIVE_TOKEN) != core.terminal) {
            return false;
        }
        if (!core.controller.DIRECTORY().isTerminalOf(projectId, IJBTerminal(address(routerTerminal.registry)))) {
            return false;
        }

        JBAccountingContext memory accountingContext =
            core.terminal.accountingContextForTokenOf({projectId: projectId, token: JBConstants.NATIVE_TOKEN});

        if (accountingContext.token != JBConstants.NATIVE_TOKEN) return false;
        if (accountingContext.decimals != DECIMALS) return false;
        if (accountingContext.currency != NATIVE_CURRENCY) return false;

        return true;
    }

    function _projectTokenSymbolIs(uint256 projectId, string memory expectedSymbol) internal view returns (bool) {
        address token = address(core.tokens.tokenOf(projectId));
        if (token == address(0)) return false;

        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("symbol()"));
        if (!success || data.length < 32) return false;

        return keccak256(bytes(abi.decode(data, (string)))) == keccak256(bytes(expectedSymbol));
    }
}
