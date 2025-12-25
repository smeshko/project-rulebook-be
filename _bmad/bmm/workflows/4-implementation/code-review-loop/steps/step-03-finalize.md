---
name: 'step-03-finalize'
description: 'Complete the workflow by updating story status, creating PR, and printing summary'

# Path Definitions
workflow_path: '{project-root}/.bmad/bmm/workflows/4-implementation/code-review-loop'

# File References
thisStepFile: '{workflow_path}/steps/step-03-finalize.md'
workflowFile: '{workflow_path}/workflow.md'

# Config References
config_source: '{project-root}/.bmad/bmm/config.yaml'
sprint_artifacts: '{config_source}:sprint_artifacts'
sprint_status_file: '{sprint_artifacts}/sprint-status.yaml'

# Template References
# (none required for this step)

# Task References
# (none required for this step)
---

# Step 3: Finalize

## STEP GOAL:

To complete the code review loop by updating the story status to "done", creating a pull request, and printing a comprehensive summary of all review cycles.

## MANDATORY EXECUTION RULES (READ FIRST):

### Universal Rules:

- 📖 CRITICAL: Read the complete step file before taking any action
- 🤖 This is an AUTONOMOUS workflow - proceed without user interaction
- ✅ This is the FINAL step - workflow completes here

### Role Reinforcement:

- ✅ You are completing the review process
- ✅ Ensure all work is properly documented
- ✅ Ensure review results are documented

### Step-Specific Rules:

- 🎯 Update story status to "done"
- 📋 Print comprehensive summary to terminal

## EXECUTION PROTOCOLS:

- 🎯 Complete all finalization tasks
- 💾 Update story file and sprint-status.yaml
- ✅ Print summary and complete workflow

## CONTEXT FROM PREVIOUS STEPS:

Available in memory:
- `cycle_count` - total cycles executed
- `exit_reason` - why we exited ("clean", "all_false_positives", "max_cycles_reached")
- `issues_fixed` - array of all fixed issues
- `issues_skipped` - array of all skipped issues
- Story key and file path

---

## FINALIZATION SEQUENCE:

### 1. Update Story Status

Update the story file to mark status as "done":

Edit the story file's frontmatter or status section:
```yaml
status: done
```

### 2. Update Sprint Status

Update `{sprint_status_file}` to mark the story as done:

```yaml
{story-key}: done
```

### 3. Print Terminal Summary

Display comprehensive summary:

```
═══════════════════════════════════════════════════════════════
  CODE REVIEW LOOP - Complete
═══════════════════════════════════════════════════════════════

  Story: {story-key}
  Status: DONE

  Review Summary:
  ───────────────────────────────────────────────────────────
  Total Cycles: {cycle_count} of 2
  Exit Reason: {exit_reason_description}

  Issues Fixed: {issues_fixed.length}
  ───────────────────────────────────────────────────────────
  {For each fixed issue:}
  • [{cycle}] {file}:{line}
    Issue: {issue}
    Fix: {fix}

  Issues Skipped: {issues_skipped.length}
  ───────────────────────────────────────────────────────────
  {For each skipped issue:}
  • [{cycle}] {file}:{line}
    Issue: {issue}
    Reason: {reason}

  Manual Validation Checklist:
  ───────────────────────────────────────────────────────────
  {Generate from acceptance criteria}
  □ {Criterion 1}
  □ {Criterion 2}
  □ {Criterion N}

═══════════════════════════════════════════════════════════════
  Workflow Complete
═══════════════════════════════════════════════════════════════
```

### 4. Exit Reason Descriptions

Map exit_reason to human-readable description:
- `clean` → "Codex found no issues - code is clean"
- `all_false_positives` → "All Codex findings were false positives"
- `max_cycles_reached` → "Maximum 2 cycles reached - some issues may remain"

### 5. Workflow Complete

The workflow is now complete. No further action needed.

---

## CRITICAL STEP COMPLETION NOTE

This is the FINAL step. After printing the summary, the workflow is complete. Do not load any additional steps.

---

## 🚨 SYSTEM SUCCESS/FAILURE METRICS

### ✅ SUCCESS:

- Story status updated to "done"
- Sprint status updated
- Summary printed to terminal
- Workflow completed cleanly

### ❌ SYSTEM FAILURE:

- Not updating story status
- Missing summary information
- Stopping to ask user questions
- Attempting to load another step

**Master Rule:** This is the FINAL step of an AUTONOMOUS workflow. Complete all tasks and exit cleanly.
