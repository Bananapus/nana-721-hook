// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@bananapus/core/src/libraries/JBCurrencyIds.sol";
import "@bananapus/core/src/libraries/JBConstants.sol";

contract AccessJBLib {
    function NATIVE() external pure returns (uint256) {
        return uint32(uint160(JBConstants.NATIVE_TOKEN));
    }

    function USD() external pure returns (uint256) {
        return JBCurrencyIds.USD;
    }

    function NATIVE_TOKEN() external pure returns (address) {
        return JBConstants.NATIVE_TOKEN;
    }

    function MAX_FEE() external pure returns (uint256) {
        return JBConstants.MAX_FEE;
    }

    function MAX_RESERVED_PERCENT() external pure returns (uint256) {
        return JBConstants.MAX_RESERVED_PERCENT;
    }

    function MAX_REDEMPTION_RATE() external pure returns (uint256) {
        return JBConstants.MAX_REDEMPTION_RATE;
    }

    function MAX_DECAY_PERCENT() external pure returns (uint256) {
        return JBConstants.MAX_DECAY_PERCENT;
    }

    function SPLITS_TOTAL_PERCENT() external pure returns (uint256) {
        return JBConstants.SPLITS_TOTAL_PERCENT;
    }
}
