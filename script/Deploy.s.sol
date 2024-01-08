pragma solidity 0.8.23;

import "lib/forge-std/src/Script.sol";

import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {IJBAddressRegistry} from "lib/juice-address-registry/src/interfaces/IJBAddressRegistry.sol";
import {IJBDirectory} from "lib/juice-contracts-v4/src/interfaces/IJBDirectory.sol";
import {IJBPermissions} from "lib/juice-contracts-v4/src/interfaces/IJBPermissions.sol";

import {JB721TiersHookDeployer} from "src/JB721TiersHookDeployer.sol";
import {JB721TiersHookProjectDeployer} from "src/JB721TiersHookProjectDeployer.sol";
import {JB721TiersHookStore} from "src/JB721TiersHookStore.sol";
import {JB721TiersHook} from "src/JB721TiersHook.sol";
import {JBGoverned721TiersHook} from "src/JBGoverned721TiersHook.sol";

contract Deploy is Script {
    function run() public {
        uint256 chainId = block.chainid;
        string memory chain;

        // Ethereum Mainnet
        if (chainId == 1) {
            chain = "1";
            // Ethereum Sepolia
        } else if (chainId == 11_155_111) {
            chain = "11155111";
            // Optimism Mainnet
        } else if (chainId == 420) {
            chain = "420";
            // Optimism Sepolia
        } else if (chainId == 11_155_420) {
            chain = "11155420";
            // Polygon Mainnet
        } else if (chainId == 137) {
            chain = "137";
            // Polygon Mumbai
        } else if (chainId == 80_001) {
            chain = "80001";
        } else {
            revert("Invalid RPC / no juice contracts deployed on this network");
        }

        address directoryAddress = _getDeploymentAddress(
            string.concat("lib/juice-contracts-v4/broadcast/Deploy.s.sol/", chain, "/run-latest.json"), "JBDirectory"
        );

        address permissionsAddress = _getDeploymentAddress(
            string.concat("lib/juice-contracts-v4/broadcast/Deploy.s.sol/", chain, "/run-latest.json"), "JBPermissions"
        );

        address addressRegistryAddress = _getDeploymentAddress(string.concat("lib/juice-address-registry/broadcast/Deploy.s.sol/", chain, "/run-latest.json"), "JBAddressRegistry");


        vm.startBroadcast();
        JB721TiersHook noGovernance = new JB721TiersHook(IJBDirectory(directoryAddress), IJBPermissions(permissionsAddress));
        JBGoverned721TiersHook onchainGovernance = new JBGoverned721TiersHook(IJBDirectory(directoryAddress), IJBPermissions(permissionsAddress));
        JB721TiersHookDeployer hookDeployer = new JB721TiersHookDeployer(onchainGovernance, noGovernance, IJBAddressRegistry(addressRegistryAddress));
        new JB721TiersHookStore();
        new JB721TiersHookProjectDeployer(IJBDirectory(directoryAddress), IJBPermissions(permissionsAddress), hookDeployer);
        vm.stopBroadcast();
    }

    /// @notice Get the address of a contract that was deployed by the Deploy script.
    /// @dev Reverts if the contract was not found.
    /// @param path The path to the deployment file.
    /// @param contractName The name of the contract to get the address of.
    /// @return The address of the contract.
    function _getDeploymentAddress(string memory path, string memory contractName) internal view returns (address) {
        string memory deploymentJson = vm.readFile(path);
        uint256 nOfTransactions = stdJson.readStringArray(deploymentJson, ".transactions").length;

        for (uint256 i = 0; i < nOfTransactions; i++) {
            string memory currentKey = string.concat(".transactions", "[", Strings.toString(i), "]");
            string memory currentContractName =
                stdJson.readString(deploymentJson, string.concat(currentKey, ".contractName"));

            if (keccak256(abi.encodePacked(currentContractName)) == keccak256(abi.encodePacked(contractName))) {
                return stdJson.readAddress(deploymentJson, string.concat(currentKey, ".contractAddress"));
            }
        }

        revert(string.concat("Could not find contract with name '", contractName, "' in deployment file '", path, "'"));
    }
}