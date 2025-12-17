---
name: write-plan
description: Creates micro-chunked implementation plans stored in .claude/plans/[feature-name]/ - breaks large features into 2-3 task chunks (300-500 tokens) optimized for subagent execution and human review
---

# Writing Micro-Chunked Plans

## Overview

Write comprehensive implementation plans broken into micro-chunks of 2-3 tasks each (300-500 tokens per chunk). This chunk size is optimized for AI agent context windows, faster human review, and better progress tracking.

Assume the engineer is skilled but has zero context for our codebase. Document everything: which files to touch, exact code, testing steps, verification commands.

**Announce at start:** "I'm using the write-plan skill to create a chunked implementation plan."

**Save plans to:** `.claude/plans/[feature-name]/`

---

## Plan Structure

Each feature gets its own directory:
- `plan-meta.json` - Metadata with execution configuration
- `chunk-001-descriptive-name.md` - First micro-chunk (2-3 tasks)
- `chunk-NNN-descriptive-name.md` - Additional chunks

**Naming:** Use descriptive names (e.g., `chunk-001-project-init.md`, not `chunk-001.md`)

---

## Micro-Chunking Strategy

**Target:** 300-500 tokens per chunk, 2-3 tasks maximum

**Chunking Boundaries (Priority Order):**
1. Natural code boundaries - setup → models → api → tests → docs
2. File groupings - All files for one self-contained feature
3. TDD cycles - test → implement → refactor as atomic unit
4. Task independence - Can be done in parallel

**Rules:**
- 2-3 tasks per chunk maximum (not 5-10!)
- 300-500 tokens per chunk (~100-200 lines)
- Each chunk completable in 5-15 minutes
- Track dependencies between chunks
- Identify complexity per chunk (simple/medium/complex)
- Assign story points per chunk (simple=1, medium=2, complex=3, adjust as needed)

---

## Writing Process

0. **Check for FPF decisions** - Look for relevant Design Rationale Records
   - Check `.claude/fpf/decisions/` for DRRs related to this feature
   - If found: Reference in plan-meta.json under `architecturalDecisions` array
   - If major architectural decisions are undocumented and approaches unclear:
     ```json
     {
       "question": "This plan involves architectural decisions that aren't documented. Run FPF reasoning first?",
       "header": "FPF Check",
       "multiSelect": false,
       "options": [
         {"label": "Yes - Run FPF first", "description": "Use fpf-reasoning skill to validate architectural choices before planning"},
         {"label": "No - Proceed with planning", "description": "Architecture is clear or already decided"}
       ]
     }
     ```
   - If user selects "Yes": Invoke `fpf-reasoning` skill, then resume write-plan

1. **Design with @story-writer** - Convert requirements to Epic → Stories breakdown
2. **Create directory** - `.claude/plans/[feature-name]/`
3. **Micro-chunk each phase** - 2-3 tasks, 300-500 tokens each
4. **Analyze complexity & estimate** - Rate each chunk, assign story points (see reference.md)
5. **Select agents for tasks** - Dynamic discovery from manifest.json (see reference.md)
6. **Identify checkpoints** - Review points every 5-7 chunks
7. **Find parallelizable chunks** - Groups that can run concurrently
8. **Write plan-meta.json** - Include phases array, executionConfig with storyPoints
9. **Write chunk files** - With agent fields, story points, and phase names
10. **MANDATORY: Validation** - Run checklist + architect review

---

## Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code" - step
- "Run tests to verify pass" - step
- "Commit" - step

---

## MANDATORY: Plan Validation Before Completion

**THIS PHASE IS NOT OPTIONAL - DO NOT SKIP**

### Step 1: Structural Validation

ALL items must pass (see reference.md for full checklist):
- All chunk files exist
- Every task has **Agent:** field
- Agents are valid
- Chunk sizes in range
- Dependencies logical
- plan-meta.json complete

**IF ANY FAILS:** STOP, fix, re-run checklist.

### Step 2: Architect Review

**Dispatch @architect-reviewer** to review the plan for:
- Chunk structure and sizing
- Agent selection appropriateness
- Dependency logic
- TDD coverage
- Completeness and gaps
- Risk assessment

See reference.md for full review prompt.

### Step 3: Handle Review Results

| Assessment | Action |
|------------|--------|
| Ready | Proceed to user confirmation |
| Needs Revision | Fix issues, re-review (max 2 cycles) |
| Major Issues | STOP, report to user, do NOT mark ready |

### Step 4: User Confirmation (REQUIRED)

Use AskUserQuestion: Plan ready / Review first / Revise

**Only after user confirms "Yes":**
- Update plan-meta.json: `"status": "ready"`
- Add planReview fields
- Proceed to execution handoff

---

## Execution Handoff

After saving the plan:

### Jira Integration (MUST ASK)

**Use AskUserQuestion to offer Jira integration:**

```json
{
  "questions": [{
    "question": "Would you like to create Jira issues for tracking this plan?",
    "header": "Jira",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes - Create Jira hierarchy",
        "description": "Run jira-plan skill to create Epic → Stories → Sub-tasks with proper hierarchy"
      },
      {
        "label": "No - Skip for now",
        "description": "Plan is ready without Jira. You can run /cc-unleashed:jira-plan later if needed"
      }
    ]
  }]
}
```

**If user selects "Yes":** Invoke the `jira-plan` skill with the feature name.

**Plan Execution:**
- `/cc-unleashed:plan-next` - Execute next chunk (manual)
- `/cc-unleashed:plan-execute` - Execute all (autonomous)
- `/cc-unleashed:plan-status` - Check progress
- `/cc-unleashed:plan-list` - See all plans

---

## Key Rules

| Rule | Requirement |
|------|-------------|
| Chunk size | 2-3 tasks, 300-500 tokens |
| Agent field | REQUIRED for every task |
| Story points | REQUIRED for every chunk (1/2/3) |
| Dependencies | Clear between chunks |
| Complexity | simple/medium/complex rating |
| Validation | Structural + architect review |
| User approval | REQUIRED before marking ready |

---

## Red Flags

**NEVER:**
- Skip validation phase
- Mark plan ready without architect review
- Write chunks without Agent fields
- Create chunks > 500 tokens
- Skip user confirmation

**ALWAYS:**
- Use descriptive chunk names
- Include exact file paths
- Provide complete code (not "add validation")
- Specify exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

---

## References

See `reference.md` for:
- Complete plan-meta.json schema
- Full chunk document template
- Agent selection algorithm
- Validation checklist details
- AskUserQuestion templates
- Example transformation (old → new style)
