---
name: write-plan
description: Creates micro-chunked implementation plans stored in .claude/plans/[feature-name]/ - breaks large features into 2-3 task chunks (300-500 tokens) optimized for subagent execution and human review
---

# Writing Micro-Chunked Plans

## Overview

Write comprehensive implementation plans broken into micro-chunks of 2-3 tasks each (300-500 tokens per chunk). This chunk size is optimized for AI agent context windows, faster human review, and better progress tracking. Plans are saved to `.claude/plans/[feature-name]/`.

Assume the engineer is skilled but has zero context for our codebase. Document everything: which files to touch, exact code, testing steps, verification commands. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the write-plan skill to create a chunked implementation plan."

**Context:** Should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `.claude/plans/[feature-name]/`

## Plan Structure

Each feature gets its own directory with:
- `plan-meta.json` - Enhanced metadata with execution configuration
- `chunk-001-descriptive-name.md` - First micro-chunk (2-3 tasks)
- `chunk-002-descriptive-name.md` - Second micro-chunk
- `chunk-NNN-descriptive-name.md` - Additional micro-chunks

**Chunk Naming:** Use descriptive names, not just numbers (e.g., `chunk-001-project-init.md`, `chunk-002-dependencies.md`)

## Creating plan-meta.json (Enhanced)

```json
{
  "feature": "feature-name",
  "created": "2025-11-12T14:30:00Z",
  "totalChunks": 24,
  "currentChunk": 1,
  "status": "pending",
  "contextTokens": 9600,
  "description": "Brief description of what this feature implements",

  "planReview": {
    "reviewedBy": "architect-reviewer",
    "reviewedAt": "2025-11-12T14:45:00Z",
    "assessment": "Ready",
    "revisionCount": 0
  },

  "phases": [
    {
      "name": "Setup & Dependencies",
      "chunks": [1, 2, 3]
    },
    {
      "name": "Core Implementation",
      "chunks": [4, 5, 6, 7, 8]
    },
    {
      "name": "Testing & Documentation",
      "chunks": [9, 10]
    }
  ],

  "executionConfig": {
    "defaultMode": "auto-detect",
    "chunkComplexity": [
      {"chunk": 1, "complexity": "simple", "reason": "boilerplate setup"},
      {"chunk": 2, "complexity": "simple", "reason": "config files"},
      {"chunk": 8, "complexity": "medium", "reason": "API client logic"},
      {"chunk": 15, "complexity": "complex", "reason": "rate limiting algorithm"}
    ],
    "reviewCheckpoints": [5, 10, 15, 20, 24],
    "parallelizable": [[1,2,3], [6,7], [10,11,12]],
    "estimatedMinutes": 360
  }
}
```

**Note:** The `phases` array groups chunks into logical development phases. Jira integration (optional) is handled separately by the jira-plan skill.

**Complexity Ratings:**
- **simple:** Boilerplate, config files, well-defined patterns → recommend automated execution
- **medium:** Business logic with clear tests, standard CRUD → recommend automated with review
- **complex:** Novel algorithms, tricky integration, architectural decisions → recommend supervised execution

## Micro-Chunking Strategy (Based on 2025 AI Research)

**Target:** 300-500 tokens per chunk, 2-3 tasks maximum

**Research Foundation:**
- Optimal chunk size for AI agent context windows: 300-500 tokens
- Modern AI can handle 30+ hour continuous tasks (Claude Sonnet 4.5)
- Smaller, well-scoped chunks improve accuracy and token efficiency
- Better for both subagent execution and human review

**Chunking Boundaries (Priority Order):**
1. **Natural code boundaries** - setup → models → api → tests → docs
2. **File groupings** - All files for one self-contained feature
3. **TDD cycles** - test → implement → refactor as atomic unit
4. **Task independence** - Can be done in parallel or any order

**Rules:**
- 2-3 tasks per chunk maximum (not 5-10!)
- 300-500 tokens per chunk (~100-200 lines)
- Each chunk completable in 5-15 minutes
- Natural stopping points between chunks
- Track dependencies between chunks
- Identify complexity per chunk (simple/medium/complex)

