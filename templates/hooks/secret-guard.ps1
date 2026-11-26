param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("pre-commit", "pre-push", "full")]
    [string]$HookMode = "pre-commit",

    [Parameter(Mandatory = $false)]
    [string]$RepoDir = ""
)

$ErrorActionPreference = "Stop"
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

function Invoke-GitRaw {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & git @args 2>&1
        $code = $LASTEXITCODE
        $lines = @()
        if ($null -ne $out) {
            $lines = @($out | ForEach-Object { "$_" })
        }
        return [PSCustomObject]@{
            ExitCode = $code
            Lines    = $lines
            Text     = ($lines -join "`n").Trim()
        }
    } finally {
        $ErrorActionPreference = $oldEap
    }
}

if (-not [string]::IsNullOrWhiteSpace($RepoDir)) {
    Set-Location -LiteralPath $RepoDir
} else {
    $top = Invoke-GitRaw rev-parse --show-toplevel
    if ($top.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($top.Text)) {
        Set-Location -LiteralPath $top.Text
    }
}

$ForbiddenFileRules = @(
    @{ Name = "ENV_SECRET_FILE"; Check = { param($p) ($p -imatch '(^|/)(\.env(\..+)?)$') -and ($p -inotmatch '\.env\.(example|sample|template|schema|dist)$') } },
    @{ Name = "PRIVATE_KEY_OR_CERT"; Check = { param($p) ($p -imatch '\.(pem|key|p12|pfx|jks|keystore|pkcs12|kubeconfig)$') -or (($p -imatch '(^|/)(id_rsa|id_ed25519|id_ecdsa|id_dsa)(\..+)?$') -and ($p -inotmatch '\.pub$')) } },
    @{ Name = "CLOUD_OR_PKG_CREDENTIAL"; Check = { param($p) ($p -imatch '(credentials|service-account|client_secret).*\.(json|yaml|yml)$') -or ($p -imatch '(^|/)(\.npmrc|\.pypirc|\.netrc|kubeconfig)$') } },
    @{ Name = "LOCAL_DB_OR_CAPTURE_DUMP"; Check = { param($p) $p -imatch '\.(har|pcap|pcapng|sqlite|sqlite3|db|dump|sql\.gz)$' } }
)

$SecretContentRules = @(
    @{ Name = "PRIVATE_KEY_BLOCK"; Pattern = '-----BEGIN (RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----' },
    @{ Name = "AI_OR_PLATFORM_API_KEY"; Pattern = '\b(sk-(proj-|ant-|live-|test-)?[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}|glpat-[A-Za-z0-9_-]{20,}|hf_[A-Za-z0-9]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}|(rk|pk)_live_[0-9A-Za-z]{20,})\b' },
    @{ Name = "CLOUD_PROVIDER_AK"; Pattern = '\b((AKIA|ASIA)[0-9A-Z]{16}|LTAI[A-Za-z0-9]{12,24}|AKID[A-Za-z0-9]{13,32})\b' },
    @{ Name = "DB_URL_WITH_PASSWORD"; Pattern = '(postgres|postgresql|mysql|mariadb|mongodb|mongodb\+srv|redis|rediss|amqp|amqps)://[^/\s:@<>{}"'']+:[^/\s@<>{}"''$]{4,}@' },
    @{ Name = "IM_WEBHOOK_SECRET_URL"; Pattern = 'https://(open\.feishu\.cn/open-apis/bot/v2/hook/[0-9a-f-]{20,}|oapi\.dingtalk\.com/robot/send\?access_token=[0-9a-zA-Z]{30,}|qyapi\.weixin\.qq\.com/cgi-bin/webhook/send\?key=[0-9a-zA-Z-]{20,}|hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+|discord(app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+)' },
    @{ Name = "HARDCODED_SECRET_ASSIGN"; Pattern = '(?i)(api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|private[_-]?key|client[_-]?secret|jwt[_-]?secret|db[_-]?password|password|passwd)\s*[:=]\s*["''][A-Za-z0-9+/=._!@#%^&*-]{12,}["'']' },
    @{ Name = "BEARER_TOKEN_HEADER"; Pattern = '(?i)Authorization\s*:\s*Bearer\s+[A-Za-z0-9._-]{20,}' }
)

function Test-PlaceholderOrAllowlisted {
    param([string]$Line)
    if ($Line -imatch '(dev-setup-ignore-secret|pragma:\s*allowlist\s*secret)') {
        return $true
    }
    if ($Line -imatch '(<YOUR_|YOUR_API_KEY|YOUR_SECRET|YOUR_TOKEN|YOUR_PASSWORD|<REDACTED>|<PASSWORD>|<TOKEN>|<API_KEY>|CHANGE_ME|REPLACE_ME|EXAMPLE_KEY|EXAMPLE_TOKEN|PLACEHOLDER|DUMMY_KEY|xxxx|\*\*\*\*)') {
        return $true
    }
    return $false
}

function Mask-Snippet {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if ($trimmed.Length -gt 90) {
        return $trimmed.Substring(0, 90) + "..."
    }
    return $trimmed
}

$Findings = New-Object System.Collections.Generic.List[string]

function Check-FileList {
    param([string[]]$Paths)
    foreach ($rawPath in $Paths) {
        $norm = ($rawPath -replace '\\', '/').Trim()
        if ([string]::IsNullOrWhiteSpace($norm)) { continue }
        if ($norm -imatch '(^|/)templates/hooks/secret-guard\.(ps1|sh)$') { continue }
        foreach ($rule in $ForbiddenFileRules) {
            if (& $rule.Check $norm) {
                $Findings.Add("[FILE:$($rule.Name)] Forbidden sensitive file detected: $norm")
            }
        }
    }
}

