---
name: lark-dispatch
version: 1.1.0
description: "会后知识智能分发工作流：从会议纪要中自动提取待办、关键决策、知识要点，识别相关人，经用户确认后按人精准分发（创建任务、推送消息、沉淀知识库）。当用户需要会后分发、会议跟进、把纪要里的事情分给对应的人时使用。"
metadata:
  requires:
    bins: ["lark-cli>=1.0.13"]
    cliHelp: "lark-cli minutes --help && lark-cli vc --help && lark-cli contact --help && lark-cli task --help && lark-cli im --help && lark-cli docs --help && lark-cli wiki --help && lark-cli drive --help"
---

# 会后知识智能分发工作流

**CRITICAL — 开始前 MUST 先用 Read 工具读取 [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md)，其中包含认证、权限处理、安全规则。如果文件不存在，提示用户先安装官方 Skills：`npx skills add https://github.com/larksuite/cli -y -g`**

## 适用场景

- "帮我把这个会议的纪要分发一下" / "dispatch meeting notes"
- "把会上说的事情分给对应的人" / "会后跟进"
- "这个会议的待办帮我建任务" / "会议纪要里的决策通知相关人"
- "开完会了，帮我整理一下谁该做什么" / "会后分发"
- "把纪要里的知识点存到知识库" / "会后归档"

## 前置条件

仅支持 **user 身份**（`--as user`）。执行前确保已授权：

```bash
# 最低可用授权（妙记 + 文档 + 通讯录）
lark-cli auth login --scope "minutes:minutes.search:read minutes:minutes.basic:read minutes:minutes:readonly minutes:minutes.artifacts:read minutes:minutes.transcript:export"
lark-cli auth login --domain docs

# 推荐授权（+ 任务 + 通讯录搜索）
lark-cli auth login --domain task
lark-cli auth login --scope "search:user"

# 完整授权（+ 消息推送 + 知识库 + 会议录制搜索）
lark-cli auth login --scope "vc:record:readonly docs:document.content:read"
lark-cli auth login --domain wiki
# Bot 消息推送需在开发者后台开通 im:message:send_as_bot
```

> 多次 login 的 scope 会累积（增量授权）。

## 能力分层

| 层级 | 功能 | 所需授权 |
|------|------|---------|
| **基础版** | 会议纪要采集 + AI 提取 + 文档报告输出 | 妙记 scopes + `--domain docs` |
| **增强版** | + 待办自动创建飞书任务并分配 | + `--domain task` |
| **高级版** | + 决策/知识按人消息推送 + 知识库沉淀 | + bot 能力 + `--domain wiki` |
| **完整版** | + 会议录制补强 + 历史分发追踪 | + `vc:record:readonly` + `--domain base` |

缺少某一层的授权时，对应模块自动跳过，不影响其他功能。分发报告中标注"（未执行 — 需 `<具体授权命令>`）"。

## 核心理念

> **AI 辅助决策，人类拍板执行。**
>
> 所有提取结果必须展示给用户确认后才能执行分发动作。绝不静默发送消息或创建任务。

## 工作流总览

```
用户触发："帮我把这个会议分发一下"
    │
    ▼
Step 1: 定位目标会议 → 获取会议纪要
    │
    ▼
Step 2: AI 分析纪要 → 提取三类信息（待办 / 决策 / 知识）+ 识别相关人
    │
    ▼
Step 3: 解析相关人 → contact +search-user 获取 open_id
    │
    ▼
Step 4: ⚠️ 展示提取结果 → 用户确认 / 编辑
    │
    ▼
Step 5: 执行分发
    ├─► 5a: 待办 → task +create（分配给责任人）
    ├─► 5b: 决策 → im +messages-send（推送给相关人）
    └─► 5c: 知识 → wiki +node-create / docs +create（沉淀到知识库）
    │
    ▼
Step 6: 生成分发报告 → docs +create
```

---

## Step 1: 定位目标会议 & 获取纪要

### 1a: 定位会议

根据用户输入确定目标会议：

