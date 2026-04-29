#!/bin/bash
# Mythos Init v3 — Install silent reasoning protocol into new projects
# Usage: bash init.sh [project-path] [--global] [--both] [--lang zh|en]
# Examples:
#   bash init.sh ~/Work/MyGame              (project only)
#   bash init.sh --global                   (user-level, all projects)
#   bash init.sh ~/Work/MyGame --both       (project + user)
#   bash init.sh --global --lang zh         (force Chinese)
set -e

# ── Language ──────────────────────────────────────────────────

LANG_PARAM="auto"
INSTALL_GLOBAL=false
INSTALL_LOCAL=false
PROJECT_PATH=""

for arg in "$@"; do
    case "$arg" in
        --global) INSTALL_GLOBAL=true ;;
        --both)   INSTALL_GLOBAL=true; INSTALL_LOCAL=true ;;
        --lang)   LANG_PARAM="next" ;;
        *)  if [ "$LANG_PARAM" = "next" ]; then
                LANG_PARAM="$arg"
            elif [ "$arg" != "--lang" ]; then
                PROJECT_PATH="$arg"
            fi ;;
    esac
done

if [ "$LANG_PARAM" = "auto" ] || [ "$LANG_PARAM" = "next" ]; then
    case "${LANG:-${LC_ALL:-${LC_MESSAGES:-en}}}" in
        zh_*|zh-*) LANG_PARAM="zh" ;;
        *)         LANG_PARAM="en" ;;
    esac
fi

# Message table
msg() {
    case "$1" in
        banner_title)   [ "$LANG_PARAM" = "zh" ] && echo "Mythos v3 — 静默推理路由器" || echo "Mythos v3 — Silent Router" ;;
        phase_global)   [ "$LANG_PARAM" = "zh" ] && echo "[用户级]" || echo "[User-level]" ;;
        phase_local)    [ "$LANG_PARAM" = "zh" ] && echo "[项目级]" || echo "[Project]" ;;
        status_skill_ok)    [ "$LANG_PARAM" = "zh" ] && echo "mythos skill 文件已安装" || echo "mythos skill files installed" ;;
        status_dir_ready)   [ "$LANG_PARAM" = "zh" ] && echo ".claude/skills/mythos/ 目录已就绪" || echo ".claude/skills/mythos/ directory ready" ;;
        status_skip_self)   [ "$LANG_PARAM" = "zh" ] && echo "跳过自复制" || echo "skip self-copy" ;;
        status_created)     [ "$LANG_PARAM" = "zh" ] && echo "已创建 CLAUDE.md" || echo "CLAUDE.md created" ;;
        status_appended)    [ "$LANG_PARAM" = "zh" ] && echo "推理协议已追加到 CLAUDE.md" || echo "protocol appended to CLAUDE.md" ;;
        status_upgraded)    [ "$LANG_PARAM" = "zh" ] && echo "v2 协议已升级到 v3 (router)" || echo "v2 protocol upgraded to v3 (router)" ;;
        status_skip_exists) [ "$LANG_PARAM" = "zh" ] && echo "v3 协议已存在，跳过" || echo "v3 protocol exists, skipped" ;;
        status_done)        [ "$LANG_PARAM" = "zh" ] && echo "完成！" || echo "Done!" ;;
        usage_simple)       [ "$LANG_PARAM" = "zh" ] && echo "简单问题 → 直接回答，零开销" || echo "Simple questions → direct answer, zero overhead" ;;
        usage_complex)      [ "$LANG_PARAM" = "zh" ] && echo "复杂问题 → 静默加载 SKILL.md，完整 v3 推理" || echo "Complex questions → silently load SKILL.md, full v3 reasoning" ;;
        usage_trace)        [ "$LANG_PARAM" = "zh" ] && echo "/mythos 或 think aloud → 显示完整推理 trace" || echo "/mythos or think aloud → show full reasoning trace" ;;
        usage_global_ready) [ "$LANG_PARAM" = "zh" ] && echo "用户级安装已就绪——所有项目自动生效。" || echo "User-level install ready — all projects active." ;;
        err_no_target)      [ "$LANG_PARAM" = "zh" ] && echo "未指定安装目标。用 --global 或传项目路径。" || echo "No install target. Use --global or pass a project path." ;;
    esac
}

# ── Resolve targets ───────────────────────────────────────────

if [ -z "$PROJECT_PATH" ] && ! $INSTALL_GLOBAL; then
    if [ -d ".claude" ] || [ -d "src" ]; then
        PROJECT_PATH="$(pwd)"
        INSTALL_LOCAL=true
    fi
fi
[ -n "$PROJECT_PATH" ] && ! $INSTALL_GLOBAL && ! $INSTALL_LOCAL && INSTALL_LOCAL=true
! $INSTALL_GLOBAL && ! $INSTALL_LOCAL && INSTALL_GLOBAL=true

