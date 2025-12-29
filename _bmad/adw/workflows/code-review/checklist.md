# Code Review (GLM) - Validation Checklist

## Context Gathering
- [ ] Story file loaded from git branch detection
- [ ] Story acceptance criteria parsed
- [ ] Git diff executed to identify changed files
- [ ] Architecture/standards docs loaded (as available)
- [ ] Project context loaded (if exists)

## GLM Review Execution
- [ ] Review prompt constructed with full context
- [ ] JSON output schema included in prompt
- [ ] GLM subagent spawned via Task tool (run_in_background: true)
- [ ] TaskOutput used to retrieve results (with timeout)
- [ ] JSON response parsed and validated

## Output
- [ ] Issues array extracted from GLM response
- [ ] Issue counts calculated (error/warning/info)
- [ ] JSON output delivered (raw for headless, formatted for interactive)

## JSON Schema Compliance
Each issue must have:
- [ ] `id`: "review-NNN" format
- [ ] `severity`: "error" | "warning" | "info"
- [ ] `description`: Clear problem description
- [ ] `location`: "file:line" format
- [ ] `context.suggestion`: Fix recommendation
- [ ] `context.code_snippet`: Relevant code fragment

_Reviewer: {{user_name}} on {{date}}_
