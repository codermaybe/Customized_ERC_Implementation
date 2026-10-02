# Customized ERC Implementations

面向学习与演示的多标准合约集合，涵盖 ERC20 / ERC721 / ERC1155 的自研实现与 OpenZeppelin 对照实现，工具链为 Foundry。

- V1：简化自研（教学版）
- V2：更贴近生产的精简实现，含 Ownable2Step、admin 体系
- V3：可升级基线（initializer + storage gap）

本仓库的目标是对比“自实现与基于 OpenZeppelin”的差异，在接口一致性、错误类型、Permit（EIP‑2612）、可升级性等方面给出清晰示例。

## 目录结构

```text
contracts/
  interfaces/          # 官方标准接口（IERC20 / IERC721 / IERC1155 / IERC165 / IERC4626 / IERC777 / IERC3525）
  standards/
    erc20/src/v1..v3   # 自研 CE20V1..V3 + OpenZeppelin 对照版
    erc721/src/v1..v3  # 自研 CE721V1..V3 + OpenZeppelin 对照版
    erc1155/src/v1..v2 # 自研 CE1155V1..V2 + OpenZeppelin 对照版
    erc3525/src/v1     # WIP，尚未完成
test/standards/<erc>/V<n>/
script/
  analyze/             # gas 报告生成
  deployment/          # 部署脚本
  upgrade/             # 升级脚本
docs/
  architecture/        # 仓库组织规则
  gas/                 # gas 报告快照
lib/                   # git submodule：forge-std v1.11.0、openzeppelin-contracts(-upgradeable) v5.4.0
```

命名约定：自研实现用 `CE<erc><version>`，OpenZeppelin 对照实现用 `CE<erc><version>_OpenZeppelin`。

## 前置条件

Foundry：`curl -L https://foundry.paradigm.xyz | bash` 然后 `foundryup`。

安装依赖（`lib/` 下的依赖为 git submodule，版本已在 `.gitmodules` 固定，无需 Node.js）：

```bash
git clone --recurse-submodules <repo-url>
# 已有克隆只需初始化：
git submodule update --init
```

也可以用 `forge install` 完成 submodule 初始化。

## 常用命令

```bash
forge build                     # 编译
forge test                      # 全量测试
forge test -vv                  # 测试 + 详细 trace
forge test --match-contract CE20V2Test
forge test --match-path test/standards/erc721/V3/CE721V3.t.sol
FOUNDRY_PROFILE=ci forge test   # CI 配置：fuzz runs = 1000
forge fmt                       # 格式化（forge fmt --check 检查）
forge lint                      # 静态检查
forge snapshot                  # 生成 gas 快照 .gas-snapshot
```

## 亮点与差异

- CE20V2 / CE20V2_OpenZeppelin
  - ERC20 基础能力 + 仅 owner 可 mint + burn/burnFrom
  - 自定义错误（ZeroAddress / InsufficientBalance / …）vs OZ 的 `IERC20Errors`
  - EIP‑2612 Permit：显式 `permit`、`nonces`、`DOMAIN_SEPARATOR`，EIP‑712 版本固定为 `"2"`
- CE721V1..V3
  - 自定义 `_baseURI`、`_nextToken`、mint/burn、管理员体系
  - V3 以 initializer 替代 constructor，作为后续代理升级的 storage layout 基线
- CE1155V1 / V2
  - FT/NFT 混合道具、单物品授权 + operator 全局授权
  - 批量/单笔路径统一在内部 update 中处理余额与事件（CEI）

提示：CE20V2 与 CE20V2_OpenZeppelin 的 Permit digest 兼容（同域、同版本），但错误类型不同。

## Gas 记录（自动化）

两层记录，都不需要人工跑脚本：

1. `.gas-snapshot`（权威记录）：`forge snapshot` 生成，按测试函数粒度记录 gas。CI 的 `gas-snapshot` job 执行 `forge snapshot --check --tolerance 5`，合约改了但快照没同步就直接失败。
2. `docs/gas/<Alias>/`（可读报告）：`script/analyze/generate-gas-reports.sh` 为每个测试合约生成 Markdown 报告，保留最近 10 份历史与 `-latest`。CI 的 `gas-refresh` job 每周一自动重算并直接提交；也可在 Actions 页面手动触发。

本地开发：

```bash
forge snapshot                                # 改了合约后刷新权威快照
forge snapshot --check --tolerance 5          # 本地预检（与 CI 门禁一致）
forge snapshot --diff --diff-sort percentage-desc   # 与上次快照对比，看 gas 变化
GAS_ON_COMMIT=1 git commit                    # 提交时顺带刷新快照与报告
```

注意：`.gas-snapshot` 必须用 default profile（fuzz runs = 256）生成；`FOUNDRY_PROFILE=ci` 下 fuzz 行的 runs/均值会变化，不要用它生成快照文件。

## CI 与本地 hooks 的分工

- CI 是唯一门禁：`forge fmt --check`、`forge lint`、`forge build`、测试、gas 快照一致性。
- `.githooks/` 只做本地快速反馈（可选的 gas 刷新、push 前快照预检），启用方式见 `.githooks/README.md`。


## 免责声明

示例代码主要用于学习演示。请在充分审计与测试后再用于生产环境，风险自担。
