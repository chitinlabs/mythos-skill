# Mythos Calibration Runner (v4 — three-mode aware)
# Usage: .\calibrate.ps1
#
# Walks through the 5 calibration cases from SKILL.md, prompts the user to
# run /mythos against each in BOTH silent and trace modes (and agent for
# high-complexity cases), then captures observed behavior and compares it
# to mode-specific expected baselines. Manual by design — quality of mythos
# reasoning cannot be programmatically verified, only structural properties.
#
# Output: writes calibration-report-YYYYMMDD-HHMM.md next to itself (install/).

$ErrorActionPreference = "Stop"

# Cases. Each defines what to expect under each mode.
$cases = @(
    @{
        id = "Q1"
        question = "Should I use SQLite or PostgreSQL for a single-user desktop app?"
        complexity = 2
        modes_to_test = @("silent", "trace")
        expected_silent = @{
            answer_must_mention = @("concurrent", "framing")
            footer_lens_count_max = 3
            mechanism = "Complexity gate; should NOT escalate to agent"
        }
        expected_trace = @{
            rounds_min = 2; rounds_max = 3
            must_trigger = @("Challenge")
            mechanism = "Visible early convergence on Challenge of framing"
        }
    },
    @{
        id = "Q2"
        question = "Our startup has 3 months of runway and our product has good reviews but declining retention. Pivot or stay?"
        complexity = 4
        modes_to_test = @("silent", "trace", "agent")
        expected_silent = @{
            answer_must_mention = @("alternative", "pivot", "stay")
            footer_lens_count_min = 4
            mechanism = "Should produce ≥2 distinct alternatives in answer"
        }
        expected_trace = @{
            rounds_min = 4; rounds_max = 5
            must_trigger = @("Expand", "Scar-Tissue")
            mechanism = "Adaptive budget: Trade-offs driver promotes Expand to ×2"
        }
        expected_agent = @{
            subagent_count_min = 4
            must_include_lenses = @("Tradeoff-Map")
            merge_must_show_tension = $true
            mechanism = "Parallel divergence between pivot/stay positions"
        }
    },
    @{
        id = "Q3"
        question = "Design a caching strategy for a read-heavy API serving 10M users"
        complexity = 3
        modes_to_test = @("silent", "trace")
        expected_silent = @{
            answer_must_mention = @("stampede", "expiry", "cold")
            footer_lens_count_max = 4
            mechanism = "Edge case must surface in answer despite no visible Edge-Hunt round"
        }
        expected_trace = @{
            rounds_min = 3; rounds_max = 4
            must_trigger = @("Edge-Hunt")
            mechanism = "Specialized lens; overthinking detection prevents 6+ rounds"
        }
    },
    @{
        id = "Q4"
        question = "What would make our code review process 10x more effective?"
        complexity = 3
        modes_to_test = @("silent", "trace")
        expected_silent = @{
            answer_must_mention = @("bottleneck", "framing", "quality")
            footer_lens_count_max = 4
            mechanism = "Challenge of framing must reach answer"
        }
        expected_trace = @{
            rounds_min = 3; rounds_max = 4
            must_trigger = @("Challenge")
            mechanism = "Cross-round attention: Challenge insight visible in Synthesize"
        }
    },
    @{
        id = "Q5"
        question = "Is it ethical to train AI on public web data without consent?"
        complexity = 5
        modes_to_test = @("silent", "trace", "agent")
        expected_silent = @{
            answer_must_mention = @("tension", "indeterminate", "framework")
            answer_must_NOT_mention = @("clear answer", "obviously")
            mechanism = "Must preserve genuine tensions, no false compromise"
        }
        expected_trace = @{
            rounds_min = 4; rounds_max = 6
            must_trigger = @("Steelman")
            mechanism = "Steelman builds strongest case for BOTH sides"
        }
        expected_agent = @{
            subagent_count_min = 4
            must_include_lenses = @("Steelman", "Tradeoff-Map")
            merge_must_show_tension = $true
            merge_must_NOT_collapse_to_compromise = $true
            mechanism = "Pro/Anti subagents must independently develop; merge preserves tension"
        }
    }
)