if ! $INSTALL_GLOBAL && ! $INSTALL_LOCAL; then
    echo "[!] $(msg err_no_target)"
    exit 1
fi

# ── Helpers ────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_REFS="$SOURCE_DIR/references"

safe_copy() {
    local src="$1" dstdir="$2" fname dst src_abs
    fname="$(basename "$src")"
    dst="$dstdir/$fname"
    mkdir -p "$dstdir"
    src_abs="$(cd "$(dirname "$src")" 2>/dev/null && pwd)/$(basename "$src")"
    if [ -f "$dst" ]; then
        local dst_abs
        dst_abs="$(cd "$(dirname "$dst")" 2>/dev/null && pwd)/$(basename "$dst")" 2>/dev/null || true
        if [ "$src_abs" = "$dst_abs" ]; then
            echo "   [..] $(msg status_skip_self): $fname"
            return
        fi
    fi
    cp "$src" "$dst"
}

install_skill_files() {
    local base="$1" skills_dir refs_dir scripts_dir
    skills_dir="$base/.claude/skills/mythos"
    refs_dir="$skills_dir/references"
    scripts_dir="$skills_dir/scripts"
    safe_copy "$SOURCE_DIR/SKILL.md"              "$skills_dir"
    safe_copy "$SOURCE_REFS/lenses.md"            "$refs_dir"
    safe_copy "$SOURCE_REFS/prompt-templates.md"  "$refs_dir"
    safe_copy "$SOURCE_REFS/agent-blueprint.md"   "$refs_dir"
    safe_copy "$SOURCE_REFS/examples.md"          "$refs_dir"
    safe_copy "$SOURCE_REFS/mythos-init.md"       "$refs_dir"
    safe_copy "$SCRIPT_DIR/calibrate.ps1"         "$scripts_dir"
    safe_copy "$SCRIPT_DIR/calibrate.sh"          "$scripts_dir"
}

install_protocol() {
    local claude_md="$1"
    local block='## Reasoning Protocol (Mythos v4 — Three-Mode Router)

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
   halt the recurrence immediately and proceed to Coda.'

    if [ -f "$claude_md" ]; then
        if grep -q "Mythos v2.*Silent Mode" "$claude_md" 2>/dev/null; then
            perl -i -0pe "s/## Reasoning Protocol.*?(?=\n## |\n\Z)/${block//\//\\/}/s" "$claude_md" 2>/dev/null || {
                sed -i.bak '/## Reasoning Protocol (Mythos v2/,/^$/d' "$claude_md"
                printf '\n%s\n' "$block" >> "$claude_md"
            }
            echo "upgraded"
        elif grep -q "Reasoning Protocol.*Mythos" "$claude_md" 2>/dev/null; then
            echo "skip"
        else
            printf '\n%s\n' "$block" >> "$claude_md"
            echo "appended"
        fi
    else
        printf '# Project Rules\n\n%s\n' "$block" > "$claude_md"
        echo "created"
    fi
}

# ── Install ────────────────────────────────────────────────────

echo "============================================"
echo "  $(msg banner_title)"
echo "============================================"
echo ""

if $INSTALL_GLOBAL; then
    echo " $(msg phase_global) $HOME"
    install_skill_files "$HOME"
    res=$(install_protocol "$HOME/.claude/CLAUDE.md")
    case "$res" in
        created)  echo " [OK] ~/.claude/ $(msg status_created)" ;;
        appended) echo " [OK] ~/.claude/ $(msg status_appended)" ;;
        upgraded) echo " [OK] ~/.claude/ $(msg status_upgraded)" ;;
        skip)     echo " [..] ~/.claude/ $(msg status_skip_exists)" ;;
    esac
    echo ""
fi

if $INSTALL_LOCAL && [ -n "$PROJECT_PATH" ]; then
    PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
    echo " $(msg phase_local) $PROJECT_PATH"
    install_skill_files "$PROJECT_PATH"
    res=$(install_protocol "$PROJECT_PATH/CLAUDE.md")
    case "$res" in
        created)  echo " [OK] $(msg status_created)" ;;
        appended) echo " [OK] $(msg status_appended)" ;;
        upgraded) echo " [OK] $(msg status_upgraded)" ;;
        skip)     echo " [..] $(msg status_skip_exists)" ;;
    esac
    echo ""
fi

echo "============================================"
echo "  $(msg status_done)"
echo "============================================"
echo ""
echo "  $(msg usage_simple)"
echo "  $(msg usage_complex)"
echo "  $(msg usage_trace)"
echo ""
if $INSTALL_GLOBAL; then
    echo "  $(msg usage_global_ready)"
fi
