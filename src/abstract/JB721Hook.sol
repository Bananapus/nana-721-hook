// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IJBDirectory} from "@bananapus/core/src/interfaces/IJBDirectory.sol";
import {IJBPayHook} from "@bananapus/core/src/interfaces/IJBPayHook.sol";
import {IJBRedeemHook} from "@bananapus/core/src/interfaces/IJBRedeemHook.sol";
import {IJBRulesetDataHook} from "@bananapus/core/src/interfaces/IJBRulesetDataHook.sol";
import {IJBTerminal} from "@bananapus/core/src/interfaces/IJBTerminal.sol";
import {JBConstants} from "@bananapus/core/src/libraries/JBConstants.sol";
import {JBMetadataResolver} from "@bananapus/core/src/libraries/JBMetadataResolver.sol";
import {JBAfterPayRecordedContext} from "@bananapus/core/src/structs/JBAfterPayRecordedContext.sol";
import {JBAfterRedeemRecordedContext} from "@bananapus/core/src/structs/JBAfterRedeemRecordedContext.sol";
import {JBBeforePayRecordedContext} from "@bananapus/core/src/structs/JBBeforePayRecordedContext.sol";
import {JBBeforeRedeemRecordedContext} from "@bananapus/core/src/structs/JBBeforeRedeemRecordedContext.sol";
import {JBPayHookSpecification} from "@bananapus/core/src/structs/JBPayHookSpecification.sol";
import {JBRedeemHookSpecification} from "@bananapus/core/src/structs/JBRedeemHookSpecification.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {mulDiv} from "@prb/math/src/Common.sol";

import {ERC721} from "./ERC721.sol";
import {IJB721Hook} from "../interfaces/IJB721Hook.sol";

