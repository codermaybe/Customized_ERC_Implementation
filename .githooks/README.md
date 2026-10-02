# Git hooks

本目录包含本地辅助脚本。

启用方式：

```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
```

## 说明

- `pre-commit`：生成 gas 报告。默认跳过以保证日常提交速度；显式指定 `GAS_ON_COMMIT=1 git commit` 时才会触发并暂存 `docs/gas`。
- CI 是主要的门禁（格式检查、编译、全量测试），本地 hooks 仅作为辅助工具。

