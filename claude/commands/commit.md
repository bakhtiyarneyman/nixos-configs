---
description: Use after completing a task to commit the session's changes before /analyze-mistakes. Enforces selective staging for concurrent session safety.
---

# Commit Session Changes

Commit changes from the current session only. Other Claude sessions may have uncommitted changes in the same working tree — never stage their work.

## Process

### 1. Survey

Run in parallel:
- `git status` — all modified/untracked files
- `git diff` — read the actual diffs to see what changed
- `git log --oneline -5` — match commit message style

### 2. Inspect and extract

For each modified file, read the `git diff` output and identify which hunks are from your session. Then write a patch file containing **only your hunks** using the Write tool:

```bash
# Write only your hunks to a patch (use the Write tool, not shell redirection)
# Then stage it:
git apply --cached /tmp/<name>.patch
```

For **new files** you created (untracked — not in `git diff`):
```bash
git add <newfile>
```
Safe because untracked files have no concurrent changes.

**Never pipe `git diff` directly into `git apply --cached`** — this blindly stages all changes in the file, including concurrent sessions' work. Always inspect first, write only your hunks.

### 3. Verify, commit, verify

```bash
git diff --cached --stat            # confirm only your changes staged
git commit -m "$(cat <<'EOF'        # HEREDOC for formatting
Message here.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
git status                          # confirm clean
```

Substitute your actual model name in the Co-Authored-By trailer.

## Rules

- **Never `git add` a modified file** — stages the entire file including concurrent changes. Only safe for new (untracked) files.
- **Never pipe diff into apply** — inspect diffs, write only your hunks to a patch via Write tool.
- **Never `git stash`** — disrupts concurrent sessions' working trees.
- **Never amend** — create new commits.
- **Never stage secrets** — skip .env, credentials, key files.
- Commit message: 1-2 sentences on WHY, not WHAT. Use HEREDOC.
