module Rules (rules) where

import Protolude hiding (ask, check)
import Text.RawString.QQ (r)

import DSL

-- | Permission rules for Claude Code Bash commands.
--
-- SECURITY PRINCIPLES — read before adding or modifying rules:
--
-- 1. DEFAULT IS ASK. When no rule matches, the engine returns "ask".
--    This is the safe fallback. Never add catch-all allow rules to
--    override it.
--
-- 2. NO BLANKET ALLOWS. Never use a .* catch-all that allows unknown
--    flags or subcommands. Only explicitly known-safe patterns should
--    be allowed. If you're not certain a flag is safe, don't whitelist
--    it — let the default ask handle it.
--
-- 3. IMPLICIT ANCHORING. All regex patterns are wrapped in \A(?:...)\z
--    by the engine. This means partial matches are impossible — the
--    entire subject must match the pattern.
--
-- 4. WORD BOUNDARIES. When whitelisting flags that are prefixes of
--    other flags (e.g. -d vs -delete, -o vs -ok), use (?=\s|$) after
--    the alternation to prevent prefix matching.
--
-- 5. USE NATIVE REGEX, NOT SHELL TOOLS. Don't shell out to grep or
--    similar for matching. Use the DSL's PCRE regex matching. Shell
--    commands in `check` should only extract/transform data, not
--    filter it.
--
-- 6. CAPTURE AND SCRUTINIZE. For complex commands, capture relevant
--    parts with named groups (?P<name>...), then scrutinize the
--    captured value in a child node. E.g. capture find's args, then
--    match them against a safe-flag grammar.
--
-- 7. RECURSE FOR SUBCOMMANDS. Commands that execute other commands
--    (sudo, bash -c, env K=V cmd) must use `recurse` to evaluate
--    the inner command against the full rule tree.
--
-- 8. EXPLAIN WHY, NOT WHAT. Reason strings must explain why a command
--    is safe (e.g. "reads files to stdout, no write capability"), not
--    just name it (e.g. "cat command").
--
-- 9. DENY SPARINGLY. Only deny commands that are catastrophic and
--    unrecoverable (rm -rf /, mkfs, dd). Everything else should ask,
--    letting the user decide.
rules :: Node
rules =
  check
    "echo $FRAGMENT_TYPE"
    Stdout
    [ "command" ~> commandRules
    , "overwrite" ~> ask "file overwrite: $COMMAND"
    , "append" ~> ask "file append: $COMMAND"
    ]

-- | Dispatch on program name (first word of command).
commandRules :: Node
commandRules =
  check
    [r|echo "$COMMAND" | awk '{print $1}'|]
    Stdout
    -- Catastrophic: deny unconditionally.
    [ "rm" ~> rmRules
    , "mkfs" ~> deny "formats filesystems, destroys all data on device"
    , "dd" ~> deny "raw disk/file writes, can destroy data"
    , -- Pure builtins: no I/O, no flags change this.
      "echo" ~> allow "output to stdout only, cannot modify filesystem"
    , "printf" ~> allow "output to stdout only, cannot modify filesystem"
    , "true" ~> allow "no-op builtin, always succeeds"
    , "false" ~> allow "no-op builtin, always fails"
    , "test" ~> allow "evaluates expressions, no side effects"
    , [r|\[|] ~> allow "evaluates expressions, no side effects"
    , -- Read-only file inspection: no flags make these write.
      "cat" ~> allow "reads files to stdout, no write capability"
    , "head" ~> allow "reads beginning of files, no write capability"
    , "tail" ~> allow "reads end of files, no write capability"
    , "wc" ~> allow "counts lines/words/bytes, no write capability"
    , "diff" ~> allow "compares files, no write capability"
    , "file" ~> allow "identifies file types, no write capability"
    , "stat" ~> allow "displays file metadata, no write capability"
    , "md5sum" ~> allow "computes checksums, no write capability"
    , "sha256sum" ~> allow "computes checksums, no write capability"
    , "readlink" ~> allow "resolves symlinks, no write capability"
    , -- Read-only system queries: no flags can make these write.
      "ls" ~> allow "lists directory contents, no write capability"
    , "which" ~> allow "locates executables, no write capability"
    , "type" ~> allow "describes command type, no write capability"
    , "whereis" ~> allow "locates binaries/manpages, no write capability"
    , "whoami" ~> allow "prints current user, no write capability"
    , "id" ~> allow "prints user/group IDs, no write capability"
    , "hostname" ~> allow "prints hostname, no write capability"
    , "uname" ~> allow "prints system info, no write capability"
    , "date" ~> allow "prints date/time, no write capability"
    , "pwd" ~> allow "prints working directory, no write capability"
    , "realpath" ~> allow "resolves paths, no write capability"
    , "dirname" ~> allow "extracts directory component, no write capability"
    , "basename" ~> allow "extracts filename component, no write capability"
    , -- Search: read-only, cannot modify files.
      "find" ~> findRules
    , "grep" ~> allow "searches file contents, no write capability"
    , "rg" ~> allow "searches file contents, no write capability"
    , -- Network inspection: safe scanning flags only.
      "nmap" ~> nmapRules
    , -- Nix tooling: safe in this repo context.
      "nix" ~> allow "nix build/eval tooling"
    , "nix-build" ~> allow "nix build tooling"
    , "nix-instantiate" ~> allow "nix eval tooling"
    , "nix-store" ~> allow "nix store queries"
    , "alejandra" ~> allow "nix formatter, only rewrites formatting"
    , "nil" ~> allow "nix language server, read-only"
    , -- Commands that execute subcommands — must recurse.
      "sudo" ~> sudoRules
    , "env" ~> envRules
    , "bash" ~> bashRules
    , "sh" ~> shRules
    , "fish" ~> fishRules
    ]

-- | find: capture args, then match against known-safe flag grammar.
-- Dangerous flags (-exec, -delete, -fprint, etc.) are not in the
-- whitelist, so they fall through to the default ask.
findRules :: Node
findRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|find\s+(?P<args>.+)|] ~> findArgRules
    , "find" ~> allow "find with no arguments lists current directory"
    ]

