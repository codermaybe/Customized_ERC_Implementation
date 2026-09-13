# CE20 V3 implementation notes

`CE20V3.sol` is the custom upgradeable baseline. `CE20V3_OpenZeppelin.sol` is
the OpenZeppelin reference implementation. Their public behavior is aligned
where the project expects differential testing:

- ERC20 metadata and core transfers
- `mint`, `burn`, and `burnFrom`, all returning `bool`
- infinite allowance behavior
- EIP-2612 `permit`, `nonces`, and `DOMAIN_SEPARATOR`
- two-step ownership

The custom implementation additionally rejects malformed `v`, high-`s`
signatures, zero-address owners, expired signatures, and replayed permits.

## Storage layout

The custom V3 layout is the compatibility boundary for V4:

1. business owner and pending owner
2. initialization state
3. name and symbol
4. total supply, balances, and allowances
5. permit nonces and domain cache
6. a 47-slot storage gap

New traditional storage fields must consume slots from the gap. Do not reorder
existing fields. OpenZeppelin 5 parents use namespaced storage; the derived V3
gap is reserved for project-owned state.

## Security choices

- implementation contracts disable direct initialization
- proxy construction and initialization are atomic
- total-supply overflow is checked before unchecked mint arithmetic
- allowance and balance subtraction are checked before unchecked arithmetic
- Permit uses EIP-712 version `"3"` and recomputes its domain after a chain-ID
  change

## V4 handoff

Before implementing V4, add a V3-to-V4 proxy upgrade test that writes every
V3 state category, upgrades, and verifies all values remain unchanged. If V4
uses ERC-7201, keep legacy V3 state accessible rather than relocating it by
changing storage declarations.
