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
    address internal immutable CONTROLLER;

    constructor(
        GuardProjects projects,
        GuardDirectory directory,
        GuardTokens tokens,
        GuardRevnetDeployer revnetDeployer,
        address controller
    ) {
        PROJECTS = projects;
        DIRECTORY = directory;
        TOKENS = tokens;
        REVNET_DEPLOYER = revnetDeployer;
        CONTROLLER = controller;
    }

    function feeProjectIsCanonical(uint256 feeProjectId) external view returns (bool) {
        return _feeProjectIsCanonical(feeProjectId);
    }

    /// @dev Mirrors `Deploy.s.sol` so the regression pins the current standalone skip guard.
    function _feeProjectIsCanonical(uint256 feeProjectId) internal view returns (bool) {
        if (PROJECTS.ownerOf(feeProjectId) != address(REVNET_DEPLOYER)) return false;
        if (DIRECTORY.controllerOf(feeProjectId) != CONTROLLER) return false;
        if (REVNET_DEPLOYER.hashedEncodedConfigurationOf(feeProjectId) == bytes32(0)) return false;
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

    MockGuardProjects internal projects;
    MockGuardDirectory internal directory;
    MockGuardTokens internal tokens;
    MockGuardRevnetDeployer internal deployer;
    FeeProjectCanonicalGuardHarness internal guard;

    address internal controller = makeAddr("controller");

    function setUp() public {
        projects = new MockGuardProjects();
        directory = new MockGuardDirectory();
        tokens = new MockGuardTokens();
        deployer = new MockGuardRevnetDeployer();
        guard = new FeeProjectCanonicalGuardHarness({
            projects: projects, directory: directory, tokens: tokens, revnetDeployer: deployer, controller: controller
        });

        projects.setOwnerOf(FEE_PROJECT_ID, address(deployer));
        directory.setControllerOf(FEE_PROJECT_ID, controller);
        tokens.setTokenOf(FEE_PROJECT_ID, address(new MockSymbolToken("NANA")));
    }

    function test_guardAcceptsArbitraryNonzeroConfigHashAndWrongFeeRevnetDependency() public {
        deployer.setHashOf(FEE_PROJECT_ID, keccak256("wrong fee project config"));
        deployer.setFeeRevnetId(999);

        assertTrue(
            guard.feeProjectIsCanonical(FEE_PROJECT_ID),
            "standalone guard accepts nonzero hash and ignores FEE_REVNET_ID"
        );
    }

    function test_guardRejectsOnlyTheCurrentlyCheckedSurfaces() public {
        deployer.setHashOf(FEE_PROJECT_ID, keccak256("wrong fee project config"));

        assertTrue(guard.feeProjectIsCanonical(FEE_PROJECT_ID), "baseline guard should pass");

        tokens.setTokenOf(FEE_PROJECT_ID, address(new MockSymbolToken("FAKE")));

        assertFalse(guard.feeProjectIsCanonical(FEE_PROJECT_ID), "symbol mismatch is checked");
    }
}
