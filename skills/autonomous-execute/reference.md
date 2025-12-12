# Autonomous Execute - Reference Documentation

Detailed examples, pseudocode, and implementation details for autonomous plan execution.

## Table of Contents

1. [Review Chain Verification](#review-chain-verification)
2. [Execution Loop Implementation](#execution-loop-implementation)
3. [AskUserQuestion Templates](#askuserquestion-templates)
4. [Final Report Templates](#final-report-templates)
5. [Example Execution](#example-execution)

---

## Review Chain Verification

**CRITICAL:** Before starting autonomous execution, verify all previous chunks have review data.

```python
def verify_review_chain(plan_meta, current_chunk):
    """
    Verify all previous chunks have proper review data.
    This ensures no chunk was completed without code review.
    """
    errors = []

    for entry in plan_meta.executionHistory:
        chunk_num = entry.get("chunk")
        if chunk_num < current_chunk:
            # Check required review fields
            if not entry.get("reviewCompleted"):
                errors.append(f"Chunk {chunk_num} missing reviewCompleted flag")
            if not entry.get("reviewedBy"):
                errors.append(f"Chunk {chunk_num} missing reviewedBy field")
            if entry.get("reviewAssessment") == "Major concerns":
                errors.append(f"Chunk {chunk_num} has unresolved 'Major concerns'")

    return errors
```

**IF REVIEW CHAIN BROKEN:**
```
STOP autonomous execution immediately.

Present to user:
"❌ Review Chain Verification Failed

Previous chunk(s) are missing code review data:
[List errors]

Autonomous execution cannot continue with broken review chain.
This indicates code review was skipped, which violates quality gates."

There is NO option to continue without fixing the review chain.
```

---

## Execution Loop Implementation

```python
start_time = current_time()
chunks_executed = []
total_subagent_calls = 0
total_tests_added = 0

# FIRST: Verify review chain before starting
review_chain_errors = verify_review_chain(plan_meta, currentChunk)
if review_chain_errors:
    present_review_chain_failure(review_chain_errors)
    return  # Cannot continue

while currentChunk <= totalChunks:
    # Show progress
    print(f"\n{'='*60}")
    print(f"Executing Chunk {currentChunk} of {totalChunks}")
    print(f"Progress: {len(chunks_executed)}/{totalChunks} complete")
    print(f"{'='*60}\n")

    # Invoke execute-plan orchestrator for this chunk
    result = invoke_skill("cc-unleashed:execute-plan")

    # Check result
    if result.status == "complete":
        # MANDATORY: Verify review was performed for this chunk
        if not result.reviewData or not result.reviewData.get("reviewCompleted"):
            print(f"\n❌ REVIEW VERIFICATION FAILED for chunk {currentChunk}")
            print(f"   Code review was NOT performed or not recorded.")
            print(f"   Cannot mark chunk as complete without review.")

            # STOP autonomous execution - ask user
            # Options: "Run code review now" or "Abort autonomous execution"
            # Handle user choice accordingly

        # Review verified - proceed
        chunks_executed.append({
            "chunk": currentChunk,
            "name": result.chunk_name,
            "duration": result.duration,
            "tests_added": result.tests_added,
            "reviewedBy": result.reviewData.get("reviewedBy"),
            "reviewAssessment": result.reviewData.get("reviewAssessment")
        })
        total_subagent_calls += result.subagent_invocations
        total_tests_added += result.tests_added

        # Re-read plan-meta.json to get updated currentChunk
        meta = read_plan_meta()
        currentChunk = meta.currentChunk

        # Brief progress update WITH REVIEW STATUS
        print(f"\n✅ Chunk {currentChunk-1} complete")
        print(f"   Duration: {result.duration} min")
        print(f"   Tests: {result.tests_added} added, all passing")
        print(f"   Review: {result.reviewData.get('reviewedBy')} → {result.reviewData.get('reviewAssessment')}")
        print(f"   Remaining: {totalChunks - currentChunk + 1} chunks\n")

    elif result.status == "review_missing" or result.status == "review_gate_failed":
        # CRITICAL: Review was skipped - cannot continue
        print(f"\n❌ REVIEW GATE FAILED at chunk {currentChunk}")
        print(f"   Code review is mandatory but was not completed.")
        print(f"   Error: {result.error}")
        print(f"\n   Stopping autonomous execution.")
        print(f"   You must run code review before continuing.")
        break

    elif result.status == "blocked":
        # Stop execution, report blockage
        print(f"\n⚠️  Execution blocked at chunk {currentChunk}")
        print(f"   Reason: {result.error}")
        print(f"   Recommendation: {result.recommendation}")

        # Ask user: supervised mode / pause / skip chunk
        break

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

---

## AskUserQuestion Templates

### Initial Confirmation

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

### Review Chain Broken

```json
{
  "questions": [{
    "question": "Review chain is broken. How to proceed?",
    "header": "Review Chain",
    "multiSelect": false,
    "options": [
      {
        "label": "Run missing reviews",
        "description": "Go back and run code review for chunks that were skipped."
      },
      {
        "label": "Abort autonomous execution",
        "description": "Stop and investigate why reviews were skipped."
      }
    ]
  }]
}
```

### Missing Review After Chunk

```json
{
  "questions": [{
    "question": "Chunk completed without code review. How to proceed?",
    "header": "Missing Review",
    "multiSelect": false,
    "options": [
      {
        "label": "Run code review now",
        "description": "Dispatch code reviewer for this chunk before continuing."
      },
      {
        "label": "Abort autonomous execution",
        "description": "Stop and investigate why review was skipped."
      }
    ]
  }]
}
```

### Chunk Blocked

```json
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
```

---

## Final Report Templates

### All Chunks Complete

```
============================================================
🎉 Plan Execution Complete!
============================================================

**Summary:**
- Total chunks: {totalChunks}
- Chunks executed: {len(chunks_executed)}
- Total duration: {total_duration} minutes
- Tests added: {total_tests_added}
- Subagent invocations: {total_subagent_calls}
- Average time per chunk: {total_duration / len(chunks_executed):.1f} min

# If Jira tracking enabled:
- Jira issues: All {totalChunks} issues transitioned to Done

**Chunks executed:**
  ✅ Chunk {chunk_info['chunk']}: {chunk_info['name']}
     Duration: {chunk_info['duration']} min, Tests: {chunk_info['tests_added']}
     Review: {chunk_info['reviewedBy']} → {chunk_info['reviewAssessment']}

**Next Steps:**
1. Review all changes: git diff origin/main
2. Run all tests: [test command]
3. Use /cc-unleashed:review to request code review
4. Create PR or merge when ready
```

### Stopped Early

```
============================================================
⚠️  Autonomous Execution Stopped
============================================================

**Summary:**
- Total chunks in plan: {totalChunks}
- Chunks completed: {len(chunks_executed)}
- Stopped at chunk: {currentChunk}
- Remaining chunks: {totalChunks - currentChunk + 1}
- Total duration: {total_duration} minutes

**Completed chunks:**
  ✅ Chunk {chunk_info['chunk']}: {chunk_info['name']}

**Next Steps:**
1. Fix the blocking issue
2. Resume with: /cc-unleashed:plan-resume
3. Or continue manually: /cc-unleashed:plan-next
```

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
   Review: code-reviewer → Ready
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
  ✅ Chunk 1: Project setup (8 min, 2 tests) - code-reviewer → Ready
  ✅ Chunk 2: Dependencies (7 min, 2 tests) - code-reviewer → Ready
  ✅ Chunk 3: User types (6 min, 2 tests) - code-reviewer → Ready
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

## Comparison with Manual Execution

| Feature | Autonomous Execute | Manual (plan-next) |
|---------|-------------------|-------------------|
| **Invocation** | One command for all chunks | Command per chunk |
| **User input** | Once at start | After each chunk |
| **Speed** | Fastest (no waiting) | Slower (user review between) |
| **Control** | Less (review at end) | More (review each chunk) |
| **Use case** | Trusted plans, fast delivery | Careful review, learning |

**Both are valuable:** Choose based on trust level and review preference