**Benefits of Micro-Chunks:**
- ✅ Fits in subagent context windows
- ✅ Faster human review (2-3 min vs 30 min)
- ✅ Better parallelization potential
- ✅ Easier to resume from interruptions
- ✅ Clearer progress tracking
- ✅ More checkpoints for validation

## Chunk Document Structure

```markdown
# Chunk N: [Descriptive Phase Name]

**Status:** pending
**Dependencies:** chunk-001-project-init, chunk-002-dependencies (or "none")
**Complexity:** simple | medium | complex
**Estimated Time:** 5-15 minutes
**Tasks:** 2-3
**Phase:** Setup & Dependencies

---

## Task 1: [Component Name]

**Agent:** python-pro
**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```

---

## Task 2: [Next Component]
[Follow same structure...]

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
```

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code" - step
- "Run tests to verify pass" - step
- "Commit" - step

## Writing Process

1. **Design with @story-writer** - Launch @story-writer subagent to:
   - Convert requirements into Epic → Stories breakdown
   - Define acceptance criteria for each story
   - Identify dependencies and complexity
   - Group into logical phases (setup, core, integration, tests, docs)
   - Capture phase names and groupings for plan-meta.json

2. **Create directory** - `.claude/plans/[feature-name]/`

3. **Micro-chunk each phase:**
   - Take each phase from @story-writer output
   - Break into 2-3 task chunks
   - Target 300-500 tokens per chunk
   - Use descriptive chunk names

4. **Analyze complexity** - Rate each chunk (simple/medium/complex)

5. **Select agents for tasks** - For each task:
   - Load available agents from manifest.json
   - Read agent descriptions to understand their capabilities
   - Match task requirements to best available agent
   - Validate selected agent exists
   - Add **Agent** field to task

6. **Identify checkpoints** - Review points every 5-7 chunks

7. **Find parallelizable chunks** - Groups that can run concurrently

8. **Write plan-meta.json** - Include phases array and executionConfig

9. **Write chunk files** - Create chunk-NNN-name.md files with agent fields and phase names

10. **Review chunking** - Ensure logical breaks, dependencies clear, token counts reasonable, agents valid

11. **Offer Jira integration** - Ask user if they want to create Jira issues via jira-plan skill

## Optional: Jira Integration

After plan files are created, use AskUserQuestion tool:

```
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

**If user selects "Yes - Create Jira hierarchy":**
- Tell user: "Running jira-plan skill to create Jira hierarchy..."
- Use Skill tool to invoke jira-plan
- jira-plan will:
  - Read plan-meta.json phases structure
  - Create Epic (feature-level)
  - Create Stories (one per phase)
  - Create Sub-tasks (one per chunk, linked to story)
  - Update plan-meta.json with jiraTracking section
  - Update chunk files with jiraIssueKey fields

**If user selects "No - Skip for now":**
- Plan is complete and ready for execution
- User can run `/cc-unleashed:jira-plan [feature-name]` later if needed

## Agent Selection (Dynamic Discovery)

For each task, dynamically select the best available agent:

### Step 1: Discover Available Agents

```
1. Read manifest.json
2. Extract all agent categories and their agents:
   {
     "development": ["python-pro.md", "react-specialist.md", ...],
     "quality": ["code-reviewer.md", "debugger.md", ...],
     "infrastructure": ["terraform-engineer.md", ...],
     ...
   }
3. Build agent ID list:
   - "python-pro"
   - "code-reviewer"
   - etc.
```

### Step 2: Load Agent Capabilities

```
For each available agent:
  1. Read agents/{category}/{agent-name}.md
  2. Extract frontmatter (name, description)
  3. Build capability profile:
     - Agent ID: python-pro
     - Description: "Expert Python developer specializing in..."
     - Category: development
     - Inferred capabilities: [python, fastapi, async, testing]
```

### Step 3: Match Task to Best Agent

