#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

require_file() {
  if [ -f "$ROOT_DIR/$1" ]; then
    ok "found $1"
  else
    fail "missing $1"
  fi
}

require_text() {
  local pattern="$1"
  local file="$2"
  local label="$3"

  if grep -Fq "$pattern" "$ROOT_DIR/$file"; then
    ok "$label"
  else
    fail "$label"
  fi
}

reject_text() {
  local pattern="$1"
  local file="$2"
  local label="$3"

  if grep -Fq -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$label"
    grep -Fn -- "$pattern" "$ROOT_DIR/$file" | sed 's/^/  /'
  else
    ok "$label"
  fi
}

printf 'lark-dispatch docs check\n'
printf 'repo: %s\n\n' "$ROOT_DIR"

require_file "README.md"
require_file "skills/lark-dispatch/SKILL.md"
require_file "docs/评审快速入口.md"
require_file "docs/最终评审摘要.md"
require_file "docs/真实实测Runbook.md"
require_file "docs/assets/live-runs.jsonl"
require_file "docs/assets/live-2026-05-10/bot-im-send.json"
require_file "docs/assets/live-2026-05-10/docs-v2-create.json"
require_file "docs/assets/live-2026-05-10/docs-v2-update.json"
require_file "docs/assets/live-2026-05-10/third-party-bot-im-send-error.json"
require_file "docs/assets/live-2026-05-10/third-party-chat-read-error.json"
require_file "demo/confirmation-draft.md"
require_file "scripts/check-docs-api.sh"
require_file "scripts/check-docs.sh"
require_file "scripts/smoke-test.sh"

require_text "bash scripts/smoke-test.sh" "README.md" "README documents smoke-test"
require_text "bash scripts/check-docs.sh" "README.md" "README documents check-docs"
require_text "bash scripts/check-docs-api.sh" "README.md" "README documents docs API check"
require_text "逐字稿 fallback" "skills/lark-dispatch/SKILL.md" "Skill documents transcript fallback"
require_text "Step 4.5: 重复分发检查" "skills/lark-dispatch/SKILL.md" "Skill documents duplicate dispatch check"
require_text "真实实测安全规则" "skills/lark-dispatch/SKILL.md" "Skill documents live test safety rule"
require_text "不要并行创建知识文档和分发报告" "skills/lark-dispatch/SKILL.md" "Skill documents serial document creation"
require_text "folder locked" "skills/lark-dispatch/SKILL.md" "Skill documents folder locked retry"
require_text "docs API 兼容规则" "skills/lark-dispatch/SKILL.md" "Skill documents docs API compatibility"
require_text "确认前不会执行" "skills/lark-dispatch/SKILL.md" "Skill keeps pre-confirmation safety section"
require_text "真实创建任务、发送消息、写文档必须等待用户明确确认" "docs/评审快速入口.md" "review guide states write confirmation rule"
require_text "两次确认" "docs/真实实测Runbook.md" "live runbook documents two confirmations"
require_text "docs/assets/live-runs.jsonl" "docs/真实实测Runbook.md" "live runbook documents local registry"
require_text "check-docs-api.sh" "docs/真实实测Runbook.md" "live runbook documents docs API check"
require_text "未收到第二次确认前，不创建任务、不发送消息、不写入知识库或分发报告" "docs/真实实测Runbook.md" "live runbook keeps write gate"
require_text "obcn27xt34ox9s245x877j56" "docs/assets/live-runs.jsonl" "registry records live test minute token"
require_text "om_x100b50c888c774a4c3700aafb8fcaae" "README.md" "README records bot IM message id"
require_text "om_x100b50c888c774a4c3700aafb8fcaae" "docs/assets/live-2026-05-10/summary.md" "live summary records bot IM message id"
require_text "om_x100b50c888c774a4c3700aafb8fcaae" "docs/最终评审摘要.md" "final review summary records bot IM message id"
require_text "QcCqdXBKSo94SOxctG8cbevGnZf" "docs/assets/live-runs.jsonl" "registry records docs v2 test document"
require_text "QcCqdXBKSo94SOxctG8cbevGnZf" "README.md" "README records docs v2 test document"
require_text "QcCqdXBKSo94SOxctG8cbevGnZf" "docs/assets/live-2026-05-10/summary.md" "live summary records docs v2 test document"
require_text "QcCqdXBKSo94SOxctG8cbevGnZf" "docs/最终评审摘要.md" "final review summary records docs v2 test document"
require_text "oc_ca2752dd467518a5b5c5bddf77676ef9" "docs/assets/live-runs.jsonl" "registry records third-party bot IM blocked target"
require_text "oc_ca2752dd467518a5b5c5bddf77676ef9" "README.md" "README records third-party bot IM blocked target"
require_text "oc_ca2752dd467518a5b5c5bddf77676ef9" "docs/assets/live-2026-05-10/summary.md" "live summary records third-party bot IM blocked target"
require_text "oc_ca2752dd467518a5b5c5bddf77676ef9" "docs/最终评审摘要.md" "final review summary records third-party bot IM blocked target"
require_text "Bot/User can NOT be out of the chat." "docs/最终评审摘要.md" "final review summary records bot not in chat boundary"
require_text "56 ok, 0 failures" "docs/最终评审摘要.md" "final review summary records final docs check"
require_text "确认状态：未确认" "demo/confirmation-draft.md" "demo draft is explicitly unconfirmed"
require_text "不创建任务" "demo/confirmation-draft.md" "demo draft states no task before confirmation"

reject_text "contact:contact.user:readonly" "README.md" "README has no stale contact scope"
reject_text "wiki:wiki:write" "README.md" "README has no stale wiki scope"
reject_text "im:message:send_as_bot" "skills/lark-dispatch/SKILL.md" "Skill has no stale bot IM scope spelling"
reject_text "im:message.send_as_bot" "scripts/smoke-test.sh" "smoke-test does not check bot IM as a user scope"
reject_text "--parent" "skills/lark-dispatch/SKILL.md" "Skill has no stale drive +create-folder --parent flag"
reject_text "docs +create --format json" "skills/lark-dispatch/SKILL.md" "Skill has no unsupported docs +create --format json"
reject_text "--api-version v2 --as user --title" "skills/lark-dispatch/SKILL.md" "Skill does not mix v2 with v1 title flag"

if [ -x "$ROOT_DIR/scripts/check-docs-api.sh" ]; then
  ok "check-docs-api.sh is executable"
else
  fail "check-docs-api.sh is not executable"
fi

if [ -x "$ROOT_DIR/scripts/check-docs.sh" ]; then
  ok "check-docs.sh is executable"
else
  fail "check-docs.sh is not executable"
fi

if [ -x "$ROOT_DIR/scripts/smoke-test.sh" ]; then
  ok "smoke-test.sh is executable"
else
  fail "smoke-test.sh is not executable"
fi

printf '\nSummary: %s ok, %s failures\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
