#!/usr/bin/env sh
# Cross-platform POSIX sh bootstrap, worktree, and audit helper for dev-setup
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TEMPLATES_ROOT="$SKILL_ROOT/templates"

ACTION="init"
TARGET_DIR=$(pwd)
PROJECT_NAME=""
SUMMARY="标准化 AI 协同软件工程项目"
TECH_STACK="TBD"
BRANCH=""
BASE_BRANCH="develop"
DELETE_BRANCH=0
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --action|-Action)       ACTION="$2"; shift 2 ;;
    --target-dir|-TargetDir) TARGET_DIR="$2"; shift 2 ;;
    --project-name|-ProjectName) PROJECT_NAME="$2"; shift 2 ;;
    --summary|-Summary)     SUMMARY="$2"; shift 2 ;;
    --tech-stack|-TechStack) TECH_STACK="$2"; shift 2 ;;
    --branch|-Branch)       BRANCH="$2"; shift 2 ;;
    --base-branch|-BaseBranch) BASE_BRANCH="$2"; shift 2 ;;
    --delete-branch|-DeleteBranch) DELETE_BRANCH=1; shift 1 ;;
    --force|-Force)         FORCE=1; shift 1 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

render_template() {
  src_file="$1"
  dst_file="$2"
  dst_parent=$(dirname -- "$dst_file")
  mkdir -p "$dst_parent"

  PROJECT_NAME_ENV="$PROJECT_NAME" \
  PROJECT_SUMMARY_ENV="$SUMMARY" \
  TECH_STACK_ENV="$TECH_STACK" \
  DATE_ENV="$NOW_DATE" \
  DATETIME_ENV="$NOW_DATETIME" \
  awk '
    function rep_lit(s, pat, val,    out, pos, plen) {
      out = ""; plen = length(pat)
      while ((pos = index(s, pat)) > 0) {
        out = out substr(s, 1, pos - 1) val
        s = substr(s, pos + plen)
      }
      return out s
    }
    {
      line = $0
      line = rep_lit(line, "{{PROJECT_NAME}}", ENVIRON["PROJECT_NAME_ENV"])
      line = rep_lit(line, "{{PROJECT_SUMMARY}}", ENVIRON["PROJECT_SUMMARY_ENV"])
      line = rep_lit(line, "{{TECH_STACK}}", ENVIRON["TECH_STACK_ENV"])
      line = rep_lit(line, "{{DATE}}", ENVIRON["DATE_ENV"])
      line = rep_lit(line, "{{DATETIME}}", ENVIRON["DATETIME_ENV"])
      print line
    }
  ' "$src_file" > "$dst_file"
}

place_file() {
  rel_src="$1"
  rel_dst="$2"
  src_full="$TEMPLATES_ROOT/$rel_src"
  dst_full="$TARGET_DIR/$rel_dst"

  if [ "$rel_dst" = ".gitignore" ] && [ -f "$dst_full" ] && [ "$FORCE" -eq 0 ]; then
    if ! grep -q "dev-setup AI Project OS Managed Rules" "$dst_full"; then
      printf '\n\n' >> "$dst_full"
      cat "$src_full" >> "$dst_full"
      echo "[MERGED]   .gitignore (appended dev-setup rules)"
    else
      echo "[PRESERVED] .gitignore (already contains dev-setup rules)"
    fi
    return
  fi

  if [ -e "$dst_full" ] && [ "$FORCE" -eq 0 ]; then
    echo "[PRESERVED] $rel_dst"
  else
    render_template "$src_full" "$dst_full"
    echo "[CREATED]  $rel_dst"
  fi
}

