#!/usr/bin/env bash
set -u

PASS=0
FAIL=0

ok() {
  printf '[OK] %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  FAIL=$((FAIL + 1))
}

run_quiet() {
  "$@" >/tmp/lark-dispatch-docs-api-check.out 2>&1
}

printf 'lark-dispatch docs API compatibility check (dry-run only)\n\n'

if ! command -v lark-cli >/dev/null 2>&1; then
  fail "lark-cli not found"
  exit 1
fi

if run_quiet lark-cli docs +create --as user --title "lark-dispatch v1 dry-run" --markdown "# dry-run" --dry-run; then
  ok "docs +create v1 dry-run supports --title + --markdown"
else
  fail "docs +create v1 dry-run failed"
  sed 's/^/  /' /tmp/lark-dispatch-docs-api-check.out
fi

if run_quiet lark-cli docs +update --as user --doc "https://www.feishu.cn/docx/dummy" --markdown "# dry-run" --mode overwrite --dry-run; then
  ok "docs +update v1 dry-run supports --markdown + --mode"
else
  fail "docs +update v1 dry-run failed"
  sed 's/^/  /' /tmp/lark-dispatch-docs-api-check.out
fi

if run_quiet lark-cli docs +create --api-version v2 --as user --content "# lark-dispatch v2 dry-run" --doc-format markdown --dry-run; then
  ok "docs +create v2 dry-run supports --content + --doc-format markdown"
else
  fail "docs +create v2 dry-run failed"
  sed 's/^/  /' /tmp/lark-dispatch-docs-api-check.out
fi

if run_quiet lark-cli docs +update --api-version v2 --as user --doc "https://www.feishu.cn/docx/dummy" --content "# dry-run" --doc-format markdown --command overwrite --dry-run; then
  ok "docs +update v2 dry-run supports --content + --doc-format markdown + --command overwrite"
else
  fail "docs +update v2 dry-run failed"
  sed 's/^/  /' /tmp/lark-dispatch-docs-api-check.out
fi

rm -f /tmp/lark-dispatch-docs-api-check.out

printf '\nSummary: %s ok, %s failures\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
