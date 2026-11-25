param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("init", "git-setup", "worktree-add", "worktree-remove", "audit")]
    [string]$Action = "init",

    [Parameter(Mandatory = $false)]
    [string]$TargetDir = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "",

    [Parameter(Mandatory = $false)]
    [string]$Summary = "",

    [Parameter(Mandatory = $false)]
    [string]$TechStack = "TBD",

    [Parameter(Mandatory = $false)]
    [string]$Branch = "",

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "develop",

    [Parameter(Mandatory = $false)]
    [switch]$DeleteBranch,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$SkillRoot = Split-Path -Parent $PSScriptRoot
$TemplatesRoot = Join-Path $SkillRoot "templates"

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Read-Utf8File {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Invoke-Git {
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
            Output   = $lines
            Text     = ($lines -join "`n").Trim()
        }
    } finally {
        $ErrorActionPreference = $oldEap
    }
}

function Resolve-NormalizedDir {
    param([string]$DirPath, [switch]$CreateIfMissing)
    if (-not (Test-Path -LiteralPath $DirPath)) {
        if ($CreateIfMissing) {
            New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
        } else {
            throw "Target directory does not exist: $DirPath"
        }
    }
    return (Resolve-Path -LiteralPath $DirPath).Path
}

function Render-TemplateContent {
    param(
        [string]$Raw,
        [string]$NameVal,
        [string]$SummaryVal,
        [string]$StackVal,
        [string]$DateVal,
        [string]$DateTimeVal
    )
    return $Raw.
        Replace("{{PROJECT_NAME}}", $NameVal).
        Replace("{{PROJECT_SUMMARY}}", $SummaryVal).
        Replace("{{TECH_STACK}}", $StackVal).
        Replace("{{DATE}}", $DateVal).
        Replace("{{DATETIME}}", $DateTimeVal)
}

