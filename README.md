# Customized ERC Implementation

个人用于学习、研读与复现以太坊常用代币标准（ERC/EIP）的 Solidity 仓库。

项目核心思路是按照 EIP 官方规范从零手写实现核心逻辑，并与 OpenZeppelin 的对照版本放在同一工程内，用于研究两者的接口一致性、存储布局、错误处理及 Gas 开销差异。

## 目录结构

```text
contracts/
  interfaces/          # 各标准对应的官方抽象接口定义（IERC20 / IERC721 / IERC1155 等）
  standards/
    erc20/src/         # ERC20 自研实现与 OpenZeppelin 对照版（V1 ~ V3）
    erc721/src/        # ERC721 自研实现与 OpenZeppelin 对照版（V1 ~ V3）
    erc1155/src/       # ERC1155 自研实现与 OpenZeppelin 对照版（V1 ~ V2）
    erc3525/src/       # ERC3525（WIP）
test/
  standards/           # Foundry 单元测试与对齐校验
script/
  analyze/             # Gas 分析辅助脚本
```

命名约定：自研实现统一命名为 `CE<erc><version>`，OpenZeppelin 对照版以 `_OpenZeppelin` 结尾。

## 构建与测试

项目完全基于 **Foundry** 工具链。

### 1. 克隆与依赖

依赖（OpenZeppelin 与 Forge-std）通过 Git Submodule 管理：

```bash
git clone --recurse-submodules <repo-url>
cd Customized_ERC_Implementation

# 若克隆时未拉取 submodule，可手动初始化：
git submodule update --init
```

### 2. 常用命令

```bash
forge build                     # 编译全量合约
forge test                      # 运行全量测试
forge test -vv                  # 测试并输出调用栈
forge test --match-contract CE20V2Test   # 运行指定合约测试
forge fmt --check               # 代码格式检查
forge lint                      # 静态检查
```

## 免责声明

本项目合约主要用于个人学习与规范研读，部分实现优先保证逻辑直观性，未经过商业审计，请勿直接部署于生产环境。
