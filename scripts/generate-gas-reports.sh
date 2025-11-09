#!/usr/bin/env bash
set -euo pipefail

# Per‑contract Forge gas reports without PowerShell.
# - Auto-discovers test contracts: `contract <Name> is Test` under test/**/*.t.sol
# - Alias = test name without suffix: _Tests/_Test/Tests/Test
# - Outputs: dev/reports/gas/<ALIAS>/gas-<ALIAS>-<YYYYmmdd-HHMMSS>-<sha7>-<env>.md
# - Maintains: dev/reports/gas/<ALIAS>/gas-<ALIAS>-latest.md
# - Keeps history per alias: GAS_KEEP (default 10)

GAS_ENV="${GAS_ENV:-local}"
GAS_KEEP="${GAS_KEEP:-10}"

# Optional: comma-separated alias filter (e.g., CE20V2,CE721_OPV2)
INCLUDE_RAW="${GAS_INCLUDE:-}"

sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
ts=$(date +%Y%m%d-%H%M%S)

forge_ver=$(forge --version 2>/dev/null || echo "forge: unavailable")
solc_ver=$(grep -Eo 'solc_version\s*=\s*"[^"]+"' foundry.toml 2>/dev/null | sed -E 's/.*"(.*)"/\1/' || true)
opt_runs=$(grep -Eo 'optimizer_runs\s*=\s*[0-9]+' foundry.toml 2>/dev/null | sed -E 's/.*=\s*//' || true)
solc_ver=${solc_ver:-unknown}
opt_runs=${opt_runs:-unknown}

mapfile -t tests < <(find test -type f -name "*.t.sol" -print0 2>/dev/null \
  | xargs -0 grep -nEh '^\s*contract\s+[A-Za-z0-9_]+' 2>/dev/null \
  | grep -E '\bis\s+Test\b' \
  | sed -E 's/^.*contract\s+([A-Za-z0-9_]+)\s+is\s+Test.*/\1/' \
  | sort -u)

if [[ ${#tests[@]} -eq 0 ]]; then
  echo "[gas] No test contracts discovered." >&2
  exit 0
fi

# Build include set if provided
declare -A INCLUDE
if [[ -n "$INCLUDE_RAW" ]]; then
  IFS=',' read -r -a inc_arr <<<"$INCLUDE_RAW"
  for a in "${inc_arr[@]}"; do
    a_trim=$(echo "$a" | xargs)
    [[ -n "$a_trim" ]] && INCLUDE["$a_trim"]=1 || true
  done
fi

derive_alias() {
  local name="$1"
  echo "$name" | sed -E 's/(_Tests|_Test|Tests|Test)$//'
}

write_header() {
  local alias="$1"
  local ts_human
  ts_human=$(date '+%Y-%m-%d %H:%M:%S %z')
  cat <<EOF
# Gas Report - $alias

- Generated: $ts_human
- Branch: $branch
- Commit: $sha
- Env: $GAS_ENV
- Forge: $forge_ver
- Solc: $solc_ver
- Optimizer runs: $opt_runs

---

EOF
}

prune_history() {
  local dir="$1" alias="$2" keep="$3"
  mapfile -t files < <(ls -1t "$dir"/gas-"$alias"-*.md 2>/dev/null | grep -v latest | grep -v baseline || true)
  local count=${#files[@]}
  if (( count > keep )); then
    for ((i=keep; i<count; i++)); do
      rm -f "${files[$i]}" || true
    done
  fi
}

for test_name in "${tests[@]}"; do
  alias=$(derive_alias "$test_name")
  if [[ -n "$INCLUDE_RAW" && -z "${INCLUDE[$alias]:-}" ]]; then
    continue
  fi
  out_dir="dev/reports/gas/$alias"
  mkdir -p "$out_dir"
  file="$out_dir/gas-$alias-$ts-$sha-$GAS_ENV.md"
  latest="$out_dir/gas-$alias-latest.md"

  echo "[gas] $alias -> $file (test: $test_name)"
  write_header "$alias" > "$file"
  forge test --gas-report --match-contract "$test_name" | tee -a "$file" >/dev/null
  cp -f "$file" "$latest"
  prune_history "$out_dir" "$alias" "$GAS_KEEP"
done

echo "[gas] Reports ready under dev/reports/gas/<ALIAS>/"