function Invoke-InitAction {
    $existedBefore = Test-Path -LiteralPath $TargetDir
    $target = Resolve-NormalizedDir -DirPath $TargetDir -CreateIfMissing
    $existingItems = @()
    if ($existedBefore) {
        $existingItems = @(Get-ChildItem -LiteralPath $target -Force | Where-Object { $_.Name -ne ".git" })
    }
    $modeLabel = if ($existingItems.Count -eq 0) { "GREENFIELD" } else { "BROWNFIELD" }

    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        $ProjectName = Split-Path -Leaf $target
    }
    if ([string]::IsNullOrWhiteSpace($Summary)) {
        $Summary = [regex]::Unescape('\u6807\u51c6\u5316 AI \u534f\u540c\u8f6f\u4ef6\u5de5\u7a0b\u9879\u76ee')
    }
    if ([string]::IsNullOrWhiteSpace($TechStack)) {
        $TechStack = "TBD"
    }

    $nowDate = (Get-Date).ToString("yyyy-MM-dd")
    $nowDateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm")

    Write-Output "=== dev-setup init ==="
    Write-Output "Target   : $target"
    Write-Output "Detected : $modeLabel"
    Write-Output "Project  : $ProjectName"

    # Ensure core directories exist (never pre-create empty src/ business folders)
    $requiredDirs = @(
        ".tmp",
        ".cursor/rules",
        "docs/00-ai-hub/handoffs",
        "docs/00-ai-hub/reviews",
        "docs/01-prd",
        "docs/02-architecture/adr",
        "docs/03-contracts",
        "docs/04-iterations",
        "docs/05-acceptance",
        "docs/06-ops-and-pitfalls"
    )
    foreach ($relDir in $requiredDirs) {
        $fullDir = Join-Path $target $relDir
        if (-not (Test-Path -LiteralPath $fullDir)) {
            New-Item -ItemType Directory -Path $fullDir -Force | Out-Null
        }
    }

    $gitkeepPath = Join-Path $target ".tmp/.gitkeep"
    if (-not (Test-Path -LiteralPath $gitkeepPath)) {
        Write-Utf8File -Path $gitkeepPath -Content ""
        Write-Output "[CREATED]  .tmp/.gitkeep"
    }

    $mappings = @(
        @{ Src = "root/AGENTS.md.tmpl"; Dst = "AGENTS.md" },
        @{ Src = "root/CLAUDE.md.tmpl"; Dst = "CLAUDE.md" },
        @{ Src = "root/GEMINI.md.tmpl"; Dst = "GEMINI.md" },
        @{ Src = "root/cursor-project-os.mdc.tmpl"; Dst = ".cursor/rules/00-project-os.mdc" },
        @{ Src = "root/README.md.tmpl"; Dst = "README.md" },
        @{ Src = "root/CHANGELOG.md.tmpl"; Dst = "CHANGELOG.md" },
        @{ Src = "root/env.example.tmpl"; Dst = ".env.example" },
        @{ Src = "root/gitignore.tmpl"; Dst = ".gitignore" },
        @{ Src = "docs/00-index.md.tmpl"; Dst = "docs/00-index.md" },
        @{ Src = "docs/00-ai-hub/STATE.md.tmpl"; Dst = "docs/00-ai-hub/STATE.md" },
        @{ Src = "docs/00-ai-hub/SESSIONS.md.tmpl"; Dst = "docs/00-ai-hub/SESSIONS.md" },
        @{ Src = "docs/00-ai-hub/handoff-template.md.tmpl"; Dst = "docs/00-ai-hub/handoffs/_template.md" },
        @{ Src = "docs/00-ai-hub/review-template.md.tmpl"; Dst = "docs/00-ai-hub/reviews/_template.md" },
        @{ Src = "docs/01-prd/prd-overview.md.tmpl"; Dst = "docs/01-prd/prd-overview.md" },
        @{ Src = "docs/02-architecture/system-design.md.tmpl"; Dst = "docs/02-architecture/system-design.md" },
        @{ Src = "docs/02-architecture/adr-0001-initial-architecture.md.tmpl"; Dst = "docs/02-architecture/adr/0001-initial-architecture.md" },
        @{ Src = "docs/03-contracts/api-spec.md.tmpl"; Dst = "docs/03-contracts/api-spec.md" },
        @{ Src = "docs/03-contracts/data-dictionary.md.tmpl"; Dst = "docs/03-contracts/data-dictionary.md" },
        @{ Src = "docs/04-iterations/iter-01-mvp.md.tmpl"; Dst = "docs/04-iterations/iter-01-mvp.md" },
        @{ Src = "docs/05-acceptance/accept-01-mvp.md.tmpl"; Dst = "docs/05-acceptance/accept-01-mvp.md" },
        @{ Src = "docs/06-ops-and-pitfalls/deployment.md.tmpl"; Dst = "docs/06-ops-and-pitfalls/deployment.md" },
        @{ Src = "docs/06-ops-and-pitfalls/pitfalls.md.tmpl"; Dst = "docs/06-ops-and-pitfalls/pitfalls.md" }
    )

    foreach ($item in $mappings) {
        $srcPath = Join-Path $TemplatesRoot $item.Src
        $dstPath = Join-Path $target $item.Dst
        $raw = Read-Utf8File -Path $srcPath
        $rendered = Render-TemplateContent -Raw $raw -NameVal $ProjectName -SummaryVal $Summary -StackVal $TechStack -DateVal $nowDate -DateTimeVal $nowDateTime

        if ($item.Dst -eq ".gitignore" -and (Test-Path -LiteralPath $dstPath) -and -not $Force) {
            $existingIgnore = Read-Utf8File -Path $dstPath
            if ($existingIgnore -notmatch "dev-setup AI Project OS Managed Rules") {
                $merged = $existingIgnore.TrimEnd() + "`n`n" + $rendered
                Write-Utf8File -Path $dstPath -Content $merged
                Write-Output "[MERGED]   .gitignore (appended dev-setup rules)"
            } else {
                Write-Output "[PRESERVED] .gitignore (already contains dev-setup rules)"
            }
            continue
        }

        if ((Test-Path -LiteralPath $dstPath) -and -not $Force) {
            Write-Output "[PRESERVED] $($item.Dst)"
        } else {
            Write-Utf8File -Path $dstPath -Content $rendered
            Write-Output "[CREATED]  $($item.Dst)"
        }
    }

    Write-Output "=== init scaffold complete ($modeLabel) ==="
}

