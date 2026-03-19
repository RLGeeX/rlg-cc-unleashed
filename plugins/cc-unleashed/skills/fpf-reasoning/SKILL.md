---
name: fpf-reasoning
description: Structured reasoning for architectural decisions using First Principles Framework (Quint Code). Orchestrates ADI cycle (Abduction→Deduction→Induction→Audit→Decision) with evidence tracking and Design Rationale Records. Use for foundational technology and architecture choices, not routine decisions.
---

# FPF Reasoning for Architectural Decisions

## Overview

Orchestrate rigorous evidence-based decision-making for architectural choices using the First Principles Framework (FPF) via Quint Code. This skill wraps the ADI cycle (Abduction → Deduction → Induction → Audit → Decision) for CC Unleashed workflows.

**Announce at start:** "I'm using the fpf-reasoning skill to evaluate architectural options with evidence-based reasoning."

---

## Prerequisites

**Quint Code must be installed.** Check and offer installation if missing:

```bash
# Check if Quint Code commands exist
if [ ! -f "$HOME/.claude/commands/q0-init.md" ]; then
  echo "Quint Code not installed"
fi
```

If not installed, use AskUserQuestion:
```json
{
  "question": "Quint Code (FPF framework) is not installed. Install it now?",
  "header": "Install",
  "multiSelect": false,
  "options": [
    {"label": "Yes - Install globally", "description": "Run: curl -fsSL https://raw.githubusercontent.com/m0n0x41d/quint-code/main/install.sh | bash -s -- -g"},
    {"label": "No - Skip FPF", "description": "Continue without structured reasoning (not recommended for architectural decisions)"}
  ]
}
```

---

## Path Configuration (CRITICAL)

**All FPF files MUST be stored in `.claude/fpf/` (not `.fpf/`).**

### Step 1: Initialize Path Structure

**ALWAYS run this script BEFORE any /q* command:**

```bash
# Ensure .claude/fpf structure exists with symlink for Quint Code compatibility
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/fpf-reasoning/scripts/ensure_fpf_path.sh
```

---

## When to Use This Skill

**USE for:**
- Technology selection (database, framework, cloud service, library)
- Architecture patterns (monolith vs microservices, sync vs async, event-driven)
- Integration approaches (API design, messaging patterns, data flow)
- Security models (auth approach, encryption, access control)
- Infrastructure decisions (cloud provider, deployment strategy)

**DO NOT USE for:**
- Routine implementation details
- Code style or formatting choices
- Simple configuration decisions
- Decisions with only one viable option

---

## The ADI Cycle

### Phase Overview

| Phase | Command | Role | Output |
|-------|---------|------|--------|
| **0. Init** | `/q0-init` | Setup | `.claude/fpf/` structure |
| **1. Abduction** | `/q1-hypothesize` | Explorer | 3-5 hypotheses → L0 |
| **2. Deduction** | `/q2-check` | Logician | Logical verification → L1 |
| **3. Induction** | `/q3-test`, `/q3-research` | Inductor | Evidence gathering → L2 |
| **4. Audit** | `/q4-audit` | Auditor | WLNK analysis, bias check |
| **5. Decision** | `/q5-decide` | Synthesizer | Create DRR |

### Assurance Levels

```
L0 (Observation)    → Unverified hypothesis
  ↓ passes /q2-check
L1 (Reasoned)       → Logically consistent
  ↓ passes /q3-test OR /q3-research
L2 (Verified)       → Empirically tested
```

---

## Workflow

### Step 1: Ensure Path Structure

```bash
# Run FIRST - creates .claude/fpf and symlink
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/fpf-reasoning/scripts/ensure_fpf_path.sh
```

### Step 2: Initialize FPF (if needed)

Check if `.claude/fpf/session.md` exists. If not:
```
/q0-init
```

This creates the FPF structure with context slices.

### Step 3: Generate Hypotheses

If called from brainstorming with existing approaches, seed the hypotheses:

```
/q1-hypothesize "DECISION QUESTION"

Seed hypotheses from brainstorming:
- H1: [Approach 1 from brainstorming]
- H2: [Approach 2 from brainstorming]
- H3: [Approach 3 from brainstorming]
```

If starting fresh, let `/q1-hypothesize` generate options.

### Step 4: Logical Verification

```
/q2-check
```

Validates logical consistency. Hypotheses with flaws stay L0, valid ones → L1.

### Step 5: Evidence Gathering

For internal evidence (tests, benchmarks, prototypes):
```
/q3-test
```

For external evidence (docs, papers, case studies):
```
/q3-research
```

Run both if applicable. Evidence moves hypotheses L1 → L2.

### Step 6: WLNK Audit

```
/q4-audit
```

**WLNK (Weakest Link) Rule:** Assurance = min(evidence), NEVER average.