| 用户输入 | 处理方式 |
|----------|----------|
| 提供了妙记链接 | 从 URL 中提取 `minute_token` |
| "刚才开的会" / "最近的会" | `minutes +search --participant-ids "me" --start "<today>" --end "<now>"` 取最新一条 |
| "上午的 XX 会议" | `minutes +search --query "XX" --participant-ids "me" --start "<today_am>" --end "<today_pm>"` |
| 提供了会议 ID | `vc +search` 按 ID 查找，获取 `minute_token` |

```bash
# 搜索自己参加的最近会议
lark-cli minutes +search --participant-ids "me" --start "<start>" --end "<end>" --format pretty

# 获取妙记基本信息
lark-cli minutes minutes get --params '{"minute_token": "<token>"}'
```

### 1b: 获取会议纪要内容（AI 产物）

```bash
# 获取 AI 总结、章节、待办等（核心数据源）
lark-cli vc +notes --minute-tokens <minute_token>
```

返回结构包含：
- `artifacts.summary`：AI 生成的完整会议总结
- `artifacts.chapters[]`：章节列表（含标题 + 摘要）
- `artifacts.todos[]`：飞书 AI 已识别的待办事项
- `note_doc_token`：纪要文档 token（可进一步 fetch 全文）
- `verbatim_doc_token`：逐字稿 token

> **数据优先级**：`summary` + `chapters` + `todos` 通常已足够进行分析。仅当用户要求更详细分析时，才通过 `docs +fetch --token <note_doc_token>` 读取纪要全文。

### 1c: 补强会议录制内容（可选）

如果 `vc +notes` 返回的信息不够完整：

```bash
# 搜索相关会议录制
lark-cli vc +search --start "<date>" --end "<date>" --query "<会议关键词>"

# 获取会议记录详情
lark-cli vc +notes --minute-tokens <minute_token>
```

---

## Step 2: AI 分析 & 提取

对 Step 1 获取的纪要数据进行 AI 分析，提取三类信息：

### 提取规则

**类型 1: 待办事项（Action Items）**
- 识别标志：包含"负责"、"完成"、"截止"、"下周前"、"需要 XX 做"等动作性语言
- 必须提取：**具体任务描述** + **责任人姓名** + **截止时间**（如有）
- 飞书 AI 已提取的 `todos[]` 直接采纳，AI 补充遗漏项
- 如果无法从纪要中确定责任人，标记为"待指定"

**类型 2: 关键决策（Decisions）**
- 识别标志：包含"决定"、"确认"、"方案"、"改为"、"统一"、"不再"等决策性语言
- 必须提取：**决策内容** + **相关人**（谁提出的、谁需要知道）
- 决策需要通知到所有相关人，确保信息对齐

**类型 3: 知识要点（Knowledge）**
- 识别标志：有参考价值的结论、数据、方法论、经验总结
- 必须提取：**知识内容** + **分类标签**
- 适合沉淀到知识库供团队长期复用的信息

### AI 输出格式

AI 必须将提取结果组织为以下结构（用于 Step 4 展示给用户）：

```
## 📋 待办事项（Action Items）

| # | 任务描述 | 责任人 | 截止时间 | 来源章节 |
|---|---------|--------|---------|---------|
| 1 | xxx     | 张三   | 4/20    | 章节标题 |

## 📢 关键决策（Decisions）

| # | 决策内容 | 相关人 | 来源章节 |
|---|---------|--------|---------|
| 1 | xxx     | 李四、王五 | 章节标题 |

## 📚 知识要点（Knowledge）

| # | 知识内容 | 分类标签 | 来源章节 |
|---|---------|---------|---------|
| 1 | xxx     | 工具推荐 | 章节标题 |
```

### 分析注意事项

1. **不要编造**：如果纪要中没有明确的待办/决策/知识，对应类别留空并标注"（未识别到）"
2. **引用来源**：每条提取结果标注来自哪个章节，便于用户核验
3. **去重**：飞书 AI 已识别的 todos 与 AI 新提取的待办做去重
4. **相关人优先从纪要中提取**：优先使用纪要中出现的真实姓名，不要猜测

