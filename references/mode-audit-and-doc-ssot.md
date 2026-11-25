# 模式规程：`audit`（规范健康巡检）与文档单一事实源（SSOT）矩阵

当项目经过多轮多 AI 迭代后，用户要求“检查项目规范”、“做一次健康巡检 / `audit`”或“对齐一下文档和代码”时，按本规程执行。

---

## 一、文档单一事实源（SSOT）与代码变更联动全表

为彻底根治「文档写完就烂、代码改了文档不改、不同文档互相打架」，全项目严格执行**每类信息仅有一处主事实源（SSOT）**原则：

| 信息维度 | 唯一事实源（SSOT）路径 | 触发同步更新的代码/工程事件 |
| :--- | :--- | :--- |
| **AI 行为准则与标准命令** | `AGENTS.md` | 新增/变更启动、测试、构建、Lint 命令，或新增团队开发红线 |
| **面向人类的快速上手门面** | `README.md` | 首次落地业务源码目录结构、核心启动方式改变、重大特性上线 |
| **全局进度断点与冻结边界** | `docs/00-ai-hub/STATE.md` | 完成子任务、切换迭代阶段、遇到新阻塞项、模块验收冻结 |
| **多端并发锁与活跃工作区** | `docs/00-ai-hub/SESSIONS.md` | 新开并行终端/worktree 认领模块，或完工/交接释放锁 |
| **业务目标与功能范围边界** | `docs/01-prd/prd-overview.md` | 新增/砍掉业务功能、变更核心业务规则或不做边界 |
| **系统架构与源码目录映射** | `docs/02-architecture/system-design.md` | 初始化业务代码目录、拆分新模块/服务、引入新核心外部依赖 |
| **重大技术选型与架构取舍** | `docs/02-architecture/adr/NNNN-*.md` | 决定关键框架/存储/鉴权方案，或推翻历史技术决策 |
| **接口协议与数据模型结构** | `docs/03-contracts/api-spec.md` & `data-dictionary.md` | 新增/修改前后端 API 路径或出入参、新增/变更数据库表字段 |
| **当前周期任务拆解** | `docs/04-iterations/iter-XX-*.md` | 迭代计划制定、开发中期需求变更或任务重排 |
| **里程碑验收标准与实测记录** | `docs/05-acceptance/accept-XX-*.md` | 制定阶段完成标准、发版前实跑验证打勾 |
| **环境变量与部署手册** | `.env.example` + `docs/06-ops-and-pitfalls/deployment.md` | 代码中新增读取任何环境变量、变更构建部署步骤 |
| **已证伪死胡同与环境怪癖** | `docs/06-ops-and-pitfalls/pitfalls.md` | 排查出隐蔽 Bug、环境兼容坑或确认某条技术方案走不通 |
| **历史版本发布记录** | `CHANGELOG.md` | 每次通过验收合并 `main` 发布新语义化版本 |

---

## 二、`audit` 模式：6 维健康巡检执行流程

### Step 1：运行确定性基础巡检与全仓敏感扫描脚本
首先调用内置脚本完成文件系统、Git 分支、安全钩子状态、秘钥硬编码风险与工作区洁癖的自动化扫描：

- **Windows**：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" -Action audit -TargetDir "<TARGET_DIR>"
  powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" -Action secret-scan -TargetDir "<TARGET_DIR>"
  ```
- **macOS / Linux / Git Bash**：
  ```bash
  sh "<SKILL_DIR>/scripts/bootstrap.sh" --action audit --target-dir "<TARGET_DIR>"
  sh "<SKILL_DIR>/scripts/bootstrap.sh" --action secret-scan --target-dir "<TARGET_DIR>"
  ```

### Step 2：AI 深度语义巡检（补齐脚本看不到的内容漂移）
结合脚本输出，快速核查以下 4 项语义一致性：
1. **桥接文件完整性**：`CLAUDE.md`、`GEMINI.md`、`.cursor/rules/00-project-os.mdc` 是否完好指向 `AGENTS.md`，有无私自写入与 `AGENTS.md` 冲突的独立规则？
2. **僵尸锁与悬空 Worktree 核查**：对比 `git worktree list` 与 `docs/00-ai-hub/SESSIONS.md`，是否存在工作区早已删除或分支早已合并、但 `SESSIONS.md` 仍挂着未释放的僵尸锁？
3. **断点面板失真核查**：对比最近 5~10 条 `git log --oneline` 与 `docs/00-ai-hub/STATE.md`，是否有代码早已提交完成但 `STATE.md` 仍停留在旧状态？
4. **文档防腐烂抽检**：对比实际源码目录树、依赖配置文件（如 `package.json` / `pyproject.toml` / `go.mod`）及环境变量使用情况，检查 `README.md`、`system-design.md`、`03-contracts/`、`.env.example` 是否存在明显漏更？

### Step 3：输出结构化《项目健康巡检报告》并分级修复
按以下结构向用户汇报巡检结果：
- **🟢 合规通过项**：目录结构、双主干分支、秘钥安全等正常项摘要。
- **🟡 可自动修复项（低风险事务性偏差）**：如缺失的标准子目录/桥接文件、`.gitignore` 漏项、根目录明确的临时垃圾移入 `.tmp/`、已确认合并分支的僵尸锁清理、`STATE.md` 明显滞后的勾选同步。
- **🔴 需人工确认项（涉及业务或破坏性决策）**：如疑似废弃但未确认的业务文件、接口实现与契约不一致时以哪边为准、未合并的陈旧分支处理等。

对 🟡 类低风险项可直接修复（或经用户点头后一键修复）并在当前分支提交 `docs(audit): 完成项目规范巡检与文档状态对齐`。
