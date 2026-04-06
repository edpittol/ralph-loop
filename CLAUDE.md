# Claude Instructions for ralph-loop Skill

## Project Overview
This is the ralph-loop skill project, designed to run the Ralph Loop on any project for autonomous iterative development driven by a PRD with user stories.

## Key Features
- Run Ralph Loop on any project
- PRD-driven development with user stories
- AFK autonomous development capability

## GitHub Integration
- Use `gh` command to integrate with GitHub
- #<number> is a reference to an issue or pull request on GitHub
- PRD description are stored as GitHub issue
- When is requested to update a PRD, add a comment in the issue with the difference. Use `diff` command to create it.

## Development Guidelines

### Code Review
- The QA process MUST BE always green

### PR Creation Feature
- When all user stories are complete (`passes: true`), the agent runs `bash "{{SKILL_DIR}}/scripts/create-pr.sh"`
- PR creation happens at completion, not per story
- The script checks for GitHub CLI availability and authentication
- PR titles respect GitHub issues from the PRD when specified
- RALPH.md can override PR configuration (title, target branch, disable creation)
- Draft PRs are created by default

### Development Hints
- Scripts cannot use absolute paths. Considere always relative from the project path defined as argumento on `launch.sh`
- Prefer always to use `scripts/common.sh` functions. Create new functions every opportunity.
