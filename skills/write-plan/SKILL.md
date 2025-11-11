---
name: write-plan
description: Creates chunked implementation plans stored in .claude/plans/[feature-name]/ - breaks large features into digestible 5-10 task chunks for better context management
---

# Writing Chunked Plans

## Overview

Write comprehensive implementation plans broken into chunks of 5-10 tasks each. Each chunk is stored separately for optimal context management. Plans are saved to `.claude/plans/[feature-name]/` instead of docs.

Assume the engineer is skilled but has zero context for our codebase. Document everything: which files to touch, exact code, testing steps, verification commands. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the write-plan skill to create a chunked implementation plan."

**Context:** Should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `.claude/plans/[feature-name]/`

## Plan Structure

Each feature gets its own directory with:
- `plan-meta.json` - Metadata about the plan
- `chunk-001.md` - First batch of tasks
- `chunk-002.md` - Second batch
- `chunk-NNN.md` - Additional chunks as needed

## Creating plan-meta.json

```json
{
  "feature": "feature-name",
  "created": "2025-11-11T14:30:00Z",
  "totalChunks": 4,
  "currentChunk": 1,
  "status": "pending",
  "contextTokens": 1200,
  "description": "Brief description of what this feature implements"
}
```

## Chunk Sizing Strategy

**Natural breakpoints for chunks:**
1. **Setup chunk** - Project structure, dependencies, config
2. **Core logic chunk** - Main implementation (may be multiple chunks)
3. **Integration chunk** - Connect components, wire up
4. **Testing chunk** - Comprehensive tests
5. **Documentation chunk** - README, API docs, examples

**Rules:**
- 5-10 tasks per chunk maximum
- Each chunk should be completable in one session
- Natural stopping points between chunks
- Track dependencies between chunks

## Chunk Document Structure

```markdown
# Chunk N: [Phase Name]

**Status:** pending
**Dependencies:** chunk-001, chunk-002 (or "none")
**Estimated Time:** 30-60 minutes

---

## Task 1: [Component Name]

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

1. **Design first** - Use brainstorming skill to understand feature fully
2. **Identify chunks** - Break down into natural phases
3. **Create directory** - `.claude/plans/[feature-name]/`
4. **Write plan-meta.json** - Set totalChunks, description
5. **Write chunk-001.md** - First 5-10 tasks
6. **Write subsequent chunks** - Continue until complete
7. **Review chunking** - Ensure logical breaks, dependencies clear

## Remember

- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits
- 5-10 tasks per chunk maximum
- Clear dependencies between chunks

## Execution Handoff

After saving the plan, offer execution choice:

**Option 1:** Execute now
- Use `/rlg:plan-next` command to load and execute chunk-001

**Option 2:** Execute later
- Plan saved to `.claude/plans/[feature-name]/`
- Use `/rlg:plan-list` to see all plans
- Use `/rlg:plan-next` when ready to start

## Example Chunk Flow

**Feature:** Add OAuth login

**plan-meta.json:**
```json
{
  "feature": "add-oauth-login",
  "created": "2025-11-11T14:30:00Z",
  "totalChunks": 4,
  "currentChunk": 1,
  "status": "pending"
}
```

**Chunks:**
1. chunk-001.md: Setup (OAuth config, dependencies, env vars) - 7 tasks
2. chunk-002.md: Auth flow (routes, handlers, session) - 8 tasks
3. chunk-003.md: User integration (DB, profile, linking) - 6 tasks
4. chunk-004.md: Testing & docs (unit, integration, docs) - 9 tasks

Total: 30 tasks across 4 manageable chunks instead of one overwhelming 30-task plan.
