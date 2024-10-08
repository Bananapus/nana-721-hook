// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "@bananapus/core/src/interfaces/IJBDirectory.sol";

interface IJB721Hook {
    function DIRECTORY() external view returns (IJBDirectory);
    function METADATA_ID_TARGET() external view returns (address);
    function PROJECT_ID() external view returns (uint256);
}
