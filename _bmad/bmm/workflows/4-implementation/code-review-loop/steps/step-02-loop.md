---
name: 'step-02-loop'
description: 'Execute the review-validate-fix-commit cycle up to 3 times'

# Path Definitions
workflow_path: '{project-root}/.bmad/bmm/workflows/4-implementation/code-review-loop'

# File References
thisStepFile: '{workflow_path}/steps/step-02-loop.md'
nextStepFile: '{workflow_path}/steps/step-03-finalize.md'
workflowFile: '{workflow_path}/workflow.md'

# External Commands
codex_review_command: '/codex-review'

# Template References
# (none required for this step)

# Task References
# (none required for this step)
---

# Step 2: Review Loop

## STEP GOAL:

To execute the review-validate-fix-commit cycle. Spawn Codex for adversarial review, validate findings against codebase and story requirements, fix valid issues, commit, and repeat until clean or max 2 cycles reached.

## MANDATORY EXECUTION RULES (READ FIRST):

### Universal Rules:

- 📖 CRITICAL: Read the complete step file before taking any action
- 🔄 CRITICAL: This step contains an internal loop - follow loop logic exactly
- 🤖 This is an AUTONOMOUS workflow - proceed without user interaction

### Role Reinforcement:

- ✅ You are the VALIDATOR and FIXER - Codex is the REVIEWER
- ✅ Codex finds issues, YOU decide if they're real
- ✅ Only fix issues that are genuinely problematic
- ✅ Dismiss false positives with clear reasoning

### Step-Specific Rules:

- 🎯 Focus on one cycle at a time
- 🚫 FORBIDDEN to fix issues without validating them first
- 💾 Commit after EVERY cycle that has fixes
- 🔄 Loop back to start of this step until exit condition met

## EXECUTION PROTOCOLS:

- 🎯 Run Codex in report-only mode
- 💾 Track all issues (fixed and skipped)
- 📖 Commit with descriptive message after each fix cycle
- 🚫 FORBIDDEN to exceed 3 cycles
- 🚫 FORBIDDEN to specify a model with `-m` flag - always use Codex's configured default

## CONTEXT FROM STEP 1:

Available in memory from initialization:
- `cycle_count` - current cycle number
- `max_cycles` - maximum cycles (3)
- `issues_fixed` - array of fixed issues
- `issues_skipped` - array of skipped issues
- Story file content with acceptance criteria
- List of changed files
- Architecture context

---

## REVIEW LOOP SEQUENCE:

### 1. Increment Cycle Counter

```
cycle_count = cycle_count + 1
```

Display:
```
───────────────────────────────────────────────────────────────
  CYCLE {cycle_count} of {max_cycles}
───────────────────────────────────────────────────────────────
```

### 2. Run Codex Adversarial Review

Execute Codex in report-only mode.

#### 2a. Build the Codex Prompt

**Base prompt (always included):**
```
Run the /bmad:bmm:workflows:code-review workflow on the current branch. Return findings as a structured list with: severity (HIGH/MEDIUM/LOW), file path, line number, issue description, and suggested fix.
```

**If `cycle_count > 1` AND `issues_skipped` is not empty, append this context:**
```

IMPORTANT: The following issues were found in previous cycles but dismissed as false positives. DO NOT report these issues again:

{For each item in issues_skipped:}
- File: {file}, Line: {line}
  Issue: {issue}
  Suggested Fix: {suggested_fix}
  Reason Dismissed: {reason}

Focus only on NEW issues not listed above.
```

#### 2b. Execute Codex

**IMPORTANT:** This command may take several minutes to complete. When invoking via the Bash tool, set the timeout to 10 minutes (600000ms).

```bash
codex exec --full-auto \
  -c 'headless=true' \
  -c 'auto_fix_mode="report-only"' \
  "{constructed_prompt}"
```

**IMPORTANT:** Do NOT use the `-m` flag to specify a model. Always use Codex's configured default model.

Capture the output from Codex.

### 3. Parse Codex Findings

Parse the Codex output to extract findings. Expected format:

```
FINDING 1:
  Severity: HIGH|MEDIUM|LOW
  File: path/to/file.py
  Line: 42
  Issue: Description of the problem
  Suggested Fix: How to fix it

FINDING 2:
  ...
```