---

## Step 3: 解析相关人 → 获取 open_id

对 Step 2 中提取的所有人名，通过通讯录搜索获取 `open_id`：

```bash
# 搜索用户获取 open_id
lark-cli contact +search-user --query "张三"
```

**处理规则：**
1. 搜索结果唯一 → 直接使用该 `open_id`
2. 搜索结果多个 → 在 Step 4 中列出候选，让用户选择
3. 搜索无结果 → 标记为"未找到"，在 Step 4 中提示用户手动指定
4. **批量搜索**：对所有相关人逐一搜索，汇总结果

> **⚠️ 通讯录搜索受权限范围限制**：只能搜到同一组织/租户内的用户。跨组织参会人无法解析。
>
> **✅ 企业内部（同租户）场景**：经第三场真实验证，同租户环境下人员解析成功率 100%（1/1），任务可精准分配给具体责任人 open_id。推荐用于企业团队内部会议的分发场景。

---

## Step 4: ⚠️ 展示提取结果 & 用户确认（CRITICAL）

**这是整个工作流最关键的一步。绝不跳过。**

将 Step 2 的提取结果 + Step 3 的人员解析结果，完整展示给用户：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 会议：{会议标题}
📅 时间：{会议时间}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 📋 待办事项（将创建飞书任务）

| # | 任务描述 | 责任人 | open_id 状态 | 截止时间 |
|---|---------|--------|-------------|---------|
| 1 | xxx     | 张三   | ✅ 已解析    | 4/20    |
| 2 | xxx     | 待指定  | ⚠️ 需手动指定 | -      |

## 📢 关键决策（将推送飞书消息）

| # | 决策内容 | 推送给 | open_id 状态 |
|---|---------|--------|-------------|
| 1 | xxx     | 李四   | ✅ 已解析    |

## 📚 知识要点（将沉淀到知识库）

| # | 知识内容 | 分类标签 |
|---|---------|---------|
| 1 | xxx     | 工具推荐 |

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
请确认以上内容，或告诉我需要修改的地方：
- 修改：如 "第 1 条待办改成 XXX" / "张三改成李四"
- 删除：如 "去掉第 2 条决策"
- 补充：如 "再加一条待办：XXX 负责人 YYY"
- 确认：回复 "确认" 或 "OK" 开始分发
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**用户确认规则：**
- 用户说"确认" / "OK" / "没问题" / "开始分发" → 进入 Step 5
- 用户提出修改 → 更新提取结果，重新展示
- 用户说"取消" → 终止工作流

---

## Step 5: 执行分发

### 5a: 待办 → 创建飞书任务

```bash
# 为每条待办创建任务并分配
lark-cli task +create --summary "<任务描述>" --due "2026-04-30" --assignee "<open_id>"
```

**处理规则：**
- 每创建一个任务，记录返回的 `task_guid` 用于分发报告
- 责任人为"待指定"的待办：仅创建任务不分配，在分发报告中标注
- 创建失败时记录错误，继续处理下一条，不中断
- 截止时间优先使用 ISO 日期（如 `2026-04-30`）或带时区时间；v1.0.20 dry-run 已验证 `--due 2026-04-30` 可稳定转换为全天截止时间

### 5b: 决策 → 推送飞书消息

```bash
# 私聊推送（需 bot 身份）
lark-cli im +messages-send --as bot --user-id "<open_id>" \
  --markdown "📢 **会议决策通知**\n\n来自：{会议标题}\n\n{决策内容}\n\n---\n_由 lark-dispatch 自动分发_"

# 群聊推送（如果用户指定了群）
lark-cli im +messages-send --as bot --chat-id "<chat_id>" \
  --markdown "📢 **会议决策通知**\n\n{决策内容}"
```

**处理规则：**
- 私聊推送需要用户先与 bot 有会话，如果失败降级为在分发报告中列出
- 如果 bot 未配置，跳过消息推送，在分发报告中标注"（消息推送跳过 — 需配置 bot）"
- **⚠️ 飞书不支持 self-send**（向自己发送消息）：`im +messages-send` 对发起人自身会返回 `HTTP 400: field validation failed`，这是飞书平台限制，非 Skill bug。当责任人与分发触发人为同一用户时，降级为分发报告中列出，由用户自行处理。