function Invoke-GitSetupAction {
    $target = Resolve-NormalizedDir -DirPath $TargetDir
    Push-Location $target
    try {
        Write-Output "=== dev-setup git-setup ==="
        $gitDir = Join-Path $target ".git"
        $hasGit = Test-Path -LiteralPath $gitDir

        if (-not $hasGit) {
            $res = Invoke-Git init -b main
            if ($res.ExitCode -ne 0) {
                Invoke-Git init | Out-Null
                Invoke-Git symbolic-ref HEAD refs/heads/main | Out-Null
            }
            Write-Output "[OK] Initialized new Git repository on 'main'."
        }

        # Ensure git author exists locally if global git config is absent
        $userRes = Invoke-Git config user.name
        if ([string]::IsNullOrWhiteSpace($userRes.Text)) {
            Invoke-Git config user.name "Developer" | Out-Null
            Invoke-Git config user.email "developer@localhost" | Out-Null
            Write-Output "[INFO] Configured fallback repo-local git user.name / user.email."
        }

        $headRes = Invoke-Git rev-parse --verify HEAD
        $hasCommits = ($headRes.ExitCode -eq 0)

        if (-not $hasCommits) {
            # Greenfield initial commit on main + create develop
            Invoke-Git symbolic-ref HEAD refs/heads/main | Out-Null
            Invoke-Git add -A | Out-Null
            $initMsg = "chore(init): " + [regex]::Unescape('\u521d\u59cb\u5316\u9879\u76ee\u5de5\u7a0b\u5316\u57fa\u5ea7\u4e0e\u6838\u5fc3\u6587\u6863')
            $commitRes = Invoke-Git commit -m $initMsg
            if ($commitRes.ExitCode -ne 0) {
                throw "git commit failed: $($commitRes.Text)"
            }
            $coRes = Invoke-Git checkout -B develop
            if ($coRes.ExitCode -ne 0) {
                throw "git checkout -B develop failed: $($coRes.Text)"
            }
            Write-Output "[OK] Created baseline commit on 'main' and switched to 'develop'."
        } else {
            # Brownfield safe branch setup without rewriting history
            $mainRes = Invoke-Git show-ref --verify --quiet refs/heads/main
            if ($mainRes.ExitCode -ne 0) {
                $masterRes = Invoke-Git show-ref --verify --quiet refs/heads/master
                if ($masterRes.ExitCode -eq 0) {
                    Invoke-Git branch main master | Out-Null
                    Write-Output "[OK] Created 'main' branch pointing to 'master'."
                } else {
                    Invoke-Git branch main HEAD | Out-Null
                    Write-Output "[OK] Created 'main' branch from current HEAD."
                }
            }

            $devRes = Invoke-Git show-ref --verify --quiet refs/heads/develop
            if ($devRes.ExitCode -ne 0) {
                Invoke-Git branch develop main | Out-Null
                Write-Output "[OK] Created 'develop' branch from 'main'."
            }

            $curBranch = (Invoke-Git branch --show-current).Text
            if ($curBranch -eq "main" -or $curBranch -eq "master") {
                $swRes = Invoke-Git checkout develop
                if ($swRes.ExitCode -eq 0) {
                    Write-Output "[OK] Switched working branch from '$curBranch' to 'develop'."
                } else {
                    Write-Output "[WARN] Could not auto-switch from '$curBranch' to 'develop': $($swRes.Text)"
                }
            } else {
                Write-Output "[INFO] Preserved current branch '$curBranch' (both 'main' and 'develop' exist)."
            }
        }
    } finally {
        Pop-Location
    }
}

function Get-BranchSlug {
    param([string]$BranchName)
    $slug = $BranchName -replace "[/\\:\s]+", "-"
    $slug = $slug -replace "[^a-zA-Z0-9._-]", ""
    return $slug.Trim("-")
}

