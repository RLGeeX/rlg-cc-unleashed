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

**Goal:** Validate each decision point through consensus and/or FPF.

**Process:**

For each decision point, determine validation approach:

| Decision Type | Validation | Tool |
|---------------|------------|------|
| Technology choice | Quick multi-AI check | Consensus |
| Architecture pattern | Evidence-based evaluation | FPF |
| Business/strategy | Depends on impact | Either |
| Foundational (6+ months impact) | Full evidence trail | FPF |

**Step 2a: Batch Consensus**

Present decisions to user for consensus validation:

```json
{
  "question": "Which decisions should we validate through consensus (quick multi-AI check)?",
  "header": "Consensus",
  "multiSelect": true,
  "options": [
    {"label": "Decision 1: Database choice", "description": "Neo4j vs Neptune vs ArangoDB"},
    {"label": "Decision 2: Agent framework", "description": "LangGraph vs CrewAI vs AutoGen"},
    {"label": "Decision 3: Deployment model", "description": "SaaS vs hybrid vs on-prem"},
    {"label": "Skip consensus", "description": "Proceed without external validation"}
  ]
}
```

For each selected, run:
```bash
$HOME/.claude/plugins/marketplaces/rlg-unleashed-marketplace/skills/consensus/scripts/consensus.sh "DECISION QUESTION"
```

**Step 2b: FPF for Foundational Decisions**

After consensus, identify decisions that need deeper validation:

```json
{
  "question": "Any decisions need rigorous evidence-based evaluation (FPF)?",
  "header": "FPF",
  "multiSelect": true,
  "options": [
    {"label": "Decision N: [contested or foundational]", "description": "Consensus showed disagreement or high impact"},
    {"label": "No FPF needed", "description": "Consensus results are sufficient"}
  ]
}
```

For each selected, invoke `fpf-reasoning` skill.

**Output:** Validated decisions with rationale

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
- Decision points: DB, framework, deployment, MVP scope, target market

DECIDE:
- Consensus on DB choice → Neo4j (3/3 agree)
- Consensus on framework → LangGraph (2/1, contested)
- FPF on framework (foundational) → LangGraph validated with evidence
- Consensus on deployment → Hybrid (3/3 agree)
- Consensus on MVP → Discovery-first (3/3 agree)

DESIGN:
- Compile into design doc
- Reference DRR for framework decision
- Present architecture
- Document risks
- Save to .claude/plans/

HANDOFF:
- User chooses: Create implementation plan
- Invoke write-plan skill
```

---

## Key Principles

1. **Track decisions explicitly** - Don't let decisions slip by unvalidated
2. **Batch consensus queries** - More efficient than one-by-one
3. **Escalate to FPF selectively** - Only for foundational/contested decisions
4. **Reference everything** - Design doc links to DRRs and consensus results
5. **User decides** - Present options, let user choose what to validate

---

## Red Flags

**NEVER:**
- Skip the Decide phase
- Run FPF on every decision (overkill)
- Forget to track decision points during Discovery
- Produce design without referencing validated decisions

**ALWAYS:**
- Present decision points to user before validation
- Let user choose which decisions to validate
- Save design document with decision references
- Offer clear next steps after design
