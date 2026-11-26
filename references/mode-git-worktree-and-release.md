# 模式规程：`worktree`（多端并行物理隔离）与 `release`（阶段验收发版）

本规程规范 Git 双主干分支模型、多终端并发防踩踏物理隔离，以及里程碑验收发版全流程。

---

## 一、Git 双主干分支与提交规范

### 1. 分支拓扑结构
- **`main`（受保护稳定主干）**：
  - 永远保持已验收、可随时交付/部署的干净状态。
  - **严禁任何 AI 直接在 `main` 上编码提交**；仅接受来自 `develop`（或紧急 `hotfix/*`）且通过 `docs/05-acceptance/` 验收的 `--no-ff` 合并，每次合入必打语义化版本 Tag（如 `v0.1.0`、`v0.2.0`）。
- **`develop`（日常迭代集成主干）**：
  - 项目主目录默认常驻分支。各并行功能分支开发自测完成后，先合入 `develop` 做集成联调与全局状态对齐。
- **工作分支命名规范（全小写英文连字符）**：
  - `feat/<scope-or-slug>`：新功能开发（如 `feat/user-auth`）
  - `fix/<scope-or-slug>`：缺陷修复（如 `fix/token-refresh-race`）
  - `docs/<scope-or-slug>`：纯文档/规范演进
  - `refactor/<scope-or-slug>`：不改变外部行为的内部重构
  - `spike/<agent>-<topic>`：技术预研或原型探索（不直接合入主干）

### 2. Commit Message 标准格式
统一采用 **`<type>(<scope>): <中文简明描述>`**：
- 合法 `<type>`：`feat` | `fix` | `docs` | `refactor` | `test` | `chore` | `perf` | `wip`（仅限临时分支保存现场，合入 `develop` 前需整理干净）
- 示例：
  - `feat(contract): 定义订单创建接口契约与数据表字典`
  - `fix(parser): 修复空输入导致的边界崩溃并补充单元测试`
  - `docs(state): 完成 iter-01 登录模块交接与状态更新`

---

## 二、`worktree` 模式：双轨自适应多终端并发隔离

### 1. 何时使用软锁 vs 何时强制开启 `git worktree`
- **场景 A（同分支软锁）**：仅修改互不重叠的文档，或在单分支下不同 AI 明确划分了完全独立的子目录且**绝不切换分支** → 在 `docs/00-ai-hub/SESSIONS.md` 登记各自锁定的路径边界即可。
- **场景 B（跨分支并行改代码 —— 强制 `git worktree`）**：只要开启第 2 个及以上终端需要**在独立功能分支上并行写代码/跑测试**，严禁在主项目目录直接 `git checkout`（否则会瞬间篡改其他终端的工作区）！必须挂载独立 worktree。

### 2. 一键创建并行工作区（`worktree-add`）
在主项目目录调用脚本开辟位于 `.worktrees/<branch-slug>` 的物理隔离工作区（`.worktrees/` 已被 `.gitignore` 忽略）：

