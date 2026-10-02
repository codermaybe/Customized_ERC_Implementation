// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.28;

/// @title IERC4626 - Tokenized Vaults Interface
/// @notice 严格依据 EIP-4626 官方规范整理，仅包含规范中明确列出的方法与事件。
/// @dev 该接口定义了一个由单一 EIP-20 资产支持的 Tokenized Vault。
///      所有 EIP-4626 Vault 必须实现 EIP-20 来表示 shares，并实现 EIP-20 的可选元数据扩展。
///      原文地址: https://eips.ethereum.org/EIPS/eip-4626
interface IERC4626 {
    // =============================================================
    //                            Methods
    // =============================================================

    /// @notice The address of the underlying token used for the Vault for accounting,
    ///         depositing, and withdrawing.
    /// @dev MUST be an EIP-20 token contract.
    ///      MUST NOT revert.
    /// @return assetTokenAddress The address of the underlying asset token.
    function asset() external view returns (address assetTokenAddress);

    /// @notice Total amount of the underlying asset that is "managed" by Vault.
    /// @dev SHOULD include any compounding that occurs from yield.
    ///      MUST be inclusive of any fees that are charged against assets in the Vault.
    ///      MUST NOT revert.
    /// @return totalManagedAssets The total amount of underlying assets managed by the Vault.
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// @notice The amount of shares that the Vault would exchange for the amount of assets provided,
    ///         in an ideal scenario where all the conditions are met.
    /// @dev MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    ///      MUST NOT show any variations depending on the caller.
    ///      MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
    ///      MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
    ///      MUST round down towards 0.
    /// @param assets The amount of assets to convert.
    /// @return shares The amount of shares that would be exchanged.
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @notice The amount of assets that the Vault would exchange for the amount of shares provided,
    ///         in an ideal scenario where all the conditions are met.
    /// @dev MUST NOT be inclusive of any fees that are charged against assets in the Vault.
    ///      MUST NOT show any variations depending on the caller.
    ///      MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
    ///      MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
    ///      MUST round down towards 0.
    /// @param shares The amount of shares to convert.
    /// @return assets The amount of assets that would be exchanged.
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @notice Maximum amount of the underlying asset that can be deposited into the Vault
    ///         for the receiver, through a deposit call.
    /// @dev MUST return the maximum amount of assets deposit would allow to be deposited for receiver
    ///      and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted.
    ///      MUST factor in both global and user-specific limits.
    ///      MUST return 2 ** 256 - 1 if there is no limit.
    ///      MUST NOT revert.
    /// @param receiver The address receiving the shares.
    /// @return maxAssets The maximum amount of assets that can be deposited.
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their deposit
    ///         at the current block, given current on-chain conditions.
    /// @dev MUST return as close to and no more than the exact amount of Vault shares that would be
    ///      minted in a deposit call in the same transaction.
    ///      MUST NOT account for deposit limits like those returned from maxDeposit.
    ///      MUST be inclusive of deposit fees.
    ///      MUST NOT revert due to vault specific user/global limits.
    /// @param assets The amount of assets to preview deposit for.
    /// @return shares The amount of shares that would be minted.
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /// @notice Mints shares Vault shares to receiver by depositing exactly assets of underlying tokens.
    /// @dev MUST emit the Deposit event.
    ///      MUST support EIP-20 approve / transferFrom on asset as a deposit flow.
    ///      MUST revert if all of assets cannot be deposited.
    /// @param assets The amount of assets to deposit.
    /// @param receiver The address receiving the shares.
    /// @return shares The amount of shares minted.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Maximum amount of shares that can be minted from the Vault for the receiver,
    ///         through a mint call.
    /// @dev MUST return the maximum amount of shares mint would allow to be deposited to receiver
    ///      and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted.
    ///      MUST factor in both global and user-specific limits.
    ///      MUST return 2 ** 256 - 1 if there is no limit.
    ///      MUST NOT revert.
    /// @param receiver The address receiving the shares.
    /// @return maxShares The maximum amount of shares that can be minted.
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their mint
    ///         at the current block, given current on-chain conditions.
    /// @dev MUST return as close to and no fewer than the exact amount of assets that would be
    ///      deposited in a mint call in the same transaction.
    ///      MUST NOT account for mint limits like those returned from maxMint.
    ///      MUST be inclusive of deposit fees.
    ///      MUST NOT revert due to vault specific user/global limits.
    /// @param shares The amount of shares to preview mint for.
    /// @return assets The amount of assets that would be deposited.
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /// @notice Mints exactly shares Vault shares to receiver by depositing assets of underlying tokens.
    /// @dev MUST emit the Deposit event.
    ///      MUST support EIP-20 approve / transferFrom on asset as a mint flow.
    ///      MUST revert if all of shares cannot be minted.
    /// @param shares The amount of shares to mint.
    /// @param receiver The address receiving the shares.
    /// @return assets The amount of assets deposited.
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /// @notice Maximum amount of the underlying asset that can be withdrawn from the owner balance
    ///         in the Vault, through a withdraw call.
    /// @dev MUST return the maximum amount of assets that could be transferred from owner through withdraw
    ///      and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted.
    ///      MUST factor in both global and user-specific limits.
    ///      MUST NOT revert.
    /// @param owner The address owning the shares.
    /// @return maxAssets The maximum amount of assets that can be withdrawn.
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their withdrawal
    ///         at the current block, given current on-chain conditions.
    /// @dev MUST return as close to and no fewer than the exact amount of Vault shares that would be
    ///      burned in a withdraw call in the same transaction.
    ///      MUST NOT account for withdrawal limits like those returned from maxWithdraw.
    ///      MUST be inclusive of withdrawal fees.
    ///      MUST NOT revert due to vault specific user/global limits.
    /// @param assets The amount of assets to preview withdrawal for.
    /// @return shares The amount of shares that would be burned.
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /// @notice Burns shares from owner and sends exactly assets of underlying tokens to receiver.
    /// @dev MUST emit the Withdraw event.
    ///      MUST support a withdraw flow where the shares are burned from owner directly where owner is msg.sender.
    ///      MUST support a withdraw flow where the shares are burned from owner directly where msg.sender
    ///      has EIP-20 approval over the shares of owner.
    ///      MUST revert if all of assets cannot be withdrawn.
    /// @param assets The amount of assets to withdraw.
    /// @param receiver The address receiving the assets.
    /// @param owner The address owning the shares being burned.
    /// @return shares The amount of shares burned.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /// @notice Maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
    ///         through a redeem call.
    /// @dev MUST return the maximum amount of shares that could be transferred from owner through redeem
    ///      and not cause a revert, which MUST NOT be higher than the actual maximum that would be accepted.
    ///      MUST factor in both global and user-specific limits.
    ///      MUST NOT revert.
    /// @param owner The address owning the shares.
    /// @return maxShares The maximum amount of shares that can be redeemed.
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their redemption
    ///         at the current block, given current on-chain conditions.
    /// @dev MUST return as close to and no more than the exact amount of assets that would be
    ///      withdrawn in a redeem call in the same transaction.
    ///      MUST NOT account for redemption limits like those returned from maxRedeem.
    ///      MUST be inclusive of withdrawal fees.
    ///      MUST NOT revert due to vault specific user/global limits.
    /// @param shares The amount of shares to preview redemption for.
    /// @return assets The amount of assets that would be withdrawn.
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /// @notice Burns exactly shares from owner and sends assets of underlying tokens to receiver.
    /// @dev MUST emit the Withdraw event.
    ///      MUST support a redeem flow where the shares are burned from owner directly where owner is msg.sender.
    ///      MUST support a redeem flow where the shares are burned from owner directly where msg.sender
    ///      has EIP-20 approval over the shares of owner.
    ///      MUST revert if all of shares cannot be redeemed.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The address receiving the assets.
    /// @param owner The address owning the shares being burned.
    /// @return assets The amount of assets withdrawn.
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    // =============================================================
    //                            Events
    // =============================================================

    /// @notice sender has exchanged assets for shares, and transferred those shares to owner.
    /// @dev MUST be emitted when tokens are deposited into the Vault via the mint and deposit methods.
    /// @param sender The address that initiated the deposit/mint.
    /// @param owner The address receiving the shares.
    /// @param assets The amount of assets deposited.
    /// @param shares The amount of shares minted.
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice sender has exchanged shares, owned by owner, for assets, and transferred those assets to receiver.
    /// @dev MUST be emitted when shares are withdrawn from the Vault in EIP-4626.redeem or EIP-4626.withdraw methods.
    /// @param sender The address that initiated the withdraw/redeem.
    /// @param receiver The address receiving the assets.
    /// @param owner The address whose shares were burned.
    /// @param assets The amount of assets withdrawn.
    /// @param shares The amount of shares burned.
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
}
