param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("init", "git-setup", "worktree-add", "worktree-remove", "secret-scan", "audit")]
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
    [string]$Author = "dev-setup (AI)",

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

# Canonical localized doc filenames (pure ASCII source escapes for PS 5.1 compatibility)
$DocPrd000      = "docs/01-prd/PRD-000-" + [regex]::Unescape('\u5168\u5c40\u4ea7\u54c1\u9700\u6c42\u603b\u7eb2') + ".md"
$DocArch000     = "docs/02-architecture/ARCH-000-" + [regex]::Unescape('\u7cfb\u7edf\u67b6\u6784\u4e0e\u6a21\u5757\u8bbe\u8ba1\u603b\u7eb2') + ".md"
$DocAdr0001     = "docs/02-architecture/adr/ADR-0001-" + [regex]::Unescape('\u521d\u59cb\u67b6\u6784\u4e0e\u6280\u672f\u9009\u578b\u57fa\u7ebf') + ".md"
$DocApi000      = "docs/03-contracts/API-000-" + [regex]::Unescape('\u5168\u5c40\u63a5\u53e3\u5951\u7ea6\u603b\u8868') + ".md"
$DocData000     = "docs/03-contracts/DATA-000-" + [regex]::Unescape('\u6838\u5fc3\u6570\u636e\u6a21\u578b\u4e0e\u5b57\u5178') + ".md"
$DocIter01      = "docs/04-iterations/ITER-01-v0.1.0-MVP" + [regex]::Unescape('\u9996\u8f6e\u8fed\u4ee3\u8ba1\u5212') + ".md"
$DocAccept01    = "docs/05-acceptance/ACCEPT-01-v0.1.0-MVP" + [regex]::Unescape('\u9996\u8f6e\u9a8c\u6536\u5355') + ".md"
$DocOps000      = "docs/06-ops-and-pitfalls/OPS-000-" + [regex]::Unescape('\u73af\u5883\u642d\u5efa\u4e0e\u90e8\u7f72\u8fd0\u7ef4\u624b\u518c') + ".md"
$DocPitfalls000 = "docs/06-ops-and-pitfalls/PITFALLS-000-" + [regex]::Unescape('\u9879\u76ee\u8e29\u5751\u9519\u9898\u672c') + ".md"

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
        [string]$AuthorVal,
        [string]$DateVal,
        [string]$DateTimeVal
    )
    return $Raw.
        Replace("{{PROJECT_NAME}}", $NameVal).
        Replace("{{PROJECT_SUMMARY}}", $SummaryVal).
        Replace("{{TECH_STACK}}", $StackVal).
        Replace("{{AUTHOR}}", $AuthorVal).
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
    if ([string]::IsNullOrWhiteSpace($Author)) {
        $Author = "dev-setup (AI)"
    }

    $nowDate = (Get-Date).ToString("yyyy-MM-dd")
    $nowDateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm")

    Write-Output "=== dev-setup init ==="
    Write-Output "Target   : $target"
    Write-Output "Detected : $modeLabel"
    Write-Output "Project  : $ProjectName"
    Write-Output "Author   : $Author"

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
        "docs/06-ops-and-pitfalls",
        "docs/99-archive"
    )
    foreach ($relDir in $requiredDirs) {
        $fullDir = Join-Path $target $relDir
        if (-not (Test-Path -LiteralPath $fullDir)) {
            New-Item -ItemType Directory -Path $fullDir -Force | Out-Null
        }
    }

    foreach ($keepRel in @(".tmp/.gitkeep", "docs/99-archive/.gitkeep")) {
        $keepPath = Join-Path $target $keepRel
        if (-not (Test-Path -LiteralPath $keepPath)) {
            Write-Utf8File -Path $keepPath -Content ""
            Write-Output "[CREATED]  $keepRel"
        }
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
        @{ Src = "docs/01-prd/prd-000-overview.md.tmpl"; Dst = $DocPrd000 },
        @{ Src = "docs/02-architecture/arch-000-system-design.md.tmpl"; Dst = $DocArch000 },
        @{ Src = "docs/02-architecture/adr-0001-initial-architecture.md.tmpl"; Dst = $DocAdr0001 },
        @{ Src = "docs/03-contracts/api-000-spec.md.tmpl"; Dst = $DocApi000 },
        @{ Src = "docs/03-contracts/data-000-dictionary.md.tmpl"; Dst = $DocData000 },
        @{ Src = "docs/04-iterations/iter-01-mvp.md.tmpl"; Dst = $DocIter01 },
        @{ Src = "docs/05-acceptance/accept-01-mvp.md.tmpl"; Dst = $DocAccept01 },
        @{ Src = "docs/06-ops-and-pitfalls/ops-000-deployment.md.tmpl"; Dst = $DocOps000 },
        @{ Src = "docs/06-ops-and-pitfalls/pitfalls-000-registry.md.tmpl"; Dst = $DocPitfalls000 }
    )

    foreach ($item in $mappings) {
        $srcPath = Join-Path $TemplatesRoot $item.Src
        $dstPath = Join-Path $target $item.Dst
        $raw = Read-Utf8File -Path $srcPath
        $rendered = Render-TemplateContent -Raw $raw -NameVal $ProjectName -SummaryVal $Summary -StackVal $TechStack -AuthorVal $Author -DateVal $nowDate -DateTimeVal $nowDateTime

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

function Install-GitSecretHooks {
    param([string]$RepoRoot)
    $hooksDir = Join-Path $RepoRoot ".git/hooks"
    if (-not (Test-Path -LiteralPath $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }

    $guardSrc = Join-Path $TemplatesRoot "hooks/secret-guard.ps1"
    $guardDst = Join-Path $hooksDir "secret-guard.ps1"
    $guardContent = Read-Utf8File -Path $guardSrc
    Write-Utf8File -Path $guardDst -Content $guardContent

    foreach ($hookName in @("pre-commit", "pre-push")) {
        $hookEntry = Join-Path $hooksDir $hookName
        $hookCmd = Join-Path $hooksDir "$hookName.cmd"
        $canWrite = $true
        if ((Test-Path -LiteralPath $hookEntry) -and -not $Force) {
            $existingHook = Read-Utf8File -Path $hookEntry
            if ($existingHook -notmatch "dev-setup-secret-guard") {
                Write-Output "[WARN] Custom Git hook '$hookName' already exists; preserved (pass -Force to replace)."
                $canWrite = $false
            }
        }
        if ($canWrite) {
            $entryBody = "#!C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile`n# dev-setup-secret-guard`n"
            $cmdBody = "@echo off`r`nREM dev-setup-secret-guard`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File ""%~dp0secret-guard.ps1"" -HookMode $hookName`r`nexit /b %ERRORLEVEL%`r`n"
            Write-Utf8File -Path $hookEntry -Content $entryBody
            Write-Utf8File -Path $hookCmd -Content $cmdBody
            Write-Output "[OK] Installed Git security hook: .git/hooks/$hookName"
        }
    }
}

function Invoke-SecretScanAction {
    $target = Resolve-NormalizedDir -DirPath $TargetDir
    $guardScript = Join-Path $TemplatesRoot "hooks/secret-guard.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guardScript -HookMode full -RepoDir $target
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
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

        # Display Chinese filenames cleanly without octal escapes in git status / diff
        Invoke-Git config core.quotepath false | Out-Null

        Install-GitSecretHooks -RepoRoot $target

        $userRes = Invoke-Git config user.name
        if ([string]::IsNullOrWhiteSpace($userRes.Text)) {
            Invoke-Git config user.name "Developer" | Out-Null
            Invoke-Git config user.email "developer@localhost" | Out-Null
            Write-Output "[INFO] Configured fallback repo-local git user.name / user.email."
        }

        $headRes = Invoke-Git rev-parse --verify HEAD
        $hasCommits = ($headRes.ExitCode -eq 0)

        if (-not $hasCommits) {
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
        $DocPrd000,
        $DocArch000,
        $DocApi000,
        $DocData000,
        $DocOps000,
        $DocPitfalls000
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
        "docs/05-acceptance",
        "docs/99-archive"
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
            Write-Output "[WARN] Non-standard Markdown file in project root: $($f.Name) (move under docs/)"
            $warnCount++
        }
        if ($f.Name -imatch "^(temp|tmp|scratch|debug|test_)") {
            Write-Output "[WARN] Possible temporary clutter in project root: $($f.Name) (move to .tmp/)"
            $warnCount++
        }
    }

    # Naming, Metadata Card & Revision History checks under docs/
    $docsRoot = Join-Path $target "docs"
    if (Test-Path -LiteralPath $docsRoot) {
        $kwMetaCard = [regex]::Unescape('\u6587\u6863\u5143\u4fe1\u606f\u5361')
        $kwLastMod  = [regex]::Unescape('\u6700\u540e\u4fee\u6539')
        $kwRevHist  = [regex]::Unescape('\u6587\u6863\u53d8\u66f4\u8bb0\u5f55')
        $messySuffixPattern = "(_v[0-9]+|_new|_final|_old|_bak|_copy|" + [regex]::Unescape('\u526f\u672c|\u6700\u7ec8\u7248') + ")\.[a-zA-Z0-9]+$"

        # 1. Subdirectory kebab-case check under docs/
        $docSubDirs = Get-ChildItem -LiteralPath $docsRoot -Directory -Recurse -Force
        foreach ($d in $docSubDirs) {
            if ($d.Name -cnotmatch "^[a-z0-9-]+$") {
                $relD = $d.FullName.Substring($target.Length + 1) -replace '\\', '/'
                Write-Output "[WARN] Directory violates lowercase kebab-case standard: $relD"
                $warnCount++
            }
        }

        # 2. Messy suffix check across docs/ (excluding 99-archive/)
        $allDocFiles = Get-ChildItem -LiteralPath $docsRoot -File -Recurse -Force
        foreach ($df in $allDocFiles) {
            $relDf = $df.FullName.Substring($target.Length + 1) -replace '\\', '/'
            if ($relDf.StartsWith("docs/99-archive/")) { continue }
            if ($df.Name -eq ".gitkeep" -or $df.Name -eq "_template.md") { continue }

            if ($df.Name -imatch $messySuffixPattern) {
                Write-Output "[WARN] Forbidden chaotic suffix (_v2/_final/_bak/etc.) in filename: $relDf"
                $warnCount++
            }
        }

        # 3. Naming formula + Metadata Card + Revision History check for docs/01..06
        $specRules = @(
            @{ Dir = "docs/01-prd";                Recurse = $false; Regex = "^PRD-[0-9]{3}-.+\.md$" },
            @{ Dir = "docs/02-architecture";       Recurse = $false; Regex = "^ARCH-[0-9]{3}-.+\.md$" },
            @{ Dir = "docs/02-architecture/adr";   Recurse = $false; Regex = "^ADR-[0-9]{4}-.+\.md$" },
            @{ Dir = "docs/03-contracts";          Recurse = $false; Regex = "^(API|DATA)-[0-9]{3}-.+\.md$" },
            @{ Dir = "docs/04-iterations";         Recurse = $false; Regex = "^ITER-[0-9]{2}-v[0-9]+\.[0-9]+\.[0-9]+-.+\.md$" },
            @{ Dir = "docs/05-acceptance";         Recurse = $false; Regex = "^(ACCEPT|TEST)-[0-9]{2}-v[0-9]+\.[0-9]+\.[0-9]+-.+\.md$" },
            @{ Dir = "docs/06-ops-and-pitfalls";   Recurse = $false; Regex = "^(OPS|PITFALLS)-[0-9]{3}-.+\.md$" }
        )

        foreach ($sr in $specRules) {
            $dirFull = Join-Path $target $sr.Dir
            if (-not (Test-Path -LiteralPath $dirFull)) { continue }
            $mdFiles = Get-ChildItem -LiteralPath $dirFull -Filter "*.md" -File -Force
            foreach ($mf in $mdFiles) {
                $relMf = "$($sr.Dir)/$($mf.Name)"
                if ($mf.Name -cnotmatch $sr.Regex) {
                    Write-Output "[WARN] Document filename violates '$($sr.Regex)' naming rule: $relMf"
                    $warnCount++
                } else {
                    $passCount++
                }

                $content = Read-Utf8File -Path $mf.FullName
                $hasCard = ($content -match $kwMetaCard) -and ($content -match $kwLastMod)
                $hasValidStatus = ($content -cmatch '`?(DRAFT|ACTIVE|COMPLETED|SUPERSEDED|DEPRECATED)`?')
                $hasRevTable = ($content -match $kwRevHist)

                if (-not ($hasCard -and $hasValidStatus -and $hasRevTable)) {
                    Write-Output "[WARN] Document missing standard metadata card, controlled status tag, or revision history table: $relMf"
                    $warnCount++
                } else {
                    $passCount++
                }

                if ($content -cmatch '\*\*`?(SUPERSEDED|DEPRECATED)`?\*\*' -or $content -cmatch ':\s*`(SUPERSEDED|DEPRECATED)`' -or $content -cmatch '\uff1a`(SUPERSEDED|DEPRECATED)`') {
                    Write-Output "[WARN] Superseded/Deprecated document should be archived to docs/99-archive/: $relMf"
                    $warnCount++
                }
            }
        }
    }

    # Git & Security checks
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

            foreach ($hk in @("pre-commit", "pre-push")) {
                $hkPath = Join-Path $gitDir "hooks/$hk"
                if (Test-Path -LiteralPath $hkPath) {
                    $passCount++
                } else {
                    Write-Output "[WARN] Git security hook '.git/hooks/$hk' is missing (run git-setup to install)."
                    $warnCount++
                }
            }

            $guardScript = Join-Path $TemplatesRoot "hooks/secret-guard.ps1"
            $oldEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
            $scanOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guardScript -HookMode full -RepoDir $target 2>&1
            $scanExit = $LASTEXITCODE
            $ErrorActionPreference = $oldEap
            if ($scanExit -eq 0) {
                $passCount++
            } else {
                foreach ($l in $scanOut) { Write-Output "$l" }
                $failCount++
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
    "secret-scan"     { Invoke-SecretScanAction }
    "audit"           { Invoke-AuditAction }
}
