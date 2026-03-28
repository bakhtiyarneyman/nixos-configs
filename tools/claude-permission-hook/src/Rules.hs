module Rules (rules) where

import Protolude hiding (ask, check, match)
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
--
-- 10. XARGS SAFETY PROBE. xargs injects arguments from stdin that are
--     unknown at permission-check time, so we cannot evaluate the full
--     command. Instead, the xargs rule appends a synthetic unrecognized
--     flag ("--unrecognized-flag-injected-by-xargs-rule") to the
--     captured subcommand and recurses. If the rule tree still allows,
--     the subcommand must be unconditionally safe regardless of what
--     arguments stdin provides.
--
--     This is secure under the following conditions (all currently hold):
--
--     a) Principle #2 is maintained: rules only whitelist explicitly
--        enumerated known-safe flags, never catch-all patterns like .*.
--        A catch-all would match the probe flag and incorrectly allow
--        argument-dependent commands via xargs.
--
--     b) Rules that unconditionally allow a program (e.g. "grep" ~> allow)
--        are genuinely safe with ANY arguments. These are the only rules
--        that survive the probe, because the probe flag is irrelevant
--        when no argument checking occurs.
--
--     c) Rules with argument whitelists (find, sort, nmap, etc.) enumerate
--        specific known-safe flags. The probe flag does not appear in any
--        whitelist, so it fails to match and falls through to ask.
--
--     d) The probe flag name is deliberately long and self-documenting
--        to prevent accidental inclusion in a whitelist.
rules :: Node
rules =
  match
    (Variable "FRAGMENT_TYPE")
    [ "command" ~> commandRules
    , "overwrite" ~>
        match
          command
          [ "/dev/null" ~> allow "writing to /dev/null discards data, no side effects"
          , [r|.*|] ~>
              match
                (Process ErrorCode [r|test -e "$(printenv COMMAND)"|])
                [ "1" ~> allow "file does not exist yet, creating new file"
                , "0" ~> ask "file overwrite (existing file): $COMMAND"
                ]
          ]
    , "append" ~> ask "file append: $COMMAND"
    ]

