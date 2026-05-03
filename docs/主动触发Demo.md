# 主动触发 Demo 说明

本项目支持通过 OpenClaw 定时任务配置会后主动触发入口。第三周期已验证 cron 配置与 run history 能真实产生；第四周期修复 OpenClaw runtime 后，已验证 cron isolated session 可读取真实飞书妙记并生成确认草稿。确认后的核心分发链路仍必须等待用户确认，已通过手动触发同一 Skill 流程完成真实飞书闭环验证。

## 功能说明
- 目标能力：每 30 分钟检查当天已结束的会议
- 目标能力：识别带有妙记的会议，判断是否已完成分发
- 当前已验证：cron 任务可创建、可手动触发、可产生 run history
- 当前已验证：cron isolated session 可读取真实飞书妙记并生成确认草稿
- 已通过手动触发同一 Skill 流程验证：用户确认后执行真实 IM、任务、知识文档和分发报告
- **严格遵循"先确认后执行"原则**：不会在用户确认前创建任务或发送消息

## 配置命令
使用以下命令创建定时触发任务。该命令用于主动生成确认草稿；确认后的分发动作仍需要用户明确确认：

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

## 参数说明
| 参数 | 说明 |
|------|------|
| `--name "lark-dispatch 会后会议扫描"` | 定时任务名称，便于识别和管理 |
| `--every 30m` | 每 30 分钟执行一次，可根据需要调整频率 |
| `--session isolated` | 使用独立会话，不影响其他任务 |
| `--model deepseek/deepseek-chat` | 显式指定本次 cron 运行模型；第三周期当前环境默认模型为 DeepSeek |
| `--thinking medium` | 思考深度设置，平衡效果和速度 |
| `--light-context` | 使用轻量上下文模式，减少资源消耗 |
| `--no-deliver` | 执行结果仅展示给用户，不自动投递 |
| `--message "..."` | 执行的具体任务指令 |

## 效果演示
当前可演示的真实链路分为两段：

1. 主动触发入口：创建 cron 任务，手动触发 run，查看 run history，确认 cron 读取真实妙记并生成确认草稿。
2. 核心分发闭环：用户确认后，手动触发同一 lark-dispatch Skill 流程执行真实分发。
3. 用户确认后，执行飞书侧分发动作，生成任务、IM、知识沉淀文档和分发报告。
4. 不做无人值守分发，不把确认前的 cron 草稿生成写成已完成分发。

## 当前环境参数验证（非破坏性）

测试日期：2026-04-28

| 项目 | 结果 |
|------|------|
| OpenClaw 版本 | `OpenClaw 2026.4.26 (be8c246)` |
| cron 参数 | `--every`、`--session isolated`、`--model zai/glm-5-turbo`、`--thinking medium`、`--light-context`、`--no-deliver`、`--disabled` 均可用 |
| 临时任务创建 | ✅ 成功，返回 disabled job |
| 临时任务清理 | ✅ 已执行 `openclaw cron rm <job_id>` 删除 |
| 残留检查 | ✅ `openclaw cron list` 返回 `No cron jobs.` |

本次只验证 cron 配置参数和任务生命周期，不触发真实会议扫描，也不创建任务、发送消息或写入文档。第三周期已补充真实 cron run history 证据，详见下方“第三周期主动触发验证结果”；当时 cron 自动进入确认草稿阶段仍未打通，第四周期已在 OpenClaw 2026.5.2 下补齐该验证。

## 第四周期 cron 修复结果

第四周期修复与验证以 [cron-fix-summary-2026-05-03.md](assets/phase4/cron-fix-summary-2026-05-03.md) 为证据入口：

| 验证项 | 状态 | 说明 |
|---|---|---|
| OpenClaw 版本更新 | 已完成 | 从 `2026.4.26` 更新到 `2026.5.2` |
| gateway 健康检查 | 已完成 | 新版 gateway 恢复 `admin-capable` |
| isolated cron 文件读取 | 已完成 | cron 可读取仓库 README，并产生 `status: ok` 的 run history |
| isolated cron 读取真实飞书妙记 | 已完成 | cron 执行 `lark-cli vc +notes` 读取真实妙记，并生成确认草稿 |
| 自动投递确认草稿 | 未验证 | 本次使用 `--no-deliver`，`deliveryStatus: not-requested` 是预期结果 |
| 确认后自动执行分发 | 不做 | 仍需用户确认后执行，不做无人值守任务/IM/文档写入 |

当前可写结论：第四周期已修复 OpenClaw cron runtime 问题，验证 cron isolated session 可读取真实飞书妙记并生成确认草稿；完整分发仍遵守用户确认门控，确认后的 IM、任务、知识文档和分发报告已通过手动触发同一 Skill 流程完成真实飞书闭环验证。

