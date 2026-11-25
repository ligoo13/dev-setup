# 模式规程：`init`（新项目冷启动 & 存量老项目无损纳管）

当用户要求“初始化新项目”、“按规范搭好项目架子”或“把这个已有项目接入标准工程体系”时，严格按以下 5 步执行。

---

## Step 1：探测目标目录状态（Greenfield vs Brownfield）

先用只读命令快速检查目标项目目录 `<TARGET_DIR>`：
- **全新项目（Greenfield）**：目录为空，或仅有空的 `.git` / 单个初始说明文件。
- **存量项目（Brownfield）**：已存在业务源码、历史 Git 提交、现有 `README.md`、`.gitignore` 或散落的 `.md` 文档。

> **存量项目红线**：严禁暴力覆盖已有的 `README.md`、`.gitignore` 或重置 `.git` 历史！脚本会自动跳过已存在的同名文件并增量合并 `.gitignore` 规则。

---

## Step 2：简短精准采访（3~5 个关键问题，确认后一键建好）

对照用户已提供的上下文，**只追问尚未明确的缺失信息**（控制在 3~5 个问题以内，一次性问完，不要连环盘问）：

1. **项目标识与定位**：项目名称（英文代号/中文名）及一句话核心目标是什么？
2. **核心技术栈与形态**：计划采用什么语言/框架（如 `Next.js + FastAPI`、`Python CLI`、`Vue3 + Go`，若暂未定可填 `TBD`）？
3. **首轮 MVP 边界（`iter-01`）**：第一阶段最核心要交付的 2~4 个功能点是什么？有哪些明确“本阶段先不做”的事项？
4. **标准验证命令与外部依赖**（可选）：已知的启动/测试/构建命令，或关键外部服务/数据库依赖？（新项目若尚未装框架，默认标记待框架初始化后回填）。
5. *(仅存量 Brownfield 项目追加)*：检测到根目录下有若干散落文档（列出文件名），是否允许在保留原意的前提下归档迁移至 `docs/` 对应编号目录？

---

## Step 3：运行确定性脚手架脚本生成标准外壳

拿到用户答复后，立即调用 `scripts/bootstrap.ps1`（Windows）或 `scripts/bootstrap.sh`（macOS/Linux/Git Bash）执行 `init`：

### Windows 调用示例
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" `
  -Action init `
  -TargetDir "<TARGET_DIR>" `
  -ProjectName "<项目名称>" `
  -Summary "<一句话定位>" `
  -TechStack "<核心技术栈>"
```

### macOS / Linux / Git Bash 调用示例
```bash
sh "<SKILL_DIR>/scripts/bootstrap.sh" \
  --action init \
  --target-dir "<TARGET_DIR>" \
  --project-name "<项目名称>" \
  --summary "<一句话定位>" \
  --tech-stack "<核心技术栈>"
```

**脚本会自动完成以下工作（UTF-8 无 BOM）**：
- 创建 `.tmp/.gitkeep`、`.cursor/rules/` 以及 `docs/00-ai-hub/{handoffs,reviews}` 至 `docs/06-ops-and-pitfalls/` 全部标准目录；
- 绝不创建空 `src/` 等业务源码目录（避免阻塞后续 `create-next-app`、`uv init`、`pnpm create` 等脚手架）；
- 从 `templates/` 渲染生成 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md`、`.cursor/rules/00-project-os.mdc`、`README.md`（若不存在）、`CHANGELOG.md`、`.env.example`、`.gitignore`（若已存在则无损追加缺失忽略项）及 `docs/00`~`06` 全套初始文档。

*(注：若环境无法运行脚本，请直接读取 `../templates/` 下所有 `.tmpl` 文件并手动写入对应路径。)*

---

## Step 4：AI 智能填充业务灵魂（严禁留空泛模板交差！）

脚本生成的是带项目元信息的标准骨架，接下来你必须结合用户的回答（以及存量项目的现有代码扫描结果），实质性完善以下关键文件：

1. **`AGENTS.md`**：填入已知的安装/启动/测试/构建验证命令（若尚未初始化代码框架，保留清晰的 `TBD（首次初始化代码框架时必须同步回填）` 标记）及项目专属补充约束。
2. **`README.md`**：完善项目背景、核心特性规划、快速开始指引（Brownfield 项目则在保留原有有效说明的基础上，补充标准 `docs/` 文档导航入口与当前工程结构说明）。
3. **`docs/01-prd/prd-overview.md`**：写入真实的项目背景目标、目标用户/使用场景、核心功能清单与明确不做边界（Non-Goals）。
4. **`docs/02-architecture/system-design.md` & `adr/0001-initial-architecture.md`**：写入技术栈选型理由、核心模块划分规划（Brownfield 项目需盘点真实源码目录树写入此处）。
5. **`docs/04-iterations/iter-01-mvp.md` & `docs/05-acceptance/accept-01-mvp.md`**：将首轮目标拆解为可执行、可勾选的任务清单，并明确对应的验收标准。
6. **`docs/00-ai-hub/STATE.md`**：将当前阶段设为 `Iter-01 MVP 准备就绪`（或存量项目对应的真实进度），明确列出「下一步待执行任务 Top 3」。

---

## Step 5：初始化 Git 双主干（`main` + `develop`）并巡检交付

文档填充完毕后，调用脚本的 `git-setup` 动作完成版本库基线闭环：

### Windows 调用示例
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" -Action git-setup -TargetDir "<TARGET_DIR>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" -Action audit -TargetDir "<TARGET_DIR>"
```

### macOS / Linux / Git Bash 调用示例
```bash
sh "<SKILL_DIR>/scripts/bootstrap.sh" --action git-setup --target-dir "<TARGET_DIR>"
sh "<SKILL_DIR>/scripts/bootstrap.sh" --action audit --target-dir "<TARGET_DIR>"
```

**`git-setup` 的标准行为**：
- **Greenfield 新仓库**：初始化 Git 并确保主干为 `main` → 将整套工程基座与定制化初始文档提交为首笔基线 Commit（`chore(init): 初始化项目工程化基座与核心文档`）→ 基于 `main` 创建并切换至日常集成分支 `develop`。
- **Brownfield 存量仓库**：绝不改写历史提交；若缺少 `develop` 分支，则基于当前主分支创建 `develop`（若有未提交改动则安全保留在工作区供确认后再提交）。

最后，确认 `audit` 输出全部通过（`PASS`），向用户简洁汇报已落地的目录摘要、当前所在 Git 分支（`develop`）以及建议的第一步开发动作。
