# Mythos Init v3 — Install silent reasoning protocol into new projects
# Usage:
#   .\init.ps1                         (auto-detect)
#   .\init.ps1 --user                   (user-level, all projects)
#   .\init.ps1 D:\Work\MyGame           (project only)
#   .\init.ps1 D:\Work\MyGame --both    (project + user)
#   .\init.ps1 --user --lang zh         (force Chinese)
$ErrorActionPreference = "Stop"

# ── Parse args manually (no [switch] — avoids PowerShell param binding quirks) ─

$ProjectPath = $null
$InstallUser  = $false
$InstallProject = $false
$Lang = "auto"

for ($i = 0; $i -lt $args.Count; $i++) {
    $a = $args[$i]
    if ($a -eq "--user")   { $InstallUser = $true }
    elseif ($a -eq "--project") { $InstallProject = $true }
    elseif ($a -eq "--both")    { $InstallUser = $true; $InstallProject = $true }
    elseif ($a -eq "--lang")    { if ($i + 1 -lt $args.Count) { $Lang = $args[++$i] } }
    elseif ($a -notmatch '^--') { $ProjectPath = $a }
}

# ── Language ──────────────────────────────────────────────────

if ($Lang -eq "auto") {
    $culture = [System.Globalization.CultureInfo]::CurrentUICulture
    $Lang = if ($culture.Name -match '^zh') { "zh" } else { "en" }
}

$msg = @{
    banner_title = @{ zh = "Mythos v3 — 静默推理路由器"; en = "Mythos v3 — Silent Router" }
    phase_user   = @{ zh = "[用户级]"; en = "[User-level]" }
    phase_project = @{ zh = "[项目级]"; en = "[Project]" }
    status_skip_self    = @{ zh = "跳过自复制"; en = "skip self-copy" }
    status_created      = @{ zh = "已创建"; en = "created" }
    status_appended     = @{ zh = "推理协议已追加到"; en = "protocol appended to" }
    status_upgraded     = @{ zh = "v2 协议已升级到 v3 (router)"; en = "v2 protocol upgraded to v3 (router)" }
    status_skip_exists  = @{ zh = "v3 协议已存在，跳过"; en = "v3 protocol exists, skipped" }
    status_done         = @{ zh = "完成！"; en = "Done!" }
    prompt_detect_user  = @{ zh = "检测到用户级 CLAUDE.md (所有项目生效)"; en = "User-level CLAUDE.md detected (all projects)" }
    prompt_choice       = @{ zh = "选择 [默认: C]"; en = "Choose [default: C]" }
    prompt_choice_a     = @{ zh = "[A] 仅当前项目  [B] 仅用户级(所有项目)  [C] 两者都装  [Q] 退出"; en = "[A] This project  [B] User-level (all)  [C] Both  [Q] Quit" }
    usage_simple        = @{ zh = "简单问题 → 直接回答，零开销"; en = "Simple questions → direct answer, zero overhead" }
    usage_complex       = @{ zh = "复杂问题 → 静默加载 SKILL.md，完整 v3 推理"; en = "Complex questions → silently load SKILL.md, full v3 reasoning" }
    usage_trace         = @{ zh = "/mythos 或 think aloud → 显示完整推理 trace"; en = "/mythos or think aloud → show full reasoning trace" }
    usage_user_ready    = @{ zh = "用户级安装已就绪——所有项目自动生效。"; en = "User-level install ready — all projects active." }
    err_no_target       = @{ zh = "未指定安装目标。用 --user 或传项目路径。"; en = "No install target. Use --user or pass a project path." }
}
function t($key) { $msg[$key][$Lang] }

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  $(t 'banner_title')" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── Resolve targets ───────────────────────────────────────────

if (-not $InstallUser -and -not $InstallProject -and -not $ProjectPath) {
    if ((Test-Path ".claude") -or (Test-Path "src")) {
        $ProjectPath = (Resolve-Path ".").Path
        $InstallProject = $true
    }
    $UserClaude = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"
    if (Test-Path $UserClaude) {
        Write-Host "  $(t 'prompt_detect_user')" -ForegroundColor Yellow
        Write-Host "  $(t 'prompt_choice_a')" -ForegroundColor Gray
        $choice = Read-Host "  $(t 'prompt_choice')"
        switch ($choice) {
            "A" { $InstallProject = $true; $InstallUser = $false; if (-not $ProjectPath) { $ProjectPath = (Resolve-Path ".").Path } }
            "B" { $InstallProject = $false; $InstallUser = $true }
            "Q" { exit 0 }
            default { if ($ProjectPath) { $InstallProject = $true }; $InstallUser = $true }
        }
    } elseif ($ProjectPath) {
        $InstallProject = $true
    } else {
        $InstallUser = $true
    }
}

if (-not $InstallUser -and -not $InstallProject) {
    Write-Host " [!] $(t 'err_no_target')" -ForegroundColor Red
    exit 1
}

if ($InstallProject -and -not $ProjectPath) {
    $ProjectPath = (Resolve-Path ".").Path
}

# ── Helpers ────────────────────────────────────────────────────

$RepoRoot = Split-Path -Parent $PSScriptRoot                 # <repo>
$SourceDir = Join-Path $RepoRoot ".claude\skills\mythos"
$SourceRefs = Join-Path $SourceDir "references"
$SourceExamples = Join-Path $SourceDir "examples"
$SourceTests = Join-Path $SourceDir "tests"

