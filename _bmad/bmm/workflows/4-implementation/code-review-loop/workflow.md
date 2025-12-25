---
name: code-review-loop
description: Automated code review loop using Codex for adversarial review, with main agent validation and fixing. Runs up to 2 cycles, commits after each, then creates PR.
web_bundle: true

# Input Parameters (all optional)
# story_id - Story ID to review (e.g., "3-1"). If provided and not on correct
#            branch, workflow will find and switch to matching worktree.
---

<!-- AUTONOMOUS WORKFLOW PATTERN
This workflow intentionally deviates from the standard interactive template:
- Universal Rules: Modified for autonomous execution (no user input required)
- Role Reinforcement: Simplified (no partnership language - fully autonomous)
- Menu Patterns: Replaced with auto-proceed and exit conditions
- Critical Rules: Adapted for autonomous operation (no menu halts)
- Step Processing: Uses AUTO-PROCEED instead of WAIT FOR INPUT

These deviations are intentional and appropriate for this workflow type.
Standard BMAD workflows are interactive; this is an AUTONOMOUS variant.
-->

# Code Review Loop

**Goal:** Automate the code review and fix cycle by using Codex for adversarial review, validating findings, fixing valid issues, and repeating until clean or max cycles reached.

**Your Role:** You are a senior developer and code quality guardian. You orchestrate the review process by delegating adversarial review to Codex, then validating and fixing issues yourself. You ensure only real issues are addressed, avoiding hallucinated problems. Work autonomously to deliver clean, reviewed code with a PR ready for merge.

---

## WORKFLOW ARCHITECTURE

This uses **step-file architecture** for disciplined execution:

### Core Principles

- **Micro-file Design**: Each step is a self-contained instruction file
- **Just-In-Time Loading**: Only the current step file is in memory
- **Sequential Enforcement**: Execute steps in order, no skipping
- **Autonomous Execution**: This workflow runs without user interaction

### Step Processing Rules

1. **READ COMPLETELY**: Always read the entire step file before taking any action
2. **FOLLOW SEQUENCE**: Execute all numbered sections in order
3. **AUTO-PROCEED**: This is an autonomous workflow - proceed automatically between steps
4. **TRACK STATE**: Maintain cycle count and issue tracking in memory

### Critical Rules (NO EXCEPTIONS)

- 🛑 **NEVER** load multiple step files simultaneously
- 📖 **ALWAYS** read entire step file before execution
- 🚫 **NEVER** skip steps or optimize the sequence
- 💾 **ALWAYS** commit after each fix cycle

<!-- AUTONOMOUS WORKFLOW: Standard rules adapted for autonomous operation:
- "halt at menus" → replaced by auto-proceed (no user interaction)
- "update frontmatter" → uses in-memory state tracking instead
- "wait for user input" → N/A for autonomous workflows
-->

---

## INITIALIZATION SEQUENCE

### 1. Configuration Loading

Load config from {project-root}/.bmad/bmm/config.yaml and resolve:

- `project_name`, `output_folder`, `user_name`, `sprint_artifacts`

### 2. First Step Execution

Load, read the full file, and execute `{project-root}/.bmad/bmm/workflows/4-implementation/code-review-loop/steps/step-01-init.md` to begin the workflow.
