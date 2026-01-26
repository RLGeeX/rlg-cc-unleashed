---
name: sk-execute
description: Autonomously execute spec-kit tasks with constitution validation, agent dispatch, Jira sync, and code review gates
---

# Spec-Kit Task Executor

Autonomously executes spec-kit tasks with constitution validation, intelligent agent detection, Jira status sync, and mandatory code review gates between phases.

**Announce at start:** "I'm using the sk-execute skill to execute tasks from your spec-kit feature."

## Prerequisites

- Spec-kit feature must exist in `specs/###-feature-name/`
- `sk-state.json` must exist (run `/cc-unleashed:sk-jira` first)
- `.specify/memory/constitution.md` must exist (project principles)
- Jira MCP server must be available

## Input

```
specs/###-feature-name/
├── spec.md           # User stories
├── plan.md           # Technical approach
├── tasks.md          # Task definitions
└── sk-state.json     # Jira mappings (from sk-jira)

.specify/memory/constitution.md  # Project principles
```

**Argument:** Feature path (e.g., `specs/001-user-auth/` or just `001-user-auth`)

---

## CRITICAL: You Are an Orchestrator

**RULES - NO EXCEPTIONS:**

1. **NEVER implement tasks yourself** - dispatch to specialized agents
2. **Constitution violation = HARD STOP** - no exceptions
3. **Code review between phases is MANDATORY**
4. **Jira transitions are MANDATORY** when sk-state.json has jiraServer
5. **User confirms agent selection** before each task

---

## Workflow

### Phase 0: Constitution Gate (HARD STOP)

**This phase MUST complete before any task execution.**

```
1. Read .specify/memory/constitution.md
2. Extract each principle (numbered sections)
3. Read spec.md and plan.md
4. For EACH principle:
   - Evaluate: Does spec/plan violate this principle?
   - Output: PASS or FAIL with reasoning
5. Store results in sk-state.json

If ANY principle FAILS:
  - Report all violations clearly
  - STOP execution
  - Require manual resolution
  - Exit skill

If ALL PASS:
  - Mark constitutionValidated: true
  - Store validation record
  - Continue to Phase 1
```

**Validation Record Format:**
```json
"constitutionValidation": {
  "validated": true,
  "timestamp": "2026-01-26T10:00:00Z",
  "results": [
    { "principle": "I. Prompt-First Architecture", "status": "pass", "reason": "No build steps in plan" },
    { "principle": "II. Safety Standards", "status": "pass", "reason": "All safeguards present" }
  ]
}
```

### Phase 1: Load State

```
1. Read sk-state.json
2. Extract:
   - jiraServer
   - Current execution position (if resuming)
   - Task statuses
   - Completed phases
3. Determine next task:
   - Skip completed tasks
   - Check dependencies satisfied
   - Respect phase order from tasks.md
4. If all tasks complete: Jump to Phase 5
```

### Phase 2: Task Execution Loop

For each pending task (respecting phase order):

#### 2a. Dependency Check

```
1. Get task dependencies from sk-state.json
2. For each dependency:
   - Check status = "done"
   - If any dependency not done: Skip task, continue to next eligible
3. If task has no unmet dependencies: Proceed
```

#### 2b. Agent Detection & Confirmation

```
1. Analyze task description for:
   - File paths → match to agent (see reference.md)
   - Keywords → match to agent
   - Context from plan.md tech stack

2. Apply disambiguation rules:
   - .tsx + next.config.* → @nextjs-specialist
   - .tsx without Next.js → @react-specialist
   - .cs + "API" → @dotnet-core-expert
   - (See reference.md for full rules)

3. Present to user via AskUserQuestion:
   Question: "Task <ID>: <description>\n\nDetected agent: @<agent>"
   Header: "Agent"
   Options:
     - "@<detected-agent> (Recommended)"
     - "@<alternative-1>"
     - "@<alternative-2>"
     - "Other" (user types agent name)

4. Store confirmed agent in sk-state.json:
   "agentAssignments": { "T001": "@python-pro" }
```

#### 2c. Jira Transition: In Progress

```
1. Get task's Jira key from sk-state.json
2. Transition to "In Progress":
   mcp-cli call <jiraServer>/transitionJiraIssue '{
     "cloudId": "<cloudId>",
     "issueIdOrKey": "<taskKey>",
     "transitionName": "In Progress"
   }'
3. Add comment:
   mcp-cli call <jiraServer>/addCommentToJiraIssue '{
     "cloudId": "<cloudId>",
     "issueIdOrKey": "<taskKey>",
     "comment": "Execution started by cc-unleashed sk-execute"
   }'
4. If transition fails: Ask user (Retry / Skip Jira / Abort)
```

#### 2d. Agent Dispatch

