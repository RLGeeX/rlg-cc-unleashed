---
name: discover-decide-design
description: Rigorous planning through three phases - Discover (explore problem space), Decide (validate each decision via consensus + FPF), Design (compile validated output). Use for complex planning with multiple architectural decisions.
---

# Discover-Decide-Design (D3)

## Overview

Orchestrate rigorous planning for complex problems that require multiple validated decisions. Unlike quick brainstorming, D3 systematically identifies decision points and validates each through consensus queries and FPF reasoning before producing a design.

**Announce at start:** "I'm using the discover-decide-design skill (D3) to systematically explore, validate decisions, and produce a rigorous design."

---

## When to Use

**USE D3 for:**
- Complex product/feature planning with multiple unknowns
- Architecture design with several technology choices
- Strategic planning requiring stakeholder buy-in
- Any planning where decisions need evidence trails

**USE brainstorming instead for:**
- Quick exploration of a single idea
- Simple features with obvious implementation
- When you just need to think out loud

---

## The Three Phases

### Phase 1: Discover

**Goal:** Explore the problem space, understand requirements, identify what decisions need to be made.

**Process:**
1. Understand the problem/goal
2. Research existing solutions, competitors, prior art
3. Identify constraints (technical, business, timeline)
4. Map out the solution space
5. **Track decision points as they emerge**

**Output:** List of identified decision points

**Decision Point Format:**
```markdown
## Decision Points Identified

| # | Decision | Options | Type |
|---|----------|---------|------|
| 1 | Database choice | Neo4j, Neptune, ArangoDB | Technology |
| 2 | Agent framework | LangGraph, CrewAI, AutoGen | Technology |
| 3 | Deployment model | SaaS, hybrid, on-prem | Architecture |
| 4 | MVP scope | Discovery-only, full testing | Business |
```

---

### Phase 2: Decide

**Goal:** Validate each decision point through consensus and/or FPF autonomously.

**IMPORTANT:** Do NOT ask user which decisions to validate. Automatically categorize and validate ALL decisions based on type.

**Decision Routing Table:**

| Decision Type | Validation | Tool | Auto-Apply |
|---------------|------------|------|------------|
| Technology choice | Quick multi-AI check | Consensus | YES |
| Implementation detail | Quick multi-AI check | Consensus | YES |
| Architecture pattern | Evidence-based evaluation | FPF | YES |
| Foundational (6+ months impact) | Full evidence trail | FPF | YES |
| Business/strategy | Depends on impact | Both | YES* |

*Business decisions: Run consensus first. If contested (2-1 split or disagreement), escalate to FPF.

**Step 2a: Run Consensus on Technology/Implementation Decisions**

For EACH technology or implementation decision, automatically run:
```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/consensus/scripts/consensus.sh "[Project context]. [Decision question]. Options: [A], [B], [C]. Which is best and why?"
```

Run multiple consensus queries in parallel when decisions are independent.

**Step 2b: Run FPF on Foundational/Architecture Decisions**

For EACH foundational or architecture decision, automatically invoke `fpf-reasoning` skill:
- Initialize FPF with `/q0-init`
- Generate hypothesis with `/q1-hypothesize`
- Test assumptions with `/q3-test`
- Reach decision with `/q5-decide`

**Step 2c: Escalate Contested Consensus Results**

If any consensus result shows disagreement (2-1 or split opinions):
- Escalate to FPF for deeper evaluation
- Document why the decision was contested

**Output:** Validated decisions with rationale (no user interaction required)

```markdown
## Validated Decisions

| # | Decision | Choice | Validation | Reference |
|---|----------|--------|------------|-----------|
| 1 | Database | Neo4j | Consensus (3/3) | - |
| 2 | Framework | LangGraph | Consensus (2/1) + FPF | DRR-001 |
| 3 | Deployment | Hybrid | Consensus (3/3) | - |
```

---

### Phase 3: Design

**Goal:** Compile validated decisions into a coherent design document.

**Process:**
1. Synthesize discovery findings + validated decisions
2. Present design in sections (200-300 words each)
3. Check understanding after each section
4. Document decision rationale and references

**Output:** Design document with:
- Problem statement
- Solution overview
- Architecture (with decision references)
- Components and interactions
- Implementation considerations
- Risk assessment
- Next steps

**Save to:** `.claude/plans/YYYY-MM-DD-[topic]-d3-design.md`

---

## After D3

### Handoff to Implementation

```json
{
  "question": "Design complete. What's next?",
  "header": "Next Step",
  "multiSelect": false,
  "options": [
    {"label": "Create implementation plan", "description": "Use write-plan skill to create micro-chunked plan"},
    {"label": "Create Jira tickets", "description": "Use jira-plan skill to create Epic → Stories hierarchy"},
    {"label": "Done for now", "description": "Save design, return later"}
  ]
}
```

---

## Decision Tracking Template

Throughout the process, maintain a decision tracker:

```markdown
# D3 Decision Tracker

## Problem Statement
[What we're solving]

## Decision Points

### Decision 1: [Name]
- **Options:** A, B, C
- **Consensus:** [Result - unanimous/majority/split]
- **FPF:** [If run - DRR path]
- **Final Choice:** [X]
- **Rationale:** [Why]

### Decision 2: [Name]
...
```

---

## Integration with Other Skills

| Skill | Role in D3 |
|-------|------------|
| `consensus` | Quick validation of specific decisions |
| `fpf-reasoning` | Deep evaluation for foundational decisions |
| `write-plan` | Create implementation plan after design |
| `jira-plan` | Create Jira hierarchy after design |

---

## Example Flow

```
User: "Help me plan a competitive AI security product"

DISCOVER:
- Research competitors (RedGraph, Pillar, etc.)
- Identify market gaps
- Map technical requirements
- Decision points identified:
  | # | Decision | Type | Validation |
  |---|----------|------|------------|
  | 1 | Database | Technology | Consensus |
  | 2 | Framework | Foundational | FPF |
  | 3 | Deployment | Architecture | Consensus → FPF if contested |
  | 4 | MVP scope | Business | Consensus |
  | 5 | Target market | Business | Consensus |

DECIDE (autonomous):
- [Parallel] Consensus on DB choice → Neo4j (3/3 agree)
- [Parallel] Consensus on deployment → Hybrid (2/1, contested) → escalate to FPF
- [Parallel] Consensus on MVP → Discovery-first (3/3 agree)
- [Parallel] Consensus on target market → Mid-market (3/3 agree)
- FPF on framework (foundational) → LangGraph validated with evidence
- FPF on deployment (contested) → Hybrid validated

DESIGN:
- Compile into design doc
- Reference DRRs for framework and deployment decisions
- Present architecture
- Document risks
- Save to .claude/plans/

HANDOFF:
- Ask user: Create implementation plan, Create Jira tickets, or Done
```

---

## Key Principles

1. **Track decisions explicitly** - Don't let decisions slip by unvalidated
2. **Run consensus in parallel** - Multiple queries at once when independent
3. **Escalate to FPF selectively** - Only for foundational/contested decisions
4. **Reference everything** - Design doc links to DRRs and consensus results
5. **Autonomous operation** - Categorize and validate without asking user

---

## Red Flags

**NEVER:**
- Skip the Decide phase
- Run FPF on every decision (overkill)
- Forget to track decision points during Discovery
- Produce design without referencing validated decisions
- Ask user which decisions to validate (be autonomous)

**ALWAYS:**
- Categorize decisions by type (technology, architecture, business)
- Auto-route to consensus or FPF based on type
- Escalate contested consensus to FPF
- Save design document with decision references
- Offer clear next steps after design