## 第三周期主动触发验证结果

### 验证结论

第三周期验证以 [第三周期证据登记表](第三周期证据登记表.md) 为唯一事实来源：

| 结论 | 证据编号 | 说明 |
|---|---|---|
| cron 配置已验证 | E01 | 已创建真实 OpenClaw cron job，配置包含 `every 30m`、`isolated session`、`deepseek/deepseek-chat`、`delivery none` |
| cron run history 已验证 | E02 | cron 手动触发成功入队并产生 run history，证明主动触发入口可运行、可追踪 |
| cron 自动 E2E 未完成 | E07 | 自动进入完整 lark-dispatch 分发链路未完成，原因包括 runtime 文件 I/O 工具加载失败、`deliveryStatus: not-delivered`、gateway restart 导致任务中断 |
| 手动触发同一 Skill 流程完成核心闭环 | E03-E06 | 已读取真实飞书妙记，生成确认草稿，并在用户确认后完成 IM、任务、知识文档、分发报告 |

### cron 验证过程

E01 记录了真实 OpenClaw cron job 创建过程。第三周期验证使用当前环境模型参数 `deepseek/deepseek-chat`，job 配置为 `every 30m`、`isolated session`、`delivery none`，并在 message 中明确要求“生成确认草稿，不要在用户确认前创建任务或发消息”。

E02 记录了 cron 手动触发结果：任务成功入队并产生 run history。DeepSeek run 的 `status` 为 `ok`，说明模型侧执行已启动；但 run summary 显示 OpenClaw runtime 文件 I/O 工具加载失败，未能继续进入会议扫描和确认草稿生成，且 `deliveryStatus` 为 `not-delivered`。

E07 记录了失败与降级过程：gateway restart 后第三轮 run 被中断，状态为 `error`，错误为 `cron: job interrupted by gateway restart`。所有测试 cron 均已禁用或清理，最终 `openclaw cron list` 显示 `No cron jobs`。

### 降级验证过程

在 cron 自动 E2E 未完成的情况下，第三周期采用“手动触发同一 lark-dispatch Skill 流程”补齐核心业务闭环证据。该降级验证仍然有价值，因为：

- 输入仍来自真实飞书妙记：`威海OPC共创`，妙记 token `obcn27xt34ox9s245x877j56`。
- AI 提取逻辑一致：从同一会议内容中提取待办、决策、知识点。
- 用户确认门控一致：确认前不创建任务、不发送 IM、不写入知识库、不生成正式分发报告。
- 执行动作仍发生在飞书生态中：bot IM 推送成功，创建 1 条飞书任务，创建知识沉淀文档，创建并更新分发报告文档。
- 失败项被记录：未解析到明确同租户接收人的条目被跳过并写入分发报告，没有伪装成成功。

### 第三周期结论

第三周期已验证主动触发入口与运行记录，但 cron 自动 E2E 尚未完全打通；核心分发链路已通过手动触发同一 Skill 流程完成真实飞书闭环验证。

## 原计划真实 E2E 验证清单（第三周期 P0）

为满足主动触发交付要求，第三周期原计划补一次真实运行记录：

| 步骤 | 操作 | 证据 |
|------|------|------|
| 1 | 创建正式 cron 任务，仍保留“确认前不执行分发”约束 | `openclaw cron show <job_id>` 输出 |
| 2 | 手动触发一次 cron run，避免等待 30 分钟 | `openclaw cron run <job_id>` 输出 |
| 3 | 查看运行历史 | `openclaw cron runs --id <job_id>` 输出 |
| 4 | 确认 Agent 生成待办/决策/知识草稿 | 确认草稿截图或文本 |
| 5 | 用户确认后执行一条安全分发动作 | 任务/消息/文档链接或跳过原因 |
| 6 | 生成分发报告 | 报告链接 |

实际验收结果：第三周期证明了“定时入口可创建、可运行、可追踪”，但未证明“cron 自动进入会议扫描并生成确认草稿”。“确认草稿 -> 用户确认 -> 分发/报告”的业务闭环已通过手动触发同一 Skill 流程完成验证，不能冒充 cron 自动 E2E 成功。

## 管理命令（OpenClaw 2026.4.26 版本）
```bash
# 查看所有 cron 任务
openclaw cron list

# 查看任务历史运行记录
openclaw cron runs --id <job_id>

# 手动触发运行一次任务
openclaw cron run <job_id>

# 暂停/启用任务
openclaw cron disable <job_id>
openclaw cron enable <job_id>

# 删除任务
openclaw cron rm <job_id>
```
