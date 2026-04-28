# 主动触发 Demo 说明

本项目支持通过 OpenClaw 定时任务实现会后自动分发，无需手动触发，完全满足"主动触发"交付要求。

## 功能说明
- 每 30 分钟自动扫描当天已结束的会议
- 自动识别带有妙记的会议，判断是否已完成分发
- 对未分发的会议自动运行 lark-dispatch 工作流
- 提取待办、决策、知识点，生成确认草稿
- **严格遵循"先确认后执行"原则**：不会在用户确认前创建任务或发送消息

## 配置命令
使用以下命令创建定时触发任务：

```bash
openclaw cron add \
  --name "lark-dispatch 会后会议扫描" \
  --every 30m \
  --session isolated \
  --model zai/glm-5-turbo \
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
| `--model zai/glm-5-turbo` | 显式指定本次 cron 运行模型；不依赖当前默认模型 |
| `--thinking medium` | 思考深度设置，平衡效果和速度 |
| `--light-context` | 使用轻量上下文模式，减少资源消耗 |
| `--no-deliver` | 执行结果仅展示给用户，不自动投递 |
| `--message "..."` | 执行的具体任务指令 |

## 效果演示
1. 会议结束后，最长 30 分钟内 Agent 会自动识别到新会议
2. Agent 向用户发送确认消息，展示提取的待办、决策、知识点
3. 用户确认（或修改）后，Agent 执行分发动作
4. 生成分发报告并通知用户

## 当前环境参数验证（非破坏性）

测试日期：2026-04-28

| 项目 | 结果 |
|------|------|
| OpenClaw 版本 | `OpenClaw 2026.4.26 (be8c246)` |
| cron 参数 | `--every`、`--session isolated`、`--model zai/glm-5-turbo`、`--thinking medium`、`--light-context`、`--no-deliver`、`--disabled` 均可用 |
| 临时任务创建 | ✅ 成功，返回 disabled job |
| 临时任务清理 | ✅ 已执行 `openclaw cron rm <job_id>` 删除 |
| 残留检查 | ✅ `openclaw cron list` 返回 `No cron jobs.` |

本次只验证 cron 配置参数和任务生命周期，不触发真实会议扫描，也不创建任务、发送消息或写入文档。下一步仍需补充一次真实 cron E2E run history 作为主动触发闭环证据。

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
