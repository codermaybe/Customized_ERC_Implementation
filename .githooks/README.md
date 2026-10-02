Git hooks setup

本仓库用 `.githooks/` 目录存放 hooks，职责边界与 CI 分开：

- CI（`.github/workflows/ci.yml`）= 唯一门禁：`forge fmt --check`、`forge lint`、`forge build`、测试、gas 快照一致性。
- 本地 hooks = 快速反馈与便利功能，不重复 CI 的门禁职责。

启用：

```bash
git config core.hooksPath .githooks
chmod +x .githooks/*   # Windows/WSL 若无可执行位：git update-index --chmod=+x .githooks/*
```

`core.hooksPath` 是本地配置，不会随 clone 分发，所以 CI 不依赖 hooks。

## Included hooks

- `pre-commit`（默认启用）：仅在被显式要求时刷新 gas 证据，其余情况直接退出。
  - `GAS_ON_COMMIT=1 git commit …`：刷新 `.gas-snapshot`（权威记录，按测试粒度）并为受影响合约生成 `docs/gas/<Alias>/` 报告，然后一并 stage。
  - 逻辑：先 `forge snapshot`，再用 `GAS_INCLUDE=<aliases>` 调 `script/analyze/generate-gas-reports.sh`。
  - 可选环境变量：`GAS_INCLUDE`、`GAS_ENV`（文件名标签，默认 `local`）、`GAS_KEEP`（每个别名保留历史数，默认 10）、`GAS_OUT_DIR`（默认 `docs/gas`）。
- `pre-push.example`（默认不启用）：`forge snapshot --check --tolerance 5`，即 CI gas 门禁的本地镜像。需要时重命名为 `pre-push`。

## Notes

- `.gas-snapshot` 必须用 default profile 生成（fuzz runs = 256）。`FOUNDRY_PROFILE=ci forge snapshot` 的 fuzz 行会变化，不要用来生成快照文件。
- gas 快照的定时自动刷新在 CI（`gas-refresh` job），无需手工执行脚本。
- Windows 下可用 Git Bash 执行 bash hooks。
