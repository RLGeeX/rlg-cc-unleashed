---
name: brainstorming
description: Use when creating or developing, before writing code or implementation plans - refines rough ideas into fully-formed designs through collaborative questioning, alternative exploration, and incremental validation. Don't use during clear 'mechanical' processes
---

# Brainstorming Ideas Into Designs

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

## Brainstorming vs Consensus

**Before starting**, determine if this is the right approach:

- **Brainstorming** (this skill): Open-ended exploration, creative ideation, architecture design, feature discovery
- **Consensus** (`/cc-unleashed:consensus`): Specific decision questions with clear alternatives (e.g., "Redis vs Memcached?")

If the user's request is a specific decision question rather than exploratory design, use AskUserQuestion:
```
AskUserQuestion:
{
  "question": "This seems like a specific decision question. Would you prefer consensus (query multiple AI models) or brainstorming (explore options together)?",
  "header": "Approach",
  "multiSelect": false,
  "options": [
    {"label": "Consensus", "description": "Query GPT, Gemini, and Grok for their recommendations"},
    {"label": "Brainstorming", "description": "Explore options collaboratively and discuss trade-offs"}
  ]
}
```

If they choose Consensus, invoke the consensus skill instead.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design in small sections (200-300 words), checking after each section whether it looks right so far.

## The Process

**Understanding the idea:**
- Check out the current project state first (files, docs, recent commits)
- Ask questions one at a time to refine the idea
- **REQUIRED:** Use AskUserQuestion tool for all questions (not plain text)
- Prefer multiple choice questions when possible (easier to answer)
- Limit to 4 options per question (tool constraint)
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria

**Exploring approaches:**
- Propose 2-3 different approaches with trade-offs
- **REQUIRED:** Use AskUserQuestion tool to present options
- Lead with your recommended option and explain why in the option description

**Architectural Decision Gate (NEW):**

After presenting approaches, determine if this is an **architectural decision**:
- Technology selection (database, framework, cloud service, library)
- Architecture patterns (monolith vs microservices, sync vs async)
- Integration approaches (API design, messaging patterns)
- Security models (auth approach, encryption)
- Infrastructure decisions (cloud provider, deployment strategy)

If YES, use AskUserQuestion:
```json
{
  "question": "This is an architectural decision with multiple viable approaches. Would you like rigorous evidence-based evaluation using FPF (First Principles Framework)?",
  "header": "FPF Eval",
  "multiSelect": false,
  "options": [
    {"label": "Yes - Run FPF cycle (Recommended)", "description": "Hypothesis generation, evidence gathering, WLNK audit, DRR (15-30 min)"},
    {"label": "No - Continue discussion", "description": "Proceed with collaborative exploration only"}
  ]
}
```

**If user selects "Yes - Run FPF cycle":**
1. Invoke the `fpf-reasoning` skill
2. Pass the decision question and the 2-3 approaches as seed hypotheses
3. After FPF completes, resume brainstorming with the validated decision
4. Reference the DRR path in the design document

**If user selects "No":**
- Continue with standard brainstorming process
- Note in design doc: "Decision made via collaborative discussion (no FPF)"

**Presenting the design:**
- Once you believe you understand what you're building, present the design
- Break it into sections of 200-300 words
- Ask after each section whether it looks right so far
- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

## After the Design

**Documentation:**
- Write the validated design to `.claude/plans/YYYY-MM-DD-<topic>-design.md`
- User manages git commits (not you)

**Implementation (if continuing):**
- Ask: "Ready to set up for implementation?"
- Use cc-unleashed:using-git-worktrees to create isolated workspace
- Use cc-unleashed:write-plan to create detailed micro-chunked implementation plan
  * Will generate 2-3 task chunks (300-500 tokens each)
  * Will add complexity ratings per chunk
  * Will identify review checkpoints
- Offer execution: "Use /cc-unleashed:plan-next to begin execution"

## Key Principles

- **Use AskUserQuestion tool** - REQUIRED for all questions (not plain text)
- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **4 options maximum** - Tool constraint, use wisely
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design in sections, validate each
- **Be flexible** - Go back and clarify when something doesn't make sense

## Example Question Format

```
AskUserQuestion tool:
{
  "question": "What's the primary goal for this feature?",
  "header": "Main Goal",
  "multiSelect": false,
  "options": [
    {
      "label": "Speed & Performance",
      "description": "Optimize for fast execution and minimal latency"
    },
    {
      "label": "Developer Experience",
      "description": "Focus on easy-to-use APIs and great documentation"
    },
    {
      "label": "Reliability",
      "description": "Emphasize error handling and fault tolerance"
    },
    {
      "label": "Flexibility",
      "description": "Support multiple use cases and configuration options"
    }
  ]
}
```

Note: User can always select "Other" to provide custom text input (automatically available)