```
1. Use Task tool with confirmed agent:
   Task(
     subagent_type: "<confirmed-agent>",
     description: "Execute spec-kit task <ID>",
     prompt: "
       Task: <description>
       Context: <relevant plan.md section>
       Dependencies completed: <list>
       Expected output: <from spec.md acceptance criteria>

       Execute this task and report what was done.
     "
   )
2. Capture agent output
3. Track duration in executionLog
```

#### 2e. Completion Update

```
1. Update sk-state.json:
   - tasks.<ID>.status = "done"
   - tasks.<ID>.agent = "<agent>"
   - Add to executionLog: { task, started, completed, agent }

2. Transition Jira to "Done":
   mcp-cli call <jiraServer>/transitionJiraIssue '{
     "issueIdOrKey": "<taskKey>",
     "transitionName": "Done"
   }'

3. Add completion comment:
   mcp-cli call <jiraServer>/addCommentToJiraIssue '{
     "issueIdOrKey": "<taskKey>",
     "comment": "Completed by @<agent>\n\nSummary: <brief output>"
   }'
```

### Phase 3: Parallel Execution

Tasks marked `[P]` in same phase with satisfied dependencies:

```
1. Identify parallel group:
   - Same parent (US1, Setup, etc.)
   - All have [P] flag
   - No inter-dependencies within group
   - All dependencies outside group are satisfied

2. Confirm agents for ALL tasks in group (batch AskUserQuestion)

3. Dispatch concurrently:
   - Launch multiple Task tools in parallel
   - Track all in executionLog

4. Wait for all to complete

5. Update state for entire group:
   - Mark all tasks done
   - Transition all Jira issues
```

### Phase 4: Code Review Gates (MANDATORY)

After completing a phase (Setup, Foundational, US1, US2, etc.):

```
1. Identify phase boundary:
   - All tasks in current phase complete
   - Next task is in different phase

2. Dispatch @code-reviewer:
   Task(
     subagent_type: "code-reviewer",
     description: "Review completed phase",
     prompt: "
       Review all changes from phase: <phase name>
       Tasks completed: <list>
       Files modified: <list>

       Check for:
       - Code quality and patterns
       - Test coverage
       - Security concerns
       - Alignment with spec.md requirements
     "
   )

3. Process review result:
   - If "Ready" or minor concerns: Continue
   - If "Major concerns": PAUSE

4. If PAUSED:
   Use AskUserQuestion:
     Question: "Code review found major concerns:\n<concerns>\n\nHow to proceed?"
     Options:
       - "Address concerns and re-review"
       - "Override and continue (DANGEROUS)"
       - "Abort execution"

5. Store review in sk-state.json:
   "reviewGates": {
     "<phase>": {
       "status": "passed",
       "reviewer": "@code-reviewer",
       "timestamp": "<ISO>",
       "notes": "<summary>"
     }
   }
```

### Phase 5: Completion

When all tasks complete:

```
1. Update sk-state.json:
   - status = "complete"
   - completedAt = "<ISO timestamp>"

2. Roll up Jira status:
   - If all sub-tasks of a story done: Transition story to "Done"
   - Check each story, transition as appropriate

3. Report summary:

   Spec-Kit Execution Complete

   Feature: <name>
   Duration: <total time>

   Tasks Completed: <count>
   Phases: <list with review status>

   Jira Epic: <key> - All stories and tasks marked Done

   Next Steps:
   - Review changes: git diff main...<branch>
   - Create PR: /cc-unleashed:finishing-a-development-branch
```

---

## Error Handling

### Task Execution Failure

If agent dispatch fails or task cannot be completed:

```
1. Update sk-state.json:
   - tasks.<ID>.status = "failed"
   - tasks.<ID>.error = "<error message>"

2. Update Jira:
   - Add blocker comment with error details
   - Do NOT transition to Done

3. Use AskUserQuestion:
   Question: "Task <ID> failed: <error>\n\nHow to proceed?"
   Options:
     - "Retry with same agent"
     - "Retry with different agent"
     - "Skip task and continue"
     - "Pause for manual intervention"

4. Log decision in executionLog
```

### Resume from Interruption

If skill is invoked with existing in-progress sk-state.json:

```
1. Read state
2. Find last completed task
3. Report: "Resuming from task <ID> in phase <phase>"
4. Skip completed tasks and passed review gates
5. Continue from next pending task
```

---

## Jira Integration Summary

| Timing | Action |
|--------|--------|
| Before task | Transition sub-task → "In Progress" |
| After task | Transition sub-task → "Done" |
| After phase | Check if story can transition to "Done" |
| On failure | Add blocker comment |
| On complete | Roll up all statuses |

**Server:** Read from `sk-state.json.jiraServer`

---

## See Also

- `reference.md` - Agent detection rules, state schema, constitution validation
- `/cc-unleashed:sk-jira` - Create Jira issues first
- `/cc-unleashed:execute-plan` - For cc-unleashed native plans
