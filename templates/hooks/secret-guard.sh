#!/usr/bin/env sh
# Self-contained POSIX sh secret & sensitive file guard for dev-setup
set -eu

HOOK_MODE="${1:-pre-commit}"
REPO_DIR="${2:-}"

if [ -n "$REPO_DIR" ]; then
  cd "$REPO_DIR"
else
  top_dir=$(git rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$top_dir" ] && cd "$top_dir"
fi

TMP_FINDINGS=$(mktemp 2>/dev/null || printf '/tmp/dev_setup_guard_%s' "$$")
: > "$TMP_FINDINGS"
trap 'rm -f "$TMP_FINDINGS"' EXIT INT TERM

check_file_path() {
  p="$1"
  [ -n "$p" ] || return 0
  case "$p" in
    *templates/hooks/secret-guard.ps1|*templates/hooks/secret-guard.sh) return 0 ;;
  esac

  base=$(basename -- "$p")
  case "$base" in
    .env.example|.env.sample|.env.template|.env.schema|.env.dist) ;;
    .env|.env.*)
      printf '[FILE:ENV_SECRET_FILE] Forbidden sensitive file detected: %s\n' "$p" >> "$TMP_FINDINGS"
      ;;
  esac

  case "$base" in
    *.pub) ;;
    id_rsa|id_rsa.*|id_ed25519|id_ed25519.*|id_ecdsa|id_ecdsa.*|id_dsa|id_dsa.*|*.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|*.pkcs12|*.kubeconfig|kubeconfig)
      printf '[FILE:PRIVATE_KEY_OR_CERT] Forbidden key/cert file detected: %s\n' "$p" >> "$TMP_FINDINGS"
      ;;
  esac

  case "$base" in
    *credentials*.json|*credentials*.yaml|*credentials*.yml|*service-account*.json|*client_secret*.json|.npmrc|.pypirc|.netrc)
      printf '[FILE:CLOUD_OR_PKG_CREDENTIAL] Forbidden credential file detected: %s\n' "$p" >> "$TMP_FINDINGS"
      ;;
    *.har|*.pcap|*.pcapng|*.sqlite|*.sqlite3|*.db|*.dump|*.sql.gz)
      printf '[FILE:LOCAL_DB_OR_CAPTURE_DUMP] Forbidden data/capture file detected: %s\n' "$p" >> "$TMP_FINDINGS"
      ;;
  esac
}

scan_diff_stream() {
  awk '
    /^(\+\+\+ b\/)/ { cur = substr($0, 7); next }
    cur ~ /templates\/hooks\/secret-guard\.(ps1|sh)$/ { next }
    /^\+/ && !/^\+\+\+/ {
      line = substr($0, 2)
      low = tolower(line)
      if (low ~ /dev-setup-ignore-secret/ || low ~ /pragma:[[:space:]]*allowlist[[:space:]]*secret/) next
      if (line ~ /(<YOUR_|YOUR_API_KEY|YOUR_SECRET|YOUR_TOKEN|YOUR_PASSWORD|<REDACTED>|<PASSWORD>|<TOKEN>|<API_KEY>|CHANGE_ME|REPLACE_ME|EXAMPLE_KEY|EXAMPLE_TOKEN|PLACEHOLDER|DUMMY_KEY|xxxx|\*\*\*\*)/) next

      hit = ""
      if (line ~ /-----BEGIN (RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----/) hit = "PRIVATE_KEY_BLOCK"
      else if (line ~ /(sk-(proj-|ant-|live-|test-)?[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}|glpat-[A-Za-z0-9_-]{20,}|hf_[A-Za-z0-9]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}|(rk|pk)_live_[0-9A-Za-z]{20,})/) hit = "AI_OR_PLATFORM_API_KEY"
      else if (line ~ /((AKIA|ASIA)[0-9A-Z]{16}|LTAI[A-Za-z0-9]{12,24}|AKID[A-Za-z0-9]{13,32})/) hit = "CLOUD_PROVIDER_AK"
      else if (line ~ /(postgres|postgresql|mysql|mariadb|mongodb|mongodb\+srv|redis|rediss|amqp|amqps):\/\/[^\/[:space:]:@<>"{}]+:[^\/[:space:]@<>"{}$]{4,}@/) hit = "DB_URL_WITH_PASSWORD"
      else if (line ~ /https:\/\/(open\.feishu\.cn\/open-apis\/bot\/v2\/hook\/[0-9a-f-]{20,}|oapi\.dingtalk\.com\/robot\/send\?access_token=[0-9a-zA-Z]{30,}|qyapi\.weixin\.qq\.com\/cgi-bin\/webhook\/send\?key=[0-9a-zA-Z-]{20,}|hooks\.slack\.com\/services\/T[A-Z0-9]+\/B[A-Z0-9]+\/[A-Za-z0-9]+|discord(app)?\.com\/api\/webhooks\/[0-9]+\/[A-Za-z0-9_-]+)/) hit = "IM_WEBHOOK_SECRET_URL"
      else if (low ~ /(api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|private[_-]?key|client[_-]?secret|jwt[_-]?secret|db[_-]?password|password|passwd)[[:space:]]*[:=][[:space:]]*["'\''][a-z0-9+\/=._!@#%^&*-]{12,}["'\'']/) hit = "HARDCODED_SECRET_ASSIGN"
      else if (low ~ /authorization[[:space:]]*:[[:space:]]*bearer[[:space:]]+[a-z0-9._-]{20,}/) hit = "BEARER_TOKEN_HEADER"

      if (hit != "") {
        snip = line
        sub(/^[[:space:]]+/, "", snip)
        if (length(snip) > 90) snip = substr(snip, 1, 90) "..."
        printf "[SECRET:%s] %s -> %s\n", hit, cur, snip
      }
    }
  ' >> "$TMP_FINDINGS"
}

