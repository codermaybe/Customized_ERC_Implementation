Git hooks setup

This repo uses a dedicated hooks directory. To enable hooks locally:

1) Point Git to this folder:
   git config core.hooksPath .githooks

2) Make hook scripts executable (Linux/macOS):
   chmod +x .githooks/*

Included templates
- pre-commit: active hook that generates per-contract gas reports for staged changes and stages them into the commit.
  Optional envs:
  - `GAS_INCLUDE` (comma-separated aliases, e.g., `CE20V2,CE721_OPV2`)
  - `GAS_ENV` (label in filenames, default `local`)
  - `GAS_KEEP` (history files to keep per alias, default `10`)
  - `GAS_OUT_DIR` (base output directory, default `docs/gas`)
- pre-push.example: optional sample to generate gas reports on push (not enabled by default). Rename to `pre-push` only if you want push-time reports.

Notes
- On Windows, Git Bash can execute Bash hooks; alternatively, call PowerShell scripts from hooks.