/// @title JB721Hook
/// @notice When a project which uses this hook is paid, this hook may mint NFTs to the payer, depending on this hook's
/// setup, the amount paid, and information specified by the payer. The project's owner can enable NFT redemptions
/// through this hook, allowing the NFT holders to burn their NFTs to reclaim funds from the project (in proportion to
/// the NFT's price).
abstract contract JB721Hook is ERC721, IJB721Hook, IJBRulesetDataHook, IJBPayHook, IJBRedeemHook {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JB721Hook_InvalidPay();
    error JB721Hook_InvalidRedeem();
    error JB721Hook_UnauthorizedToken(uint256 tokenId, address holder);
    error JB721Hook_UnexpectedTokenRedeemed();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice The ID used when parsing metadata.
    address public immutable override METADATA_ID_TARGET;

    //*********************************************************************//
    // -------------------- public stored properties --------------------- //
    //*********************************************************************//

    /// @notice The ID of the project that this contract is associated with.
    uint256 public override PROJECT_ID;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A directory of terminals and controllers for projects.
    constructor(IJBDirectory directory) {
        DIRECTORY = directory;
        // Store the address of the original hook deploy. Clones will each use the address of the instance they're based
        // on.
        METADATA_ID_TARGET = address(this);
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The data calculated before a payment is recorded in the terminal store. This data is provided to the
    /// terminal's `pay(...)` transaction.
    /// @dev Sets this contract as the pay hook. Part of `IJBRulesetDataHook`.
    /// @param context The payment context passed to this contract by the `pay(...)` function.
    /// @return weight The new `weight` to use, overriding the ruleset's `weight`.
    /// @return hookSpecifications The amount and data to send to pay hooks (this contract) instead of adding to the
    /// terminal's balance.
    function beforePayRecordedWith(JBBeforePayRecordedContext calldata context)
        public
        view
        virtual
        override
        returns (uint256 weight, JBPayHookSpecification[] memory hookSpecifications)
    {
        // Forward the received weight and memo, and use this contract as the only pay hook.
        weight = context.weight;
        hookSpecifications = new JBPayHookSpecification[](1);
        hookSpecifications[0] = JBPayHookSpecification({hook: this, amount: 0, metadata: bytes("")});
    }

    /// @notice The data calculated before a redemption is recorded in the terminal store. This data is provided to the
    /// terminal's `redeemTokensOf(...)` transaction.
    /// @dev Sets this contract as the redeem hook. Part of `IJBRulesetDataHook`.
    /// @dev This function is used for NFT redemptions, and will only be called if the project's ruleset has
    /// `useDataHookForRedeem` set to `true`.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return redemptionRate The redemption rate influencing the reclaim amount.
    /// @return redeemCount The amount of tokens that should be considered redeemed.
    /// @return totalSupply The total amount of tokens that are considered to be existing.
    /// @return hookSpecifications The amount and data to send to redeem hooks (this contract) instead of returning to
    /// the beneficiary.
    function beforeRedeemRecordedWith(JBBeforeRedeemRecordedContext calldata context)
        public
        view
        virtual
        override
        returns (
            uint256 redemptionRate,
            uint256 redeemCount,
            uint256 totalSupply,
            JBRedeemHookSpecification[] memory hookSpecifications
        )
    {
        // Make sure (fungible) project tokens aren't also being redeemed.
        if (context.redeemCount > 0) revert JB721Hook_UnexpectedTokenRedeemed();

        // Fetch the redeem hook metadata using the corresponding metadata ID.
        (bool metadataExists, bytes memory metadata) =
            JBMetadataResolver.getDataFor(JBMetadataResolver.getId("redeem", METADATA_ID_TARGET), context.metadata);

        // Use this contract as the only redeem hook.
        hookSpecifications = new JBRedeemHookSpecification[](1);
        hookSpecifications[0] = JBRedeemHookSpecification(this, 0, bytes(""));

        uint256[] memory decodedTokenIds;

        // Decode the metadata.
        if (metadataExists) decodedTokenIds = abi.decode(metadata, (uint256[]));

        // Use the redemption weight of the provided 721s.
        redeemCount = redemptionWeightOf(decodedTokenIds, context);

        // Use the total redemption weight of the 721s.
        totalSupply = totalRedemptionWeight(context);

        // Use the redemption rate from the context.
        redemptionRate = context.redemptionRate;
    }

    /// @notice Required by the IJBRulesetDataHook interfaces. Return false to not leak any permissions.
    function hasMintPermissionFor(uint256, address) external pure returns (bool) {
        return false;
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Returns the cumulative redemption weight of the specified token IDs relative to the
    /// `totalRedemptionWeight`.
    /// @param tokenIds The NFT token IDs to calculate the cumulative redemption weight of.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return The cumulative redemption weight of the specified token IDs.
    function redemptionWeightOf(
        uint256[] memory tokenIds,
        JBBeforeRedeemRecordedContext calldata context
    )
        public
        view
        virtual
        returns (uint256)
    {
        tokenIds; // Prevents unused var compiler and natspec complaints.
        context; // Prevents unused var compiler and natspec complaints.
        return 0;
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param _interfaceId The ID of the interface to check for adherence to.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return _interfaceId == type(IJB721Hook).interfaceId || _interfaceId == type(IJBRulesetDataHook).interfaceId
            || _interfaceId == type(IJBPayHook).interfaceId || _interfaceId == type(IJBRedeemHook).interfaceId
            || _interfaceId == type(IERC2981).interfaceId || super.supportsInterface(_interfaceId);
    }

    /// @notice Calculates the cumulative redemption weight of all NFT token IDs.
    /// @param context The redemption context passed to this contract by the `redeemTokensOf(...)` function.
    /// @return The total cumulative redemption weight of all NFT token IDs.
    function totalRedemptionWeight(JBBeforeRedeemRecordedContext calldata context)
        public
        view
        virtual
        returns (uint256)
    {
        context; // Prevents unused var compiler and natspec complaints.
        return 0;
    }

    //*********************************************************************//
    // ------------------------ internal views --------------------------- //
    //*********************************************************************//

    /// @notice Initializes the contract by associating it with a project and adding ERC721 details.
    /// @param projectId The ID of the project that this contract is associated with.
    /// @param name The name of the NFT collection.
    /// @param symbol The symbol representing the NFT collection.
    function _initialize(uint256 projectId, string memory name, string memory symbol) internal {
        ERC721._initialize(name, symbol);
        PROJECT_ID = projectId;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Mints one or more NFTs to the `context.benficiary` upon payment if conditions are met. Part of
    /// `IJBPayHook`.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param context The payment context passed in by the terminal.
    // slither-disable-next-line locked-ether
    function afterPayRecordedWith(JBAfterPayRecordedContext calldata context) external payable virtual override {
        uint256 projectId = PROJECT_ID;

        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an
        // interaction with the correct project.
        if (
            msg.value != 0 || !DIRECTORY.isTerminalOf(projectId, IJBTerminal(msg.sender))
                || context.projectId != projectId
        ) revert JB721Hook_InvalidPay();

        // Process the payment.
        _processPayment(context);
    }

    /// @notice Burns the specified NFTs upon token holder redemption, reclaiming funds from the project's balance for
    /// `context.beneficiary`. Part of `IJBRedeemHook`.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param context The redemption context passed in by the terminal.
    // slither-disable-next-line locked-ether
    function afterRedeemRecordedWith(JBAfterRedeemRecordedContext calldata context) external payable virtual override {
        // Keep a reference to the project ID.
        uint256 projectId = PROJECT_ID;

        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an
        // interaction with the correct project.
        if (
            msg.value != 0 || !DIRECTORY.isTerminalOf(projectId, IJBTerminal(msg.sender))
                || context.projectId != projectId
        ) revert JB721Hook_InvalidRedeem();

        // Fetch the redeem hook metadata using the corresponding metadata ID.
        (bool metadataExists, bytes memory metadata) = JBMetadataResolver.getDataFor(
            JBMetadataResolver.getId("redeem", METADATA_ID_TARGET), context.redeemerMetadata
        );

        uint256[] memory decodedTokenIds;

        // Decode the metadata.
        if (metadataExists) decodedTokenIds = abi.decode(metadata, (uint256[]));

        // Get a reference to the number of NFT token IDs to check the owner of.
        uint256 numberOfTokenIds = decodedTokenIds.length;

        // Iterate through the NFTs, burning them if the owner is correct.
        for (uint256 i; i < numberOfTokenIds; i++) {
            // Set the current NFT's token ID.
            uint256 tokenId = decodedTokenIds[i];

            // Make sure the token's owner is correct.
            if (_ownerOf(tokenId) != context.holder) revert JB721Hook_UnauthorizedToken(tokenId, context.holder);

            // Burn the token.
            _burn(tokenId);
        }

        // Call the hook.
        _didBurn(decodedTokenIds);
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Executes after NFTs have been burned via redemption.
    /// @param tokenIds The token IDs of the NFTs that were burned.
    function _didBurn(uint256[] memory tokenIds) internal virtual;

    /// @notice Process a received payment.
    /// @param context The payment context passed in by the terminal.
    function _processPayment(JBAfterPayRecordedContext calldata context) internal virtual;
}