function ReadTrim($prompt) {
    $v = Read-Host $prompt
    if ($null -eq $v) { return "" }
    return $v.Trim()
}

function ReadInt($prompt) {
    $v = Read-Host $prompt
    try { return [int]$v } catch { return 0 }
}

function ReadYN($prompt) {
    $v = Read-Host "$prompt [y/n]"
    return $v -match '^[Yy]'
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Mythos Calibration Runner v4 (three-mode)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This walks through 5 cases across silent / trace / agent modes" -ForegroundColor Gray
Write-Host "  (depending on each case's complexity). For each (case, mode)" -ForegroundColor Gray
Write-Host "  pair, run the question via /mythos in your CC session, then" -ForegroundColor Gray
Write-Host "  return here to record what you observed." -ForegroundColor Gray
Write-Host ""

$results = @()
$totalChecks = 0
$passCount = 0

foreach ($c in $cases) {
    Write-Host ""
    Write-Host "===== Case $($c.id) (complexity $($c.complexity)/5) =====" -ForegroundColor Yellow
    Write-Host "Question:" -ForegroundColor White
    Write-Host "  $($c.question)" -ForegroundColor Gray

    foreach ($mode in $c.modes_to_test) {
        Write-Host ""
        Write-Host "----- $($c.id) / $mode mode -----" -ForegroundColor Cyan

        $invocation = switch ($mode) {
            "silent" { "/mythos $($c.question)" }
            "trace"  { "/mythos trace $($c.question)" }
            "agent"  { "/mythos deep $($c.question)" }
        }
        $expected = switch ($mode) {
            "silent" { $c.expected_silent }
            "trace"  { $c.expected_trace }
            "agent"  { $c.expected_agent }
        }

        Write-Host ""
        Write-Host "  Invocation:" -ForegroundColor White
        Write-Host "    $invocation" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Expected ($mode):" -ForegroundColor White
        $expected.GetEnumerator() | ForEach-Object {
            Write-Host "    $($_.Key) = $($_.Value)" -ForegroundColor Gray
        }
        Write-Host ""
        Read-Host "  Press ENTER when the run is complete"

        $caseChecks = @()

        if ($mode -eq "silent") {
            $answer = ReadTrim "  Paste a sentence from the Answer that captures the key insight"
            $lensCountStr = ReadTrim "  Footer's lens path count (e.g. 'Clarify→Deepen→Challenge' = 3)"
            $lensCount = 0
            try { $lensCount = [int]$lensCountStr } catch { $lensCount = 0 }
            $emittedRounds = ReadYN "  Did silent mode incorrectly emit visible Round headers?"

            if ($emittedRounds) {
                $caseChecks += "[FAIL] silent mode emitted visible rounds — mode routing broken"
            } else {
                $caseChecks += "[PASS] silent mode produced no visible rounds"
                $passCount++
            }
            $totalChecks++

            if ($expected.ContainsKey("footer_lens_count_max") -and $lensCount -gt 0) {
                if ($lensCount -le $expected.footer_lens_count_max) {
                    $caseChecks += "[PASS] lens count $lensCount within ≤$($expected.footer_lens_count_max)"
                    $passCount++
                } else {
                    $caseChecks += "[FAIL] lens count $lensCount exceeds expected max $($expected.footer_lens_count_max) (overthinking)"
                }
                $totalChecks++
            }

            if ($expected.ContainsKey("answer_must_mention")) {
                foreach ($kw in $expected.answer_must_mention) {
                    if ($answer -match $kw) {
                        $caseChecks += "[PASS] answer mentions '$kw'"
                        $passCount++
                    } else {
                        $caseChecks += "[FAIL] answer missing expected '$kw'"
                    }
                    $totalChecks++
                }
            }
        } elseif ($mode -eq "trace") {
            $rounds = ReadInt "  Observed total visible rounds"
            $lensesStr = ReadTrim "  Lenses applied (comma-separated, e.g. Clarify,Deepen,Challenge)"
            $lenses = $lensesStr -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

            if ($rounds -ge $expected.rounds_min -and $rounds -le $expected.rounds_max) {
                $caseChecks += "[PASS] round count $rounds in expected $($expected.rounds_min)-$($expected.rounds_max)"
                $passCount++
            } else {
                $caseChecks += "[FAIL] round count $rounds outside expected $($expected.rounds_min)-$($expected.rounds_max)"
            }
            $totalChecks++

            foreach ($req in $expected.must_trigger) {
                if ($lenses -contains $req) {
                    $caseChecks += "[PASS] $req lens applied"
                    $passCount++
                } else {
                    $caseChecks += "[FAIL] $req lens MISSING"
                }
                $totalChecks++
            }
        } elseif ($mode -eq "agent") {
            $subagents = ReadInt "  Number of parallel subagents dispatched"
            $sequentialDispatch = ReadYN "  Were subagents dispatched sequentially (one tool call after the next), not in a single message?"
            $tensionPreserved = ReadYN "  Did the merge phase preserve tension between subagents (vs collapsing to consensus/false-compromise)?"
            $lensesStr = ReadTrim "  Lenses dispatched (comma-separated)"
            $lenses = $lensesStr -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

            if ($subagents -ge $expected.subagent_count_min) {
                $caseChecks += "[PASS] subagent count $subagents ≥ $($expected.subagent_count_min)"
                $passCount++
            } else {
                $caseChecks += "[FAIL] subagent count $subagents below expected $($expected.subagent_count_min)"
            }
            $totalChecks++

            if ($sequentialDispatch) {
                $caseChecks += "[FAIL] subagents dispatched sequentially — read agent-blueprint.md for parallel pattern"
            } else {
                $caseChecks += "[PASS] subagents dispatched in parallel"
                $passCount++
            }
            $totalChecks++

            foreach ($req in $expected.must_include_lenses) {
                if ($lenses -contains $req) {
                    $caseChecks += "[PASS] $req lens dispatched"
                    $passCount++
                } else {
                    $caseChecks += "[FAIL] $req lens NOT dispatched"
                }
                $totalChecks++
            }

            if ($expected.ContainsKey("merge_must_show_tension")) {
                if ($tensionPreserved) {
                    $caseChecks += "[PASS] merge preserved tension"
                    $passCount++
                } else {
                    $caseChecks += "[FAIL] merge collapsed to false consensus"
                }
                $totalChecks++
            }
        }

        $notes = ReadTrim "  Anything notable about this run"

        $results += [pscustomobject]@{
            Id = $c.id; Mode = $mode; Invocation = $invocation;
            Checks = $caseChecks; Notes = $notes
        }

        Write-Host ""
        foreach ($chk in $caseChecks) {
            $color = if ($chk.StartsWith("[PASS]")) { "Green" } else { "Red" }
            Write-Host "    $chk" -ForegroundColor $color
        }
    }
}

# Report
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$reportPath = Join-Path $PSScriptRoot "calibration-report-$timestamp.md"

$report = @"
# Mythos Calibration Report (v4)

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm")

## Cases × Modes
"@

foreach ($r in $results) {
    $report += @"

### $($r.Id) — $($r.Mode)
**Invocation:** ``$($r.Invocation)``

**Checks:**
"@
    foreach ($chk in $r.Checks) { $report += "`n- $chk" }
    if ($r.Notes) { $report += "`n`n**Notes:** $($r.Notes)" }
    $report += "`n"
}

$failCount = $totalChecks - $passCount
$report += @"

## Summary

- Total checks: $totalChecks
- PASS: $passCount
- FAIL: $failCount

If FAIL count > 0, mode routing or lens application is degraded.
- silent emitted visible rounds → mode routing broken; re-read SKILL.md
- agent dispatched sequentially → read agent-blueprint.md (parallel is the point)
- expected lens missing → standard rotation not followed; check Prelude diagnosis
- merge collapsed to consensus → false-compromise antipattern; preserve genuine tensions
"@

Set-Content -Path $reportPath -Value $report -Encoding UTF8

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Calibration complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Report: $reportPath" -ForegroundColor Green
Write-Host "  PASS: $passCount / $totalChecks  FAIL: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Yellow" } else { "Green" })
Write-Host ""
