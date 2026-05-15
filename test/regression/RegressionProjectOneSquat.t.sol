// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {JBController} from "@bananapus/core-v6/src/JBController.sol";
import {JBDirectory} from "@bananapus/core-v6/src/JBDirectory.sol";
import {JBFundAccessLimits} from "@bananapus/core-v6/src/JBFundAccessLimits.sol";
import {JBPermissions} from "@bananapus/core-v6/src/JBPermissions.sol";
import {JBPrices} from "@bananapus/core-v6/src/JBPrices.sol";
import {JBProjects} from "@bananapus/core-v6/src/JBProjects.sol";
import {JBRulesets} from "@bananapus/core-v6/src/JBRulesets.sol";
import {JBSplits} from "@bananapus/core-v6/src/JBSplits.sol";
import {JBTokens} from "@bananapus/core-v6/src/JBTokens.sol";
import {JBERC20} from "@bananapus/core-v6/src/JBERC20.sol";
import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {IJBRulesetApprovalHook} from "@bananapus/core-v6/src/interfaces/IJBRulesetApprovalHook.sol";
import {JBFundAccessLimitGroup} from "@bananapus/core-v6/src/structs/JBFundAccessLimitGroup.sol";
import {JBRulesetConfig} from "@bananapus/core-v6/src/structs/JBRulesetConfig.sol";
import {JBRulesetMetadata} from "@bananapus/core-v6/src/structs/JBRulesetMetadata.sol";
import {JBSplitGroup} from "@bananapus/core-v6/src/structs/JBSplitGroup.sol";
import {JBTerminalConfig} from "@bananapus/core-v6/src/structs/JBTerminalConfig.sol";

contract RegressionProjectOneSquatTest is Test {
    address internal constant MULTISIG = address(uint160(uint256(keccak256("multisig"))));
    address internal constant ATTACKER = address(uint160(uint256(keccak256("attacker"))));

    JBPermissions internal permissions;
    JBProjects internal projects;
    JBDirectory internal directory;
    JBRulesets internal rulesets;
    JBTokens internal tokens;
    JBPrices internal prices;
    JBSplits internal splits;
    JBFundAccessLimits internal fundAccess;
    JBController internal controller;

    function setUp() public {
        permissions = new JBPermissions(address(0));
        projects = new JBProjects(MULTISIG, address(0), address(0));
        directory = new JBDirectory(permissions, projects, MULTISIG);
        rulesets = new JBRulesets(directory);
        tokens = new JBTokens(directory, new JBERC20(permissions, projects));
        prices = new JBPrices(directory, permissions, projects, MULTISIG, address(0));
        splits = new JBSplits(directory);
        fundAccess = new JBFundAccessLimits(directory);
        controller = new JBController(
            directory, fundAccess, permissions, prices, projects, rulesets, splits, tokens, address(0), address(0)
        );

        vm.prank(MULTISIG);
        directory.setIsAllowedToSetFirstController(address(controller), true);
    }

    function test_projectOneCanBePermissionlesslySquatted() public {
        vm.prank(ATTACKER);
        uint256 attackerProjectId = projects.createFor(ATTACKER);

        assertEq(attackerProjectId, 1, "the first public mint claims the canonical fee project id");
        assertEq(projects.ownerOf(1), ATTACKER, "the attacker becomes the owner of project 1");

        vm.prank(MULTISIG);
        uint256 operatorProjectId = projects.createFor(MULTISIG);

        assertEq(operatorProjectId, 2, "the intended operator is permanently pushed to project 2");
    }

    function test_blankProjectOneSquatBreaksDeployerApprovalPath() public {
        vm.prank(ATTACKER);
        projects.createFor(ATTACKER);

        // This mirrors Deploy.s.sol line 215: only the project owner can approve the revnet deployer for project 1.
        vm.prank(MULTISIG);
        vm.expectRevert();
        projects.approve(address(0xBEEF), 1);
    }

    function test_configuredProjectOneSquatTriggersSkipGuard() public {
        vm.prank(ATTACKER);
        projects.createFor(ATTACKER);

        JBRulesetConfig[] memory rulesetConfigurations = new JBRulesetConfig[](1);
        rulesetConfigurations[0] = JBRulesetConfig({
            mustStartAtOrAfter: uint48(block.timestamp),
            duration: 0,
            weight: uint112(1e18),
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: JBRulesetMetadata({
                reservedPercent: 0,
                cashOutTaxRate: 0,
                baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                pausePay: false,
                pauseCreditTransfers: false,
                allowOwnerMinting: true,
                allowSetCustomToken: false,
                allowTerminalMigration: false,
                allowSetTerminals: true,
                allowSetController: false,
                allowAddAccountingContext: false,
                allowAddPriceFeed: false,
                ownerMustSendPayouts: false,
                holdFees: false,
                scopeCashOutsToLocalBalances: false,
                pauseCrossProjectFeeFreeInflows: false,
                useDataHookForPay: false,
                useDataHookForCashOut: false,
                dataHook: address(0),
                metadata: 0
            }),
            splitGroups: new JBSplitGroup[](0),
            fundAccessLimitGroups: new JBFundAccessLimitGroup[](0)
        });

        vm.prank(ATTACKER);
        controller.launchRulesetsFor({
            projectId: 1,
            projectUri: "",
            rulesetConfigurations: rulesetConfigurations,
            terminalConfigurations: new JBTerminalConfig[](0),
            memo: ""
        });

        assertTrue(
            address(directory.controllerOf(1)) != address(0), "attacker can pre-configure controller for project 1"
        );
        assertEq(
            address(directory.controllerOf(1)),
            address(controller),
            "the deploy script's controllerOf(1) skip guard now evaluates true"
        );
    }
}
