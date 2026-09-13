# 仓库结构与组织规则

## 定位

本仓库是个人 Solidity 标准实现与安全工程展示项目，重点展示：

- ERC/EIP 标准语义与接口；
- 自研实现和 OpenZeppelin 参考实现的差异；
- Foundry 测试、模糊测试、升级测试与 gas 证据。

教学实现用于研究和对比，不默认作为生产协议依赖。

## 目录

```text
contracts/
  standards/<erc>/src/
  libs/
  protocols/
test/
  standards/
  libs/
  protocols/
script/
  deploy/
  upgrade/
  verify/
docs/
  architecture/
  gas/
lib/
```

`standards` 按 ERC 编号组织；`versions/v1`、`v2`、`v3` 表示教学演进。OpenZeppelin 对照实现与自研实现放在同一标准模块中，并使用 `_OP` 命名。

`libs` 只放通用的个人 Solidity 库。只有出现两个真实调用方、且不包含业务语义时，才提取为库。具体业务放在 `protocols`，使用业务名称命名。

## 依赖方向

```text
protocols -> libs + standards
standards -> libs（仅限通用基础能力）
test      -> 被测模块
script    -> contracts
```

标准和库不得依赖具体协议；Foundry 是唯一的构建、测试和脚本工具链。

## 版本

标准编号表达标准身份，不表达实现版本。教学版本只保留在标准模块中。真实可升级协议的实现代际使用业务名称；发布版本使用 Git Tag，不创建源码版本目录。

## 测试与证据

测试通过公开接口观察行为，按需要覆盖 conformance、differential、fuzz、invariant、adversarial 和升级回归。Gas、coverage、storage layout 等机器生成结果只保留可复现且有展示价值的版本。

## 文档与提交

README、稳定的架构规则、精选 gas 报告可以进入公开仓库。路线图、过程记录、未复核设计和草稿放入 `docs/drafts/`，不作为公共项目入口。

`lib/` 中的第三方依赖以 Git submodule 或锁定版本管理，提交依赖指针和版本信息，不直接修改第三方源码。
