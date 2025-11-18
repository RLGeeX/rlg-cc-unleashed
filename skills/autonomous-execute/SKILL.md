---
name: autonomous-execute
description: Fully autonomous plan execution - executes all remaining chunks automatically with subagents, code review, and progress tracking
---

# Autonomous Plan Execution

## Overview

Fully autonomous execution of micro-chunked plans from start to finish. This skill executes all remaining chunks in a plan automatically using the execute-plan orchestrator and execute-plan-with-subagents for each chunk, with code review between chunks and error handling.

**Core principle:** Load plan → Confirm with user → Execute all chunks → Report completion

**Called by:** `/cc-unleashed:plan-execute` command

**Announce at start:**
"I'm executing the entire plan autonomously with subagents. This will continue until all chunks are complete or an error occurs."

---

## The Autonomous Flow

### Step 1: Load Plan and Verify

```
1. Read plan-meta.json:
   - Get currentChunk number
   - Get totalChunks
   - Calculate remaining chunks
   - Check plan status (must be "in-progress" or "pending")

2. Verify plan is ready:
   - Plan file exists
   - At least one chunk remaining
   - No blocking errors from previous execution

3. If currentChunk > totalChunks:
   "✅ Plan already complete! All chunks executed."
   Exit gracefully

4. Calculate scope:
   remaining_chunks = totalChunks - currentChunk + 1
   estimated_time = remaining_chunks * 12  # ~12 min per chunk average
```

### Step 2: Get User Confirmation

Present context to user:

```
"Ready to execute plan autonomously:

Plan: [feature-name]
Progress: [currentChunk] of [totalChunks] chunks complete
Remaining: [N] chunks to execute
Estimated time: ~[X] minutes

**Autonomous Mode:**
- All chunks will execute automatically with subagents
- Code review after each chunk
- Progress updates shown between chunks
- Execution stops on errors or test failures
- You can review all changes at the end"
```

Use AskUserQuestion:
```json
{
  "questions": [{
    "question": "Proceed with autonomous execution of all remaining chunks?",
    "header": "Autonomous",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes - Execute all chunks",
        "description": "Run all remaining chunks automatically. Fastest option, review all at end."
      },
      {
        "label": "No - Execute one at a time",
        "description": "Use /cc-unleashed:plan-next to execute chunks manually with review after each."
      },
      {
        "label": "Cancel",
        "description": "Don't execute anything right now."
      }
    ]
  }]
}
```

If user selects "No" or "Cancel":
  - Exit gracefully
  - Suggest: "Use /cc-unleashed:plan-next to execute chunks one at a time"

If user selects "Yes":
  - Proceed to Step 3

### Step 3: Execute All Chunks Loop