- **Windows**：
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" `
    -Action worktree-add -TargetDir "<TARGET_DIR>" -Branch "feat/<slug>" -BaseBranch "develop"
  ```
- **macOS / Linux / Git Bash**：
  ```bash
  sh "<SKILL_DIR>/scripts/bootstrap.sh" \
    --action worktree-add --target-dir "<TARGET_DIR>" --branch "feat/<slug>" --base-branch "develop"
  ```

### 3. 并行开发期间的「零冲突三原则」
1. **先锁契约再分头写**：前后端或跨模块多 AI 并行前，必须在主目录 `develop` 分支先把 `docs/03-contracts/API-000-全局接口契约总表.md` 与 `DATA-000-核心数据模型与字典.md` 定稿提交（同步刷新其元信息卡与文末修订记录），再各自拉出 worktree 开发。
2. **主目录登记全局锁**：开辟 worktree 时，在主目录的 `docs/00-ai-hub/SESSIONS.md` 登记该 worktree 路径、分支名、负责的 AI 与锁定的业务模块。
3. **子分支免冲突纪律**：在 `.worktrees/<slug>` 内部专注修改所属业务模块、测试与增量 `handoffs/`/`reviews/` 文件，**不在并行子分支内频繁改写全局 `STATE.md`**，避免多分支合回 `develop` 时产生状态文件冲突。

### 4. 并行任务合入与安全清理（`worktree-remove`）
1. 在 `.worktrees/<slug>` 内跑通全部自测验证命令并提交干净代码；
2. 回到主工作区（`develop` 分支），执行合并：`git merge --no-ff feat/<slug> -m "feat(<scope>): 合入 <功能描述>"` 并跑通集成验证；
3. 在主工作区统一刷新 `docs/00-ai-hub/STATE.md`，清除 `SESSIONS.md` 中的活跃锁；
4. 调用脚本安全移除子工作区并删除已合并临时分支：
   - **Windows**：
     ```powershell
     powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/bootstrap.ps1" `
       -Action worktree-remove -TargetDir "<TARGET_DIR>" -Branch "feat/<slug>"
     ```
   - **macOS / Linux / Git Bash**：
     ```bash
     sh "<SKILL_DIR>/scripts/bootstrap.sh" \
       --action worktree-remove --target-dir "<TARGET_DIR>" --branch "feat/<slug>"
     ```

---

## 三、`release` 模式：阶段验收与语义化版本发布规程

当某一迭代（如 `iter-01-mvp`）开发完成准备验收发版时，严格按以下 6 步闭环：

1. **执行健康巡检（`audit`）**：确认无未清理 `.tmp` 外泄垃圾、无未释放并行 worktree、无秘钥泄露、无遗漏的 `WIP` 或违规假数据 Mock。
2. **真实验收核验**：打开对应的 `docs/05-acceptance/ACCEPT-XX-vX.Y.Z-*.md`，在终端**逐条实跑**构建、Lint、自动化测试与核心场景验证命令，如实填写验收结果（`PASS`/`FAIL`）与执行角色署名，验收全部通过后将该验收单及对应 `ITER-XX` 迭代单的顶部状态由 `ACTIVE` 更新为 `COMPLETED`，并追加文末修订记录；若有未通过项，立即阻断发版并退回修复。
3. **文档与版本信息同步**：
   - 检查 `README.md`、`docs/02-architecture/ARCH-000-系统架构与模块设计总纲.md`、`docs/03-contracts/` 是否与最新代码完全一致；
   - 检查是否有已被替代的旧草案需改为 `SUPERSEDED` 并移入 `docs/99-archive/`；
   - 更新 `CHANGELOG.md`：将本次迭代的新增特性（Added）、修复（Fixed）、变更（Changed）归档至新版本号标题下（遵循 SemVer：`0.1.0` → `0.2.0` / `0.1.1` / `1.0.0`）；
   - 更新 `docs/00-ai-hub/STATE.md` 当前版本号与里程碑状态，在 `develop` 提交归档 Commit：`chore(release): 完成 vX.Y.Z 验收归档与日志更新`。
4. **合入稳定主干 `main` 并打 Tag**（合入前向用户简要展示验收摘要并确认版本号）：
   ```bash
   git checkout main
   git merge --no-ff develop -m "chore(release): 发布版本 vX.Y.Z"
   git tag -a vX.Y.Z -m "Release vX.Y.Z: <里程碑简述>"
   ```
5. **切回 `develop` 开启下一周期**：
   ```bash
   git checkout develop
   git merge --ff-only main
   ```
   按需在 `docs/04-iterations/` 与 `docs/05-acceptance/` 创建下一轮迭代与验收文档骨架，并在 `STATE.md` 更新下一阶段目标。
6. **自动化安全扫描与远端推送（Autonomous Push with Secret Guard）**：
   - 本体系默认在 `.git/hooks/pre-commit` 与 `pre-push` 部署了物理级秘钥与敏感资产拦截钩子。
   - 只要项目配置了远程仓库（`git remote -v` 非空），AI 在执行 `secret-scan`（或经由本地 Git 安全钩子自动核验通过）确认无任何 API Key、密码连接串、敏感文件及未脱敏文档信息后，**可按开发与发版闭环自主执行 `git commit` 与 `git push`**（含推送分支与语义化版本 Tag）。
   - **安全铁律**：首次在 GitHub 创建仓库默认必须设为 `Private`；若检测到远端仓库为 `Public`，推送前必须额外复核文档与代码中无任何内部地址或业务敏感逻辑；任何情况下一旦触发安全钩子拦截报错，**严禁使用 `--no-verify` 强行跳过**！
