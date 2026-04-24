# Cursor Dual-Agent Workflow

在 Cursor 里搭一套 **arch + coder** 双角色协作工作流：arch 负责架构设计和 code review，coder 负责按阶段分解开发，每阶段完成触发 review，通过后定稿总结文档并进入下一阶段。

仓库本身只是"框架"——rules 模板、hooks 脚本、初始化工具。实际工作时，每个项目会在 `~/cursor-workflow/<项目名>/` 下积累自己的架构文档、阶段 plan、review 结论和 summary。

## 架构一览

```
┌─────────────────────────────────────┐   ┌────────────────────────────────┐
│  本仓库（框架，可公开）             │   │ ~/cursor-workflow/<项目名>/   │
│  cursor-dual-agent-workflow/        │   │ （项目工作流数据，私密）      │
│                                     │   │                                │
│  ├─ install.ps1      一键部署       │   │  ├─ state.json                 │
│  ├─ uninstall.ps1                   │   │  ├─ ARCHITECTURE.md            │
│  ├─ hooks.json       Cursor 钩子    │   │  ├─ PHASES.md                  │
│  ├─ hooks/           钩子脚本       │   │  ├─ phase-NN-plan.md           │
│  ├─ rules-template/  arch/coder 规则│   │  ├─ phase-NN-summary.md        │
│  ├─ workflow-template/ 文档脚手架   │   │  └─ phase-NN-review.md         │
│  └─ init-workflow.ps1 初始化新项目  │   │                                │
└──────────────┬──────────────────────┘   └────────────────┬───────────────┘
               │ install.ps1                                │ init-workflow.ps1
               ▼                                            ▼
      ~/.cursor/（用户级配置）                   每个项目根/.cursor/rules/
      hooks.json / hooks/                        workflow-core.mdc
      rules-template/ / workflow-template/       role-arch.mdc
      init-workflow.ps1                          role-coder.mdc
```

## 在新电脑上复刻（仅需 4 步）

```powershell
# 1. 装 Cursor（官网下载）

# 2. clone 本仓库
cd $HOME
git clone https://github.com/<你的用户名>/cursor-dual-agent-workflow.git

# 3. 安装到 ~/.cursor/
cd cursor-dual-agent-workflow
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

# 4. 重启 Cursor；之后每个新项目打开后执行一次：
#    cd <项目根>
#    powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.cursor\init-workflow.ps1
```

安装器会把所有文件布到 `~/.cursor/` 对应位置，原有 `hooks.json` 会自动备份。

## 日常使用

两个 Cursor 聊天窗口：

- **arch 聊天**：输入 `@role-arch <需求>` → 产出 `ARCHITECTURE.md` + `PHASES.md` + `phase-01-plan.md`
- **coder 聊天**：输入 `@role-coder 继续` → 读 plan 写代码 → 起草 `phase-01-summary.md`
- 切回 **arch 聊天**：`@role-arch 继续` → 做 review → 写 `phase-01-review.md`（frontmatter 带 `verdict: APPROVED` 或 `REJECTED`）
- 保存 review 文件的瞬间，hook 自动流转 `state.json`

状态机见 [workflow-template/README.md](workflow-template/README.md)。

## 项目数据存放位置

默认：`~/cursor-workflow/<项目名>/`（项目代码仓库外，不污染 git）。

覆盖方式：
- 设环境变量 `CURSOR_WORKFLOW_DIR=<任意绝对路径>`
- 或运行 `init-workflow.ps1 -UseProjectInternalDocs` 让文档放项目内 `docs/workflow/`（并记得 `.gitignore`）

查找顺序（hooks 内置）：
1. `CURSOR_WORKFLOW_DIR` 环境变量
2. `~/cursor-workflow/<工作区 leaf 目录名>/`
3. `<项目根>/docs/workflow/`

## 备份你的项目工作流数据

项目数据（架构决策、review 历史）很有价值，建议另起一个**私有 git 仓库**管理 `~/cursor-workflow/`：

```powershell
cd $HOME\cursor-workflow
git init
git add .
git commit -m "initial snapshot"
# 去 GitHub 创建私有仓库 cursor-workflow-archive 后
git remote add origin https://github.com/<你>/cursor-workflow-archive.git
git push -u origin main
```

之后每做完一个阶段随手 `git add . && git commit -m "phase 0N done on <project>" && git push` 即可。

## 升级框架

```powershell
cd $HOME\cursor-dual-agent-workflow
git pull
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

`install.ps1` 是幂等的：内容一致的文件会 `up-to-date` 跳过，变更的文件会先备份旧版再覆盖。

## 卸载

```powershell
cd $HOME\cursor-dual-agent-workflow
powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
```

卸载只影响 `~/.cursor/` 下的框架文件；`~/cursor-workflow/` 下的项目数据不会被触碰。

## 目录详解

| 路径 | 用途 |
|--|--|
| `hooks.json` | Cursor hooks 配置：sessionStart / stop / afterFileEdit 三个事件 |
| `hooks/_common.ps1` | 工作流目录查找、UTF-8 读写等公共函数 |
| `hooks/inject-state.ps1` | sessionStart: 把当前项目的 state 摘要注入会话上下文 |
| `hooks/on-stop.ps1` | stop: agent 停机时检查产物完整性，不齐则 followup |
| `hooks/on-after-edit.ps1` | afterFileEdit: 写入 review.md 时解析 verdict 自动流转 state |
| `rules-template/workflow-core.mdc` | 工作流核心规则（alwaysApply） |
| `rules-template/role-arch.mdc` | arch 角色规则（@role-arch 激活） |
| `rules-template/role-coder.mdc` | coder 角色规则（@role-coder 激活） |
| `workflow-template/` | 新项目初始化时复制到 `~/cursor-workflow/<项目名>/` 的骨架 |
| `init-workflow.ps1` | 新项目一键初始化：分发 rules 到项目根 + 铺工作流目录 |
| `install.ps1` | 部署本仓库到 `~/.cursor/` |
| `uninstall.ps1` | 从 `~/.cursor/` 移除（保留项目数据） |

## 平台

目前只支持 **Windows + PowerShell 5.1+**（脚本是 `.ps1`）。macOS/Linux 版本待补（把 PowerShell 脚本换成 bash 即可，逻辑同）。
