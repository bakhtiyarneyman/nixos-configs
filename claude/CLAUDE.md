# CLAUDE.md

## Communication

- If I'm asking a question, answer it instead of interpreting it as a request. Always answer the question, don't propose changes. I will use imperative mood for requests.
- When asking for permissions, always explain what you are trying to accomplish and why.

## General Principles
- Gather facts about the system before researching solutions.
- When command output contains values you cannot trace to a known source, investigate their origin before theorizing. Unexplained data is the fastest path to the real cause.
- Verify behavioral claims from logs/tests, not documentation.
- Don't mitigate failure modes you haven't observed. Example: when passing data through multiple layers (shell → IPC → subprocess), don't add encoding infrastructure for hypothetical special characters — pass the data directly until a real input breaks.
- Question the necessity of every piece of proposed code and remove what you can't justify with evidence.
- Write minimal, elegant and maintainable code: don't duplicate logic that already exists elsewhere.
- When comparing solutions, prioritize in this order: (1) correctness, (2) efficiency, (3) lowest complexity of the resulting solution. Judge complexity by the end state, not the diff. No compat shims, no parallel representations of concepts already modeled, no indirection through mechanisms that duplicate existing capabilities. Example: when modifying a data consumer, trace back to producers — extraction or embedding that nothing reads anymore is dead complexity in the end state.
- When you can't observe full input, probe for the property you need. Don't give up or pretend you have complete information — find a way to test the relevant property indirectly.
- Use self-documenting names. When a value's purpose isn't obvious from context, the name should make it self-evident to the reader.
- When naming a pair of related things (client/server, source/sink, request/response), choose names from an established dual pair. Don't mix metaphors across the pair.
- Security documentation must articulate conditions, not just rules. "Don't do X" is insufficient — enumerate the conditions under which the approach is safe and what must hold for it to remain safe.
- Review your own work in a loop until you find no more issues, before presenting it.
- Articulate assumptions explicitly and verify them before building on them. In particular, verify file paths exist (via glob or ls) before embedding them in plans or commands.
- Before running a command that escalates privileges or changes execution context, trace what each step will run as and whether it can proceed non-interactively.
- When a command launches a process via a compositor, daemon, or service manager (swaymsg exec, systemd, etc.), trace the working directory and environment that process inherits — it is not the caller's.
- When generating text that will be embedded in another format (markup inside shell strings, HTML inside JSON, etc.), trace every escaping layer the text passes through before writing. Each layer may require its own escaping.
- When building a feature that needs data, check what's already provided in the immediate context (stdin, arguments, environment) and what already flows through the system's internal layers, before adding new plumbing or reading external sources.
- When building UI-visible changes (notifications, markup, terminal output) that you cannot directly observe, ask the user to verify each individual change before moving on. Don't stack multiple untested changes.
- When existing code contradicts a stated constraint, treat the contradiction as a bug to fix — not as precedent that weakens the constraint.
- When writing instructions or documentation, include the triggering condition — specify when the instruction applies, not just what to do.
- When a bug manifests in multiple places, fix the abstraction that caused it — don't patch each call site. This includes when a test fails due to a bug in supporting code (parser, framework, utility) — fix the underlying bug rather than adjusting the test inputs to avoid triggering it.
- Write tests before implementation (TDD). Start with tests in a plan too.
- After the work is done, use /commit to commit the session's changes, then /analyze-mistakes to propose updates to these instructions.
- When analyzing mistakes, extract a learning from every failure — even if an existing instruction covers it. If an instruction was violated, add examples showing how the abstraction applies to non-obvious cases, so the connection is easier to see next time.

## Responding to Feedback
- When corrected, extract the GENERAL PRINCIPLE, not just the specific fix. Ask "what class of mistake is this?" and apply it everywhere, not just the instance pointed out.
- When a constraint rules out an approach, don't just invert, negate, or restructure it — same logic in different structure is the same mistake. Find a fundamentally different approach.
- Before adding external tools or shelling out, check whether the system you're building in already has the capability.
- Understand WHY a constraint exists before implementing it. Mechanical application without understanding leads to accidentally negating the constraint.
- When corrected, re-examine ALL prior work through the updated lens, not just the specific line pointed at. Corrections should be durable, not local patches.
- When receiving feedback, it's not always clear if it's specific or general. If unsure whether a correction is a local fix or a broad principle — or if the WHY behind it is unclear — ask rather than guess.
- When a tool call is rejected, read the rejection reason carefully before deciding on a next action. The reason often contains the fix.
- When a command fails or is rejected, never resubmit it unchanged — diagnose the failure, explain what was wrong, and describe the fix before running the corrected version.
- When a plan revision is rejected, don't just fix the cited issue — make the entire plan consistent with the fix. If the fix implies a cleaner API style, update naming, error handling, and structure to match.

