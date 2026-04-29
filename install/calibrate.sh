#!/bin/bash
# Mythos Calibration Runner v4 (three-mode aware)
# Usage: bash calibrate.sh
#
# Walks through the 5 calibration cases × 2-3 modes, prompts the user to
# run /mythos against each in silent / trace / agent modes, captures observed
# behavior, performs structural checks, writes a timestamped report.
# Manual by design — quality of mythos reasoning cannot be programmatically
# verified, only structural properties.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d-%H%M")
REPORT="$SCRIPT_DIR/calibration-report-$TIMESTAMP.md"

# 5 cases. Index-aligned arrays.
IDS=("Q1" "Q2" "Q3" "Q4" "Q5")
QUESTIONS=(
    "Should I use SQLite or PostgreSQL for a single-user desktop app?"
    "Our startup has 3 months of runway and our product has good reviews but declining retention. Pivot or stay?"
    "Design a caching strategy for a read-heavy API serving 10M users"
    "What would make our code review process 10x more effective?"
    "Is it ethical to train AI on public web data without consent?"
)
COMPLEXITIES=(2 4 3 3 5)
# Modes per case (space-separated)
MODES_PER_CASE=(
    "silent trace"
    "silent trace agent"
    "silent trace"
    "silent trace"
    "silent trace agent"
)
# Trace-mode lens requirements (comma-separated)
TRACE_REQUIRED_LENSES=(
    "Challenge"
    "Expand,Scar-Tissue"
    "Edge-Hunt"
    "Challenge"
    "Steelman"
)
TRACE_ROUNDS_MIN=(2 4 3 3 4)
TRACE_ROUNDS_MAX=(3 5 4 4 6)
# Agent-mode required lenses
AGENT_REQUIRED_LENSES=(
    ""
    "Tradeoff-Map"
    ""
    ""
    "Steelman,Tradeoff-Map"
)
AGENT_MIN_SUBAGENTS=(0 4 0 0 4)
# Silent-mode answer keywords (semicolon-separated)
SILENT_ANSWER_KEYWORDS=(
    "concurrent;framing"
    "alternative;pivot;stay"
    "stampede;expiry;cold"
    "bottleneck;framing;quality"
    "tension;indeterminate"
)

PASS=0
FAIL=0
TOTAL=0

cat > "$REPORT" <<EOF
# Mythos Calibration Report (v4)

Generated: $(date "+%Y-%m-%d %H:%M")

## Cases × Modes
EOF

echo "============================================"
echo "  Mythos Calibration Runner v4 (three-mode)"
echo "============================================"
echo ""
echo "  This walks through 5 cases across silent / trace / agent modes."
echo "  For each (case, mode), run the question via /mythos in your CC"
echo "  session, then return here to record observations."
echo ""