do_init() {
  MODE_LABEL="GREENFIELD"
  if [ -d "$TARGET_DIR" ]; then
    non_git_count=$({ ls -A "$TARGET_DIR" 2>/dev/null || true; } | { grep -v '^\.git$' || true; } | wc -l | tr -d ' ')
    if [ "$non_git_count" -gt 0 ]; then
      MODE_LABEL="BROWNFIELD"
    fi
  fi
  mkdir -p "$TARGET_DIR"
  TARGET_DIR=$(CDPATH= cd -- "$TARGET_DIR" && pwd)

  if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(basename -- "$TARGET_DIR")
  fi
  NOW_DATE=$(date "+%Y-%m-%d")
  NOW_DATETIME=$(date "+%Y-%m-%d %H:%M")

  echo "=== dev-setup init ==="
  echo "Target   : $TARGET_DIR"
  echo "Detected : $MODE_LABEL"
  echo "Project  : $PROJECT_NAME"

  mkdir -p \
    "$TARGET_DIR/.tmp" \
    "$TARGET_DIR/.cursor/rules" \
    "$TARGET_DIR/docs/00-ai-hub/handoffs" \
    "$TARGET_DIR/docs/00-ai-hub/reviews" \
    "$TARGET_DIR/docs/01-prd" \
    "$TARGET_DIR/docs/02-architecture/adr" \
    "$TARGET_DIR/docs/03-contracts" \
    "$TARGET_DIR/docs/04-iterations" \
    "$TARGET_DIR/docs/05-acceptance" \
    "$TARGET_DIR/docs/06-ops-and-pitfalls"

  if [ ! -e "$TARGET_DIR/.tmp/.gitkeep" ]; then
    : > "$TARGET_DIR/.tmp/.gitkeep"
    echo "[CREATED]  .tmp/.gitkeep"
  fi

  place_file "root/AGENTS.md.tmpl" "AGENTS.md"
  place_file "root/CLAUDE.md.tmpl" "CLAUDE.md"
  place_file "root/GEMINI.md.tmpl" "GEMINI.md"
  place_file "root/cursor-project-os.mdc.tmpl" ".cursor/rules/00-project-os.mdc"
  place_file "root/README.md.tmpl" "README.md"
  place_file "root/CHANGELOG.md.tmpl" "CHANGELOG.md"
  place_file "root/env.example.tmpl" ".env.example"
  place_file "root/gitignore.tmpl" ".gitignore"
  place_file "docs/00-index.md.tmpl" "docs/00-index.md"
  place_file "docs/00-ai-hub/STATE.md.tmpl" "docs/00-ai-hub/STATE.md"
  place_file "docs/00-ai-hub/SESSIONS.md.tmpl" "docs/00-ai-hub/SESSIONS.md"
  place_file "docs/00-ai-hub/handoff-template.md.tmpl" "docs/00-ai-hub/handoffs/_template.md"
  place_file "docs/00-ai-hub/review-template.md.tmpl" "docs/00-ai-hub/reviews/_template.md"
  place_file "docs/01-prd/prd-overview.md.tmpl" "docs/01-prd/prd-overview.md"
  place_file "docs/02-architecture/system-design.md.tmpl" "docs/02-architecture/system-design.md"
  place_file "docs/02-architecture/adr-0001-initial-architecture.md.tmpl" "docs/02-architecture/adr/0001-initial-architecture.md"
  place_file "docs/03-contracts/api-spec.md.tmpl" "docs/03-contracts/api-spec.md"
  place_file "docs/03-contracts/data-dictionary.md.tmpl" "docs/03-contracts/data-dictionary.md"
  place_file "docs/04-iterations/iter-01-mvp.md.tmpl" "docs/04-iterations/iter-01-mvp.md"
  place_file "docs/05-acceptance/accept-01-mvp.md.tmpl" "docs/05-acceptance/accept-01-mvp.md"
  place_file "docs/06-ops-and-pitfalls/deployment.md.tmpl" "docs/06-ops-and-pitfalls/deployment.md"
  place_file "docs/06-ops-and-pitfalls/pitfalls.md.tmpl" "docs/06-ops-and-pitfalls/pitfalls.md"

  echo "=== init scaffold complete ($MODE_LABEL) ==="
}

install_git_secret_hooks() {
  repo_root="$1"
  hooks_dir="$repo_root/.git/hooks"
  mkdir -p "$hooks_dir"

  cp "$TEMPLATES_ROOT/hooks/secret-guard.sh" "$hooks_dir/secret-guard.sh"
  chmod +x "$hooks_dir/secret-guard.sh"

  for hk in pre-commit pre-push; do
    hk_path="$hooks_dir/$hk"
    if [ -f "$hk_path" ] && [ "$FORCE" -eq 0 ]; then
      if ! grep -q "dev-setup-secret-guard" "$hk_path"; then
        echo "[WARN] Custom Git hook '$hk' already exists; preserved (pass --force to replace)."
        continue
      fi
    fi
    cat > "$hk_path" <<EOF
#!/usr/bin/env sh
# dev-setup-secret-guard
exec "\$(dirname "\$0")/secret-guard.sh" "$hk"
EOF
    chmod +x "$hk_path"
    echo "[OK] Installed Git security hook: .git/hooks/$hk"
  done
}

do_secret_scan() {
  TARGET_DIR=$(CDPATH= cd -- "$TARGET_DIR" && pwd)
  sh "$TEMPLATES_ROOT/hooks/secret-guard.sh" full "$TARGET_DIR"
}