-- | Dispatch on program name (first word of command).
commandRules :: Node
commandRules =
  match
    (Process Stdout [r|printenv COMMAND | awk '{print $1}'|])
    -- Catastrophic: deny unconditionally.
    [ "rm" ~> rmRules
    , "mkfs" ~> deny "formats filesystems, destroys all data on device"
    , "dd" ~> deny "raw disk/file writes, can destroy data"
    , -- Pure builtins: no I/O, no flags change this.
      "echo" ~> allow "output to stdout only, cannot modify filesystem"
    , "printf" ~> allow "output to stdout only, cannot modify filesystem"
    , "true" ~> allow "no-op builtin, always succeeds"
    , "false" ~> allow "no-op builtin, always fails"
    , "cd" ~> allow "changes working directory, process-local state only, no filesystem writes"
    , "test" ~> allow "evaluates expressions, no side effects"
    , [r|\[|] ~> allow "evaluates expressions, no side effects"
    , -- Read-only file inspection: no flags make these write.
      "cat" ~> allow "reads files to stdout, no write capability"
    , "head" ~> allow "reads beginning of files, no write capability"
    , "tail" ~> allow "reads end of files, no write capability"
    , "wc" ~> allow "counts lines/words/bytes, no write capability"
    , "uniq" ~> allow "filters adjacent duplicate lines, all flags control filtering only"
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
    , "man" ~> allow "displays manual pages, no write capability"
    , -- Search: read-only, cannot modify files.
      "find" ~> findRules
    , "grep" ~> allow "searches file contents, no write capability"
    , "rg" ~> allow "searches file contents, no write capability"
    , "sort" ~> sortRules
    , -- Network inspection: safe scanning flags only.
      "nmap" ~> nmapRules
    , -- Nix tooling: safe in this repo context.
      "nix" ~> allow "nix build/eval tooling"
    , "nix-build" ~> allow "nix build tooling"
    , "nix-instantiate" ~> allow "nix eval tooling"
    , "nix-store" ~> allow "nix store queries"
    , "alejandra" ~> allow "nix formatter, only rewrites formatting"
    , -- Haskell build tooling: compiles source to build artifacts.
      "ghc" ~> allow "Haskell compiler, produces build artifacts (.o, .hi, executables)"
    , "nil" ~> allow "nix language server, read-only"
    , -- Version control: read-only queries and local-only writes.
      "git" ~> gitRules
    , -- System management: safe subcommands only.
      "nixos-rebuild" ~> nixosRebuildRules
    , -- Commands that execute subcommands — must recurse.
      "pkexec" ~> pkexecRules
    , "sudo" ~> sudoRules
    , "env" ~> envRules
    , "bash" ~> bashRules
    , "sh" ~> shRules
    , "fish" ~> fishRules
    , "xargs" ~> xargsRules
    ]

-- | find: capture args via printenv (preserves quoting), then match
-- against safe-flag grammar.  -exec is handled by recursing into the
-- subcommand through the full rule tree.
findRules :: Node
findRules =
  match
    command
    [ [r|find\s+(?P<args>.+)|] ~> findArgRules
    , "find" ~> allow "find with no arguments lists current directory"
    ]

findArgRules :: Node
findArgRules =
  match
    (Variable "args")
    [ findExecPattern ~> recurse Command "$subcmd"
    , safeFindFlags ~> allow "find with only known read-only flags"
    ]

-- | Individual safe find flag alternation (one flag unit).
safeFindFlag :: Text
safeFindFlag = [r|-(?:name|iname|path|ipath|wholename|iwholename|regex|iregex|type|xtype|size|perm|user|group|uid|gid|links|inum|samefile|mtime|mmin|atime|amin|ctime|cmin|newer|anewer|cnewer|used|fstype|context|maxdepth|mindepth|regextype|printf|files0-from|D)\s+(?:'[^']*'|"[^"]*"|\S+)|-(?:empty|readable|writable|executable|nouser|nogroup|noleaf|depth|d|mount|xdev|daystart|follow|true|false|warn|nowarn|ignore_readdir_race|noignore_readdir_race|help|version|print|print0|ls|prune|quit|not|and|or|a|o|P|L|H|O[0-3])(?=\s|$)|!|\\[()]|(?:'[^']*'|"[^"]*"|[^-\s]\S*)|]

-- | Zero or more safe find flags.
safeFindFlags :: Text
safeFindFlags = [r|(\s*(?:|] <> safeFindFlag <> [r|))*\s*|]

-- | Safe find flags with a single -exec block whose subcommand is captured.
-- The subcmd capture uses (?:(?!\s*\{\}).)+  to stop before the {} placeholder.
findExecPattern :: Text
findExecPattern =
  [r|(\s*(?:|] <> safeFindFlag
  <> [r|))*\s*-exec\s+(?P<subcmd>(?:(?!\s*\{\}).)+)\s*\{\}\s*(?:\\;|\+)?\s*(\s*(?:|]
  <> safeFindFlag <> [r|))*\s*|]

-- | sort: allow known-safe flags, ask for -o/--output (writes file)
-- and --compress-program (executes external program).
sortRules :: Node
sortRules =
  match
    command
    [ [r|sort(\s+(-(?:b|d|f|g|i|M|h|n|R|r|V|c|C|m|s|u|z)(?=\s|$)|-(?:k|t|S|T|batch-size|parallel|random-source|files0-from|sort)\s*(?:'[^']*'|"[^"]*"|\S+)|--(?:reverse|numeric-sort|general-numeric-sort|month-sort|human-numeric-sort|random-sort|version-sort|ignore-leading-blanks|dictionary-order|ignore-case|ignore-nonprinting|check|merge|stable|unique|zero-terminated|debug|help|version)(?=\s|$)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "sort with only known-safe flags, no -o/--output or --compress-program"
    ]

-- | nmap: allow known-safe scanning/display flags, ask for script
-- execution (-sC, -A, --script) and file output (-oN, -oX, etc.).
nmapRules :: Node
nmapRules =
  match
    command
    [ [r|nmap\s+(?P<args>.+)|] ~> nmapArgRules
    , "nmap" ~> allow "nmap with no arguments shows usage help"
    ]

nmapArgRules :: Node
nmapArgRules =
  match
    (Variable "args")
    [ [r|(\s*(?:-(?:p|e|iL)\s+(?:'[^']*'|"[^"]*"|\S+)|-(?:s[STUAWMNFXOVRL]|sn|sP|Pn|P0|PE|PP|PM|T[0-5]|n|R|F|r|6|v|d|O)(?=\s|$)|-P[SAUY]\S*(?=\s|$)|--(?:open|reason|packet-trace|iflist|unprivileged|version|help|osscan-guess|osscan-limit)(?=\s|$)|--(?:top-ports|min-rate|max-rate|host-timeout|scan-delay|max-retries|version-intensity)\s+(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "nmap with only known-safe scanning and display flags"
    ]

-- | git: allow read-only subcommands unconditionally (no flags on these
-- can write).  Allow add/commit as local, reversible operations.
-- Everything else (push, reset, checkout, rebase, merge, clean, etc.)
-- falls through to ask.
gitRules :: Node
gitRules =
  match
    command
    [ [r|git\s+(?:status|diff|log|show|blame|shortlog|describe|rev-parse|rev-list|ls-files|ls-tree|cat-file|name-rev|merge-base|for-each-ref)(?:\s+.*)?|]
        ~> allow "read-only git query, no flags can write or modify state"
    , [r|git\s+branch(?:\s+.*)?|] ~> gitBranchRules
    , [r|git\s+tag(?:\s+.*)?|] ~> gitTagRules
    , [r|git\s+(?:add|commit)(?:\s+.*)?|]
        ~> allow "local staging/commit, fully reversible and does not affect remotes"
    ]

-- | git branch: allow only known read-only listing and query flags.
-- Mutation flags (-d, -D, -m, -M, -c, -C, --set-upstream-to,
-- --unset-upstream, --edit-description) and bare branch names fall
-- through to ask.
gitBranchRules :: Node
gitBranchRules =
  match
    command
    [ [r|git\s+branch(\s+(-[avrvi]+(?=\s|$)|--(?:all|remotes|verbose|show-current|no-color|no-column|ignore-case)(?=\s|$)|--(?:list|merged|no-merged|contains|no-contains)(?:(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)|--(?:sort|format|color|column|points-at|abbrev)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)))*\s*|]
        ~> allow "git branch with only read-only listing and query flags"
    ]

-- | git tag: allow only known read-only listing, query, and verify flags.
-- Mutation flags (-d, -a, -s, -u, -f, -m, -F, --delete, --force) and bare
-- tag names fall through to ask.
gitTagRules :: Node
gitTagRules =
  match
    command
    [ [r|git\s+tag(\s+(-n\d*(?=\s|$)|--(?:no-color|no-column|ignore-case)(?=\s|$)|--(?:list|verify|contains|no-contains|points-at|merged|no-merged|sort|format|color|column|abbrev)(?:(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)|-[lv](?:\s+(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)))*\s*|]
        ~> allow "git tag with only read-only listing, query, and verify flags"
    ]

-- | nixos-rebuild: allow non-persistent subcommands (test, build, dry-build,
-- dry-run, dry-activate, build-vm, build-vm-with-bootloader, list-generations,
-- repl).  switch and boot modify the boot menu, so they fall through to ask.
nixosRebuildRules :: Node
nixosRebuildRules =
  match
    command
    [ [r|nixos-rebuild\s+(?:build|dry-build|dry-run|dry-activate|build-vm|build-vm-with-bootloader|list-generations|repl)(?:\s+.*)?|]
        ~> allow "nixos-rebuild build/query subcommand, does not activate or modify boot menu"
    ]

-- | pkexec: strip "pkexec" prefix, recurse into subcommand.
pkexecRules :: Node
pkexecRules =
  match
    command
    [ [r|pkexec\s+(?P<subcmd>.+)|] ~> recurse Command "$subcmd"
    ]

-- | rm: deny when / is a standalone argument (root target), ask otherwise.
rmRules :: Node
rmRules =
  match
    command
    [ [r|rm\s+.*\s/(\s.*)?|] ~> deny "rm with / as target wipes entire filesystem"
    ]

-- | sudo: strip "sudo" prefix, recurse into subcommand.
sudoRules :: Node
sudoRules =
  match
    command
    [ [r|sudo\s+(?P<subcmd>.+)|] ~> recurse Command "$subcmd"
    ]

-- | env K=V ...: strip env and variable assignments, recurse.
envRules :: Node
envRules =
  match
    command
    [ [r|env\s+(?P<subcmd>\S+=\S+\s+.+)|] ~> recurse Command "$subcmd"
    ]

-- | bash -c CMD: extract and recurse into CMD.
bashRules :: Node
bashRules =
  match
    command
    [ [r|bash\s+-c\s+(?P<subcmd>.+)|] ~> recurse Command "$subcmd"
    ]

-- | sh -c CMD: extract and recurse into CMD.
shRules :: Node
shRules =
  match
    command
    [ [r|sh\s+-c\s+(?P<subcmd>.+)|] ~> recurse Command "$subcmd"
    ]

-- | fish -c CMD: extract and recurse into CMD.
fishRules :: Node
fishRules =
  match
    command
    [ [r|fish\s+-c\s+(?P<subcmd>.+)|] ~> recurse Command "$subcmd"
    ]

-- | xargs: builds command lines from stdin, so the captured subcommand
-- is incomplete — stdin-injected arguments are unknown at check time.
-- We append a synthetic unknown flag and recurse: if the rule tree still
-- allows the probed command, the subcommand must be unconditionally safe
-- regardless of arguments.  See CLAUDE.md "xargs safety probe" section.
xargsRules :: Node
xargsRules =
  match
    command
    [ [r|xargs(?:\s+(?:-[0rxtp](?=\s|$)|--(?=\s|$)|-[nLPsdEIa]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:null|no-run-if-empty|verbose|interactive|open-tty|help|version|exit)(?=\s|$)|--(?:max-args|max-lines|max-procs|max-chars|delimiter|eof|replace|arg-file|process-slot-var)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)))*\s+(?P<subcmd>.+)|]
        ~> recurse Command "$subcmd --unrecognized-flag-injected-by-xargs-rule"
    ]
