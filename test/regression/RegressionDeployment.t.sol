// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {REVConfig} from "@rev-net/core-v6/src/structs/REVConfig.sol";
import {JBTerminalConfig} from "@bananapus/core-v6/src/structs/JBTerminalConfig.sol";
import {REVSuckerDeploymentConfig} from "@rev-net/core-v6/src/structs/REVSuckerDeploymentConfig.sol";

import {FeeProjectConfigBuilder} from "../TestFeeProjectDeployer.sol";
import {FeeProjectEdgeCases} from "../FeeProjectEdgeCases.t.sol";

contract RegressionOperatorDriftTest is Test {
    address internal constant CANONICAL_NANA_OPERATOR = 0x80a8F7a4bD75b539CE26937016Df607fdC9ABeb5;

    FeeProjectConfigBuilder internal builder;

    function setUp() public {
        builder = new FeeProjectConfigBuilder();
    }

    function test_safeDerivedOperatorDriftsFromCanonicalNanaOperator() public {
        address sphinxSafe = makeAddr("sphinxSafe");
        vm.assume(sphinxSafe != CANONICAL_NANA_OPERATOR);

        REVConfig memory deployedByThisRepo = builder.buildRevnetConfiguration(sphinxSafe);
        REVConfig memory canonicalDeployment = builder.buildRevnetConfiguration(CANONICAL_NANA_OPERATOR);

        assertEq(deployedByThisRepo.splitOperator, sphinxSafe, "current script routes split operator to the Safe");
        assertEq(
            deployedByThisRepo.stageConfigurations[0].splits[0].beneficiary,
            sphinxSafe,
            "reserved tokens route to the Safe"
        );
        assertEq(
            deployedByThisRepo.stageConfigurations[0].autoIssuances[0].beneficiary,
            sphinxSafe,
            "auto-issuance beneficiary routes to the Safe"
        );

        assertEq(canonicalDeployment.splitOperator, CANONICAL_NANA_OPERATOR, "canonical deploy-all operator");
        assertEq(
            canonicalDeployment.stageConfigurations[0].splits[0].beneficiary,
            CANONICAL_NANA_OPERATOR,
            "canonical reserved-token beneficiary"
        );
        assertEq(
            canonicalDeployment.stageConfigurations[0].autoIssuances[0].beneficiary,
            CANONICAL_NANA_OPERATOR,
            "canonical auto-issuance beneficiary"
        );

        assertTrue(
            deployedByThisRepo.splitOperator != canonicalDeployment.splitOperator,
            "using safeAddress changes the fee project's operator surface"
        );
    }
}

contract RegressionReplayNotIdempotentTest is FeeProjectEdgeCases {
    function test_secondFeeProjectDeploymentReverts() public {
        _deployFeeProject();

        (
            REVConfig memory config,
            JBTerminalConfig[] memory terminalConfigs,
            REVSuckerDeploymentConfig memory suckerConfig
        ) = _buildFeeProjectConfig();

        vm.prank(MULTISIG);
        vm.expectRevert(abi.encodeWithSignature("REVDeployer_Unauthorized(uint256,address)", FEE_PROJECT_ID, MULTISIG));
        revDeployer.deployFor({
            revnetId: FEE_PROJECT_ID,
            configuration: config,
            terminalConfigurations: terminalConfigs,
            suckerDeploymentConfiguration: suckerConfig
        });
    }
}
