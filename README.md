# mythos-skill

> English · [中文](./README_CN.md)

A prompt-layer protocol that approximates the Recurrent-Depth Transformer paradigm explored by OpenMythos, applied inside Claude Code to simulate latent-space reasoning through structured iteration.

## What is this

[OpenMythos](https://github.com/kyegomez/OpenMythos) is a community-built, **speculative** open-source project inspired by public discussion of recurrent-depth Transformer architectures. It is **not affiliated with or endorsed by Anthropic**, and makes no verified claim about how any production Claude model actually works. The hypothesis it explores: a Transformer that runs the same weight block multiple times to perform "silent deep thinking," with reasoning happening in a continuous latent space and no intermediate tokens emitted between iterations.

**mythos-skill** takes that hypothesis and maps it onto Claude Code at the prompt layer: a structured **Prelude → Recurrent Block → Coda** protocol that approximates latent reasoning behaviorally — not architecturally — through deliberate prompt design. Each iteration re-injects the original question (`e`-injection) to prevent drift, and routes to one of three execution modes based on problem complexity.

## What this is NOT

To set expectations clearly:

- **Not an Anthropic product**, and not affiliated with Anthropic in any way.
- **Not reverse-engineered** from any production model. Nobody here has inside knowledge of Claude's actual architecture.
- **Not an architectural claim.** This is structured prompting — a discipline imposed at the input layer. The "recurrent depth" framing is a metaphor borrowed from a community hypothesis to organize the protocol, not a description of what the model is doing internally.
- **Not benchmarked** against vanilla chain-of-thought or other reasoning frameworks. Quality is judged manually via the calibration cases; we have no rigorous evals showing it beats simpler approaches on a fixed task set.
- **Not magic.** On simple questions it adds overhead — that's why "Direct" mode exists for complexity-1 questions and skips the protocol entirely.

## Installation

The skill ships at `.claude/skills/mythos/` and is auto-discovered by Claude Code. No extra steps if you cloned this repo and work inside it.

To install into another project or user-globally (applies to every project), run the init script:

```bash
# Windows (PowerShell)
install/init.ps1 --user           # user-global (all projects)
install/init.ps1 D:\Work\MyGame   # specific project
install/init.ps1 --both           # install both

# macOS / Linux
bash install/init.sh --user
bash install/init.sh /path/to/project
```

> **What the install scripts modify:** They copy the skill files (SKILL.md, references/, examples/, tests/) into `~/.claude/skills/mythos/` (user-global) or `<project>/.claude/skills/mythos/` (project-local), then **append a "Reasoning Protocol" block to your `CLAUDE.md`** at the same scope. That protocol block changes how Claude routes complex questions. The install scripts are not part of the marketplace skill package — they only ship in this repo, for direct-clone users who want one-command setup.

Or just copy the directory:

```bash
cp -r .claude/skills/mythos /path/to/other-project/.claude/skills/
```

## Usage

### Basic

```
/mythos <your question>
```

**Examples:**

```
/mythos Should our strategy game use event sourcing or traditional CRUD for save data?
/mythos Why is our 82%-positive game seeing DAU drop from 5000 to 800?
/mythos Compare three engine paths: in-house, Godot, Unity
```

### Three-mode routing (v4)

The skill picks an execution mode automatically from a 1–5 complexity score:

| Mode | Default trigger | What the user sees | Notes |
|---|---|---|---|
| **Direct** | Complexity 1 | Direct answer | Zero overhead, skips Recurrent Block |
| **Silent** (default) | Complexity 2–3 | Coda only (answer + one-line trace note) | Reasoning runs in internal/extended-thinking; no inter-token commitment |
| **Trace** | `trace` keyword | Prelude + per-round insight chain + Answer | Auditable; for teaching/debugging/deep analysis |
| **Agent** | Complexity 4–5 | Prelude + parallel subagent results + merge + Answer | Multiple lenses dispatched **in parallel** as independent subagents, then merged |

**Complexity scoring (1 point each):** multi-hop dependency, ambiguous tradeoff, hidden assumptions, novel domain, high-stakes decision.

### Mode keywords (override default routing)

```
/mythos trace Should we adopt Conventional Commits?           # force Trace (visible rounds)
/mythos deep Should we rewrite the render pipeline?           # force Agent (parallel fan-out)
/mythos agent Evaluate this architecture                      # alias for deep
/mythos quick Is this variable name good?                     # force Silent (even if complex)
```

Keywords are case-insensitive. When multiple keywords appear, **last one wins**, and only the leading bare word in the slash-command argument is parsed.

### Auto-trigger

The skill activates automatically when the question matches:

- Multi-layered reasoning or hierarchical problems
- Design tradeoffs or architectural decisions
- Strategic analysis requiring multiple perspectives
- Problems that need to surface and challenge hidden assumptions

## How it works

```
[Your question]
     ↓
[PRELUDE]        Comprehend, decompose, score complexity, identify primary drivers, allocate per-lens budget
     ↓
[RECURRENT × N]  One of three execution paths
  silent: Lens rotation runs in internal reasoning, no per-round emission
  trace:  Lens rotation emits visible rounds with cross-round insight chain
  agent:  Lenses dispatched as N parallel subagents that explore independently, then merge
     ↓
[CODA]           Cross-validation, residual-uncertainty flags, mode-specific output formatting
```

### Reasoning lenses

Each round applies a specific analytical lens, simulating the loop-index embedding of Mythos:

| Round | Lens | Core question |
|---|---|---|
| 1 | **Clarify** | What's the actual question? Disambiguate, define terms |
| 2 | **Deepen** | What's one layer below? Root cause, first principles |
| 3 | **Challenge** | What assumptions am I making? What's the strongest counter? |
| 4 | **Expand** | What alternatives exist? How would experts in other fields see this? |
| 5 | **Synthesize** | How do all perspectives integrate into one coherent answer? |

Specialized lenses: System-Think, Edge-Hunt, Tradeoff-Map, Invert, Scar-Tissue, First-Principles, Steelman.

### Adaptive budget allocation

Prelude identifies 1–3 **primary complexity drivers**; the matching lenses get a 2× budget:

| Primary driver | Doubled lenses |
|---|---|
| Ambiguity | Clarify |
| Hidden assumptions | Challenge, Steelman |
| Multi-hop reasoning | Deepen, System-Think |
| Tradeoff | Tradeoff-Map, Expand |
| Novel domain | First-Principles, Expand |
| System dynamics | System-Think, Edge-Hunt |

Total rounds: silent/trace typically 4–8 rounds; agent mode dispatches 3–5 parallel subagents.

### Key mechanisms

- **Original-context injection (`e`-injection):** Re-read your original question at the start of every round — the core mechanism in the Mythos architecture for preventing reasoning drift
- **Convergence detection:** 5 strict criteria (no delta / trivial delta / self-consistent / max rounds reached / negative delta = over-thinking)
- **Mid-flight mode upgrade:** One re-Prelude per session is allowed; if Round 2 surfaces a missed primary driver, the score can be re-evaluated and the mode upgraded
- **Three-mode mapping:** silent ≈ "no inter-layer token commitment," agent ≈ "parallel paths in latent space," trace trades architectural fidelity for auditability

## Difference from vanilla Claude

|  | Plain Claude reply | mythos-skill |
|---|---|---|
| Reasoning style | Single forward pass | Multi-round iterative refinement / parallel multi-path |
| Chain of thought | Linear token output | Structured multi-perspective analysis |
| Context preservation | Drifts as tokens grow | Original question re-injected each round |
| Reasoning depth | Fixed | Complexity-adaptive + driver-weighted |
| Auditability | Final answer only | Trace mode fully visible; silent mode includes a lens-path footnote |

## File layout

```
.claude/skills/mythos/                # marketplace artifact (agent-portable)
├── SKILL.md                         # Main entry — three-mode routing + full pipeline
├── references/
│   ├── lenses.md                    # 12 lenses + question-type selector + driver→lens mapping
│   ├── prompt-templates.md          # Prelude/Recurrent/Coda internal templates (incl. degraded Coda)
│   ├── agent-blueprint.md           # Full parallel-subagent prompt for Agent mode + failure fallback
│   ├── examples.md                  # Annotated examples (lazy-loaded by SKILL.md)
│   └── mythos-init.md               # Snippet injected by the install script
├── examples/                        # marketplace-facing showcase examples
└── tests/                           # marketplace-facing test docs (manual calibration)

install/                              # source-only tooling (NOT bundled in marketplace package)
├── init.ps1 / init.sh               # Install into another project or user-global ~/.claude/CLAUDE.md
└── calibrate.ps1 / calibrate.sh     # Interactive run of 5 calibration cases
```

## Calibration

`install/calibrate.ps1` / `bash install/calibrate.sh` runs 5 calibration cases (covering technical decisions, strategic tradeoffs, cache design, process improvement, ethics disputes), interactively verifying the structural properties of the three modes (lens path, round count, parallel vs sequential dispatch) and producing a timestamped report `calibration-report-YYYYMMDD-HHMM.md`.

Calibration is **manual by design** — mythos reasoning quality cannot be verified purely programmatically; only structural properties can (lens presence, round count, parallel dispatch). FAIL counts should be treated as a signal to re-read SKILL.md, not as ground truth.

## Theoretical background

Inspired by the following research and community open-source work. None of these are official Anthropic publications, and the protocol below is a behavioral approximation, not an architectural claim:

- [OpenMythos](https://github.com/kyegomez/OpenMythos) — community open-source hypothesis of an RDT-style architecture (unofficial, not affiliated with Anthropic)
- [Parcae](https://arxiv.org/abs/2604.12946) — stable training scaling laws for recurrent language models
- [Reasoning with Latent Thoughts](https://arxiv.org/abs/2502.17416) — reasoning capability in recurrent Transformers
- [COCONUT](https://arxiv.org/abs/2412.06769) — training continuous latent-space reasoning

Full papers live under `papers/` (gitignored, kept locally).

## License

MIT
