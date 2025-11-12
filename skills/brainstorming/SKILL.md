---
name: brainstorming
description: Use when creating or developing, before writing code or implementation plans - refines rough ideas into fully-formed designs through collaborative questioning, alternative exploration, and incremental validation. Don't use during clear 'mechanical' processes
---

# Brainstorming Ideas Into Designs

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

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
