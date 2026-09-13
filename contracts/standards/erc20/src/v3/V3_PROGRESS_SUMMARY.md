# V3 completion summary

V3 now provides a consistent upgradeable baseline for the custom and
OpenZeppelin tracks.

Completed:

- naming continues V1/V2: `CE20V3` and `CE20_OPV3`
- both implementations use transparent proxies and locked implementations
- custom ERC20 core, mint/burn, allowance extensions, and two-step ownership
- hardened custom EIP-2612 Permit
- OpenZeppelin ERC20Permit reference implementation
- custom/reference differential tests for balances, supply, and transfers
- proxy-based initialization, replay, malformed-signature, and chain-ID tests

The next version should start with a storage-preservation upgrade test, then
introduce V4-only behavior without modifying the V3 layout.
