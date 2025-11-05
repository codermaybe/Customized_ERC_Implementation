# Customized ERC Implementations

面向学习与演示的多标准合约集合，涵盖 ERC20 / ERC721 / ERC1155 两套实现风格：
- V1：简化自研（含 Hardhat JS 测试）
- V2：更贴近生产的精简实现与 OpenZeppelin 版本（含 Foundry 测试）

本仓库的目标是对比“自实现与基于 OpenZeppelin”的差异，在接口一致性、错误类型、Permit（EIP‑2612）等方面给出清晰示例。

## 目录结构
- `contracts/CustomizedERC20`
  - `v1/CE20V1.sol` 自研 ERC20（教学版）
  - `v1/CE20_openzepplinV1.sol` 基于 OZ 的 ERC20（V1）
  - `v2/CE20V2.sol` 自研 ERC20 + Permit（EIP‑2612 版本号为 "2"）
  - `v2/CE20_openzepplinV2.sol` 基于 OZ ERC20 + 自实现 Permit("2")，接口与 CE20V2 对齐
- `contracts/CustomizedERC721`：最小 ERC721 与 OZ 版
- `contracts/CustomizedERC1155`：最小 ERC1155 与 OZ 版接口
- `test/CustomizedERC20/V1`：Hardhat JS 测试（V1）
- `test/CustomizedERC20/V2`：Foundry 测试（V2，自研与 OZ 版）

## 亮点与差异
- CE20V2（自研）
  - ERC20 基础能力 + 仅 owner 可 mint + burn/burnFrom
  - 自定义错误（ZeroAddress/InsufficientBalance/…）
  - EIP‑2612 Permit：显式 `permit`、`nonces`、`DOMAIN_SEPARATOR`，EIP‑712 版本为 "2"
- CE20_OPV2（OZ 版）
  - 继承 `ERC20` + `Ownable`，保留 OZ 的错误类型（IERC20Errors）与事件语义
  - 自实现 Permit（不修改 OZ 源码），同样暴露 `permit/nonces/DOMAIN_SEPARATOR`，EIP‑712 版本为 "2"

提示：两者 Permit 的 digest 兼容（同域、同版本）；但错误类型不同（自定义错误 vs. OZ 的 IERC20Errors）。

## 前置条件
- Node.js 18+，`npm` 或 `pnpm`
- Foundry（可选，用于 Solidity 测试）：`curl -L https://foundry.paradigm.xyz | bash` 并执行 `foundryup`

安装依赖：
```
npm i
```

## 测试
本仓库同时提供 Hardhat（V1）与 Foundry（V2）两套测试。

### Foundry（推荐用于 V2）
- 全量：`forge test -vv`
- 仅跑某文件：`forge test --match-path test/CustomizedERC20/V2/CE20_openzepplinV2.t.sol`
- 仅跑某合约：`forge test --match-contract CE20_OPV2Test`
- 仅跑某用例：`forge test --match-test permit_skeleton`

### Hardhat（用于 V1）
- 全量：`npx hardhat test`
- 指定文件：`npx hardhat test ./test/CustomizedERC20/V1/CE20V1.js`
- 名称匹配：`npx hardhat test --grep "Your_test_name"`

## 部署（Hardhat Ignition）
在 `hardhat.config.js` 配置 `networks`（URL 与私钥）。

示例：
```
npx hardhat ignition deploy ./ignition/modules/CustomizedERC20/V1/CE20V1.js --network <your_network>
```

## Permit（EIP‑2612）说明（V2）
- 域：`EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)`
- 版本号：固定为 "2"（自研与 OZ 版保持一致）
- 方法：`permit(owner, spender, value, deadline, v, r, s)`；`nonces(owner)`；`DOMAIN_SEPARATOR()`

## 免责声明
示例代码主要用于学习演示。请在充分审计与测试后再用于生产环境，风险自担。
