# CLAUDE.md — mythos-skill

Project-level guidance. This repository is the development and distribution source for the **mythos** skill — a protocol that ports the Recurrent-Depth Transformer paradigm onto the Claude Code prompt layer. The repo itself runs no application code (only install / calibration scripts); every artifact is a markdown skill file.

## Project purpose

Implement and maintain the `mythos` skill: a Prelude → Recurrent Block → Coda protocol that behaviorally approximates the "latent-space recurrent-depth reasoning" hypothesis explored by OpenMythos (a community, **non-Anthropic-affiliated** speculation). The current version is **v4 Three-Mode Router** (silent / trace / agent); the most recent major rewrite landed in commit `1b0a9f9`.

Do not treat this repo as an ordinary application project — the "code" is a prompt protocol, the "tests" are manual calibrations, and "deployment" is copying the skill into other Claude Code projects.

## Repository layout

```
.claude/skills/mythos/        # the only shipping artifact
├── SKILL.md                  # main entry; all three-mode routing logic lives here
├── references/               # lazy-loaded references; SKILL.md Reads them at specific STEPs
│   ├── lenses.md             # 12 lenses + question-type → lens sequence + driver → lens weighting
│   ├── prompt-templates.md   # Prelude / per-round / Coda templates
│   ├── agent-blueprint.md    # parallel subagent dispatch + merge protocol
│   ├── examples.md           # annotated examples
│   └── mythos-init.md        # protocol snippet injected by the init script
└── scripts/
    ├── init.ps1 / init.sh    # install into another project or user-global ~/.claude/CLAUDE.md
    └── calibrate.ps1/.sh     # interactive 5-case calibration; emits a timestamped markdown report

papers/        research papers (gitignored, kept locally for reference)
research/      early-stage research scripts and scan results (gitignored)
docs/          design notes and integration reports (gitignored)
vibe/          launch / outreach drafts (gitignored)
README.md      user-facing docs
```

## Conventions for editing the mythos skill

### Lazy-load references is intentional

SKILL.md uses the pattern "Read references/Y.md at the start of STEP X." **Do not** preload them at the top of SKILL.md. This saves tokens on simple problems — the Prelude phase does not need agent-blueprint.md; that file is only read after routing to agent mode.

When editing, preserve this convention: a new reference file → add an explicit Read instruction at the matching STEP in SKILL.md. Do not add a "this skill also uses references/foo.md" preamble at the top of the document.

### Don't merge the three modes casually

Silent / Trace / Agent each map to a different property of the architectural hypothesis:

- **Silent** ≈ "no inter-layer token commitment" — reasoning runs in internal/extended-thinking; users see only the Coda
- **Agent** ≈ "parallel paths in latent space" — multiple lenses are dispatched as subagents **in parallel** (a single message containing multiple Agent tool calls), not sequentially
- **Trace** trades architectural fidelity for auditability; it's a teaching / debugging mode

Reject any temptation to "unify the modes" or "standardize the output format" — the three modes exist precisely because they map to three different Claude Code primitives. If a change makes the three modes' outputs converge, the change is wrong.

### Complexity scoring vs keyword priority

The interaction between complexity scoring (1–5) and keywords (`trace` / `deep` / `agent` / `quick`) in SKILL.md is easy to mis-implement. The rules:

1. Compute complexity first (sum of 5 one-point checks)
2. Then let keywords override **routing** (not the diagnostic scoring)
3. When multiple keywords appear, **last one wins**, and only the **leading bare word** of the slash-command argument is parsed

When modifying routing logic, preserve this ordering. If you see a PR that parses keywords before computing complexity, that's almost certainly a bug.

### Standard rotation is the baseline, not a hard rule

`Clarify → Deepen → Challenge → Expand → Synthesize` is the default rotation. The "question type → lens sequence" table in `lenses.md` is an **alternative**, used only when the standard rotation is clearly mismatched (e.g., contentious topics opening with Steelman). When you switch, write the reason on the Lens-sequence line of the Prelude. Never silently change the rotation — it breaks calibration comparability.

### Convergence detection has 5 criteria; none are optional

```
1. No delta (substantively identical to the previous round)
2. Trivial delta (the new insight is minor relative to early rounds)
3. Self-consistent (answer is coherent, assumptions surfaced, counters addressed)
4. Max rounds reached (Prelude budget exhausted)
5. Negative delta (over-thinking — the new insight degrades quality)
```

Criterion 5 is the linchpin against over-thinking. Don't delete it from SKILL.md just because "the model should think more." `A compact answer that converges in round 2 > a 5-round endurance display` is a core stance of the skill.

## Install scripts

`scripts/init.ps1` / `init.sh` install the skill into a target project or user-globally (`~/.claude/CLAUDE.md`). The two scripts must be edited together — the PowerShell and bash logic must stay equivalent. Supported flags:

```
--user              user-global (applies to all projects)
--project           project-local only
--both              install both
--lang zh|en|auto   message language; default `auto` follows locale
```

The protocol snippet injected into CLAUDE.md is read from `references/mythos-init.md` — **do not** hand-duplicate it in either init script. Single source of truth.

## Calibration

`scripts/calibrate.ps1` / `calibrate.sh` walks 5 calibration cases (SQLite vs Postgres / pivot or stay / cache strategy / code-review improvement / AI training-data ethics), interactively asking what lens path / round count / convergence behavior was observed, then runs structural checks and emits a report.

**Calibration is manual by design** — mythos reasoning quality cannot be verified purely programmatically; only structural properties can (lens completeness, round count within budget, parallel vs sequential dispatch). Run it after any SKILL.md change. A FAIL is a signal to re-read SKILL.md, not a test ground truth.

## Commit conventions

Recent commit style:

```
Update Mythos Reasoning Protocol to v4 with Three-Mode Router
Enhance Mythos reasoning framework with new calibration scripts and refined protocols
Refactor init scripts to enhance language support and improve user prompts
```

Concise verb + protocol name + concrete change. Avoid messages like "fix typo" — typos in this repo regularly alter routing behavior.

## User's global rules

The user's `~/.claude/CLAUDE.md` already references the mythos protocol ("Reasoning Protocol Mythos v4 — Three-Mode Router"). That means complex questions in **any** project trigger the protocol defined here. Changes to SKILL.md affect the user's entire workflow, not just this repo — assess impact before editing.

For experimental changes scoped to this repo, work on a branch first; merge to main and propagate to the user-global install via the init script only after the change is confirmed stable.