function Invoke-WorktreeAddAction {
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        throw "Parameter -Branch is required for worktree-add (e.g. -Branch 'feat/user-auth')."
    }
    $target = Resolve-NormalizedDir -DirPath $TargetDir
    $slug = Get-BranchSlug -BranchName $Branch
    $wtRel = ".worktrees/$slug"
    $wtFull = Join-Path $target $wtRel

    Push-Location $target
    try {
        if (Test-Path -LiteralPath $wtFull) {
            throw "Worktree path already exists: $wtFull"
        }
        $wtParent = Join-Path $target ".worktrees"
        if (-not (Test-Path -LiteralPath $wtParent)) {
            New-Item -ItemType Directory -Path $wtParent -Force | Out-Null
        }

        $brExists = Invoke-Git show-ref --verify --quiet "refs/heads/$Branch"
        if ($brExists.ExitCode -eq 0) {
            $wtRes = Invoke-Git worktree add $wtFull $Branch
        } else {
            $baseExists = Invoke-Git show-ref --verify --quiet "refs/heads/$BaseBranch"
            if ($baseExists.ExitCode -ne 0) {
                throw "Base branch '$BaseBranch' does not exist."
            }
            $wtRes = Invoke-Git worktree add $wtFull -b $Branch $BaseBranch
        }
        if ($wtRes.ExitCode -ne 0) {
            throw "git worktree add failed: $($wtRes.Text)"
        }
        Write-Output "[OK] Isolated worktree ready: $wtFull (branch: $Branch)"
        Write-Output "[NEXT] Register this worktree lock in docs/00-ai-hub/SESSIONS.md on the integration branch."
    } finally {
        Pop-Location
    }
}

function Invoke-WorktreeRemoveAction {
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        throw "Parameter -Branch is required for worktree-remove."
    }
    $target = Resolve-NormalizedDir -DirPath $TargetDir
    $slug = Get-BranchSlug -BranchName $Branch
    $wtFull = Join-Path $target ".worktrees/$slug"

    Push-Location $target
    try {
        if (-not (Test-Path -LiteralPath $wtFull)) {
            throw "Worktree directory not found: $wtFull"
        }
        $dirtyRes = Invoke-Git -C $wtFull status --porcelain
        if (-not [string]::IsNullOrWhiteSpace($dirtyRes.Text) -and -not $Force) {
            throw "[ABORT] Worktree has uncommitted changes ($wtFull). Commit/clean first or pass -Force."
        }
        if ($Force) {
            $rmRes = Invoke-Git worktree remove --force $wtFull
        } else {
            $rmRes = Invoke-Git worktree remove $wtFull
        }
        if ($rmRes.ExitCode -ne 0) {
            throw "git worktree remove failed: $($rmRes.Text)"
        }
        Invoke-Git worktree prune | Out-Null
        Write-Output "[OK] Removed worktree: $wtFull"

        if ($DeleteBranch) {
            $delRes = Invoke-Git branch -d $Branch
            if ($delRes.ExitCode -eq 0) {
                Write-Output "[OK] Deleted merged branch: $Branch"
            } else {
                Write-Output "[WARN] Branch '$Branch' is not fully merged; kept branch for safety."
            }
        }
    } finally {
        Pop-Location
    }
}

