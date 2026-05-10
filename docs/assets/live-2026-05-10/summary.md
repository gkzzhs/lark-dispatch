# 真实最小闭环实测摘要

- 实测时间：2026-05-10 07:51-07:54 CST
- 会议：威海OPC共创
- 妙记 token：`obcn27xt34ox9s245x877j56`
- 数据来源：逐字稿 fallback
- 用户确认范围：主闭环只执行 1 条未分配任务、1 份知识文档、1 份分发报告，跳过 IM；08:08 CST 用户单独确认后补测 1 条 bot IM

## 创建结果

| 资源 | 状态 | 链接 |
|---|---|---|
| 飞书任务 | 成功 | https://applink.feishu.cn/client/todo/detail?guid=31540b59-3d1e-4dc0-9373-9429fcddcfd5 |
| 知识沉淀文档 | 成功 | https://www.feishu.cn/docx/KbPDd9YryofBZgxHUW0cFBZnnhf |
| 分发报告文档 | 成功 | https://www.feishu.cn/docx/F7Esdur9EoVGGXxPYizcBeAKnbf |
| IM 推送 | 后续补测成功 | message_id `om_x100b50c888c774a4c3700aafb8fcaae`，chat_id `oc_1942d821be9157fea4eee1780e85e5b8` |
| docs v2 写入 | 后续补测成功 | https://mxevfgxd6ba.feishu.cn/docx/QcCqdXBKSo94SOxctG8cbevGnZf |
| 第三方/群聊 bot IM | 已实测受阻 | 目标 `oc_ca2752dd467518a5b5c5bddf77676ef9`；bot 不在会话中，错误码 `230002` |

## 降级与异常

- 知识文档首次创建返回 `folder locked`，随后串行重试成功。
- 分发报告创建后已执行 `docs +update --mode overwrite`，补入真实任务和知识文档链接。
- 收尾 `openclaw cron list` 仍显示 `No cron jobs.`。
- 刚创建的分发报告可能存在搜索索引延迟，标题搜索暂未命中，但创建和更新命令均返回成功。
- 08:08 CST 用户确认后，单独补测 bot IM 成功，消息发送给用户本人。
- 08:18 CST 用户确认后，单独补测 docs v2 真实创建和 overwrite 更新成功。
- 用户确认后尝试向第三方/群聊 `oc_ca2752dd467518a5b5c5bddf77676ef9` 发送 bot IM，真实发送失败；只读消息列表检查返回 `Bot/User can NOT be out of the chat.`，说明需要先把 bot 加入该会话，或改用 `ou_` 用户 open_id 做私聊测试。

## 原始证据文件

| 文件 | 内容 |
|---|---|
| `env.txt` | lark-cli、OpenClaw、模型状态 |
| `task-create.json` | 飞书任务创建原始返回 |
| `knowledge-doc-create-error.json` | 知识文档首次创建失败原始返回 |
| `knowledge-doc-create.json` | 知识文档重试创建成功原始返回 |
| `dispatch-report-create.json` | 分发报告创建原始返回 |
| `dispatch-report-update.json` | 分发报告 overwrite 更新原始返回 |
| `bot-im-send.json` | bot IM 补测发送原始返回 |
| `docs-v2-create.json` | docs v2 真实创建原始返回 |
| `docs-v2-update.json` | docs v2 overwrite 更新原始返回 |
| `third-party-bot-im-send-error.json` | 第三方/群聊 bot IM 发送失败原始返回 |
| `third-party-chat-read-error.json` | bot 不在目标会话的只读验证原始返回 |
| `cron-final-check.txt` | OpenClaw cron 收尾检查 |
| `final-check.txt` | 最终本地检查结果 |

## 最终检查

| 检查 | 结果 |
|---|---|
| `bash scripts/check-docs.sh` | 56 ok, 0 failures |
| `bash scripts/check-docs-api.sh` | 4 ok, 0 failures |
| `bash scripts/smoke-test.sh` | 23 ok, 1 warning, 0 failures |
| `git diff --check` | 通过 |
| `docs/assets/live-runs.jsonl` | JSONL 可解析 |