findArgRules :: Node
findArgRules =
  check
    "echo $args"
    Stdout
    [ [r|(\s*(?:-(?:name|iname|path|ipath|wholename|iwholename|regex|iregex|type|xtype|size|perm|user|group|uid|gid|links|inum|samefile|mtime|mmin|atime|amin|ctime|cmin|newer|anewer|cnewer|used|fstype|context|maxdepth|mindepth|regextype|printf|files0-from|D)\s+(?:'[^']*'|"[^"]*"|\S+)|-(?:empty|readable|writable|executable|nouser|nogroup|noleaf|depth|d|mount|xdev|daystart|follow|true|false|warn|nowarn|ignore_readdir_race|noignore_readdir_race|help|version|print|print0|ls|prune|quit|not|and|or|a|o|P|L|H|O[0-3])(?=\s|$)|!|\\[()]|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "find with only known read-only flags"
    ]

-- | nmap: allow known-safe scanning/display flags, ask for script
-- execution (-sC, -A, --script) and file output (-oN, -oX, etc.).
nmapRules :: Node
nmapRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|nmap\s+(?P<args>.+)|] ~> nmapArgRules
    , "nmap" ~> allow "nmap with no arguments shows usage help"
    ]

nmapArgRules :: Node
nmapArgRules =
  check
    "echo $args"
    Stdout
    [ [r|(\s*(?:-(?:p|e|iL)\s+(?:'[^']*'|"[^"]*"|\S+)|-(?:s[STUAWMNFXOVRL]|sn|sP|Pn|P0|PE|PP|PM|T[0-5]|n|R|F|r|6|v|d|O)(?=\s|$)|-P[SAUY]\S*(?=\s|$)|--(?:open|reason|packet-trace|iflist|unprivileged|version|help|osscan-guess|osscan-limit)(?=\s|$)|--(?:top-ports|min-rate|max-rate|host-timeout|scan-delay|max-retries|version-intensity)\s+(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "nmap with only known-safe scanning and display flags"
    ]

-- | rm: deny when / is a standalone argument (root target), ask otherwise.
rmRules :: Node
rmRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|rm\s+.*\s/(\s.*)?|] ~> deny "rm with / as target wipes entire filesystem"
    ]

-- | sudo: strip "sudo" prefix, recurse into subcommand.
sudoRules :: Node
sudoRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|sudo\s+(?P<subcmd>.+)|] ~> recurse "subcmd"
    ]

-- | env K=V ...: strip env and variable assignments, recurse.
envRules :: Node
envRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|env\s+(?P<subcmd>\S+=\S+\s+.+)|] ~> recurse "subcmd"
    ]

-- | bash -c CMD: extract and recurse into CMD.
bashRules :: Node
bashRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|bash\s+-c\s+(?P<subcmd>.+)|] ~> recurse "subcmd"
    ]

-- | sh -c CMD: extract and recurse into CMD.
shRules :: Node
shRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|sh\s+-c\s+(?P<subcmd>.+)|] ~> recurse "subcmd"
    ]

-- | fish -c CMD: extract and recurse into CMD.
fishRules :: Node
fishRules =
  check
    "echo $COMMAND"
    Stdout
    [ [r|fish\s+-c\s+(?P<subcmd>.+)|] ~> recurse "subcmd"
    ]
