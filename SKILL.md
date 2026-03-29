---
name: ralph-loop
description: Run the Ralph Loop on any project. Autonomous iterative development driven by a PRD with user stories. Use when the user wants to run ralph, start a ralph loop, do AFK autonomous development, or iterate through user stories.
---

# Global ralph

Ralph Loop runs an AI agent in an iterative loop. Each iteration picks one user story from a PRD, implements it, runs QA, commits, and marks it done. The loop continues until all stories pass.

## Setup flow

When this skill triggers, follow these steps:

### 1. Determine the target project

If the current working directory is a git repository, use it as the target project. Otherwise, ask the user for the project path.

### 2. Initialize state

Run the init script if the project has no ralph state yet:

```bash
bash {{SKILL_DIR}}/scripts/init-project.sh <project-path>
```

This creates the state directory at `$CLAUDE_CONFIG_DIR/projects/{encoded-path}/ralph/` with a template prd.json and progress.txt.

### 3. Create or update the PRD

If prd.json is empty or contains the template, help the user create a PRD:

1. Read context from the conversation and any referenced files the user provided
2. Ask the user for a high-level description if not already provided
3. Ask for a branch name (default: `ralph/<feature>`)
4. Generate prd.json with user stories. Each story needs: id, title, description, acceptanceCriteria, priority, passes (false)
5. Automatically append a final story as the lowest priority: "Update project documentation with learnings" — this story reads codebase patterns from progress.txt and updates CLAUDE.md files in directories modified during the run
6. Show the generated PRD to the user for review and refinement

The PRD format follows `references/prd-template.json`. See the real example at the state directory for reference.

### 4. Mention RALPH.md

Tell the user they can optionally create a `RALPH.md` file at the project root for ralph-specific instructions (e.g., QA commands, conventions, directories to avoid). The agent reads this file each iteration if present.

### 5. Show the launch command

Provide the command to start the AFK loop:

```bash
bash {{SKILL_DIR}}/scripts/launch.sh <project-path> --max-iterations 10
```

The user runs this in a terminal and walks away. The launch script:
- Creates a git worktree for the branch
- Sets up the stop-hook for the loop mechanism
- Starts Claude autonomously

## Resuming

If ralph state already exists with incomplete stories (some with `passes: false`):
1. Read prd.json and show a status summary (completed vs remaining stories)
2. Read progress.txt for any codebase patterns or recent learnings
3. Provide the launch command to continue

## Status check

To check progress on a project:
1. Read `$CLAUDE_CONFIG_DIR/projects/{encoded-path}/ralph/prd.json` for story status
2. Read `$CLAUDE_CONFIG_DIR/projects/{encoded-path}/ralph/progress.txt` for learnings and iteration history

## How the loop works

1. `launch.sh` creates a worktree and starts Claude with the agent prompt
2. Claude implements one user story, commits, and tries to exit
3. The stop-hook intercepts the exit and feeds the same prompt back
4. Claude reads the updated PRD, picks the next story, and continues
5. When all stories pass, Claude outputs `<promise>COMPLETE</promise>` and the loop ends

Each iteration's learnings persist in progress.txt, so subsequent iterations (and future runs) build on accumulated knowledge.
