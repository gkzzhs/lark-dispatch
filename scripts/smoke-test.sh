#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/lark-dispatch-smoke-$$"
MINUTE_TOKEN="${LARK_DISPATCH_SMOKE_MINUTE_TOKEN:-obcn27xt34ox9s245x877j56}"

PASS=0
WARN=0
FAIL=0

mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

ok() {
  printf '[OK] %s\n' "$1"
  PASS=$((PASS + 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  WARN=$((WARN + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  FAIL=$((FAIL + 1))
}

run_quiet() {
  "$@" >"$TMP_DIR/out.txt" 2>&1
}

json_body() {
  sed -n '/^{/,$p' "$1"
}

printf 'lark-dispatch smoke test (non-destructive)\n'
printf 'repo: %s\n\n' "$ROOT_DIR"

if command -v lark-cli >/dev/null 2>&1; then
  ok "lark-cli found: $(lark-cli --version 2>/dev/null | head -n 1)"
else
  fail "lark-cli not found"
fi

if command -v openclaw >/dev/null 2>&1; then
  ok "openclaw found: $(openclaw --version 2>/dev/null | head -n 1)"
else
  warn "openclaw not found; cron checks skipped"
fi

if [ "$FAIL" -gt 0 ]; then
  printf '\nCannot continue without lark-cli.\n'
  exit 1
fi

for service in minutes vc contact task im docs wiki drive; do
  if run_quiet lark-cli "$service" --help; then
    ok "lark-cli $service help is available"
  else
    fail "lark-cli $service help failed"
  fi
done

if [ -f "$ROOT_DIR/skills/lark-shared/SKILL.md" ]; then
  ok "repo-local lark-shared skill found"
elif [ -f "$HOME/.agents/skills/lark-shared/SKILL.md" ] || [ -f "$HOME/.codex/skills/lark-shared/SKILL.md" ]; then
  ok "global lark-shared skill found"
else
  warn "lark-shared skill not found; install official Lark CLI skills before using lark-dispatch"
fi

if run_quiet lark-cli auth status; then
  if grep -q '"tokenStatus": "valid"' "$TMP_DIR/out.txt"; then
    ok "lark-cli user token is valid"
  else
    warn "lark-cli auth status returned, but tokenStatus is not valid"
  fi
else
  fail "lark-cli auth status failed"
fi

REQUIRED_SCOPES="minutes:minutes.search:read minutes:minutes.basic:read minutes:minutes:readonly minutes:minutes.artifacts:read minutes:minutes.transcript:export contact:user:search task:task:write wiki:node:create docs:document.content:read docx:document:create im:message.send_as_user vc:note:read vc:meeting.search:read"
if run_quiet lark-cli auth check --scope "$REQUIRED_SCOPES"; then
  ok "required user scopes are granted"
else
  fail "required user scope check failed"
  json_body "$TMP_DIR/out.txt" | sed 's/^/  /'
fi

if (cd "$TMP_DIR" && lark-cli vc +notes --as user --minute-tokens "$MINUTE_TOKEN" --output-dir ./minutes --jq '{ok, notes_count:(.data.notes|length), artifact_keys:(.data.notes[0].artifacts|keys)}' >"$TMP_DIR/out.txt" 2>&1); then
  ok "vc +notes can read sample minute token"
else
  warn "vc +notes sample read failed; set LARK_DISPATCH_SMOKE_MINUTE_TOKEN to a minute token you can access"
fi

if run_quiet lark-cli contact +search-user --as user --user-ids me --jq '{ok, users_count:(.data.users // [] | length)}'; then
  ok "contact +search-user read check passed"
else
  warn "contact +search-user read check failed"
fi

if run_quiet lark-cli task +create --as user --summary "lark-dispatch dry-run capability check" --due 2026-05-10 --dry-run; then
  ok "task +create dry-run passed"
else
  fail "task +create dry-run failed"
fi

if run_quiet lark-cli docs +create --as user --title "lark-dispatch dry-run report" --markdown "# lark-dispatch dry-run report" --dry-run; then
  ok "docs +create dry-run passed"
else
  fail "docs +create dry-run failed"
fi

if run_quiet lark-cli wiki +node-create --as user --space-id my_library --title "lark-dispatch dry-run knowledge" --dry-run; then
  ok "wiki +node-create dry-run passed"
else
  fail "wiki +node-create dry-run failed"
fi

if run_quiet lark-cli im +messages-send --as user --user-id ou_dry_run_placeholder --text "lark-dispatch dry-run message" --dry-run; then
  ok "im +messages-send user dry-run passed"
else
  fail "im +messages-send user dry-run failed"
fi

# Bot IM uses app identity permission from the Feishu developer console, so
# user-scope auth checks are not a reliable signal. Validate request shape here.
if run_quiet lark-cli im +messages-send --as bot --user-id ou_dry_run_placeholder --text "lark-dispatch bot dry-run message" --dry-run; then
  ok "im +messages-send bot dry-run request can be built"
else
  warn "im +messages-send bot dry-run failed"
fi

if run_quiet lark-cli drive +create-folder --as user --name "lark-dispatch dry-run archive" --dry-run; then
  ok "drive +create-folder dry-run passed"
else
  fail "drive +create-folder dry-run failed"
fi

if command -v openclaw >/dev/null 2>&1; then
  if run_quiet openclaw models status --plain; then
    ok "openclaw model status available: $(tail -n 1 "$TMP_DIR/out.txt")"
  else
    warn "openclaw model status failed"
  fi

  if run_quiet openclaw cron list --json; then
    if json_body "$TMP_DIR/out.txt" | grep -q '"total": 0'; then
      ok "openclaw has no enabled cron jobs"
    else
      warn "openclaw has enabled cron jobs; inspect with openclaw cron list"
    fi
  else
    warn "openclaw cron list failed"
  fi

  if run_quiet openclaw cron list --all --json; then
    if json_body "$TMP_DIR/out.txt" | grep -q '"total": 0'; then
      ok "openclaw has no historical cron job records"
    else
      warn "openclaw has disabled historical cron records; this is safe but should be documented"
    fi
  else
    warn "openclaw cron list --all failed"
  fi
fi

printf '\nSummary: %s ok, %s warnings, %s failures\n' "$PASS" "$WARN" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