Audit checks:
- Congruence of external evidence to our context
- Confirmation bias in evidence selection
- Context drift from original problem

### Step 7: Create Decision Record

```
/q5-decide
```

Creates DRR (Design Rationale Record) in `.claude/fpf/decisions/`.

**DRR includes:**
- Decision made and rationale
- Alternatives considered (and why rejected)
- Evidence trail with assurance levels
- Validity conditions (when to revisit)

---

## Integration Points

### Called From

- **brainstorming** - When architectural decision gate triggers
- **Direct invocation** - For standalone architectural decisions

### Outputs To

- `.claude/fpf/decisions/DRR-NNN-*.md` - Design Rationale Records
- `.claude/fpf/knowledge/L2/` - Verified hypotheses
- `.claude/fpf/evidence/` - Test results and research findings

### Referenced By

- **write-plan** - Links DRRs in plan-meta.json
- **Future skills** - Can query `.claude/fpf/` for past decisions

---

## Returning to Caller

After `/q5-decide` completes:

1. **Summarize the decision:**
   ```
   FPF Decision Complete:
   - Decision: [chosen approach]
   - DRR: .claude/fpf/decisions/DRR-NNN-[topic].md
   - Confidence: [L2 with WLNK score]
   - Key evidence: [top 2-3 evidence points]
   ```

2. **If called from brainstorming:**
   - Return to brainstorming workflow
   - Continue with "Presenting the design" using validated decision
   - Reference DRR in the design document

3. **If called standalone:**
   - Offer next steps: "Ready to create an implementation plan with /cc-unleashed:plan-new?"

---

## Utility Commands

During the cycle, these commands are available:

| Command | Purpose |
|---------|---------|
| `/q-status` | Show current phase, hypotheses, progress |
| `/q-query <topic>` | Search knowledge base and past decisions |
| `/q-decay` | Check evidence freshness |
| `/q1-extend` | Add hypothesis mid-cycle (after q1, before q3) |
| `/q-reset` | Discard cycle, preserve learnings |

---

## File Structure

After initialization:

```
.claude/
├── fpf/                        # FPF reasoning artifacts
│   ├── knowledge/
│   │   ├── L0/                 # Unverified hypotheses
│   │   ├── L1/                 # Logically verified
│   │   ├── L2/                 # Empirically tested
│   │   └── invalid/            # Disproved (kept for learning)
│   ├── evidence/
│   │   ├── *-internal.md       # Test results, benchmarks
│   │   └── *-external.md       # Docs, papers, case studies
│   ├── decisions/
│   │   └── DRR-NNN-*.md        # Design Rationale Records
│   ├── sessions/               # Archived cycles
│   ├── context.md              # Project context slices
│   ├── session.md              # Current cycle state
│   └── config.yaml             # Optional configuration
├── decisions/                  # ADRs (lighter weight, separate)
├── plans/                      # Implementation plans
└── ...
.fpf -> .claude/fpf             # Symlink for Quint Code compatibility
```

---

## Red Flags

**NEVER:**
- Skip the path setup (Step 1)
- Run /q5-decide without at least /q2-check
- Ignore WLNK audit warnings
- Use for trivial decisions (wastes time)

**ALWAYS:**
- Run path setup before any /q* command
- Complete at least phases 1-3-5 (2 and 4 recommended)
- Reference DRR in subsequent planning docs
- Check `/q-status` if unsure of current phase

---

## Example: Database Selection

```
User: "Should we use PostgreSQL or MongoDB for the new service?"

1. [Run path setup script]

2. /q0-init (if not initialized)

3. /q1-hypothesize "Which database for order service: PostgreSQL vs MongoDB?"
   → H1: PostgreSQL (ACID, relations)
   → H2: MongoDB (flexible schema, scale)
   → H3: PostgreSQL + Redis cache (hybrid)

4. /q2-check
   → H1, H2, H3 all logically valid → L1

5. /q3-research
   → Find: PostgreSQL JSONB approach, MongoDB transactions
   → Assess congruence with our scale/team

6. /q3-test
   → Prototype both with sample queries
   → Benchmark with expected load

7. /q4-audit
   → WLNK: H3's weakest link = cache invalidation complexity
   → H1's weakest link = limited horizontal scale (but we don't need it)

8. /q5-decide
   → User chooses H1 (PostgreSQL)
   → DRR created: .claude/fpf/decisions/DRR-001-database-selection.md

9. Return to brainstorming/write-plan with validated decision
```

---

## References

- **Quint Code Repo:** https://github.com/m0n0x41d/quint-code
- **FPF Theory:** First Principles Framework by Anatoly Levenchuk
- **CC Unleashed:** This skill integrates FPF into the CC Unleashed workflow
