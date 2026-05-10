# 真实实测 Runbook

本文档用于在真实飞书环境中跑一遍 lark-dispatch 最小闭环。真实实测会创建飞书资源，必须由用户明确确认后执行。

## 什么时候可以实测

当前建议：在 `check-docs` 与 `smoke-test` 均通过后即可实测。以 2026-05-10 当前环境为例，项目已具备最小真实闭环条件，但仍需用户明确给出两次确认：

1. 确认进入真实实测：允许读取真实妙记、生成确认草稿、做重复分发检查。
2. 确认真实执行：允许按确认草稿创建飞书任务、知识沉淀文档和分发报告；IM 推送视 bot 权限决定是否执行。

未收到第二次确认前，不创建任务、不发送消息、不写入知识库或分发报告。

## 实测前检查

```bash
cd lark-dispatch
bash scripts/check-docs.sh
bash scripts/check-docs-api.sh
bash scripts/smoke-test.sh
openclaw cron list
```

通过标准：

| 检查项 | 通过标准 |
|---|---|
| 文档门禁 | `check-docs.sh` 输出 `0 failures` |
| docs API 兼容 | `check-docs-api.sh` 输出 `0 failures` |
| 环境验收 | `smoke-test.sh` 输出 `0 failures` |
| 写入预览 | `task/docs/wiki/im/drive` dry-run 均通过 |
| cron 状态 | `openclaw cron list` 无启用任务 |
| 用户确认 | 用户明确回复“开始真实最小闭环实测” |

## 推荐实测范围

先跑最小闭环，不直接做大规模分发：

| 模块 | 最小实测动作 | 说明 |
|---|---|---|
| 妙记读取 | 读取 1 场用户指定会议 | 优先选内部同租户会议 |
| 确认草稿 | 生成 1 份确认草稿 | 必须列出数据来源、人员解析、确认前不执行 |
| 重复检查 | 先查本地 registry，再搜索同标题和同 `minute_token` 报告 | 命中后由用户决定是否补发 |
| 任务创建 | 创建 1 条已确认待办 | 责任人不明确时只创建未分配任务或跳过 |
| 知识沉淀 | 创建 1 份知识文档 | 可使用 `docs +create` 降级，不强依赖 wiki |
| 分发报告 | 最后创建 1 份报告文档 | 记录成功、失败、跳过和确认范围，并包含任务/知识文档真实链接 |
| IM 推送 | 可选 | 缺 bot 权限或 self-send 时跳过并写入报告 |

## 执行流程

### 1. 用户指定会议

用户提供以下任一信息：

- 妙记链接或 `minute_token`
- 会议标题 + 日期时间
- “最近一场有妙记的会议”

如果匹配多场会议，必须列出候选并让用户选择，不能自动取第一场。

### 2. 生成确认草稿

读取会议数据后，生成 Step 4 确认草稿。确认草稿必须包含：

- 会议标题、时间、`minute_token`
- 数据来源：AI 总结、章节、todos 或逐字稿 fallback
- 待办、决策、知识点列表
- 人员解析状态：已解析、多候选、未找到
- 确认后将执行什么
- 确认前不会执行什么

### 3. 重复分发检查

```bash
rg "\"minute_token\":\"<minute_token>\"|\"meeting_title\":\"<会议标题>\"" docs/assets/live-runs.jsonl
lark-cli docs +search --as user --query "分发报告 | <会议标题>" --page-size 10
lark-cli docs +search --as user --query "<minute_token>" --page-size 10
```

如果本地 registry 或飞书搜索命中历史报告，暂停并询问用户是否继续。用户未确认继续时，不执行真实写入。飞书搜索可能有索引延迟，因此真实执行成功后必须写入本地 registry。

### 4. 用户二次确认

只有用户明确回复以下含义，才进入真实执行：

```text
确认真实执行，只执行确认草稿里的这些条目
```

用户只确认部分条目时，只执行明确确认的条目。其他条目标记为“待确认/跳过”。

### 5. 真实执行

按确认范围串行执行。推荐顺序：先任务，再知识文档，最后分发报告。分发报告必须包含任务和知识文档的真实链接。

```bash
lark-cli task +create --as user --summary "<待办标题>" --due "<YYYY-MM-DD>"
lark-cli docs +create --as user --title "会议知识 | <会议标题> | <日期>" --markdown "@knowledge.md"
lark-cli docs +create --as user --title "分发报告 | <会议标题> | <日期>" --markdown "@dispatch-report.md"
```

如果 `docs +create` / `docs +update` 返回 `folder locked`、网络超时或临时 5xx，等待 2-3 秒后重试 1 次。重试前不要改成并行创建，也不要创建多份同名文档。

### docs API 兼容说明

当前稳定路径仍使用 v1 参数：

```bash
lark-cli docs +create --as user --title "会议知识 | <会议标题> | <日期>" --markdown "@knowledge.md"
lark-cli docs +update --as user --doc "<doc_url>" --markdown "@dispatch-report.md" --mode overwrite
```

如果迁移到 v2，必须改用 v2 参数，不能混用 `--title --markdown`：

```bash
lark-cli docs +create --api-version v2 --as user --content "@knowledge.md" --doc-format markdown
lark-cli docs +update --api-version v2 --as user --doc "<doc_url>" --content "@dispatch-report.md" --doc-format markdown --command overwrite
```

迁移前先运行：

```bash
bash scripts/check-docs-api.sh
```

如果 IM 条件满足，再执行：

```bash
lark-cli im +messages-send --as bot --user-id "<open_id>" --markdown "<用户确认的决策摘要>"
```

如果 bot scope 未开、用户未与 bot 建立会话、接收人是自己或 open_id 未解析，跳过 IM，并在报告里写明原因。

## 证据归档

建议将实测证据保存到：

```text
docs/assets/live-YYYY-MM-DD/
```

建议保留：

| 文件 | 内容 |
|---|---|
| `env.txt` | `lark-cli --version`、`openclaw --version`、模型状态 |
| `vc-notes.json` | 妙记读取结果摘要，不必保存完整隐私内容 |
| `confirmation-draft.md` | 用户确认前草稿 |
| `user-confirmation.txt` | 用户确认文字 |
| `task-create.json` | 任务创建结果 |
| `knowledge-doc-create.txt` | 知识文档创建结果 |
| `dispatch-report.md` | 分发报告正文 |
| `registry-entry.jsonl` | 追加到 `docs/assets/live-runs.jsonl` 的 registry 记录 |
| `cron-final-check.txt` | `openclaw cron list` 输出 |

## 停止条件

出现以下任一情况，停止真实写入：

1. 用户没有明确确认真实执行。
2. 多场会议匹配但用户未选择具体会议。
3. 人员解析出现多候选，且该条目必须指定接收人。
4. `docs +search` 命中历史报告，但用户未确认继续。
5. 任一写入命令需要高风险确认或返回权限错误，且用户未补充授权。

## 回滚与清理

本项目默认不自动删除真实飞书资源。若实测创建了错误任务或文档：

- 任务：在飞书任务中手动完成、关闭或删除。
- 文档：在飞书云文档中手动移动到回收站。
- IM：消息通常不可可靠回滚，只能补发说明消息。

因此真实实测优先选择最小闭环，并避免向大范围群聊推送。
