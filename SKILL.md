---
name: dev-setup
description: >-
  AI 原生项目工程化基座与多 Agent 全生命周期协同规范（Project OS）。当用户开启新项目初始化（init）、纳管存量老项目、配置统一目录结构与文档体系（PRD/架构/ADR/接口契约/迭代/验收/踩坑错题本）、编写 README 与 AGENTS.md/CLAUDE.md/GEMINI.md、执行断点续开发（resume）、生成跨会话或多 AI 交接单與方案互审（handoff）、开辟多终端并行开发隔离工作区（worktree）、执行阶段验收与版本发布（release），或进行项目规范健康巡检与文档防腐烂修复（audit）时，必须激活此 Skill。Use whenever bootstrapping a new or existing software project, configuring agent rules, documentation lifecycle, Git dual-trunk workflow, git worktree multi-agent isolation, session checkpoint/resume/handoff, milestone release, or project hygiene audit.
---

# `dev-setup` — AI 原生项目工程化基座与多端协同协议

本 Skill 用于将任何全新或存量软件项目纳入一套**跨 AI 工具通用、全项目高度统一、支持多终端并发与无损断点接力**的标准工程体系。完成初始化后，目标项目内的 `AGENTS.md` 与 `docs/00-ai-hub/` 将构成自治运行的「项目操作系统」，确保任何后续接入的 AI（即使未安装本 Skill）也能严格按同一套工程纪律协作。

---

## 1. 意图识别与 6 大模式路由（按需加载）

收到用户请求后，首先判定当前任务属于以下哪种模式，并**仅读取对应模式的参考手册**以节约上下文窗口：

| 模式标识 | 典型触发场景 | 必读操作规程（按需读取） |
| :--- | :--- | :--- |
| **`init`** | 开启新项目基建、将已有半成品/混乱老项目改造为标准规范 | [mode-init-and-brownfield.md](./references/mode-init-and-brownfield.md) |
| **`resume`** | 新开终端/切换 AI 接手项目、询问“上次做到哪了/继续开发” | [mode-resume-and-handoff.md](./references/mode-resume-and-handoff.md) |
| **`handoff`** | 当前会话准备停工、上下文快满、换另一个 AI 接力，或多 AI 方案比选/交叉审查 | [mode-resume-and-handoff.md](./references/mode-resume-and-handoff.md) |
| **`worktree`** | 开启第 2+ 个终端并行开发不同功能分支，或回收已合并的并行工作区 | [mode-git-worktree-and-release.md](./references/mode-git-worktree-and-release.md) |
| **`release`** | 完成某一轮迭代开发，执行验收核对、合入 `main`、更新日志并打版本号 Tag | [mode-git-worktree-and-release.md](./references/mode-git-worktree-and-release.md) |
| **`audit`** | 项目运行一段时间后检查文档是否腐烂、有无根目录垃圾、命名违规、僵尸锁或规范偏离 | [mode-audit-and-doc-ssot.md](./references/mode-audit-and-doc-ssot.md) |

> **新建或修改任何文档前必读标准**：凡涉及新建文件夹、新增阶段文档（需求/迭代/测试/验收/ADR/交接/评审）或修改现有文档，必须严格遵守 **[文件命名、信息标签词典与变更溯源标准](./references/standards-naming-and-metadata.md)**。

---

## 2. 全项目唯一标准拓扑与文档命名基准（禁止擅自变形）

无论项目大小或技术栈如何，所有受管项目严格对齐以下工程与文档外壳（**注意：`init` 阶段绝不预建 `src/` 等空业务源码目录；文件夹统一用小写英文 `kebab-case`；`docs/` 内文档采用「大写类型码-编号-中文直白主题.md」，其中 `-000-` 代表全周期仅一份原地更新的常青主文档**）：

