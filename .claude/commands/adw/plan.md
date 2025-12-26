# Plan

Create a new implementation plan for the `Issue` using the exact specified markdown `Plan Format`. Follow the `Instructions` to create the plan and use the `Relevant Files` to focus on the right files.

## Variables
issue_number: $1
adw_id: $2
issue_json: $3

## Instructions

- IMPORTANT: You're writing an implementation plan based on the `Issue` that will add value to the application.
- IMPORTANT: The `Issue` describes what needs to be done but remember we're not implementing it yet, we're creating the plan that will be used to implement it based on the `Plan Format` below.
- Create the plan in the `specs/` directory with filename: `issue-{issue_number}-adw-{adw_id}-{descriptive-name}.md`
  - Replace `{descriptive-name}` with a short, descriptive name based on the issue (e.g., "add-auth-system", "fix-login-error", "update-dependencies")
- Use the `Plan Format` below to create the plan.
- Research the codebase to understand existing patterns, architecture, and conventions before planning.
- IMPORTANT: Replace every <placeholder> in the `Plan Format` with the requested value. Add as much detail as needed to implement successfully.
- Use your reasoning model: THINK HARD about the requirements, design, and implementation approach.
- Follow existing patterns and conventions in the codebase. Don't reinvent the wheel.
- Be surgical with changes - solve the problem at hand and don't fall off track.
- We want the minimal number of changes that will accomplish the task.
- If you need a new library, use `uv add` and be sure to report it in the `Notes` section of the `Plan Format`.
- Don't use decorators. Keep it simple.
- IMPORTANT: If the issue includes UI components or user interactions:
  - Add a task in the `Step by Step Tasks` section to create a separate E2E test file in `.claude/commands/e2e/test_<descriptive_name>.md` based on examples in that directory
  - Add E2E test validation to your Validation Commands section
  - IMPORTANT: When you fill out the `Plan Format: Relevant Files` section, add an instruction to read `.claude/commands/test_e2e.md`, and `.claude/commands/e2e/test_basic_query.md` to understand how to create an E2E test file. List your new E2E test file to the `Plan Format: New Files` section.
- Respect requested files in the `Relevant Files` section.
- Start your research by reading the `README.md` file.

## Relevant Files

Focus on the following files:
- `README.md` - Contains the project overview and instructions.
- `app/server/**` - Contains the codebase server.
- `app/client/**` - Contains the codebase client.
- `scripts/**` - Contains the scripts to start and stop the server + client.
- `adws/**` - Contains the AI Developer Workflow (ADW) scripts.

- Read `.claude/commands/conditional_docs.md` to check if your task requires additional documentation
- If your task matches any of the conditions listed, include those documentation files in the `Plan Format: Relevant Files` section of your plan

Ignore all other files in the codebase.

## Plan Format

```md
# Issue: <issue title>

## Metadata
issue_number: `{issue_number}`
adw_id: `{adw_id}`
issue_json: `{issue_json}`

## Description
<describe the issue in detail, including its purpose and value>

## Problem Statement
<clearly define the specific problem or opportunity this issue addresses>

## Solution Statement
<describe the proposed solution approach and how it solves the problem>

## Relevant Files
Use these files to implement the solution:

<find and list the files that are relevant to the issue, describe why they are relevant in bullet points. If there are new files that need to be created, list them in an h3 'New Files' section.>

## Step by Step Tasks
IMPORTANT: Execute every step in order, top to bottom.

<list step by step tasks as h3 headers plus bullet points. use as many h3 headers as needed to implement the solution. Order matters, start with the foundational shared changes required then move on to the specific implementation. Include creating tests throughout the implementation process.>

<If the issue affects UI, include a task to create a E2E test file (like `.claude/commands/e2e/test_basic_query.md`) as one of your early tasks. That e2e test should validate the functionality works as expected, be specific with the steps to demonstrate the new functionality.>

<Your last step should be running the `Validation Commands` to validate everything works correctly with zero regressions.>

## Testing Strategy
### Unit Tests
<describe unit tests needed>

### Edge Cases
<list edge cases that need to be tested>

## Acceptance Criteria
<list specific, measurable criteria that must be met for the issue to be considered complete>

## Validation Commands
Execute every command to validate everything works correctly with zero regressions.

<list commands you'll use to validate with 100% confidence the implementation is correct with zero regressions. every command must execute without errors.>

<If you created an E2E test, include the following validation step: `Read .claude/commands/test_e2e.md`, then read and execute your new E2E `.claude/commands/e2e/test_<descriptive_name>.md` test file to validate this functionality works.>

- `cd app/server && uv run pytest` - Run server tests to validate with zero regressions
- `cd app/client && bun tsc --noEmit` - Run frontend type checks
- `cd app/client && bun run build` - Run frontend build to validate with zero regressions

## Notes
<optionally list any additional notes, future considerations, or context that will be helpful to the developer>
```

## Issue
Extract the issue details from the `issue_json` variable (parse the JSON and use the title and body fields).

## Report

- IMPORTANT: Return exclusively the path to the plan file created and nothing else.
