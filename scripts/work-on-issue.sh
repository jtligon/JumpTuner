#!/bin/bash
# Picks a random open GitHub issue and implements it in a fresh Claude Code session.
# Designed to run from crontab hourly.

set -euo pipefail

REPO="jtligon/JumpTuner"
WORK_DIR="/Users/jtligon/Documents/JumpTuner/JumpTuner"
LOG_DIR="$WORK_DIR/logs"
LOG_FILE="$LOG_DIR/issue-worker-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"

# Redirect all output to a dated log file and stdout
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(date)] Starting issue worker"

# Pick a random open issue that doesn't already have an open PR
echo "[$(date)] Fetching open issues..."
ISSUES=$(gh issue list --repo "$REPO" --state open --json number,title,body --limit 50)
COUNT=$(echo "$ISSUES" | jq length)

if [ "$COUNT" -eq 0 ]; then
  echo "[$(date)] No open issues. Exiting."
  exit 0
fi

# Shuffle and find the first issue without an existing open PR
SELECTED=""
for IDX in $(python3 -c "import random,sys; l=list(range($COUNT)); random.shuffle(l); print(' '.join(map(str,l)))"); do
  ISSUE_NUMBER=$(echo "$ISSUES" | jq -r ".[$IDX].number")
  # Check if there's already a PR for this issue
  EXISTING_PR=$(gh pr list --repo "$REPO" --state open --json number,title | \
    jq -r ".[] | select(.title | test(\"#$ISSUE_NUMBER\")) | .number" 2>/dev/null || true)
  # Also check branch name convention
  BRANCH_EXISTS=$(gh api "repos/$REPO/branches" --paginate --jq ".[].name" 2>/dev/null | \
    grep -E "^issue-${ISSUE_NUMBER}-" || true)
  if [ -z "$EXISTING_PR" ] && [ -z "$BRANCH_EXISTS" ]; then
    SELECTED="$IDX"
    break
  fi
  echo "[$(date)] Issue #$ISSUE_NUMBER already has a PR or branch, skipping."
done

if [ -z "$SELECTED" ]; then
  echo "[$(date)] All open issues already have PRs. Exiting."
  exit 0
fi

ISSUE_NUMBER=$(echo "$ISSUES" | jq -r ".[$SELECTED].number")
ISSUE_TITLE=$(echo "$ISSUES" | jq -r ".[$SELECTED].title")
ISSUE_BODY=$(echo "$ISSUES" | jq -r ".[$SELECTED].body // \"(no description)\"")

echo "[$(date)] Selected issue #$ISSUE_NUMBER: $ISSUE_TITLE"

# Build the prompt for the fresh Claude session
PROMPT="You are working on the JumpTuner iOS app at /Users/jtligon/Documents/JumpTuner/JumpTuner (GitHub: jtligon/JumpTuner).

Your task is to implement GitHub issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}

Issue description:
${ISSUE_BODY}

Instructions:
1. cd into /Users/jtligon/Documents/JumpTuner/JumpTuner and create a branch named issue-${ISSUE_NUMBER}-<short-slug> from latest origin/main.
2. If there is too much ambiguity to proceed, post a comment on the issue asking clarifying questions, then exit without writing code.
3. Otherwise implement with TDD: write failing tests first and commit them, then write the implementation and commit it.
4. Use the Swift Testing framework (import Testing, @Suite, @Test, #expect) — NOT XCTest.
5. Open a PR against main. Include 'Closes #${ISSUE_NUMBER}' in the PR body.
6. Do not ask for confirmation at any step — make judgment calls and proceed."

echo "[$(date)] Spawning fresh Claude Code session..."
claude --dangerously-skip-permissions -p "$PROMPT"
echo "[$(date)] Claude session finished."