### 5c: 知识 → 沉淀到知识库

```bash
# 路径 A：创建知识库节点（推荐，v1.0.13 起自动给用户授权）
lark-cli wiki +node-create --space-id "my_library" --title "会议知识 | {会议标题} | {日期}"
lark-cli docs +update --doc "<node_token>" --markdown "@knowledge.md" --mode overwrite

# 路径 B：创建独立文档（降级）
lark-cli docs +create --title "会议知识 | {会议标题} | {日期}" --markdown "@knowledge.md"

# 路径 C：归档到指定文件夹（v1.0.13 新增）
lark-cli drive +create-folder --name "会议分发归档 | {月份}" --parent "<folder_token>"
```

> **v1.0.13 改进**：知识库节点创建后自动给用户授权，无需手动处理权限。分发报告可归档到指定云空间文件夹。

**知识文档格式：**
```markdown
# 会议知识沉淀 | {会议标题}

📅 会议时间：{时间}
📝 来源：{妙记链接}

---

## 知识要点

### 1. {知识标题}
{知识内容}

> 来源章节：{章节标题}

---

_由 lark-dispatch 自动沉淀 | {日期}_
```

---

## Step 6: 生成分发报告

所有分发动作完成后，生成汇总报告：

```bash
# 将报告写入文件
cat > dispatch-report.md << 'EOF'
# 📊 会后分发报告

## 会议信息
- **会议**：{会议标题}
- **时间**：{会议时间}
- **分发时间**：{当前时间}

## 分发汇总

| 类型 | 总数 | 已分发 | 跳过 | 失败 |
|------|------|--------|------|------|
| 📋 待办 | {n} | {n} | {n} | {n} |
| 📢 决策 | {n} | {n} | {n} | {n} |
| 📚 知识 | {n} | {n} | {n} | {n} |

## 详细记录

### 📋 待办分发

| 任务描述 | 责任人 | 飞书任务 | 状态 |
|---------|--------|---------|------|
| xxx | 张三 | [任务链接] | ✅ 已创建 |

### 📢 决策推送

| 决策内容 | 推送给 | 方式 | 状态 |
|---------|--------|------|------|
| xxx | 李四 | 私聊 | ✅ 已推送 |

### 📚 知识沉淀

| 知识内容 | 沉淀位置 | 状态 |
|---------|---------|------|
| xxx | [知识库链接] | ✅ 已沉淀 |

---

_由 lark-dispatch 自动生成_
EOF

# 创建分发报告文档
lark-cli docs +create --title "分发报告 | {会议标题} | {日期}" --markdown "@dispatch-report.md"
```

> **⚠️ `@file` 必须使用相对路径**，需先 `cd` 到文件所在目录。

---

## 权限表

| 命令 | 授权方式 | 是否必须 | 用途 |
|------|---------|---------|------|
| `minutes +search` | `--scope "minutes:minutes.search:read"` | 是 | 搜索会议 |
| `minutes minutes get` | `--scope "minutes:minutes.basic:read"` | 是 | 获取妙记信息 |
| `vc +notes` | `--scope "minutes:minutes:readonly minutes:minutes.artifacts:read minutes:minutes.transcript:export"` | 是 | 获取 AI 产物 |
| `contact +search-user` | `--scope "search:user"` | 推荐 | 姓名 → open_id |
| `contact +get-user` | 默认 | 否 | 获取当前用户信息 |
| `task +create` | `--domain task` | 推荐 | 创建待办任务 |
| `docs +create` | `--domain docs` | 是 | 创建分发报告 |
| `docs +update` | `--domain docs` | 否 | 更新知识文档 |
| `docs +fetch` | `--scope "docs:document.content:read"` | 否 | 读取纪要全文 |
| `wiki +node-create` | `--domain wiki` | 否 | 知识库沉淀 |
| `im +messages-send` | `--as bot` 或 `--as user`(v1.0.13) | 否 | 消息推送（user 身份支持发图片/文件） |
| `drive +create-folder` | `--domain docs` | 否 | 创建归档文件夹 |
| `vc +search` | `--scope "vc:record:readonly"` | 否 | 会议录制搜索 |

