---
description: Use after completing a task to systematically identify mistakes, derive abstract lessons, and record them. Triggered by the CLAUDE.md instruction "analyze your mistakes and propose updates to these instructions."
---

# Analyze Mistakes

Systematic retrospective after completing a task. Derives abstract, reusable lessons and records them where they'll prevent future mistakes.

## Process

### 1. Trace decision points

Walk through the conversation chronologically. At each point where you made a choice, record:
- **What you decided** (the action taken)
- **What alternatives existed** (what you could have done instead)
- **What happened** (the outcome — correction, rejection, wasted work)

Don't stop at the first mistake. Trace ALL decision points, including ones where you were corrected and ones where you got lucky.

### 2. Classify each mistake

For each bad decision, ask: **"What class of mistake is this?"**

Common classes:
- **Constraint violation**: A stated rule existed and you didn't follow it
- **Rationalization**: You knew the constraint but argued your way around it
- **Shallow analysis**: You didn't gather enough facts before acting
- **Wrong abstraction level**: You proposed a specific fix when a general principle was needed, or vice versa
- **Precedent fallacy**: You used existing behavior to justify new behavior without questioning whether the existing behavior was correct

### 3. Check existing instructions

For each abstract lesson, search CLAUDE.md files for existing instructions that should have prevented the mistake.

Three outcomes:
- **No instruction exists** → Genuine gap. Write a new instruction.
- **Instruction exists but is too vague** → Needs to be more specific or stronger. Edit it.
- **Instruction exists and is clear** → You ignored it. Ask WHY — was it buried? Did you rationalize around it? The fix might be restructuring, not adding.

### 4. Verify preventive power

For each proposed lesson, answer: **"If this instruction had existed at the start, would I have avoided the mistake?"**

If "probably not" — the lesson is too abstract or addresses the wrong thing. Dig deeper into why the mistake actually happened.

### 5. Determine placement

- **Global CLAUDE.md**: Abstract principles applicable across all projects
- **Project CLAUDE.md**: Project-specific conventions and technical constraints

### 6. Write concise instructions

Each instruction must:
- Include a **triggering condition** — when does this instruction apply? ("When X, do Y" not just "Do Y")
- Be one sentence (two at most)
- Be actionable and falsifiable (you can tell when you're violating it)
- Be abstract enough to apply beyond this specific situation

### 7. Propose edits to the user

Show the full analysis, then propose the actual CLAUDE.md edits (not just descriptions of what should change). Let the user accept, reject, or modify each.

## Termination

This skill is itself a task. To avoid infinite recursion: after running, check if the analysis produced any CLAUDE.md edits. If yes, briefly scan the analysis itself for mistakes — but only propose changes to the skill, not another full retrospective. If no edits were produced, stop.

## Anti-patterns

- **Surface-level enumeration**: Listing "I made mistake X" without tracing WHY
- **Dismissing as "already covered"**: An instruction you violated isn't "covering" the mistake — it's failing to prevent it
- **Trivial additions**: If your lesson is just restating what went wrong, it's not abstract enough
- **Kitchen sink**: Adding every possible lesson dilutes the important ones. Propose only lessons with clear preventive power
- **Missing trigger**: Instructions without conditions fire everywhere or nowhere. Always specify when.
