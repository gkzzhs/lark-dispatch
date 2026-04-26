<p align="center">
  <h1 align="center">📨 lark-dispatch</h1>
  <p align="center">
    <strong>基于飞书 CLI 的会后知识智能分发 Agent</strong><br>
    会议结束后，AI 自动从纪要中提取决策、待办、知识点，识别相关人，经用户确认后按人分发——任务建到飞书任务、知识沉淀到知识库、通知发到相关人。
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/version-1.1.0-blue" alt="version">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="license">
    <img src="https://img.shields.io/badge/lark--cli-%3E%3D1.0.13-orange" alt="lark-cli">
    <img src="https://img.shields.io/badge/zero%20code-pure%20SKILL.md-blueviolet" alt="zero code">
    <img src="https://img.shields.io/badge/飞书%20AI%20校园挑战赛-2026-red" alt="contest">
  </p>
</p>

---

## 😩 它解决什么问题

你一定经历过这种场景——

一场一小时的会，决策讨论了 5 条，待办口头分了 3 个，还冒出几个好想法。会议纪要？飞书 AI 帮你生成了。然后呢？

**然后就没有然后了。**

纪要存在文档里，相关人不知道、不看、不翻。口头分的待办没人建任务，两周后才发现没人做。有价值的技术讨论散落在一次会议里，团队无法复用。

我之前做了 [lark-retro](https://github.com/gkzzhs/lark-retro)，解决了"数据收集 + 报告生成"的问题。但跑了一段时间发现：**报告生成了，然后死在了知识库里，没人看。**

所以我做了 lark-dispatch：**开完会，AI 自动把决策、待办、知识点分给该知道的人。知识不落地，不散会。**

## 🧭 Before / After

| | Before（手动） | After（lark-dispatch） |
|---|---|---|
| **信息提取** | 人工翻会议纪要，逐条识别 | AI 自动分类：待办 / 决策 / 知识点 |
| **责任分配** | 口头说"你来做"，无记录 | 自动创建飞书任务，指定负责人 |
| **知识沉淀** | 存文档，没人翻 | 自动写入知识库，按主题归档 |
| **通知到人** | 群里 @一下，容易漏 | 按信息类型定向分发到个人 |
| **总耗时** | 50-75 分钟 | < 3 分钟 |

## ⚡ 核心工作流（6 步）

```
Step 1  定位会议
        ↓  用户说"帮我处理今天下午的产品评审会" → 搜索日历 + 妙记
Step 2  AI 提取
        ↓  从会议纪要中提取：待办项 / 决策项 / 知识点
Step 3  解析相关人
        ↓  识别每条信息的相关干系人 → 调用通讯录匹配 open_id
Step 4  用户确认 ← 关键门控
        ↓  展示提取结果，用户可修改/删除/补充，确认后才执行
Step 5  执行分发
        ↓  待办 → 创建飞书任务 | 决策 → 发消息通知 | 知识 → 写入知识库
Step 6  生成报告
        ↓  输出分发执行报告：成功/失败/跳过，附飞书文档链接
```

**核心设计原则：AI 辅助提取，人类拍板执行。** Step 4 的确认门控确保 AI 提取错误不会导致错误分发。

## 📊 效果验证

**2 场独立真实会议，22 条信息提取，零失败，零误触发。**

| 指标 | 第一场（Mini Camp） | 第二场（OPC 创造营） | 累计 |
|------|:------------------:|:------------------:|:----:|
| 会议时长 | 2.3 小时 | 1.7 小时 | — |
| 信息提取总数 | 10 条 | 12 条 | **22 条** |
| 提取准确率 | 100% | 100% | **100%** |
| 分发成功率 | 100%（4/4） | 100%（5/5） | **100%** |
| 降级跳过 | 6 条（跨租户） | 8 条（跨租户） | 14 条 |
| 流程中断 | 0 次 | 0 次 | **0 次** |
| 效率提升 | 17–25x | 17–25x | — |

两场覆盖了「同租户任务可创建」和「全跨租户降级」两种极端场景，系统均稳定运行。

> 完整验证数据见 [效果验证报告 v1.1.0](docs/效果验证报告.md)

## 🏗️ 技术栈

纯 SKILL.md 实现，零代码。依赖飞书 CLI (lark-cli) 的原子能力：

| 能力 | 飞书 CLI 命令 | 用途 |
|------|-------------|------|
| 日历搜索 | `calendar +agenda` | 定位目标会议 |
| 妙记读取 | `minutes search` / `minutes get` | 获取会议纪要内容 |
| 通讯录查询 | `contact +search-user` / `contact +get-user` | 解析相关人 open_id |
| 任务创建 | `task +create` | 创建待办任务并指定负责人 |
| 消息发送 | `im +messages-send` | 定向通知决策相关人 |
| 文档创建 | `docs +create` | 生成分发报告 |
| 知识库写入 | `wiki +create-node` | 沉淀知识点到知识库 |

## 📁 项目结构

```
lark-dispatch/
├── README.md                    # 本文件
├── LICENSE                      # MIT License
├── skills/
│   └── lark-dispatch/
│       └── SKILL.md             # 核心 Skill 定义（可直接安装使用）
├── docs/
│   ├── 场景定义文档.md           # 完整场景分析与产品设计
│   └── 效果验证报告.md           # 真实数据验证结果
└── demo/
    ├── dispatch-report.md       # 示例分发报告
    └── knowledge.md             # 示例知识沉淀
```

## 🚀 快速开始

### 前置条件

- [飞书 CLI](https://github.com/larksuite/cli) >= 1.0.13
- 已完成 `lark-cli auth login`（user 身份）
- 所需 Scope：`minutes:minutes.search:read`、`minutes:minutes.basic:read`、`minutes:minutes:readonly`、`minutes:minutes.artifacts:read`、`contact:contact.user:readonly`、`task:task:write`、`wiki:wiki:write`、`im:message:send`

### 安装

将 `skills/lark-dispatch/` 目录复制到你的 Agent 的 skills 目录下即可。

### 使用

对你的 Agent 说：

```
帮我处理一下今天下午的产品评审会
```

Agent 会自动执行 6 步流程，在 Step 4 展示提取结果等你确认。

## 🔗 相关项目

- [lark-retro](https://github.com/gkzzhs/lark-retro) — 基于飞书 CLI 的 AI 回顾 & 周报工作流（lark-dispatch 的前身）
- [飞书 CLI](https://github.com/nicepkg/lark-cli) — 飞书命令行工具

## 🏆 参赛信息

本项目为**飞书 AI 校园挑战赛 2026** OpenClaw 赛道参赛作品，课题方向：企业办公知识整合与分发 Agent。

## 📄 License

[MIT](LICENSE)

---

<p align="center">
  <strong>开完会，AI 自动把该知道的事告诉该知道的人。</strong>
</p>