```
For each task in chunk:
  1. Analyze task:
     - Extract file extensions: [.py, .ts, .sql, etc.]
     - Extract keywords from description: ["API", "database", "UI", etc.]
     - Determine primary work type: implementation, review, infrastructure, etc.

  2. Score each available agent:
     - Match file extensions (exact match = +10 points)
     - Match keywords in description (+5 per keyword)
     - Match category (+3 points)
     - Prefer specific specialists over generalists (+2)

  3. Select highest scoring agent
  4. Fallback if no good match:
     - Development tasks → fullstack-developer (if exists)
     - Infrastructure → devops-engineer (if exists)
     - Last resort → general-purpose (Claude Code built-in)
```

### Step 4: Validation

```
Before writing agent to chunk:
  1. Verify agent ID format: {agent-name}
  2. Confirm agent exists in manifest.json
  3. Confirm file exists in ~/.claude/agents/cc-unleashed/{agent-name}.md
  4. If validation fails:
     - Log warning
     - Try fallback agent
     - If fallback fails, use general-purpose
```

### Example Selection Process

```
Task: "Create UserService with CRUD operations"
Files: ["src/services/user_service.py", "tests/test_user_service.py"]

Analysis:
- File extensions: .py (Python)
- Keywords: ["service", "CRUD", "database"]
- Work type: implementation

Available agents (from manifest):
- python-pro: "Expert Python developer..." → Score: 10 (file) + 5 (keywords) + 3 (dev) = 18
- fastapi-developer: "FastAPI specialist..." → Score: 10 (file) + 3 (dev) = 13
- fullstack-developer: "Full-stack..." → Score: 5 (general) + 3 (dev) = 8

Selected: python-pro (highest score)
```

### Implementation Notes

