// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

interface GuardProjects {
    function ownerOf(uint256 projectId) external view returns (address);
}

interface GuardDirectory {
    function controllerOf(uint256 projectId) external view returns (address);
}

interface GuardTokens {
    function tokenOf(uint256 projectId) external view returns (address);
}

interface GuardRevnetDeployer {
    function FEE_REVNET_ID() external view returns (uint256);
    function hashedEncodedConfigurationOf(uint256 projectId) external view returns (bytes32);
}

interface GuardRevnetOwner {
    function isOperatorOf(uint256 revnetId, address addr) external view returns (bool);
}

contract MockGuardProjects is GuardProjects {
    mapping(uint256 projectId => address owner) internal _ownerOf;

    function setOwnerOf(uint256 projectId, address owner) external {
        _ownerOf[projectId] = owner;
    }

    function ownerOf(uint256 projectId) external view override returns (address) {
        return _ownerOf[projectId];
    }
}

contract MockGuardDirectory is GuardDirectory {
    mapping(uint256 projectId => address controller) internal _controllerOf;

    function setControllerOf(uint256 projectId, address controller) external {
        _controllerOf[projectId] = controller;
    }

    function controllerOf(uint256 projectId) external view override returns (address) {
        return _controllerOf[projectId];
    }
}

contract MockGuardTokens is GuardTokens {
    mapping(uint256 projectId => address token) internal _tokenOf;

    function setTokenOf(uint256 projectId, address token) external {
        _tokenOf[projectId] = token;
    }

    function tokenOf(uint256 projectId) external view override returns (address) {
        return _tokenOf[projectId];
    }
}

contract MockGuardRevnetDeployer is GuardRevnetDeployer {
    uint256 internal _feeRevnetId;
    mapping(uint256 projectId => bytes32 hash) internal _hashOf;

    function setFeeRevnetId(uint256 feeRevnetId) external {
        _feeRevnetId = feeRevnetId;
    }

    function setHashOf(uint256 projectId, bytes32 hash) external {
        _hashOf[projectId] = hash;
    }

    function FEE_REVNET_ID() external view override returns (uint256) {
        return _feeRevnetId;
    }

    function hashedEncodedConfigurationOf(uint256 projectId) external view override returns (bytes32) {
        return _hashOf[projectId];
    }
}

contract MockGuardRevnetOwner is GuardRevnetOwner {
    mapping(uint256 projectId => mapping(address addr => bool isOperator)) internal _isOperatorOf;

    function setIsOperatorOf(uint256 projectId, address addr, bool isOperator) external {
        _isOperatorOf[projectId][addr] = isOperator;
    }

    function isOperatorOf(uint256 projectId, address addr) external view override returns (bool) {
        return _isOperatorOf[projectId][addr];
    }
}

contract MockSymbolToken {
    string internal _symbol;

    constructor(string memory symbol_) {
        _symbol = symbol_;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }
}

contract FeeProjectCanonicalGuardHarness {
    string internal constant SYMBOL = "NANA";

    GuardProjects internal immutable PROJECTS;
    GuardDirectory internal immutable DIRECTORY;
    GuardTokens internal immutable TOKENS;
    GuardRevnetDeployer internal immutable REVNET_DEPLOYER;
    GuardRevnetOwner internal immutable REVNET_OWNER;
    address internal immutable CONTROLLER;

    constructor(
        GuardProjects projects,
        GuardDirectory directory,
        GuardTokens tokens,
        GuardRevnetDeployer revnetDeployer,
        GuardRevnetOwner revnetOwner,
        address controller
    ) {
        PROJECTS = projects;
        DIRECTORY = directory;
        TOKENS = tokens;
        REVNET_DEPLOYER = revnetDeployer;
        REVNET_OWNER = revnetOwner;
        CONTROLLER = controller;
    }

    function feeProjectIsCanonical(
        uint256 feeProjectId,
        bytes32 expectedConfigurationHash,
        address expectedOperator
    )
        external
        view
        returns (bool)
    {
        return _feeProjectIsCanonical({
            feeProjectId: feeProjectId,
            expectedConfigurationHash: expectedConfigurationHash,
            expectedOperator: expectedOperator
        });
    }

    /// @dev Mirrors `Deploy.s.sol` so the regression pins the current standalone skip guard. The ownership check
    /// compares against the REVOwner contract because that is where `REVDeployer.deployFor` parks the project NFT.
    function _feeProjectIsCanonical(
        uint256 feeProjectId,
        bytes32 expectedConfigurationHash,
        address expectedOperator
    )
        internal
        view
        returns (bool)
    {
        if (PROJECTS.ownerOf(feeProjectId) != address(REVNET_OWNER)) return false;
        if (DIRECTORY.controllerOf(feeProjectId) != CONTROLLER) return false;
        if (REVNET_DEPLOYER.FEE_REVNET_ID() != feeProjectId) return false;
        if (REVNET_DEPLOYER.hashedEncodedConfigurationOf(feeProjectId) != expectedConfigurationHash) return false;
        if (!REVNET_OWNER.isOperatorOf({revnetId: feeProjectId, addr: expectedOperator})) return false;
        if (!_projectTokenSymbolIs({projectId: feeProjectId, expectedSymbol: SYMBOL})) return false;
        return true;
    }

    function _projectTokenSymbolIs(uint256 projectId, string memory expectedSymbol) internal view returns (bool) {
        address token = TOKENS.tokenOf(projectId);
        if (token == address(0)) return false;

        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("symbol()"));
        if (!success || data.length < 32) return false;

        return keccak256(bytes(abi.decode(data, (string)))) == keccak256(bytes(expectedSymbol));
    }
}

