// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Compile OpenZeppelin's transparent proxy artifacts for the manual deployment scripts.
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