**Dynamic Discovery Benefits:**
- Works with any agent set (user's custom agents, future additions)
- No hardcoded mappings to maintain
- Adapts to available agents automatically
- Supports user-created custom agents

**Agent Fallback Chain:**
```
Best match agent
  ↓ (if not found)
Category-appropriate generalist (fullstack-developer, devops-engineer)
  ↓ (if not found)
general-purpose (built-in Claude Code agent)
```

## Remember

- **Micro-chunks:** 2-3 tasks, 300-500 tokens per chunk (not 5-10!)
- **Descriptive names:** chunk-001-project-init.md (not just chunk-001.md)
- **Complexity ratings:** Simple/medium/complex per chunk in plan-meta.json
- **Agent fields:** Every task must have valid **Agent:** field
- **Review checkpoints:** Every 5-7 chunks
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits
- Clear dependencies between chunks

---

## MANDATORY: Plan Validation Before Completion

**THIS PHASE IS NOT OPTIONAL - DO NOT SKIP**

Before marking the plan as ready, you MUST complete ALL validation steps:

### Step 1: Structural Validation Checklist

Run through this checklist. ALL items must pass:

```
□ All chunk files exist in .claude/plans/[feature-name]/
□ Every task in every chunk has an **Agent:** field
□ All Agent fields reference valid agents (check manifest.json)
□ Chunk sizes are in range (2-3 tasks, 300-500 tokens each)
□ Dependencies are logical (no circular dependencies)
□ Complexity ratings are present (simple/medium/complex)
□ plan-meta.json has all required fields
□ Phases array groups chunks logically
```

**IF ANY ITEM FAILS:**
- STOP immediately
- Fix the issue before proceeding
- Re-run the checklist

### Step 2: Plan Review by Architect

**Dispatch @architect-reviewer to review the plan:**

```
Use Task tool:
  subagent_type: "architect-reviewer"
  description: "Review implementation plan for [feature-name]"

  prompt: |
    Review this implementation plan for quality and completeness.

    ## Plan Location
    .claude/plans/[feature-name]/

    ## Review Criteria
    1. **Chunk Structure:** Are chunks properly sized (2-3 tasks, 300-500 tokens)?
    2. **Agent Selection:** Are the right agents assigned to each task?
    3. **Dependencies:** Are chunk dependencies logical and complete?
    4. **TDD Coverage:** Does each task follow test-first approach?
    5. **Completeness:** Are there any gaps in the implementation plan?
    6. **Risk Assessment:** Any high-risk areas that need extra attention?

    ## Report Format
    **Assessment:** Ready | Needs Revision | Major Issues

    **Strengths:**
    - [What's well-designed]

    **Issues:**
    - Critical: [Must fix before execution]
    - Important: [Should fix]
    - Minor: [Nice to have]

    **Recommendations:**
    - [Specific improvements]
```

### Step 3: Handle Review Results

```
IF assessment == "Ready":
  → Proceed to Step 4 (User Confirmation)

IF assessment == "Needs Revision":
  → Fix the issues identified
  → Re-run architect review
  → Maximum 2 revision cycles

IF assessment == "Major Issues":
  → STOP and report to user
  → User must decide how to proceed
  → Do NOT mark plan as ready
```

### Step 4: User Confirmation (REQUIRED)

Present the plan summary and review results to the user:

```
Use AskUserQuestion:
{
  "questions": [{
    "question": "Plan has been reviewed. Ready to finalize?",
    "header": "Finalize",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes - Plan is ready",
        "description": "Architect review passed. Save plan and proceed to execution options."
      },
      {
        "label": "Review plan first",
        "description": "Show me the plan details before finalizing."
      },
      {
        "label": "Revise plan",
        "description": "I want to make changes before finalizing."
      }
    ]
  }]
}
```

**Only after user confirms "Yes - Plan is ready":**
- Update plan-meta.json with `"status": "ready"`
- Add `"reviewedBy": "architect-reviewer"`
- Add `"reviewedAt": "[timestamp]"`
- Proceed to Execution Handoff

---

## Execution Handoff

After saving the plan, provide user with next steps:

**Jira Integration (Optional):**
- `/cc-unleashed:jira-plan [feature-name]` - Create Jira Epic → Stories → Sub-tasks
- Can be run now or later

**Plan Execution:**
- `/cc-unleashed:plan-next` - Execute next chunk (manual mode)
- `/cc-unleashed:plan-execute` - Execute all remaining chunks (autonomous mode)
- `/cc-unleashed:plan-status` - Check current progress
- `/cc-unleashed:plan-list` - See all available plans

## Example: Transformation from Old to New

**Feature:** Add OAuth login (30 tasks total)

**Old Way (4 large chunks):**
```
chunk-001.md: Setup - 7 tasks (~1,500 tokens)
chunk-002.md: Auth flow - 8 tasks (~1,800 tokens)
chunk-003.md: User integration - 6 tasks (~1,200 tokens)
chunk-004.md: Testing & docs - 9 tasks (~2,000 tokens)
```

**New Way (12 micro-chunks):**
```
chunk-001-oauth-config.md: 2 tasks (~350 tokens) - simple
chunk-002-dependencies.md: 2 tasks (~300 tokens) - simple
chunk-003-env-setup.md: 3 tasks (~450 tokens) - simple
chunk-004-routes.md: 2 tasks (~400 tokens) - medium
chunk-005-handlers.md: 3 tasks (~500 tokens) - medium
chunk-006-session-mgmt.md: 3 tasks (~450 tokens) - complex
chunk-007-db-models.md: 2 tasks (~350 tokens) - simple
chunk-008-profile-logic.md: 2 tasks (~400 tokens) - medium
chunk-009-account-linking.md: 2 tasks (~400 tokens) - complex
chunk-010-unit-tests.md: 3 tasks (~450 tokens) - simple
chunk-011-integration-tests.md: 3 tasks (~500 tokens) - medium
chunk-012-docs.md: 3 tasks (~400 tokens) - simple
```

**Benefits:**
- 3x more chunks, but each takes 5-10 min vs 30-60 min
- Clear complexity per chunk enables smart execution mode selection
- Better checkpoints: review after chunks 6 and 12
- Parallelizable: chunks 1-3 can run concurrently, 7-8 can run concurrently