for i in "${!IDS[@]}"; do
    id="${IDS[$i]}"
    q="${QUESTIONS[$i]}"
    cx="${COMPLEXITIES[$i]}"
    modes="${MODES_PER_CASE[$i]}"

    echo ""
    echo "===== Case $id (complexity $cx/5) ====="
    echo "Question: $q"

    for mode in $modes; do
        echo ""
        echo "----- $id / $mode mode -----"
        case "$mode" in
            silent) invocation="/mythos $q" ;;
            trace)  invocation="/mythos trace $q" ;;
            agent)  invocation="/mythos deep $q" ;;
        esac

        echo "  Invocation: $invocation"
        echo ""
        read -p "  Press ENTER when the run is complete..." _

        case_checks=""

        if [ "$mode" = "silent" ]; then
            read -p "  Did silent mode incorrectly emit visible Round headers? [y/n]: " emitted
            if [[ "$emitted" =~ ^[Yy] ]]; then
                case_checks+="- [FAIL] silent mode emitted visible rounds — mode routing broken"$'\n'
                FAIL=$((FAIL+1))
                echo "    [FAIL] silent emitted rounds"
            else
                case_checks+="- [PASS] silent mode produced no visible rounds"$'\n'
                PASS=$((PASS+1))
                echo "    [PASS] no visible rounds"
            fi
            TOTAL=$((TOTAL+1))

            read -p "  Paste a sentence from the Answer that captures the key insight: " answer

            keywords="${SILENT_ANSWER_KEYWORDS[$i]}"
            IFS=';' read -ra KWS <<< "$keywords"
            for kw in "${KWS[@]}"; do
                kw_trim=$(echo "$kw" | sed 's/^ *//;s/ *$//')
                if echo "$answer" | grep -qi "$kw_trim"; then
                    case_checks+="- [PASS] answer mentions '$kw_trim'"$'\n'
                    PASS=$((PASS+1))
                    echo "    [PASS] mentions '$kw_trim'"
                else
                    case_checks+="- [FAIL] answer missing '$kw_trim'"$'\n'
                    FAIL=$((FAIL+1))
                    echo "    [FAIL] missing '$kw_trim'"
                fi
                TOTAL=$((TOTAL+1))
            done

        elif [ "$mode" = "trace" ]; then
            read -p "  Observed total visible rounds: " rounds
            read -p "  Lenses applied (comma-separated): " lenses
            rmin="${TRACE_ROUNDS_MIN[$i]}"
            rmax="${TRACE_ROUNDS_MAX[$i]}"

            if [[ "$rounds" =~ ^[0-9]+$ ]] && [ "$rounds" -ge "$rmin" ] && [ "$rounds" -le "$rmax" ]; then
                case_checks+="- [PASS] round count $rounds in $rmin-$rmax"$'\n'
                PASS=$((PASS+1))
                echo "    [PASS] rounds $rounds in $rmin-$rmax"
            else
                case_checks+="- [FAIL] round count $rounds outside expected $rmin-$rmax"$'\n'
                FAIL=$((FAIL+1))
                echo "    [FAIL] rounds $rounds outside $rmin-$rmax"
            fi
            TOTAL=$((TOTAL+1))

            req="${TRACE_REQUIRED_LENSES[$i]}"
            IFS=',' read -ra REQS <<< "$req"
            for r in "${REQS[@]}"; do
                rt=$(echo "$r" | sed 's/^ *//;s/ *$//')
                if echo "$lenses" | grep -qi "$rt"; then
                    case_checks+="- [PASS] $rt lens applied"$'\n'
                    PASS=$((PASS+1))
                    echo "    [PASS] $rt lens applied"
                else
                    case_checks+="- [FAIL] $rt lens MISSING"$'\n'
                    FAIL=$((FAIL+1))
                    echo "    [FAIL] $rt lens missing"
                fi
                TOTAL=$((TOTAL+1))
            done

        elif [ "$mode" = "agent" ]; then
            read -p "  Number of parallel subagents dispatched: " subs
            read -p "  Were subagents dispatched sequentially (one tool call after another)? [y/n]: " seq
            read -p "  Did the merge phase preserve tension between subagents? [y/n]: " tension
            read -p "  Lenses dispatched (comma-separated): " lenses

            min_sub="${AGENT_MIN_SUBAGENTS[$i]}"
            if [[ "$subs" =~ ^[0-9]+$ ]] && [ "$subs" -ge "$min_sub" ]; then
                case_checks+="- [PASS] subagent count $subs >= $min_sub"$'\n'
                PASS=$((PASS+1))
                echo "    [PASS] subagents $subs >= $min_sub"
            else
                case_checks+="- [FAIL] subagent count $subs < expected $min_sub"$'\n'
                FAIL=$((FAIL+1))
                echo "    [FAIL] subagents $subs < $min_sub"
            fi
            TOTAL=$((TOTAL+1))

            if [[ "$seq" =~ ^[Yy] ]]; then
                case_checks+="- [FAIL] subagents dispatched sequentially — read agent-blueprint.md"$'\n'
                FAIL=$((FAIL+1))
                echo "    [FAIL] sequential dispatch"
            else
                case_checks+="- [PASS] subagents dispatched in parallel"$'\n'
                PASS=$((PASS+1))
                echo "    [PASS] parallel dispatch"
            fi
            TOTAL=$((TOTAL+1))

            req="${AGENT_REQUIRED_LENSES[$i]}"
            if [ -n "$req" ]; then
                IFS=',' read -ra REQS <<< "$req"
                for r in "${REQS[@]}"; do
                    rt=$(echo "$r" | sed 's/^ *//;s/ *$//')
                    if echo "$lenses" | grep -qi "$rt"; then
                        case_checks+="- [PASS] $rt lens dispatched"$'\n'
                        PASS=$((PASS+1))
                        echo "    [PASS] $rt dispatched"
                    else
                        case_checks+="- [FAIL] $rt lens NOT dispatched"$'\n'
                        FAIL=$((FAIL+1))
                        echo "    [FAIL] $rt missing"
                    fi
                    TOTAL=$((TOTAL+1))
                done
            fi

            if [[ "$tension" =~ ^[Yy] ]]; then
                case_checks+="- [PASS] merge preserved tension"$'\n'
                PASS=$((PASS+1))
                echo "    [PASS] tension preserved"
            else
                case_checks+="- [FAIL] merge collapsed to false consensus"$'\n'
                FAIL=$((FAIL+1))
                echo "    [FAIL] false consensus"
            fi
            TOTAL=$((TOTAL+1))
        fi

        read -p "  Anything notable: " notes

        cat >> "$REPORT" <<EOF

### $id — $mode
**Invocation:** \`$invocation\`

**Checks:**
$case_checks
EOF
        [ -n "$notes" ] && echo "**Notes:** $notes" >> "$REPORT"
    done
done

cat >> "$REPORT" <<EOF

## Summary

- Total checks: $TOTAL
- PASS: $PASS
- FAIL: $FAIL

If FAIL count > 0, mode routing or lens application is degraded.
- silent emitted visible rounds → mode routing broken; re-read SKILL.md
- agent dispatched sequentially → read agent-blueprint.md (parallel is the point)
- expected lens missing → standard rotation not followed; check Prelude diagnosis
- merge collapsed to consensus → false-compromise antipattern; preserve genuine tensions
EOF

echo ""
echo "============================================"
echo "  Calibration complete"
echo "============================================"
echo "  Report: $REPORT"
echo "  PASS: $PASS / $TOTAL  FAIL: $FAIL"
echo ""