function SafeCopy($src, $dstDir) {
    $fileName = Split-Path $src -Leaf
    $dst = Join-Path $dstDir $fileName
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    try {
        $srcAbs = (Resolve-Path $src).Path
        if (Test-Path $dst) { $dstAbs = (Resolve-Path $dst).Path } else { $dstAbs = "" }
        if ($srcAbs -eq $dstAbs) {
            Write-Host "   [..] $(t 'status_skip_self'): $fileName" -ForegroundColor Gray
        } else {
            Copy-Item $src $dst -Force
        }
    } catch {
        Copy-Item $src $dst -Force
    }
}

function Install-SkillFiles($baseDir) {
    $d = Join-Path $baseDir ".claude\skills\mythos"
    $r = Join-Path $d "references"
    $e = Join-Path $d "examples"
    $t = Join-Path $d "tests"
    SafeCopy (Join-Path $SourceDir      "SKILL.md")              $d
    SafeCopy (Join-Path $SourceRefs     "lenses.md")             $r
    SafeCopy (Join-Path $SourceRefs     "prompt-templates.md")   $r
    SafeCopy (Join-Path $SourceRefs     "agent-blueprint.md")    $r
    SafeCopy (Join-Path $SourceRefs     "examples.md")           $r
    SafeCopy (Join-Path $SourceRefs     "mythos-init.md")        $r
    SafeCopy (Join-Path $SourceExamples "README.md")             $e
    SafeCopy (Join-Path $SourceTests    "README.md")             $t
}

function Install-Protocol($claudeMdPath) {
    $block = @'

## Reasoning Protocol (Mythos v4 — Three-Mode Router)

Before responding to any non-trivial request:

1. **Assess complexity (1-5):**
   - **1:** respond directly. Zero overhead. Do NOT load any skill.
   - **2-5:** Read `.claude/skills/mythos/SKILL.md` and follow STEP 1–3. SKILL.md is the single
     source of mode routing — it will pick:
     - **silent mode** (complexity 2-3, default): Recurrent Block runs in your internal /
       extended-thinking reasoning; user sees only Coda.
     - **agent mode** (complexity 4-5, default): lenses dispatched as parallel subagents,
       then merged.
     - **trace mode** (only if user explicitly used `trace` keyword): visible token-level rounds.
     **Keep reasoning INTERNAL by default. Only emit visible rounds in trace mode.**

2. **Output expectations:**
   - silent (default): just the Answer + brief footer. No Prelude, no Rounds.
   - agent: Prelude + parallel subagent results + merge + Answer.
   - trace (opt-in): full Prelude + each Round + Answer.

3. **Mode keywords (parsed from user input, case-insensitive, last-wins):**
   - `trace` → force trace mode (visible rotation)
   - `deep` or `agent` → force agent mode (parallel fan-out) even at lower complexity
   - `quick` → force silent mode even at high complexity

4. **Gate:** Complexity = 1 returns directly without loading SKILL.md.
   If a lens application produces no new insight or introduces confusion (negative delta),
   halt the recurrence immediately and proceed to Coda.
'@
    if (Test-Path $claudeMdPath) {
        $existing = Get-Content $claudeMdPath -Raw
        if ($existing -match "Reasoning Protocol.*Mythos") {
            if ($existing -match "Mythos v2.*Silent Mode") {
                $updated = $existing -replace '(?s)## Reasoning Protocol \(Mythos v2.*?(?=\r?\n## |\Z)', $block.TrimEnd()
                Set-Content $claudeMdPath $updated
                return "upgraded"
            }
            return "skip"
        } else {
            Add-Content $claudeMdPath "`r`n$block"
            return "appended"
        }
    } else {
        Set-Content $claudeMdPath "# Project Rules`r`n`r`n$block"
        return "created"
    }
}

# ── Install ────────────────────────────────────────────────────

if ($InstallUser) {
    $userBase = $env:USERPROFILE
    Write-Host " $(t 'phase_user') $userBase" -ForegroundColor Cyan
    Install-SkillFiles $userBase
    $res = Install-Protocol (Join-Path $userBase ".claude\CLAUDE.md")
    $txt = switch ($res) {
        "created"  { t 'status_created' }
        "appended" { "$(t 'status_appended') CLAUDE.md" }
        "upgraded" { t 'status_upgraded' }
        "skip"     { t 'status_skip_exists' }
    }
    Write-Host " [OK] ~/.claude/ ${txt}" -ForegroundColor $(if ($res -eq "skip") { "Gray" } else { "Green" })
    Write-Host ""
}

if ($InstallProject -and $ProjectPath) {
    $ProjectPath = Resolve-Path $ProjectPath
    Write-Host " $(t 'phase_project') $ProjectPath" -ForegroundColor Cyan
    Install-SkillFiles $ProjectPath
    $res = Install-Protocol (Join-Path $ProjectPath "CLAUDE.md")
    $txt = switch ($res) {
        "created"  { "$(t 'status_created') CLAUDE.md" }
        "appended" { "$(t 'status_appended') CLAUDE.md" }
        "upgraded" { t 'status_upgraded' }
        "skip"     { t 'status_skip_exists' }
    }
    Write-Host " [OK] ${txt}" -ForegroundColor $(if ($res -eq "skip") { "Gray" } else { "Green" })
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  $(t 'status_done')" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  $(t 'usage_simple')" -ForegroundColor Gray
Write-Host "  $(t 'usage_complex')" -ForegroundColor Gray
Write-Host "  $(t 'usage_trace')" -ForegroundColor Gray
Write-Host ""
if ($InstallUser) {
    Write-Host "  $(t 'usage_user_ready')" -ForegroundColor Green
}