## 边界情况处理

### 多场会议匹配

当用户说"今天的会"但当天有多场会议时：
1. 列出所有匹配的会议（标题 + 时间 + 时长）
2. 让用户选择具体哪一场
3. **绝不自动选第一场**

### 无纪要 / 纪要内容为空

- `minutes +search` 无结果 → 提示"没有找到匹配的妙记，请确认会议是否开启了录制"
- `vc +notes` 返回但 `summary` 和 `chapters` 均为空 → 提示"会议纪要内容为空，可能录制时间太短或 AI 未生成总结"
- 纪要存在但内容极少（如 <100 字）→ 正常处理，但在 Step 4 提示"纪要内容较短，提取结果可能不完整"

### 提取结果为空

如果 AI 分析后三类信息（待办 / 决策 / 知识）全部为空：
- 在 Step 4 展示："本次会议未识别到明确的待办、决策或知识要点。可能原因：会议以讨论为主、内容尚未形成结论。"
- 询问用户是否手动添加分发项
- **不要为了输出而编造**

### 大型会议（章节 > 20 / 时长 > 2 小时）

- 优先使用 `summary` + `todos` 进行分析（已压缩）
- 仅当用户要求"更详细"时才逐章节分析 `chapters[]`
- 避免一次性读取 `note_doc_token` 全文（可能超长），分段处理

### 相关人全部未解析

如果 Step 3 中所有人名都搜索无结果（如跨组织会议）：
- 在 Step 4 中明确标注每个人"❌ 未解析（跨租户）"
- 待办仍可创建（不分配责任人），决策和知识仍可沉淀
- **不要因为人名解析失败就中断整个工作流**

### 重复分发防护

如果用户对同一场会议多次触发分发：
- 提醒用户"这场会议已在 {上次分发时间} 分发过，是否继续？"（通过搜索标题匹配已有分发报告）
- 用户确认后正常执行（允许补发漏项）
- 不自动跳过

## 错误处理

| 错误 | 原因 | 处理 |
|------|------|------|
| `missing_scope` | 未授权某 scope | 跳过对应步骤，在分发报告中标注，显示修复命令 |
| `No minutes` | 无妙记数据 | 提示用户确认会议是否开启了录制 |
| `contact search no result` | 通讯录搜不到人 | 标记"未解析"，让用户手动指定 open_id |
| `bot message send failed` | 用户未与 bot 建立会话 | 降级为分发报告中列出，跳过推送 |
| `rate_limit` | API 限流 | 等待 1-2 秒后重试，最多 3 次 |
| `task create failed` | 任务创建失败 | 记录错误原文，继续下一条，不中断 |
| `wiki space not found` | 知识库不存在或无权限 | 降级为 `docs +create` 创建独立文档 |
| `docs create failed` | 文档创建失败 | 将报告内容直接输出到对话中，确保用户不丢失分发记录 |
| 网络超时 | 网络不稳定 | 重试 1 次；仍失败则跳过该步骤，在报告中标注 |

## 安全规则

- **⚠️ 所有分发动作必须经用户确认**：绝不静默创建任务、发送消息或写入知识库
- **⚠️ 严禁修改 `strict-mode`** 和 **`--profile`**
- **⚠️ 消息内容不泄露会议机密**：推送内容仅包含用户确认的决策摘要，不附带完整纪要
- **⚠️ 通讯录数据不外泄**：`open_id` 仅用于分发，不在报告中明文展示
- **⚠️ 不自作主张扩大分发范围**：如果用户确认了 3 条待办，就只分发 3 条，不要"顺便"加上 AI 觉得应该分发的内容
- **⚠️ 分发失败不静默吞掉**：任何步骤执行失败，必须在分发报告中明确标注失败原因和建议的手动操作步骤