contract RegressionCanonicalGuardTest is Test {
    uint256 internal constant FEE_PROJECT_ID = 1;
    bytes32 internal constant EXPECTED_HASH = keccak256("expected fee project config");

    MockGuardProjects internal projects;
    MockGuardDirectory internal directory;
    MockGuardTokens internal tokens;
    MockGuardRevnetDeployer internal deployer;
    MockGuardRevnetOwner internal owner;
    FeeProjectCanonicalGuardHarness internal guard;

    address internal controller = makeAddr("controller");
    address internal operator = makeAddr("operator");

    function setUp() public {
        projects = new MockGuardProjects();
        directory = new MockGuardDirectory();
        tokens = new MockGuardTokens();
        deployer = new MockGuardRevnetDeployer();
        owner = new MockGuardRevnetOwner();
        guard = new FeeProjectCanonicalGuardHarness({
            projects: projects,
            directory: directory,
            tokens: tokens,
            revnetDeployer: deployer,
            revnetOwner: owner,
            controller: controller
        });

        // After a real deployment, `REVDeployer.deployFor` permanently forwards the project NFT to the REVOwner
        // contract, which is the project's authoritative owner. Stub the canonical owner accordingly.
        projects.setOwnerOf(FEE_PROJECT_ID, address(owner));
        directory.setControllerOf(FEE_PROJECT_ID, controller);
        tokens.setTokenOf(FEE_PROJECT_ID, address(new MockSymbolToken("NANA")));
        deployer.setFeeRevnetId(FEE_PROJECT_ID);
        deployer.setHashOf(FEE_PROJECT_ID, EXPECTED_HASH);
        owner.setIsOperatorOf(FEE_PROJECT_ID, operator, true);
    }

    function test_guardAcceptsExpectedCanonicalSurfaces() public view {
        assertTrue(
            guard.feeProjectIsCanonical({
                feeProjectId: FEE_PROJECT_ID, expectedConfigurationHash: EXPECTED_HASH, expectedOperator: operator
            }),
            "baseline guard should pass"
        );
    }

    function test_guardRecognizesFeeProjectOwnedByRevnetOwnerAsCanonical() public {
        // This is the real post-deployment state: the project NFT is owned by the REVOwner contract. A re-run must
        // recognize it as canonical and no-op rather than reverting as not-canonical.
        projects.setOwnerOf(FEE_PROJECT_ID, address(owner));

        assertTrue(
            guard.feeProjectIsCanonical({
                feeProjectId: FEE_PROJECT_ID, expectedConfigurationHash: EXPECTED_HASH, expectedOperator: operator
            }),
            "fee project owned by REVOwner must be recognized as canonical"
        );
    }

    function test_guardRejectsFeeProjectStillOwnedByDeployer() public {
        // The project NFT never rests at the deployer after a real deployment; treat that state as non-canonical.
        projects.setOwnerOf(FEE_PROJECT_ID, address(deployer));

        assertFalse(
            guard.feeProjectIsCanonical({
                feeProjectId: FEE_PROJECT_ID, expectedConfigurationHash: EXPECTED_HASH, expectedOperator: operator
            }),
            "owner check must compare against the authoritative REVOwner contract, not the deployer"
        );
    }

    function test_guardRejectsArbitraryNonzeroConfigHashAndWrongFeeRevnetDependency() public {
        deployer.setHashOf(FEE_PROJECT_ID, keccak256("wrong fee project config"));
        deployer.setFeeRevnetId(999);

        assertFalse(
            guard.feeProjectIsCanonical({
                feeProjectId: FEE_PROJECT_ID, expectedConfigurationHash: EXPECTED_HASH, expectedOperator: operator
            }),
            "standalone guard must reject wrong hash and fee dependency"
        );
    }

    function test_guardRejectsWrongHashEvenWhenOtherSurfacesMatch() public {
        deployer.setHashOf(FEE_PROJECT_ID, keccak256("wrong fee project config"));

        assertFalse(
            guard.feeProjectIsCanonical({
                feeProjectId: FEE_PROJECT_ID, expectedConfigurationHash: EXPECTED_HASH, expectedOperator: operator
            }),
            "wrong config hash is not canonical"
        );
    }

    function test_guardRejectsMissingExpectedOperator() public {
        owner.setIsOperatorOf(FEE_PROJECT_ID, operator, false);

        assertFalse(
            guard.feeProjectIsCanonical({
                feeProjectId: FEE_PROJECT_ID, expectedConfigurationHash: EXPECTED_HASH, expectedOperator: operator
            }),
            "wrong operator surface is not canonical"
        );
    }

    function test_guardRejectsSymbolMismatch() public {
        tokens.setTokenOf(FEE_PROJECT_ID, address(new MockSymbolToken("FAKE")));

        assertFalse(
            guard.feeProjectIsCanonical({
                feeProjectId: FEE_PROJECT_ID, expectedConfigurationHash: EXPECTED_HASH, expectedOperator: operator
            }),
            "symbol mismatch is checked"
        );
    }

    function test_scriptGuardIncludesCurrentCanonicalSurfaces() public view {
        string memory deploySource = vm.readFile("script/Deploy.s.sol");
        string memory guardSource = _section({
            haystack: deploySource,
            startNeedle: "function _feeProjectIsCanonical(",
            endNeedle: "function _encodedConfigurationHashOf("
        });
        string memory hashSource = _section({
            haystack: deploySource,
            startNeedle: "function _encodedConfigurationHashOf(",
            endNeedle: "function _reservedSplitIsCanonical("
        });

        assertTrue(
            _contains(guardSource, "ownerOf(feeProjectId) != address(revnet.owner)"),
            "guard checks ownership against the authoritative REVOwner contract"
        );
        assertFalse(
            _contains(guardSource, "ownerOf(feeProjectId) != address(revnet.basicDeployer)"),
            "guard must not compare project ownership against the basic deployer"
        );
        assertTrue(_contains(guardSource, "FEE_REVNET_ID()"), "guard checks fee-revnet dependency");
        assertTrue(
            _contains(guardSource, "hashedEncodedConfigurationOf(feeProjectId) != expectedConfigurationHash"),
            "guard checks exact configuration hash"
        );
        assertTrue(_contains(guardSource, "isOperatorOf"), "guard checks expected operator");
        assertTrue(_contains(guardSource, "uriOf(feeProjectId)"), "guard checks project URI");
        assertTrue(_contains(guardSource, "_reservedSplitIsCanonical"), "guard checks reserved split routing");
        assertTrue(_contains(guardSource, "_nativeTerminalConfigIsCanonical"), "guard checks terminal setup");
        assertFalse(_contains(hashSource, "core.terminal"), "hash excludes canonical multi terminal");
        assertFalse(_contains(hashSource, "routerTerminal.registry"), "hash excludes canonical router terminal");
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0) return true;
        if (n.length > h.length) return false;

        for (uint256 i; i <= h.length - n.length; i++) {
            bool matched = true;
            for (uint256 j; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }

        return false;
    }

    function _indexOfFrom(string memory haystack, string memory needle, uint256 start) internal pure returns (uint256) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        require(n.length != 0, "empty needle");
        require(n.length <= h.length, "needle too long");

        for (uint256 i = start; i <= h.length - n.length; i++) {
            bool matched = true;
            for (uint256 j; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return i;
        }

        revert("needle not found");
    }

    function _section(
        string memory haystack,
        string memory startNeedle,
        string memory endNeedle
    )
        internal
        pure
        returns (string memory)
    {
        bytes memory h = bytes(haystack);
        uint256 start = _indexOfFrom(haystack, startNeedle, 0);
        uint256 end = _indexOfFrom(haystack, endNeedle, start);
        require(end >= start, "invalid section");

        bytes memory out = new bytes(end - start);
        for (uint256 i; i < out.length; i++) {
            out[i] = h[start + i];
        }
        return string(out);
    }
}
