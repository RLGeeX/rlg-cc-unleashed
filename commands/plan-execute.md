---
description: Execute entire plan automatically with subagents
---

Use the Skill tool to invoke the `cc-unleashed:execute-plan` skill with full automation mode enabled.

This command will execute all remaining chunks in the current plan automatically, using subagents for each chunk with code review between chunks. This is the fastest way to implement a complete feature plan.

**What happens:**
1. Loads the current plan and verifies it's ready
2. Asks you to confirm autonomous execution
3. Executes all remaining chunks sequentially with subagents
4. Stops on failures with clear error reporting
5. Shows progress updates between chunks
6. Generates final summary when complete

**Use this when:**
- You've created a plan and want full automation
- You trust the micro-chunked plan quality
- You want fastest possible implementation
- You're ready to review all code at the end

**Use `/cc-unleashed:plan-next` if:**
- You want to execute chunks one at a time
- You want to review progress after each chunk
- You want more control over the process