do_git_setup() {
  TARGET_DIR=$(CDPATH= cd -- "$TARGET_DIR" && pwd)
  cd "$TARGET_DIR"
  echo "=== dev-setup git-setup ==="

  if [ ! -d ".git" ]; then
    git init -b main >/dev/null 2>&1 || { git init >/dev/null && git symbolic-ref HEAD refs/heads/main; }
    echo "[OK] Initialized new Git repository on 'main'."
  fi

  install_git_secret_hooks "$TARGET_DIR"

  if [ -z "$(git config user.name || true)" ]; then
    git config user.name "Developer"
    git config user.email "developer@localhost"
    echo "[INFO] Configured fallback repo-local git user.name / user.email."
  fi

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    git symbolic-ref HEAD refs/heads/main >/dev/null 2>&1 || true
    git add -A
    git commit -m "chore(init): 初始化项目工程化基座与核心文档" >/dev/null
    git checkout -B develop >/dev/null 2>&1
    echo "[OK] Created baseline commit on 'main' and switched to 'develop'."
  else
    if ! git show-ref --verify --quiet refs/heads/main; then
      if git show-ref --verify --quiet refs/heads/master; then
        git branch main master
        echo "[OK] Created 'main' branch pointing to 'master'."
      else
        git branch main HEAD
        echo "[OK] Created 'main' branch from current HEAD."
      fi
    fi
    if ! git show-ref --verify --quiet refs/heads/develop; then
      git branch develop main
      echo "[OK] Created 'develop' branch from 'main'."
    fi
    cur_branch=$(git branch --show-current || true)
    if [ "$cur_branch" = "main" ] || [ "$cur_branch" = "master" ]; then
      git checkout develop >/dev/null 2>&1
      echo "[OK] Switched working branch from '$cur_branch' to 'develop'."
    else
      echo "[INFO] Preserved current branch '$cur_branch' (both 'main' and 'develop' exist)."
    fi
  fi
}

branch_slug() {
  printf '%s' "$1" | tr '/\\: ' '----' | tr -cd 'a-zA-Z0-9._-'
}

do_worktree_add() {
  [ -n "$BRANCH" ] || { echo "Error: --branch is required for worktree-add" >&2; exit 2; }
  TARGET_DIR=$(CDPATH= cd -- "$TARGET_DIR" && pwd)
  cd "$TARGET_DIR"
  slug=$(branch_slug "$BRANCH")
  wt_path="$TARGET_DIR/.worktrees/$slug"
  [ ! -e "$wt_path" ] || { echo "Error: Worktree path already exists: $wt_path" >&2; exit 1; }
  mkdir -p "$TARGET_DIR/.worktrees"

  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$wt_path" "$BRANCH"
  else
    git show-ref --verify --quiet "refs/heads/$BASE_BRANCH" || { echo "Error: Base branch '$BASE_BRANCH' not found" >&2; exit 1; }
    git worktree add "$wt_path" -b "$BRANCH" "$BASE_BRANCH"
  fi
  echo "[OK] Isolated worktree ready: $wt_path (branch: $BRANCH)"
  echo "[NEXT] Register this worktree lock in docs/00-ai-hub/SESSIONS.md on the integration branch."
}

do_worktree_remove() {
  [ -n "$BRANCH" ] || { echo "Error: --branch is required for worktree-remove" >&2; exit 2; }
  TARGET_DIR=$(CDPATH= cd -- "$TARGET_DIR" && pwd)
  cd "$TARGET_DIR"
  slug=$(branch_slug "$BRANCH")
  wt_path="$TARGET_DIR/.worktrees/$slug"
  [ -d "$wt_path" ] || { echo "Error: Worktree directory not found: $wt_path" >&2; exit 1; }

  if [ -n "$(git -C "$wt_path" status --porcelain)" ] && [ "$FORCE" -eq 0 ]; then
    echo "[ABORT] Worktree has uncommitted changes ($wt_path). Commit/clean first or pass --force." >&2
    exit 1
  fi

  if [ "$FORCE" -eq 1 ]; then
    git worktree remove --force "$wt_path"
  else
    git worktree remove "$wt_path"
  fi
  git worktree prune
  echo "[OK] Removed worktree: $wt_path"

  if [ "$DELETE_BRANCH" -eq 1 ]; then
    if git branch -d "$BRANCH" 2>/dev/null; then
      echo "[OK] Deleted merged branch: $BRANCH"
    else
      echo "[WARN] Branch '$BRANCH' is not fully merged; kept branch for safety."
    fi
  fi
}

