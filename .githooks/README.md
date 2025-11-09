Git hooks setup

This repo uses a dedicated hooks directory. To enable hooks locally:

1) Point Git to this folder:
   git config core.hooksPath .githooks

2) Make hook scripts executable (Linux/macOS):
   chmod +x .githooks/*

Included templates
- pre-push.example: sample pre-push that runs per-contract gas reports only.
  Rename to `pre-push` to activate. Optional envs:
  - `GAS_INCLUDE` (comma-separated aliases, e.g., `CE20V2,CE721_OPV2`)
  - `GAS_ENV` (label in filenames, default `local`)
  - `GAS_KEEP` (history files to keep per alias, default `10`)

Notes
- On Windows, Git Bash can execute Bash hooks; alternatively, call PowerShell scripts from hooks.