```
start_time = current_time()
chunks_executed = []
total_subagent_calls = 0
total_tests_added = 0

while currentChunk <= totalChunks:
    # Show progress
    print(f"\n{'='*60}")
    print(f"Executing Chunk {currentChunk} of {totalChunks}")
    print(f"Progress: {len(chunks_executed)}/{totalChunks} complete")
    print(f"{'='*60}\n")

    # Invoke execute-plan orchestrator for this chunk
    result = invoke_skill("cc-unleashed:execute-plan")

    # The orchestrator will:
    # 1. Load the chunk
    # 2. Detect complexity
    # 3. Recommend mode (we override to "automated")
    # 4. Dispatch to execute-plan-with-subagents
    # 5. Handle code review
    # 6. Update plan-meta.json
    # 7. Return result

    # Check result
    if result.status == "complete":
        chunks_executed.append({
            "chunk": currentChunk,
            "name": result.chunk_name,
            "duration": result.duration,
            "tests_added": result.tests_added
        })
        total_subagent_calls += result.subagent_invocations
        total_tests_added += result.tests_added

        # Re-read plan-meta.json to get updated currentChunk
        meta = read_plan_meta()
        currentChunk = meta.currentChunk

        # Brief progress update
        print(f"\n✅ Chunk {currentChunk-1} complete")
        print(f"   Duration: {result.duration} min")
        print(f"   Tests: {result.tests_added} added, all passing")
        print(f"   Remaining: {totalChunks - currentChunk + 1} chunks\n")

    elif result.status == "blocked":
        # Stop execution, report blockage
        print(f"\n⚠️  Execution blocked at chunk {currentChunk}")
        print(f"   Reason: {result.error}")
        print(f"   Recommendation: {result.recommendation}")

        # Ask user how to proceed
        use AskUserQuestion:
        {
          "questions": [{
            "question": "Chunk execution blocked. How would you like to proceed?",
            "header": "Blocked",
            "multiSelect": false,
            "options": [
              {
                "label": "Switch to supervised mode",
                "description": "Continue this chunk with human-in-loop for better control."
              },
              {
                "label": "Pause and investigate",
                "description": "Stop autonomous execution to manually debug the issue."
              },
              {
                "label": "Skip chunk and continue",
                "description": "Mark chunk as skipped and continue with next chunk."
              }
            ]
          }]
        }

        Handle user choice:
        - "Switch to supervised mode":
            Execute current chunk in supervised mode, then continue loop
        - "Pause and investigate":
            Break loop, report status, exit
        - "Skip chunk and continue":
            Mark chunk as skipped, increment currentChunk, continue loop

    elif result.status == "tests_failing":
        # Critical blocker - stop execution
        print(f"\n❌ Tests failing after chunk {currentChunk}")
        print(f"   Output: {result.test_output}")
        print(f"\n   Stopping autonomous execution.")
        print(f"   Fix tests before continuing with /cc-unleashed:plan-next")
        break

    else:
        # Unexpected status
        print(f"\n⚠️  Unexpected status: {result.status}")
        print(f"   Stopping autonomous execution.")
        break

# End of loop
end_time = current_time()
total_duration = end_time - start_time
```

### Step 4: Final Report

After all chunks complete (or stopped):

**If all chunks complete:**
```
print(f"\n{'='*60}")
print(f"🎉 Plan Execution Complete!")
print(f"{'='*60}\n")

print(f"**Summary:**")
print(f"- Total chunks: {totalChunks}")
print(f"- Chunks executed: {len(chunks_executed)}")
print(f"- Total duration: {total_duration} minutes")
print(f"- Tests added: {total_tests_added}")
print(f"- Subagent invocations: {total_subagent_calls}")
print(f"- Average time per chunk: {total_duration / len(chunks_executed):.1f} min")

print(f"\n**Chunks executed:**")
for chunk_info in chunks_executed:
    print(f"  ✅ Chunk {chunk_info['chunk']}: {chunk_info['name']}")
    print(f"     Duration: {chunk_info['duration']} min, Tests: {chunk_info['tests_added']}")

print(f"\n**Next Steps:**")
print(f"1. Review all changes: git diff origin/main")
print(f"2. Run all tests: [test command]")
print(f"3. Use /cc-unleashed:review to request code review")
print(f"4. Create PR or merge when ready")

# Invoke finishing-a-development-branch skill
print(f"\n**Finishing branch...**")
invoke_skill("cc-unleashed:finishing-a-development-branch")
```

**If stopped early:**
```
print(f"\n{'='*60}")
print(f"⚠️  Autonomous Execution Stopped")
print(f"{'='*60}\n")

print(f"**Summary:**")
print(f"- Total chunks in plan: {totalChunks}")
print(f"- Chunks completed: {len(chunks_executed)}")
print(f"- Stopped at chunk: {currentChunk}")
print(f"- Remaining chunks: {totalChunks - currentChunk + 1}")
print(f"- Total duration: {total_duration} minutes")

print(f"\n**Completed chunks:**")
for chunk_info in chunks_executed:
    print(f"  ✅ Chunk {chunk_info['chunk']}: {chunk_info['name']}")

print(f"\n**Next Steps:**")
print(f"1. Fix the blocking issue")
print(f"2. Resume with: /cc-unleashed:plan-resume")
print(f"3. Or continue manually: /cc-unleashed:plan-next")
```

---

## Autonomous Execution Strategy

**Mode Selection:**
- Override user confirmation for each chunk
- Always use "automated" mode (subagents + code review)
- Only switch to supervised if blocked and user chooses

**Error Handling:**
- Stop on critical errors (tests failing, subagent failures)
- Ask user for direction on blockages
- Provide clear next steps

**Progress Updates:**
- Show progress header before each chunk
- Brief summary after each chunk completes
- Final comprehensive report at end

