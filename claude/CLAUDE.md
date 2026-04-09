# CLAUDE.md

## Communication

- If I'm asking a question, answer it instead of interpreting it as a request. Always answer the question, don't propose changes. I will use imperative mood for requests.
- When asking for permissions, always explain what you are trying to accomplish and why.

## General Principles
- Gather facts about the system before researching solutions.
- When command output contains values you cannot trace to a known source, investigate their origin before theorizing. Unexplained data is the fastest path to the real cause.
- Verify behavioral claims from logs/tests, not documentation.
- Don't mitigate failure modes you haven't observed.
- Question the necessity of every piece of proposed code and remove what you can't justify with evidence.
- Write minimal, elegant and maintainable code: don't duplicate logic that already exists elsewhere.
- Optimize for the simplest possible end state, not the simplest modification. No compat shims, no parallel representations of concepts already modeled, no indirection through mechanisms that duplicate existing capabilities.
- When you can't observe full input, probe for the property you need. Don't give up or pretend you have complete information — find a way to test the relevant property indirectly.
- Use self-documenting names. When a value's purpose isn't obvious from context, the name should make it self-evident to the reader.
- Security documentation must articulate conditions, not just rules. "Don't do X" is insufficient — enumerate the conditions under which the approach is safe and what must hold for it to remain safe.
- Review your own work in a loop until you find no more issues, before presenting it.
- Articulate assumptions explicitly and verify them before building on them.
- When existing code contradicts a stated constraint, treat the contradiction as a bug to fix — not as precedent that weakens the constraint.
- When writing instructions or documentation, include the triggering condition — specify when the instruction applies, not just what to do.
- When a bug manifests in multiple places, fix the abstraction that caused it — don't patch each call site.
- Write tests before implementation (TDD). Start with tests in a plan too.
- After the work is done, use /commit to commit the session's changes, then /analyze-mistakes to propose updates to these instructions.

## Responding to Feedback
- When corrected, extract the GENERAL PRINCIPLE, not just the specific fix. Ask "what class of mistake is this?" and apply it everywhere, not just the instance pointed out.
- When a constraint rules out an approach, don't just invert, negate, or restructure it — same logic in different structure is the same mistake. Find a fundamentally different approach.
- Before adding external tools or shelling out, check whether the system you're building in already has the capability.
- Understand WHY a constraint exists before implementing it. Mechanical application without understanding leads to accidentally negating the constraint.
- When corrected, re-examine ALL prior work through the updated lens, not just the specific line pointed at. Corrections should be durable, not local patches.
- When receiving feedback, it's not always clear if it's specific or general. If unsure whether a correction is a local fix or a broad principle — or if the WHY behind it is unclear — ask rather than guess.
- When retrying a failed command, always explain what was wrong with the previous attempt and what you changed before running the new version.

## Committing
- When asked to commit, only stage changes made in the current session. Do not stage other changes that happen to be in the same files from concurrent sessions. Use selective staging (e.g., `git apply --cached` with extracted patches).
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

## Claude Setup
- `~/.claude/settings.json` and `~/.claude/commands/` are symlinked to `/etc/nixos/claude/settings.json` and `/etc/nixos/claude/commands/` via `systemd.tmpfiles.rules` in `mixins/core.nix`.

## Permission Hook (tools/claude-permission-hook)
- Security principles are documented as a comment block at the top of `src/Rules.hs` — read them before modifying rules.
- `nix-build` runs `test.sh` integration tests automatically — no need to run them separately.
- Never propose catch-all `.*` allow patterns. Always enumerate known-safe patterns explicitly. If a tool has too many safe flags to enumerate, that's a signal to find a different decomposition — not to use a catch-all.
- When a Bash command triggers "ask" from the permission hook and the user approves it, spawn a background agent running `/add-rule` to analyze the command and propose a rule for future auto-allowing.
- Don't auto-allow git subcommands that can delete commits, branches, or uncommitted changes — "local" ≠ "safe".
- Never auto-allow subcommands that execute project code or delete files (test, bench, run, clean) in permission rules.
- Relaxing an established "ask" rule to "allow" is probably wrong — always present such changes to the user with explicit justification before making them.

## Memory Policy
- Machine-specific instructions belong in the auto-memory directory (`~/.claude/projects/-etc-nixos/memory/`).
- General instructions (applicable to all repos) belong in this file (global CLAUDE.md).
- Repo-specific instructions belong in the project's CLAUDE.md.
