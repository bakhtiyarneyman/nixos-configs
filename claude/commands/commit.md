---
description: Use after completing a task to commit the session's changes before /analyze-mistakes. Detects worktree vs shared tree and adapts.
---

# Commit Session Changes

## Step 0: Detect worktree

```bash
# If these differ, you're in a worktree
git rev-parse --git-common-dir
git rev-parse --git-dir
```

If in a **worktree** → follow the Worktree Path.
If in a **shared tree** → follow the Shared Tree Path.

---

## Worktree Path

The worktree is exclusive to this session — no concurrent changes to worry about.

### 1. Survey

Run in parallel:
- `git status` — all modified/untracked files
- `git diff` — read the actual diffs
- `git log --oneline -5 master` — match commit message style

### 2. Stage and commit

```bash
git add -A                          # safe — exclusive worktree
git diff --cached --stat            # review what's staged
git commit -m "$(cat <<'EOF'
Message here.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### 3. Merge into master

```bash
git -C <main-tree> merge <branch>  # merge from main tree, no checkout needed
git log --oneline -3 master         # verify
```

---

## Shared Tree Path

Other Claude sessions may have uncommitted changes in the same working tree — never stage their work.

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
git commit -m "$(cat <<'EOF'
Message here.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
git status                          # confirm clean
```

---

## Rules (both paths)

- **Never stage secrets** — skip .env, credentials, key files.
- **Never amend** — create new commits.
- **Never push** unless the user explicitly asks.
- Commit message: 1-2 sentences on WHY, not WHAT. Use HEREDOC.
- Before committing, scan CLAUDE.md files for stale references to behavior you changed.
- Substitute your actual model name in the Co-Authored-By trailer.

### Shared tree only

- **Never `git add` a modified file** — stages the entire file including concurrent changes. Only safe for new (untracked) files.
- **Never pipe diff into apply** — inspect diffs, write only your hunks to a patch via Write tool.
- **Chain apply+commit atomically** — join all `git apply --cached` calls and `git commit` in one `&&` chain to avoid partial staging.
- **Never `git stash`** — disrupts concurrent sessions' working trees.