do_audit() {
  TARGET_DIR=$(CDPATH= cd -- "$TARGET_DIR" && pwd)
  pass_c=0
  warn_c=0
  fail_c=0
  echo "=== dev-setup audit: $TARGET_DIR ==="

  for rel in \
    "AGENTS.md" \
    "CLAUDE.md" \
    "GEMINI.md" \
    ".cursor/rules/00-project-os.mdc" \
    "README.md" \
    "CHANGELOG.md" \
    ".env.example" \
    ".gitignore" \
    "docs/00-index.md" \
    "docs/00-ai-hub/STATE.md" \
    "docs/00-ai-hub/SESSIONS.md" \
    "docs/01-prd/prd-overview.md" \
    "docs/02-architecture/system-design.md" \
    "docs/03-contracts/api-spec.md" \
    "docs/03-contracts/data-dictionary.md" \
    "docs/06-ops-and-pitfalls/deployment.md" \
    "docs/06-ops-and-pitfalls/pitfalls.md"
  do
    if [ -f "$TARGET_DIR/$rel" ]; then
      pass_c=$((pass_c + 1))
    else
      echo "[FAIL] Missing required file: $rel"
      fail_c=$((fail_c + 1))
    fi
  done

  for rdir in \
    ".tmp" \
    "docs/00-ai-hub/handoffs" \
    "docs/00-ai-hub/reviews" \
    "docs/02-architecture/adr" \
    "docs/04-iterations" \
    "docs/05-acceptance"
  do
    if [ -d "$TARGET_DIR/$rdir" ]; then
      pass_c=$((pass_c + 1))
    else
      echo "[FAIL] Missing required directory: $rdir"
      fail_c=$((fail_c + 1))
    fi
  done

  if [ -f "$TARGET_DIR/.gitignore" ]; then
    for pat in ".env" ".tmp" ".worktrees"; do
      if grep -Fq "$pat" "$TARGET_DIR/.gitignore"; then
        pass_c=$((pass_c + 1))
      else
        echo "[WARN] .gitignore does not mention '$pat'"
        warn_c=$((warn_c + 1))
      fi
    done
  fi

  for fpath in "$TARGET_DIR"/*; do
    [ -f "$fpath" ] || continue
    fname=$(basename -- "$fpath")
    case "$fname" in
      AGENTS.md|CLAUDE.md|GEMINI.md|README.md|CHANGELOG.md|LICENSE.md) ;;
      *.md)
        echo "[WARN] Non-standard Markdown file in project root: $fname (consider moving under docs/)"
        warn_c=$((warn_c + 1))
        ;;
    esac
    case "$fname" in
      temp*|tmp*|scratch*|debug*|test_*)
        echo "[WARN] Possible temporary clutter in project root: $fname (move to .tmp/)"
        warn_c=$((warn_c + 1))
        ;;
    esac
  done

  if [ -d "$TARGET_DIR/.git" ]; then
    cd "$TARGET_DIR"
    if [ -n "$(git ls-files .env)" ]; then
      echo "[FAIL] SECURITY: '.env' is tracked by Git! Untrack immediately."
      fail_c=$((fail_c + 1))
    else
      pass_c=$((pass_c + 1))
    fi
    for b in main develop; do
      if git show-ref --verify --quiet "refs/heads/$b"; then
        pass_c=$((pass_c + 1))
      else
        echo "[WARN] Git branch '$b' is missing."
        warn_c=$((warn_c + 1))
      fi
    done
    for hk in pre-commit pre-push; do
      if [ -f "$TARGET_DIR/.git/hooks/$hk" ]; then
        pass_c=$((pass_c + 1))
      else
        echo "[WARN] Git security hook '.git/hooks/$hk' is missing (run git-setup to install)."
        warn_c=$((warn_c + 1))
      fi
    done
    if sh "$TEMPLATES_ROOT/hooks/secret-guard.sh" full "$TARGET_DIR"; then
      pass_c=$((pass_c + 1))
    else
      fail_c=$((fail_c + 1))
    fi
    echo "[INFO] Current Git branch: $(git branch --show-current || true)"
    echo "[INFO] Active Git worktrees:"
    git worktree list | sed 's/^/       /'
  else
    echo "[WARN] Git repository (.git) is not initialized yet."
    warn_c=$((warn_c + 1))
  fi

  echo "=== Audit Summary: PASS=$pass_c | WARN=$warn_c | FAIL=$fail_c ==="
  [ "$fail_c" -eq 0 ]
}

case "$ACTION" in
  init)            do_init ;;
  git-setup)       do_git_setup ;;
  worktree-add)    do_worktree_add ;;
  worktree-remove) do_worktree_remove ;;
  secret-scan)     do_secret_scan ;;
  audit)           do_audit ;;
  *) echo "Unsupported action: $ACTION" >&2; exit 2 ;;
esac
