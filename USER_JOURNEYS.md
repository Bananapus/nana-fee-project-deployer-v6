# User Journeys -- nana-fee-project-deployer-v6

Concrete end-to-end flows through the fee project deployment. Since this repo contains only a deployment script (no runtime contracts), these journeys describe the deployment process and the resulting on-chain state.

## Journey 1: Deploy the NANA Fee Project (Full Deployment)

**Actor:** Protocol team via Sphinx multi-chain deployment.
**Goal:** Deploy and configure project #1 as the NANA revnet -- the protocol fee recipient across all Juicebox V6 operations.

### Precondition

- All core infrastructure is already deployed on each target chain: `JBProjects`, `JBMultiTerminal`, `JBController`, `REVDeployer`, sucker deployers, and `JBRouterTerminalRegistry`.
- The Sphinx safe owns project #1 (the ERC-721 NFT).
- Deployment artifact paths are correct (either via npm packages or environment variable overrides).

### Steps

1. **Sphinx proposal is created and approved by the team**

   - `configureSphinx()` sets project name `"nana-core-v6"` and target chains: Ethereum, Optimism, Base, Arbitrum (mainnets or testnets)

2. **`run()` loads deployment artifacts**

   - Reads `CoreDeployment` from `@bananapus/core-v6/deployments/` -- provides `core.terminal`, `core.projects`, `core.controller`
   - Reads `SuckerDeployment` from `@bananapus/suckers-v6/deployments/` -- provides `suckers.optimismDeployer`, `suckers.baseDeployer`, `suckers.arbitrumDeployer`
   - Reads `RevnetCoreDeployment` from `@rev-net/core-v6/deployments/` -- provides `revnet.basic_deployer`
   - Reads `RouterTerminalDeployment` from `@bananapus/router-terminal-v6/deployments/` -- provides `routerTerminal.registry`
   - Sets `OPERATOR = safeAddress()` (the Sphinx multisig on the current chain)

3. **`deploy()` executes under the `sphinx` modifier**

   a. **Configure terminals**
   - Terminal 1: `core.terminal` (JBMultiTerminal) accepting native token (ETH, 18 decimals)
   - Terminal 2: `routerTerminal.registry` (JBRouterTerminalRegistry) with no accounting contexts

   b. **Configure splits**
   - Single split: 100% (`SPLITS_TOTAL_PERCENT`) to `OPERATOR`, no lock, no hook, no project redirect

   c. **Configure auto-issuances**
   - 4 entries, one per chain:
     - Ethereum mainnet (chain 1): ~34,614,774 * 10^18 tokens to OPERATOR
     - Base (chain 8453): ~1,604,412 * 10^18 tokens to OPERATOR
     - Optimism (chain 10): ~6,266 * 10^18 tokens to OPERATOR
     - Arbitrum (chain 42161): ~105 * 10^18 tokens to OPERATOR

   d. **Configure the revnet stage**
   - Single stage starting at timestamp `1740089444`
   - `splitPercent = 6200` (62% of issuance to splits)
   - `initialIssuance = 10,000 * 10^18` (10,000 NANA per ETH)
   - `issuanceCutFrequency = 360 days`
   - `issuanceCutPercent = 380,000,000` (38% decay per 360 days)
   - `cashOutTaxRate = 1000` (10%)
   - `extraMetadata = 4` (allow adding suckers)

   e. **Configure sucker deployments**
   - On Ethereum: 3 suckers (OP deployer, Base deployer, Arbitrum deployer)
   - On L2s: 1 sucker back to mainnet (auto-selects correct deployer)
   - Token mapping: native token to native token, `minGas = 200,000`, `minBridgeAmount = 0.01 ether`
   - Salt: `"_NANA_SUCKER_SALTV6__"` for deterministic addresses

   f. **Approve and deploy**
   - `core.projects.approve(revnet.basic_deployer, 1)` -- gives REVDeployer ERC-721 approval for project #1
   - `revnet.basic_deployer.deployFor(1, revnetConfiguration, terminalConfigurations, suckerDeploymentConfiguration)` -- configures the revnet

### Result

