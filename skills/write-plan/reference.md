# Write Plan - Reference Documentation

Detailed examples, templates, and implementation details for creating micro-chunked plans.

## Table of Contents

1. [plan-meta.json Schema](#plan-metajson-schema)
2. [Chunk Document Template](#chunk-document-template)
3. [Agent Selection Algorithm](#agent-selection-algorithm)
4. [Validation Checklist](#validation-checklist)
5. [AskUserQuestion Templates](#askuserquestion-templates)
6. [Example Transformation](#example-transformation)

---

## plan-meta.json Schema

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
      {"chunk": 1, "complexity": "simple", "storyPoints": 1, "reason": "boilerplate setup"},
      {"chunk": 2, "complexity": "simple", "storyPoints": 1, "reason": "config files"},
      {"chunk": 8, "complexity": "medium", "storyPoints": 2, "reason": "API client logic"},
      {"chunk": 15, "complexity": "complex", "storyPoints": 3, "reason": "rate limiting algorithm"}
    ],
    "reviewCheckpoints": [5, 10, 15, 20, 24],
    "parallelizable": [[1,2,3], [6,7], [10,11,12]],
    "estimatedMinutes": 360
  }
}
```

**Complexity Ratings & Story Points:**
| Complexity | Story Points | Description |
|------------|--------------|-------------|
| simple | 1 | Boilerplate, config files, well-defined patterns |
| medium | 2 | Business logic with clear tests, standard CRUD |
| complex | 3 | Novel algorithms, tricky integration, architectural decisions |

Adjust story points based on task scope - a simple chunk with many files may warrant 2 points.

---

## Chunk Document Template

```markdown
# Chunk N: [Descriptive Phase Name]

**Status:** pending
**Dependencies:** chunk-001-project-init, chunk-002-dependencies (or "none")
**Complexity:** simple | medium | complex
**Story Points:** 1 | 2 | 3
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

---

## Agent Selection Algorithm

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

**Agent Fallback Chain:**
```
Best match agent
  ↓ (if not found)
Category-appropriate generalist (fullstack-developer, devops-engineer)
  ↓ (if not found)
general-purpose (built-in Claude Code agent)
```

---

## Validation Checklist

### Structural Validation (ALL must pass)

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

### Architect Review Prompt

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

### Handle Review Results

```
IF assessment == "Ready":
  → Proceed to User Confirmation

IF assessment == "Needs Revision":
  → Fix the issues identified
  → Re-run architect review
  → Maximum 2 revision cycles

IF assessment == "Major Issues":
  → STOP and report to user
  → User must decide how to proceed
  → Do NOT mark plan as ready
```

---

## AskUserQuestion Templates

### Jira Integration

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

### Plan Finalization

```json
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

---

## Example Transformation

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
