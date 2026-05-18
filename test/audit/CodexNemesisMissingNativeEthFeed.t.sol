// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IJBDirectory} from "@bananapus/core-v6/src/interfaces/IJBDirectory.sol";
import {IJBPermissions} from "@bananapus/core-v6/src/interfaces/IJBPermissions.sol";
import {IJBProjects} from "@bananapus/core-v6/src/interfaces/IJBProjects.sol";
import {JBPrices} from "@bananapus/core-v6/src/JBPrices.sol";
import {JBConstants} from "@bananapus/core-v6/src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@bananapus/core-v6/src/libraries/JBCurrencyIds.sol";

contract CodexNemesisMissingNativeEthFeedTest is Test {
    function test_missingNativeEthMatchingFeedRevertsFeeProjectCurrencyConversion() public {
        JBPrices prices = new JBPrices({
            directory: IJBDirectory(address(0)),
            permissions: IJBPermissions(address(0)),
            projects: IJBProjects(address(0)),
            owner: address(this),
            trustedForwarder: address(0)
        });

        uint32 nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));

        vm.expectRevert(
            abi.encodeWithSelector(
                JBPrices.JBPrices_PriceFeedNotFound.selector,
                uint256(0),
                uint256(nativeCurrency),
                uint256(JBCurrencyIds.ETH)
            )
        );

        prices.pricePerUnitOf({
            projectId: 1, pricingCurrency: nativeCurrency, unitCurrency: JBCurrencyIds.ETH, decimals: 18
        });
    }
}