function Invoke-AuditAction {
    $target = Resolve-NormalizedDir -DirPath $TargetDir
    $passCount = 0
    $warnCount = 0
    $failCount = 0

    Write-Output "=== dev-setup audit: $target ==="

    $requiredFiles = @(
        "AGENTS.md",
        "CLAUDE.md",
        "GEMINI.md",
        ".cursor/rules/00-project-os.mdc",
        "README.md",
        "CHANGELOG.md",
        ".env.example",
        ".gitignore",
        "docs/00-index.md",
        "docs/00-ai-hub/STATE.md",
        "docs/00-ai-hub/SESSIONS.md",
        "docs/01-prd/prd-overview.md",
        "docs/02-architecture/system-design.md",
        "docs/03-contracts/api-spec.md",
        "docs/03-contracts/data-dictionary.md",
        "docs/06-ops-and-pitfalls/deployment.md",
        "docs/06-ops-and-pitfalls/pitfalls.md"
    )

    foreach ($rel in $requiredFiles) {
        $p = Join-Path $target $rel
        if (Test-Path -LiteralPath $p) {
            $passCount++
        } else {
            Write-Output "[FAIL] Missing required file: $rel"
            $failCount++
        }
    }

    $requiredDirs = @(
        ".tmp",
        "docs/00-ai-hub/handoffs",
        "docs/00-ai-hub/reviews",
        "docs/02-architecture/adr",
        "docs/04-iterations",
        "docs/05-acceptance"
    )
    foreach ($relDir in $requiredDirs) {
        $p = Join-Path $target $relDir
        if (Test-Path -LiteralPath $p) {
            $passCount++
        } else {
            Write-Output "[FAIL] Missing required directory: $relDir"
            $failCount++
        }
    }

    # Check .gitignore safety patterns
    $gitignoreFile = Join-Path $target ".gitignore"
    if (Test-Path -LiteralPath $gitignoreFile) {
        $giText = Read-Utf8File -Path $gitignoreFile
        foreach ($pat in @(".env", ".tmp", ".worktrees")) {
            if ($giText -match [regex]::Escape($pat)) {
                $passCount++
            } else {
                Write-Output "[WARN] .gitignore does not mention '$pat'"
                $warnCount++
            }
        }
    }

    # Root clutter check
    $allowedRootMd = @("AGENTS.md", "CLAUDE.md", "GEMINI.md", "README.md", "CHANGELOG.md", "LICENSE.md")
    $rootFiles = Get-ChildItem -LiteralPath $target -File -Force
    foreach ($f in $rootFiles) {
        if ($f.Extension -ieq ".md" -and ($allowedRootMd -notcontains $f.Name)) {
            Write-Output "[WARN] Non-standard Markdown file in project root: $($f.Name) (consider moving under docs/)"
            $warnCount++
        }
        if ($f.Name -imatch "^(temp|tmp|scratch|debug|test_)") {
            Write-Output "[WARN] Possible temporary clutter in project root: $($f.Name) (move to .tmp/)"
            $warnCount++
        }
    }

    # Git checks
    $gitDir = Join-Path $target ".git"
    if (Test-Path -LiteralPath $gitDir) {
        Push-Location $target
        try {
            $envTracked = Invoke-Git ls-files .env
            if (-not [string]::IsNullOrWhiteSpace($envTracked.Text)) {
                Write-Output "[FAIL] SECURITY: '.env' is tracked by Git! Untrack immediately with 'git rm --cached .env'."
                $failCount++
            } else {
                $passCount++
            }

            foreach ($b in @("main", "develop")) {
                $bRes = Invoke-Git show-ref --verify --quiet "refs/heads/$b"
                if ($bRes.ExitCode -eq 0) {
                    $passCount++
                } else {
                    Write-Output "[WARN] Git branch '$b' is missing."
                    $warnCount++
                }
            }

            $cur = (Invoke-Git branch --show-current).Text
            Write-Output "[INFO] Current Git branch: $cur"
            $wtList = (Invoke-Git worktree list).Output
            Write-Output "[INFO] Active Git worktrees ($($wtList.Count)):"
            foreach ($line in $wtList) {
                Write-Output "       $line"
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Output "[WARN] Git repository (.git) is not initialized yet."
        $warnCount++
    }

    Write-Output "=== Audit Summary: PASS=$passCount | WARN=$warnCount | FAIL=$failCount ==="
    if ($failCount -gt 0) {
        exit 1
    }
}

switch ($Action) {
    "init"            { Invoke-InitAction }
    "git-setup"       { Invoke-GitSetupAction }
    "worktree-add"    { Invoke-WorktreeAddAction }
    "worktree-remove" { Invoke-WorktreeRemoveAction }
    "audit"           { Invoke-AuditAction }
}