```text
<project-root>/
├── AGENTS.md                        # 【唯一主宪法】所有 AI 的最高行为准则与流程总纲（SSOT）
├── CLAUDE.md                        # 【桥接指针】极简指令，强制引导 Claude Code 读取 AGENTS.md
├── GEMINI.md                        # 【桥接指针】极简指令，强制引导 Gemini / Antigravity 读取 AGENTS.md
├── .cursor/rules/00-project-os.mdc  # 【IDE 桥接】Cursor 等编辑器常驻规则，强制指向 AGENTS.md
├── README.md                        # 【面向人类】项目定位、技术栈、快速启动命令、目录速览与文档入口
├── CHANGELOG.md                     # 【版本演进】基于 SemVer 的里程碑变更归档
├── .env.example                     # 【安全防呆】环境变量键名模板（严禁提交真实 .env 与秘钥）
├── .gitignore                       # 【版本防护】默认忽略秘钥、敏感库快照、.tmp/* 与 .worktrees/
├── .tmp/                            # 【临时草稿隔离区】AI 一次性测试脚本与草稿唯一存放处（Git 忽略内容）
└── docs/                            # 【全项目正式文档与 AI 协同唯一中心】
    ├── 00-index.md                  # 文档总导航 + 单一事实源（SSOT）与代码变更联动矩阵
    ├── 00-ai-hub/                   # AI 运行时控制中枢
    │   ├── STATE.md                 # 全局断点状态面板（当前阶段、已完成禁改区、进行中、阻塞项、下一步）
    │   ├── SESSIONS.md              # 多终端/多 AI 活跃会话登记与模块锁表
    │   ├── handoffs/                # 交接单：YYYY-MM-DD-HHmm-<交出AI>-to-<接收AI>-<中文主题>.md
    │   └── reviews/                 # 方案与审查：YYYY-MM-DD-<PROPOSAL|REVIEW>-<中文主题>-by-<AI>.md
    ├── 01-prd/                      # 需求中心：PRD-000-全局产品需求总纲.md + PRD-00X-<中文主题>.md
    ├── 02-architecture/             # 架构中心：ARCH-000-系统架构与模块设计总纲.md + adr/ADR-000X-<中文主题>.md
    ├── 03-contracts/                # 契约中心：API-000-全局接口契约总表.md + DATA-000-核心数据模型与字典.md
    ├── 04-iterations/               # 迭代中心：ITER-01-v0.1.0-MVP首轮迭代计划.md（按 ITER-XX-vX.Y.Z-<中文主题> 递增）
    ├── 05-acceptance/               # 验收测试：ACCEPT-01-v0.1.0-MVP首轮验收单.md / TEST-XX-vX.Y.Z-<中文主题>.md
    ├── 06-ops-and-pitfalls/         # 运维与错题：OPS-000-环境搭建与部署运维手册.md + PITFALLS-000-项目踩坑错题本.md
    └── 99-archive/                  # 历史归档区：存放已标记 SUPERSEDED / DEPRECATED 的淘汰历史文档
```

---

## 3. 全局不可逾越的五大工程铁律

在执行本 Skill 的任何模式，以及编写目标项目的 `AGENTS.md` 时，必须强制贯彻以下准则：

1. **进场先对齐铁律**：新会话开工前，必读 `AGENTS.md` → `docs/00-ai-hub/STATE.md` → `SESSIONS.md` → 最新 `handoffs/` → `docs/06-ops-and-pitfalls/PITFALLS-000-项目踩坑错题本.md`，先向用户输出 **≤5 行的「进度对齐简报」**，再动手修改代码。
2. **反糊弄铁律**：严禁未经用户明确允许用硬编码假数据（Mock / Stub / 空 `TODO`）冒充已完成；未在终端实际跑通验证命令前，严禁声称“已完成”。
3. **防越界、洁癖与标准命名溯源铁律**：
   - 严守最小改动半径，禁止顺手重构无关文件、擅自新增/升级重型依赖、触碰其他 AI 在 `SESSIONS.md` 锁定的模块，或污染项目根目录（临时文件一律进 `.tmp/`）。
   - **命名、标签与修订留痕**：文件夹一律用小写 `kebab-case`，全仓严禁 `_v2`/`_new`/`_final`/`_bak` 等混乱后缀；`docs/01`~`06` 所有文档必须严格按公式命名，顶部包含**中文文档元信息卡**（使用受控状态标签 `DRAFT`/`ACTIVE`/`COMPLETED`/`SUPERSEDED`/`DEPRECATED`），每次修改正文必须同步更新元信息卡中的「最后修改」并在文末《文档变更记录》追加记录行；作废旧文档一律改状态后归档至 `docs/99-archive/`。