## Committing
- In a worktree (`git rev-parse --git-common-dir` differs from `--git-dir`), `git add -A` is safe — the worktree is exclusive. Merge into master after committing.
- In a shared tree, only stage changes made in the current session. Do not stage other changes that happen to be in the same files from concurrent sessions. Use selective staging (e.g., `git apply --cached` with extracted patches).
- Never use `git stash` — other Claude sessions may be working off the same directory concurrently. Stashing would disrupt their working tree.
- After implementation, before committing, scan CLAUDE.md files and instructions for stale references to the behavior you changed.

## Development Principles
- Don't spawn exploration agents for simple, targeted edits — just read the file.
- Do not remove temporary debugging facilities until proven working.
- Use pkexec to execute privileged commands.
- When authentication prompts (pkexec, sudo) fail or get cancelled, ask the user before trying alternative commands.
- When pkexec fails restart soteria user service with `systemctl --user restart polkit-soteria.service`.
- Use exec to record debug messages in bash scripts.
- Never read files with passwords, stat them
- Never see or handle secret values directly. Generate secrets by piping (e.g., `openssl rand -hex 32 > /path/to/secret`)
- When claude is used via ssh, `sudo` must be used instead of `pkexec`.
- In Haskell, never make unnecessary states representable. Each sum type constructor should carry exactly the data it needs — don't add shared fields only used by one variant.
- When propagating data through layers, preserve structural representation (types, lists, records) until the final output stage. String concatenation is lossy — structure first, format last.
- When working in a git worktree, always use worktree-relative paths for file reads and edits. Never reference the original repo path (e.g., use `./tools/foo` not `/etc/nixos/tools/foo` when CWD is a worktree).
- When launching GUI programs (alacritty, etc.) from scripts, check how they're invoked in sway.conf or other existing launch points — they may require flags like `--config-file` that aren't part of the default behavior.

## Claude Setup
- `~/.claude/settings.json` and `~/.claude/commands/` are symlinked to `/etc/nixos/claude/settings.json` and `/etc/nixos/claude/commands/` via `systemd.tmpfiles.rules` in `mixins/core.nix`.
- `/etc/claude-code/CLAUDE.md` is built from `/etc/nixos/claude/CLAUDE.md` via `environment.etc` in `mixins/core.nix`. To modify it, edit the source in `/etc/nixos/claude/CLAUDE.md` (requires `nixos-rebuild` to take effect).

## Permission Hook (tools/claude-permission-hook)
- Security principles are documented as a comment block at the top of `src/Rules.hs` — read them before modifying rules.
- `nix-build` runs `test.sh` integration tests automatically — no need to run them separately.
- Never propose catch-all `.*` allow patterns. Always enumerate known-safe patterns explicitly. If a tool has too many safe flags to enumerate, that's a signal to find a different decomposition — not to use a catch-all.
- Don't auto-allow git subcommands that can delete commits, branches, or uncommitted changes — "local" ≠ "safe".
- Never auto-allow subcommands that execute project code or delete files (test, bench, run, clean) in permission rules.
- Relaxing an established "ask" rule to "allow" is probably wrong — always present such changes to the user with explicit justification before making them.

## Memory Policy
- Auto-memory (`~/.claude/projects/-etc-nixos/memory/`) is ONLY for machine-specific facts (e.g., "this machine is iron"). Never write general principles, feedback, or project knowledge there — those belong in CLAUDE.md files. When tempted to save a memory, ask: "Is this specific to this machine?" If no, don't save it.
- General instructions (applicable to all repos) belong in this file (global CLAUDE.md).
- Repo-specific instructions belong in the project's CLAUDE.md.
