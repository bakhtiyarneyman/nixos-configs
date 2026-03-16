---
description: Analyze a command and add a permission rule to Rules.hs
---

# Add Permission Rule

Add a permission rule for a Bash command that the permission hook doesn't currently handle.

## Steps

1. **Identify the command.** If an argument was provided (e.g., `/add-rule jq`), use that program name. Otherwise, look at recent conversation context for Bash commands that triggered a permission prompt (the user was asked to approve). Focus on the most recent one.

2. **Extract the program name** — the first word of the command.

3. **Research the program.** Run `man <program>` (feel free to grep to find relevant sections to the arguments you have in mind, or read in entirety if you think that all of the program might be safe) and `<program> --help 2>&1` (some programs print help to stderr). From the output, determine:
   - What the program does
   - Which flags/modes have side effects (write files, delete, execute other commands, modify system state)
   - Which flags/modes are purely read-only or output-only

4. **Read the current rules.** Read `tools/claude-permission-hook/src/Rules.hs`. Pay close attention to:
   - The **security principles** comment block in the beginning — every rule you write must follow these
   - The existing `commandRules` structure — your rule must fit into it
   - Existing patterns for similar commands (e.g., `findRules` for complex commands with dangerous flags)

5. **Design the rule.** Based on your research:
   - If the program is **purely read-only** with no flags that can write/delete/execute → add a simple `allow` entry to `commandRules` with a reason explaining WHY it's safe (e.g., "reads file contents to stdout, no flags can write or execute")
   - If **some flags are dangerous** → create a sub-rule function (like `findRules`) that whitelists known-safe flag patterns. Dangerous flags must not be in the whitelist — they fall through to the engine's default "ask".
   - If the program **executes subcommands** (like `xargs`, `parallel`) → use `recurse` to evaluate the subcommand
   - If the specific invocation the user approved was safe but you can't easily generalize → add a narrow rule for that specific usage pattern, not a broad allow

6. **Edit Rules.hs.** Add the rule to the appropriate section in `commandRules`. If you created a sub-rule function, add it after the existing sub-rule functions following the same style.

7. **Verify.** After editing, check that the file still has valid Haskell syntax — all strings are closed, all brackets are balanced, imports are present if needed.