function Check-DiffLines {
    param([string[]]$DiffLines)
    $currentFile = "<unknown>"
    foreach ($line in $DiffLines) {
        if ($line.StartsWith("+++ b/")) {
            $currentFile = $line.Substring(6).Trim()
            continue
        }
        if ($currentFile -imatch '(^|/)templates/hooks/secret-guard\.(ps1|sh)$') { continue }
        if ($line.StartsWith("+") -and -not $line.StartsWith("+++")) {
            $added = $line.Substring(1)
            if (Test-PlaceholderOrAllowlisted -Line $added) { continue }
            foreach ($rule in $SecretContentRules) {
                if ($added -match $rule.Pattern) {
                    $Findings.Add("[SECRET:$($rule.Name)] $currentFile -> $(Mask-Snippet -Line $added)")
                    break
                }
            }
        }
    }
}

if ($HookMode -eq "pre-commit") {
    $stagedFiles = (Invoke-GitRaw diff --cached --name-only --diff-filter=ACMR).Lines
    Check-FileList -Paths $stagedFiles
    $stagedDiff = (Invoke-GitRaw diff --cached -U0 --no-color).Lines
    Check-DiffLines -DiffLines $stagedDiff
}
elseif ($HookMode -eq "pre-push") {
    $trackedFiles = (Invoke-GitRaw ls-files).Lines
    Check-FileList -Paths $trackedFiles

    $upstreamRes = Invoke-GitRaw rev-parse --abbrev-ref --symbolic-full-name "@{u}"
    if ($upstreamRes.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($upstreamRes.Text)) {
        $pushDiff = (Invoke-GitRaw diff "$($upstreamRes.Text)..HEAD" -U0 --no-color).Lines
    } else {
        $emptyTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
        $pushDiff = (Invoke-GitRaw diff "$emptyTree..HEAD" -U0 --no-color).Lines
    }
    Check-DiffLines -DiffLines $pushDiff
}
elseif ($HookMode -eq "full") {
    $tracked = (Invoke-GitRaw ls-files).Lines
    $untracked = (Invoke-GitRaw ls-files --others --exclude-standard).Lines
    $allFiles = @($tracked) + @($untracked) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    Check-FileList -Paths $allFiles

    $BinaryExtRegex = '\.(png|jpe?g|webp|gif|bmp|ico|icns|avif|tiff?|psd|ai|eps|mp3|wav|ogg|flac|aac|m4a|mp4|mov|avi|mkv|webm|woff2?|ttf|otf|eot|pdf|zip|tar|tgz|gz|bz2|xz|7z|rar|wasm|py[cod]|so|dylib|dll|exe|bin|o|a|obj|class|jar|sqlite3?|db|dump|pcap(ng)?|p12|pfx|jks|keystore|pkcs12)$'

    foreach ($rel in $allFiles) {
        $norm = ($rel -replace '\\', '/').Trim()
        if ($norm -imatch '(^|/)templates/hooks/secret-guard\.(ps1|sh)$') { continue }
        if ($norm -imatch $BinaryExtRegex) { continue }
        if (-not (Test-Path -LiteralPath $rel -PathType Leaf)) { continue }
        $item = Get-Item -LiteralPath $rel -Force
        if ($item.Length -gt 2097152 -or $item.Length -eq 0) { continue } # Skip empty or >2MB files

        # Fast NUL-byte check on first 4KB to skip extensionless binary files
        try {
            $fs = [System.IO.File]::OpenRead($item.FullName)
            try {
                $bufLen = [Math]::Min([int]$item.Length, 4096)
                $buf = New-Object byte[] $bufLen
                $readBytes = $fs.Read($buf, 0, $bufLen)
                $hasNull = $false
                for ($b = 0; $b -lt $readBytes; $b++) {
                    if ($buf[$b] -eq 0) { $hasNull = $true; break }
                }
                if ($hasNull) { continue }
            } finally {
                $fs.Close()
            }
            $rawLines = [System.IO.File]::ReadAllLines($item.FullName, [System.Text.Encoding]::UTF8)
        } catch {
            continue
        }
        for ($i = 0; $i -lt $rawLines.Length; $i++) {
            $ln = $rawLines[$i]
            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
            if (Test-PlaceholderOrAllowlisted -Line $ln) { continue }
            foreach ($rule in $SecretContentRules) {
                if ($ln -match $rule.Pattern) {
                    $lineNo = $i + 1
                    $Findings.Add("[SECRET:$($rule.Name)] ${norm}:${lineNo} -> $(Mask-Snippet -Line $ln)")
                    break
                }
            }
        }
    }
}

if ($Findings.Count -gt 0) {
    Write-Output "=================================================================="
    Write-Output "[BLOCKED BY DEV-SETUP SECRET GUARD] Sensitive data risk detected!"
    Write-Output "Mode     : $HookMode"
    Write-Output "Findings : $($Findings.Count)"
    Write-Output "------------------------------------------------------------------"
    foreach ($f in $Findings) {
        Write-Output "  $f"
    }
    Write-Output "------------------------------------------------------------------"
    Write-Output "Action Required:"
    Write-Output "  1. Move secrets to environment variables (.env) and register empty keys in .env.example."
    Write-Output "  2. Redact real IPs, tokens, passwords, or PII in docs/handoffs/pitfalls with <REDACTED>."
    Write-Output "  3. DO NOT bypass with --no-verify. If a test dummy line is a verified false positive,"
    Write-Output "     ask human approval before adding inline comment 'dev-setup-ignore-secret'."
    Write-Output "=================================================================="
    exit 1
}

if ($HookMode -eq "full") {
    Write-Output "[OK] secret-scan passed: 0 secrets or sensitive files detected."
}
exit 0