4. **数据安全与脱敏推送铁律（双保险强制门禁）**：
   - **代码与配置零硬编码**：严禁在源码、脚本、测试、配置文件中硬编码任何真实 API Key（`sk-...`、`AIza...`、`ghp_...` 等）、云厂商 AK/SK（`AKIA...`、`LTAI...`、`AKID...`）、私钥、带明文密码的数据库连接串或飞书/企微/钉钉/Slack Webhook Token。
   - **文档与交接单强制脱敏**：编写 `README.md`、`deployment.md`、`pitfalls.md`、`handoffs/` 与 `reviews/` 时，严禁写入真实生产服务器公网 IP、SSH 凭据、未脱敏的 `Authorization` / `Cookie` 调试报文或真实用户隐私数据（PII，如真实手机号/邮箱/业务库导出样本），一律替换为 `<YOUR_API_KEY>`、`<REDACTED>` 等安全占位符。
   - **自主提交推送与物理钩子门禁**：项目初始化时默认自动安装 `.git/hooks/pre-commit` 与 `pre-push` 敏感拦截钩子。**只要通过自动化秘钥与敏感数据扫描（无违规阻断），允许 AI 按工程流程自主执行 `git commit` 与 `git push`**；一旦钩子或 `secret-scan` 报警阻断，严禁使用 `--no-verify` 强行绕过！首次创建远端仓库默认必须为 `Private`，若远端为 `Public` 仓库则推送前必须额外核验无任何内部架构敏感路径。
5. **高危操作熔断铁律**：凡涉及删除核心文件/持久化数据、推翻既有 ADR 架构决策、`git reset --hard`、`git push --force`、绕过安全钩子（`--no-verify`）或直接在 `main` 分支提交，必须立即停下请示人类确认。
6. **双主干与双轨隔离规范**：
   - Git 采用 `main`（仅存已验收稳定版 + `vX.Y.Z` Tag）← `develop`（日常迭代集成主干）← `feat/*`、`fix/*`、`docs/*`、`refactor/*`、`spike/*`。
   - 多终端并行改不同分支时，强制使用 `git worktree`（挂载于 `.worktrees/<branch-slug>`）物理隔离；同分支处理轻量非重叠目录时，使用 `SESSIONS.md` 登记模块锁。
7. **语言与 Commit 规范**：文档、代码关键注释、日常沟通、交接单一律使用**中文**；代码标识符与 Git 分支名使用**英文**；Commit Message 统一为 `<type>(<scope>): <中文描述>`（如 `feat(auth): 实现登录鉴权与令牌刷新`）。

---

## 4. 确定性脚本执行引擎（优先调用，无环境自动降级）

为实现「1 秒零误差建骨架、自动部署安全钩子、大幅节省 Token」，本 Skill 在 `scripts/` 下内置了零外部依赖的双平台脚本（逻辑完全一致）：

- **Windows（PowerShell 5.1 / 7+）**：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" -Action <init|git-setup|worktree-add|worktree-remove|secret-scan|audit> -TargetDir "<TARGET_PROJECT_DIR>" [参数...]
  ```
- **macOS / Linux / Git Bash（POSIX sh / bash）**：
  ```bash
  sh "<SKILL_DIR>/scripts/bootstrap.sh" --action <init|git-setup|worktree-add|worktree-remove|secret-scan|audit> --target-dir "<TARGET_PROJECT_DIR>" [参数...]
  ```
- **受限环境降级兜底**：若当前运行环境禁止执行外部脚本，请直接读取 `[templates/](./templates/)` 目录下的 `.tmpl` 模板文件，替换模板变量（`{{PROJECT_NAME}}`、`{{PROJECT_SUMMARY}}`、`{{TECH_STACK}}`、`{{DATE}}`）后通过文件写入工具落盘，并手动执行对应 `git` 命令。