Project #1 is configured as the NANA revnet on the current chain. The revnet has:
- A NANA ERC-20 token
- A single immutable stage with the specified issuance, decay, and cashout parameters
- Pre-minted tokens distributed to the OPERATOR on each chain
- Sucker contracts connecting to other chains for cross-chain bridging
- Two terminals: the multi-terminal for direct payments and the router terminal for swap routing

### What to verify

- `FEE_PROJECT_ID` is `1`. The entire Juicebox fee system routes to project #1 -- using any other ID would mean fees go to the wrong project.
- The `OPERATOR` address is the correct multisig on each chain. Since `safeAddress()` returns the Sphinx-managed safe, verify the safe configuration.
- Auto-issuance amounts sum to the intended total NANA supply across all chains.
- The revnet stage parameters match the intended economic design (10,000 NANA/ETH initial issuance, 38% decay per 360 days, 10% cashout tax, 62% split).
- On mainnet, all 3 suckers are deployed. On each L2, the correct bridge deployer is selected.
- `extraMetadata = 4` correctly enables the "add suckers" permission in the revnet configuration.

---

## Journey 2: Protocol Fees Flow to Project #1

**Actor:** Any user paying into or cashing out of any Juicebox V6 project.
**Goal:** Understand how protocol fees reach the NANA fee project after deployment.

### Precondition

Project #1 is deployed and configured (Journey 1 complete). A user interacts with any Juicebox V6 project's terminal.

### Steps (post-deployment, for context)

1. **User pays into or cashes out of project N via `JBMultiTerminal`**

   - `JBMultiTerminal` charges a 2.5% fee on payouts and cashouts (unless the address is feeless)
   - Fees are held for 28 days, then processed

2. **Fees are routed to project #1**

   - `JBMultiTerminal` pays the fee amount to project #1 via the fee project's terminal
   - Project #1's revnet mints NANA tokens to the fee payer (at the current issuance rate)

3. **NANA tokens accrue value**

   - As fees flow in, the project's surplus grows
   - The issuance rate decays by 38% every 360 days, reducing new token minting over time
   - Token holders can cash out at a 10% tax rate

4. **Splits distribute issuance**

   - 62% of newly minted tokens go to the OPERATOR (multisig) via the configured split
   - The remaining 38% goes to the fee payer

### Result

The NANA fee project continuously receives protocol fees, minting NANA tokens and building surplus. The economic parameters are immutable once deployed.

### What to verify

- The fee routing in `JBMultiTerminal` targets `FEE_BENEFICIARY_PROJECT_ID = 1` (defined in nana-core, not in this script).
- The terminal configured for project #1 can receive the same tokens that other terminals charge fees in (native token).
- The auto-issuance tokens represent a bootstrap allocation that dilutes future fee payers. Verify the amounts are proportionate to the intended economics.

---

## Journey 3: Cross-Chain Bridging via Suckers

**Actor:** NANA token holder on an L2.
**Goal:** Bridge NANA tokens between chains using the sucker infrastructure deployed by this script.

### Precondition

Project #1 is deployed on multiple chains with suckers connecting them.

### Steps (post-deployment, for context)

1. **User holds NANA tokens on Base**

   - Tokens were either purchased via payments to project #1 on Base or bridged from another chain

2. **User initiates a bridge via the sucker**

   - The Base sucker maps native token to native token (`JBConstants.NATIVE_TOKEN` on both sides)
   - Minimum bridge amount is `0.01 ether`
   - Minimum gas for the bridge is `200,000`

3. **Tokens arrive on mainnet (or vice versa)**

   - The sucker mechanism uses merkle trees to verify cross-chain transfers
   - On arrival, the destination sucker mints equivalent NANA tokens

### Result

NANA tokens are fungible across chains via the sucker bridge infrastructure.

### What to verify

- Token mappings are correct: native token on both sides, with the remote token encoded as `bytes32(uint256(uint160(JBConstants.NATIVE_TOKEN)))`.
- The `minBridgeAmount = 0.01 ether` prevents dust-amount bridges that would be uneconomical.
- The `minGas = 200,000` is sufficient for the bridge operation on each target chain.
- The sucker salt (`"_NANA_SUCKER_SALTV6__"`) produces deterministic addresses that are consistent across chains.