if [ "$HOOK_MODE" = "pre-commit" ]; then
  git diff --cached --name-only --diff-filter=ACMR | while IFS= read -r f; do
    check_file_path "$f"
  done
  git diff --cached -U0 --no-color | scan_diff_stream
elif [ "$HOOK_MODE" = "pre-push" ]; then
  git ls-files | while IFS= read -r f; do
    check_file_path "$f"
  done
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)
  if [ -n "$upstream" ]; then
    git diff "$upstream..HEAD" -U0 --no-color | scan_diff_stream
  else
    empty_tree="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    git diff "$empty_tree..HEAD" -U0 --no-color | scan_diff_stream
  fi
elif [ "$HOOK_MODE" = "full" ]; then
  { git ls-files; git ls-files --others --exclude-standard; } | sort -u | while IFS= read -r f; do
    [ -n "$f" ] || continue
    check_file_path "$f"
    case "$f" in
      *templates/hooks/secret-guard.ps1|*templates/hooks/secret-guard.sh) continue ;;
    esac
    [ -f "$f" ] || continue
    awk -v fname="$f" '
      {
        line = $0
        low = tolower(line)
        if (low ~ /dev-setup-ignore-secret/ || low ~ /pragma:[[:space:]]*allowlist[[:space:]]*secret/) next
        if (line ~ /(<YOUR_|YOUR_API_KEY|YOUR_SECRET|YOUR_TOKEN|YOUR_PASSWORD|<REDACTED>|<PASSWORD>|<TOKEN>|<API_KEY>|CHANGE_ME|REPLACE_ME|EXAMPLE_KEY|EXAMPLE_TOKEN|PLACEHOLDER|DUMMY_KEY|xxxx|\*\*\*\*)/) next

        hit = ""
        if (line ~ /-----BEGIN (RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----/) hit = "PRIVATE_KEY_BLOCK"
        else if (line ~ /(sk-(proj-|ant-|live-|test-)?[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}|glpat-[A-Za-z0-9_-]{20,}|hf_[A-Za-z0-9]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}|(rk|pk)_live_[0-9A-Za-z]{20,})/) hit = "AI_OR_PLATFORM_API_KEY"
        else if (line ~ /((AKIA|ASIA)[0-9A-Z]{16}|LTAI[A-Za-z0-9]{12,24}|AKID[A-Za-z0-9]{13,32})/) hit = "CLOUD_PROVIDER_AK"
        else if (line ~ /(postgres|postgresql|mysql|mariadb|mongodb|mongodb\+srv|redis|rediss|amqp|amqps):\/\/[^\/[:space:]:@<>"{}]+:[^\/[:space:]@<>"{}$]{4,}@/) hit = "DB_URL_WITH_PASSWORD"
        else if (line ~ /https:\/\/(open\.feishu\.cn\/open-apis\/bot\/v2\/hook\/[0-9a-f-]{20,}|oapi\.dingtalk\.com\/robot\/send\?access_token=[0-9a-zA-Z]{30,}|qyapi\.weixin\.qq\.com\/cgi-bin\/webhook\/send\?key=[0-9a-zA-Z-]{20,}|hooks\.slack\.com\/services\/T[A-Z0-9]+\/B[A-Z0-9]+\/[A-Za-z0-9]+|discord(app)?\.com\/api\/webhooks\/[0-9]+\/[A-Za-z0-9_-]+)/) hit = "IM_WEBHOOK_SECRET_URL"
        else if (low ~ /(api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|private[_-]?key|client[_-]?secret|jwt[_-]?secret|db[_-]?password|password|passwd)[[:space:]]*[:=][[:space:]]*["'\''][a-z0-9+\/=._!@#%^&*-]{12,}["'\'']/) hit = "HARDCODED_SECRET_ASSIGN"
        else if (low ~ /authorization[[:space:]]*:[[:space:]]*bearer[[:space:]]+[a-z0-9._-]{20,}/) hit = "BEARER_TOKEN_HEADER"

        if (hit != "") {
          snip = line
          sub(/^[[:space:]]+/, "", snip)
          if (length(snip) > 90) snip = substr(snip, 1, 90) "..."
          printf "[SECRET:%s] %s:%d -> %s\n", hit, fname, NR, snip
        }
      }
    ' "$f" >> "$TMP_FINDINGS"
  done
fi

if [ -s "$TMP_FINDINGS" ]; then
  count=$(wc -l < "$TMP_FINDINGS" | tr -d ' ')
  echo "=================================================================="
  echo "[BLOCKED BY DEV-SETUP SECRET GUARD] Sensitive data risk detected!"
  echo "Mode     : $HOOK_MODE"
  echo "Findings : $count"
  echo "------------------------------------------------------------------"
  sed 's/^/  /' "$TMP_FINDINGS"
  echo "------------------------------------------------------------------"
  echo "Action Required:"
  echo "  1. Move secrets to environment variables (.env) and register empty keys in .env.example."
  echo "  2. Redact real IPs, tokens, passwords, or PII in docs/handoffs/pitfalls with <REDACTED>."
  echo "  3. DO NOT bypass with --no-verify. Ask human approval if false positive."
  echo "=================================================================="
  exit 1
fi

if [ "$HOOK_MODE" = "full" ]; then
  echo "[OK] secret-scan passed: 0 secrets or sensitive files detected."
fi
exit 0