**Quality Gates:**
- Code review after each chunk (via execute-plan-with-subagents)
- All tests must pass before proceeding
- Fix attempts limited to 2 per issue

---

## Integration with Other Skills

**Uses:**
- **execute-plan** (orchestrator) - Called once per chunk
- **execute-plan-with-subagents** (via orchestrator) - Handles subagent dispatch
- **finishing-a-development-branch** (at end) - Finalizes work

**Called by:**
- `/cc-unleashed:plan-execute` command

**Reads:**
- plan-meta.json (current progress)
- chunk-NNN-*.md files (via execute-plan)

**Updates:**
- plan-meta.json (via execute-plan)
- TodoWrite (progress tracking)

---

## Comparison with Manual Execution

| Feature | Autonomous Execute | Manual (plan-next) |
|---------|-------------------|-------------------|
| **Invocation** | One command for all chunks | Command per chunk |
| **User input** | Once at start | After each chunk |
| **Speed** | Fastest (no waiting) | Slower (user review between) |
| **Control** | Less (review at end) | More (review each chunk) |
| **Use case** | Trusted plans, fast delivery | Careful review, learning |

**Both are valuable:** Choose based on trust level and review preference

---

## Example Execution

```
User: /cc-unleashed:plan-execute

Autonomous Executor:
"Ready to execute plan autonomously:

Plan: phase1-week3-descope-management
Progress: 0 of 24 chunks complete
Remaining: 24 chunks to execute
Estimated time: ~4.8 hours

Autonomous Mode:
- All chunks will execute automatically with subagents
- Code review after each chunk
- Progress updates shown between chunks
- Execution stops on errors or test failures
- You can review all changes at the end

Proceed with autonomous execution? [Yes/No/Cancel]"

User: Yes

Autonomous Executor:
"============================================================
Executing Chunk 1 of 24
Progress: 0/24 complete
============================================================

[Invokes execute-plan orchestrator]
[Orchestrator loads chunk-001-project-setup.md]
[Orchestrator dispatches to execute-plan-with-subagents]
[Subagent executes 2 tasks with TDD]
[Code reviewer reviews work]
[Orchestrator updates plan-meta.json]

✅ Chunk 1 complete
   Duration: 8 min
   Tests: 2 added, all passing
   Remaining: 23 chunks

============================================================
Executing Chunk 2 of 24
Progress: 1/24 complete
============================================================

[... continues for all 24 chunks ...]

============================================================
🎉 Plan Execution Complete!
============================================================

Summary:
- Total chunks: 24
- Chunks executed: 24
- Total duration: 4.2 hours
- Tests added: 48
- Subagent invocations: 102
- Average time per chunk: 10.5 min

Chunks executed:
  ✅ Chunk 1: Project setup (8 min, 2 tests)
  ✅ Chunk 2: Dependencies (7 min, 2 tests)
  ✅ Chunk 3: User types (6 min, 2 tests)
  ... [all 24 chunks listed]

Next Steps:
1. Review all changes: git diff origin/main
2. Run all tests: pytest
3. Use /cc-unleashed:review to request code review
4. Create PR or merge when ready

Finishing branch...
[Invokes finishing-a-development-branch skill]"
```

---

## Red Flags

**Never:**
- Execute without user confirmation at start
- Continue with failing tests
- Skip error reporting
- Lose progress on interruption

**Always:**
- Ask user to confirm before starting
- Show progress updates between chunks
- Stop on critical errors
- Provide clear summary at end
- Update plan-meta.json after each chunk (via orchestrator)

---

## Success Criteria

✅ **User confirms:** Autonomous execution approved before starting
✅ **All chunks execute:** Loop completes or stops gracefully on error
✅ **Progress tracked:** Updates shown between chunks
✅ **Quality maintained:** Code review after each chunk
✅ **Clear reporting:** Final summary with all details
✅ **Resumable:** Can continue with /cc-unleashed:plan-resume if stopped

---

## Remember

This skill is a **loop wrapper** around execute-plan:
- ✅ Load plan and verify
- ✅ Get user confirmation
- ✅ Loop through all chunks
- ✅ Call execute-plan for each chunk
- ✅ Handle errors gracefully
- ✅ Report comprehensive summary

The actual chunk execution happens in execute-plan and execute-plan-with-subagents.