If Codex returns "No issues found" or empty findings:
- Set `exit_reason = "clean"`
- Proceed to step 3 (finalize)

### 4. Validate Each Finding

For EACH finding from Codex:

#### 4a. Read the Relevant Code

Read the file and surrounding context (10 lines before/after the reported line).

#### 4b. Check Against Codebase

Ask yourself:
- Does this issue actually exist in the code?
- Is the code actually problematic, or is Codex misunderstanding?
- Does the code follow project patterns and architecture?

#### 4c. Check Against Story Requirements

Ask yourself:
- Is this relevant to the story's acceptance criteria?
- Does fixing this align with the story's goals?
- Is this within scope of the current work?

#### 4d. Classify the Finding

**VALID** if:
- The issue genuinely exists in the code
- Fixing it improves code quality, security, or correctness
- It's relevant to the current story

**FALSE_POSITIVE** if:
- The code is actually correct
- Codex misunderstood the pattern or intent
- The issue is out of scope for this story
- The "fix" would break other functionality

### 5. Process Validated Findings

#### 5a. For VALID Issues

For each VALID issue:
1. Fix the issue in the code
2. Add to tracking:
   ```
   issues_fixed.append({
     cycle: cycle_count,
     file: "path/to/file",
     issue: "Brief description",
     fix: "What was changed"
   })
   ```

#### 5b. For FALSE_POSITIVE Issues

For each FALSE_POSITIVE:
1. Do NOT modify any code
2. Add to tracking with FULL context (so Codex won't report it again):
   ```
   issues_skipped.append({
     cycle: cycle_count,
     severity: "HIGH|MEDIUM|LOW",
     file: "path/to/file",
     line: 42,
     issue: "Full issue description from Codex",
     suggested_fix: "The fix Codex suggested",
     reason: "Why this was dismissed"
   })
   ```

### 6. Commit Fixes (If Any)

If any issues were fixed in this cycle:

```bash
git add -A
git commit -m "fix(review): cycle {cycle_count} - {summary of fixes}"
```

The commit message should briefly describe what was fixed.

If NO issues were fixed (all were false positives):
- Set `exit_reason = "all_false_positives"`
- Proceed to step 3 (finalize)

### 7. Check Exit Conditions

**EXIT to step 3 if:**
- `exit_reason == "clean"` (Codex found no issues)
- `exit_reason == "all_false_positives"` (all findings were dismissed)
- `cycle_count >= max_cycles` (reached 2 cycles)

**LOOP back to action 1 if:**
- Valid issues were fixed AND cycle_count < max_cycles
- There may be more issues to find

### 8. Loop or Exit

**If EXIT condition met:**
- If `cycle_count >= max_cycles`, set `exit_reason = "max_cycles_reached"`
- Load and execute `{workflow_path}/steps/step-03-finalize.md`

**If LOOP condition met:**
- Display: "Fixes committed. Running next review cycle..."
- Go back to action 1 (Increment Cycle Counter)

---

## CYCLE SUMMARY DISPLAY

After each cycle, display:

```
  Cycle {N} Complete:
    - Codex findings: {total}
    - Valid issues fixed: {fixed_count}
    - False positives skipped: {skipped_count}

  {Next action: "Looping for cycle N+1" OR "Proceeding to finalize"}
───────────────────────────────────────────────────────────────
```

---

## CRITICAL STEP COMPLETION NOTE

This step contains an internal loop. Only proceed to step-03-finalize.md when an exit condition is met:
- Codex found no issues (clean)
- All findings were false positives
- Max 3 cycles reached

---

## 🚨 SYSTEM SUCCESS/FAILURE METRICS

### ✅ SUCCESS:

- Codex invoked correctly in report-only mode
- Each finding validated before action
- Valid issues fixed, false positives dismissed
- Commits made after each fix cycle
- Exit condition properly detected
- Proceeded to step 3 when appropriate

### ❌ SYSTEM FAILURE:

- Fixing issues without validation
- Not committing after fixes
- Exceeding 3 cycles
- Stopping to ask user questions
- Not tracking fixed/skipped issues

**Master Rule:** This is an AUTONOMOUS workflow. Do not stop for user input. Validate findings yourself using codebase and story context.