## 主动触发模式（Auto-Dispatch）

lark-dispatch 支持两种触发方式：

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| **手动触发** | 用户主动告知 Agent 处理某场会议 | 按需分发、单次补发 |
| **主动触发入口（cron）** | 定时检查近期会议，生成待确认的分发草稿；确认后才执行分发 | 每日分发、团队级运营 |

### 配置主动触发（推荐：每日早晨检查昨日会议）

使用 OpenClaw cron 或系统 crontab 实现定时调度。第三周期已验证 cron 配置与 run history 可真实产生；第四周期在 OpenClaw 2026.5.2 下已验证 cron isolated session 可读取真实飞书妙记并生成确认草稿。即使由 cron 触发，也不能跳过用户确认门控。

**方式一：OpenClaw cron（推荐验证路径）**

```bash
openclaw cron add \
  --name "lark-dispatch 会后会议扫描" \
  --every 30m \
  --session isolated \
  --model deepseek/deepseek-chat \
  --thinking medium \
  --light-context \
  --no-deliver \
  --message "检查今天已结束且有妙记的会议，若发现未分发会议，运行 lark-dispatch 工作流：提取待办、决策、知识点，生成确认草稿，不要在用户确认前创建任务或发消息。"
```

该命令只配置主动触发入口。即使由 cron 触发，后续仍必须生成确认草稿，并等待用户明确确认后才能创建任务、发送消息或写入知识库。

**方式二：手动 cron 脚本**

    # crontab -e 添加以下行（每天 09:00 执行）
    0 9 * * * lark-cli minutes +search --participant-ids "me" \
      --start "$(date -v-1d '+%Y-%m-%d') 00:00" \
      --end "$(date -v-1d '+%Y-%m-%d') 23:59" \
      --format json > /tmp/yesterday_meetings.json
    # 将结果交给 Agent 处理

**方式三：事件驱动（高级，规划能力）**

通过飞书开放平台配置 webhook，在妙记生成后自动触发分发。适合有开发能力的团队，配置方法见[飞书开放平台文档](https://open.feishu.cn)。

### 自动触发时的行为约束

> **核心原则不变：AI 辅助决策，人类拍板执行。**

自动触发与手动触发的唯一区别在于"起点"——后续的 Step 4 用户确认门控**仍然存在**，不因自动触发而跳过。

在主动触发场景下，Step 4 的确认可通过对话或飞书消息承载。当前已验证的是手动触发同一 Skill 流程下的确认门控；飞书消息卡片确认属于后续可增强形态：
- Agent 先展示提取结果
- 用户明确确认后，才执行 Step 5
- 用户要求修改时，进入对话修改流程
- 未确认的条目不执行分发，并在报告中标注待确认或跳过原因

### 与 lark-retro 的联动

lark-dispatch 可作为 lark-retro 的下游模块：

    lark-retro（每周周期性汇总）
        ↓ 生成报告
    lark-dispatch（自动提取报告中的 Action Items）
        ↓ 分发给相关人
    飞书任务 / 消息 / 知识库

当 lark-retro 生成周期报告后，可把报告内容交给 lark-dispatch 做二次分发。该联动属于扩展方向，仍需遵守“先确认后执行”的安全门控。

## 参考

- [lark-shared](../lark-shared/SKILL.md) — 认证、权限、安全规则
- [lark-minutes](../lark-minutes/SKILL.md) — 妙记查询
- [lark-vc](../lark-vc/SKILL.md) — `vc +notes`, `vc +search`
- [lark-contact](../lark-contact/SKILL.md) — `contact +search-user`
- [lark-task](../lark-task/SKILL.md) — `task +create`
- [lark-doc](../lark-doc/SKILL.md) — `docs +create`, `docs +update`, `docs +fetch`
- [lark-wiki](../lark-wiki/SKILL.md) — `wiki +node-create`
- [lark-im](../lark-im/SKILL.md) — `im +messages-send`
- [lark-retro](../lark-retro/SKILL.md) — 姊妹项目，知识整合层
