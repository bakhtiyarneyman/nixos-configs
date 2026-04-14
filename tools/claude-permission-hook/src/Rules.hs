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
--
-- 11. EXPLICIT ASK FOR KNOWN DANGERS. When a command has subcommands or
--     flags that are deliberately not allowed, match them with an
--     explicit `ask` rather than relying on fall-through. This tells
--     future editors the omission was a deliberate security decision.
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
    (Process Stdout [r|printenv COMMAND | awk 'NR==1{print $1}'|])
    -- Catastrophic: deny unconditionally.
    [ "rm" ~> rmRules
    , "mkfs" ~> deny "formats filesystems, destroys all data on device"
    , "dd" ~> deny "raw disk/file writes, can destroy data"
    , -- Pure builtins: no I/O, no flags change this.
      "echo" ~> allow "output to stdout only, cannot modify filesystem"
    , "printf" ~> allow "output to stdout only, cannot modify filesystem"
    , "true" ~> allow "no-op builtin, always succeeds"
    , "false" ~> allow "no-op builtin, always fails"
    , "sleep" ~> allow "delays for specified duration, no flags can write, delete, or execute"
    , "cd" ~> allow "changes working directory, process-local state only, no filesystem writes"
    , "test" ~> allow "evaluates expressions, no side effects"
    , [r|\[|] ~> allow "evaluates expressions, no side effects"
    , -- Read-only file inspection: no flags make these write.
      "cat" ~> allow "reads files to stdout, no write capability"
    , "head" ~> allow "reads beginning of files, no write capability"
    , "tail" ~> allow "reads end of files, no write capability"
    , "wc" ~> allow "counts lines/words/bytes, no write capability"
    , "tr" ~> allow "translates/deletes characters from stdin to stdout, no flags can write files or execute commands"
    , "uniq" ~> allow "filters adjacent duplicate lines, all flags control filtering only"
    , "jq" ~> allow "JSON processor, reads stdin/files and writes to stdout only, no flags can write files or execute commands"
    , "diff" ~> allow "compares files, no write capability"
    , "file" ~> allow "identifies file types, no write capability"
    , "stat" ~> allow "displays file metadata, no write capability"
    , "ldd" ~> allow "prints shared library dependencies, all flags are read-only"
    , "md5sum" ~> allow "computes checksums, no write capability"
    , "sha256sum" ~> allow "computes checksums, no write capability"
    , "readlink" ~> allow "resolves symlinks, no write capability"
    , "mktemp" ~> allow "creates temporary files/directories with unique random names, no flags can overwrite existing files, delete, or execute commands"
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
    , "pgrep" ~> allow "looks up running processes by name/attributes, output only, no flags can write or execute"
    , "man" ~> allow "displays manual pages, no write capability"
    , -- Search: read-only, cannot modify files.
      "find" ~> findRules
    , "grep" ~> allow "searches file contents, no write capability"
    , "rg" ~> allow "searches file contents, no write capability"
    , "sort" ~> sortRules
    , "sed" ~> sedRules
    , "awk" ~> awkRules
    , -- Network inspection: safe scanning flags only.
      "nmap" ~> nmapRules
    , "ss" ~> ssRules
    , -- System tracing: observation-only flags allowed, subcommand recursed.
      "strace" ~> straceRules
    , -- Network transfer: safe fetching flags only.
      "curl" ~> curlRules
    , -- Nix tooling: sandboxed builds and read-only queries allowed.
      "nix" ~> nixRules
    , "nix-build" ~> allow "nix build tooling, executes in Nix sandbox"
    , "nix-instantiate" ~> allow "pure Nix evaluation, no host execution"
    , "nix-prefetch-url" ~> allow "downloads URL into Nix store and prints hash, all flags control download/hashing only, no host execution"
    , "nixos-option" ~> allow "inspects NixOS configuration options, all flags are read-only queries"
    , "nix-shell" ~> nixShellRules
    , "nix-store" ~> nixStoreRules
    , "alejandra" ~> allow "nix formatter, only rewrites formatting"
    , -- Haskell build tooling: safe subcommands/flags only.
      "cabal" ~> cabalRules
    , "ghc" ~> ghcRules
    , "nil" ~> allow "nix language server, read-only"
    , -- Version control: read-only queries and local-only writes.
      "git" ~> gitRules
    , "gh" ~> ghRules
    , -- System management: safe subcommands only.
      "nixos-rebuild" ~> nixosRebuildRules
    , "systemctl" ~> systemctlRules
    , "journalctl" ~> journalctlRules
    , -- Database clients: read-only queries allowed.
      "redis-cli" ~> redisCliRules
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
    [ findExecPattern ~> recurse [(Command, "$subcmd")]
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

-- | sed: stream editor. Without -i/--in-place, sed reads from
-- files/stdin and writes to stdout only. Allow known-safe flags,
-- ask for -i/--in-place (modifies files in place).
sedRules :: Node
sedRules =
  match
    command
    [ [r|sed(\s+(-[nErsuz]+(?=\s|$)|-[efl]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:quiet|silent|debug|posix|regexp-extended|separate|unbuffered|null-data|sandbox|follow-symlinks|help|version)(?=\s|$)|--(?:expression|file|line-length)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "sed with only known-safe flags, no -i/--in-place; reads files/stdin and writes to stdout only"
    ]

-- | awk: text processing language. Allow known-safe flags only.
-- Dangerous flags that fall through to ask:
--   -l/--load (loads dynamic shared libraries)
--   -d/--dump-variables, -D/--debug, -o/--pretty-print, -p/--profile (write files)
-- Note: awk programs can contain system() and output redirection,
-- but we don't parse program text (same approach as sedRules).
awkRules :: Node
awkRules =
  match
    command
    [ [r|awk(\s+(-[bcCghIkMNnOPrsStV]+(?=\s|$)|-[Fv]\s*(?:'[^']*'|"[^"]*"|\S+)|-[efEi]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:characters-as-bytes|traditional|copyright|gen-pot|help|trace|csv|bignum|use-lc-numeric|non-decimal-data|optimize|posix|re-interval|no-optimize|sandbox|lint-old|version)(?=\s|$)|--(?:field-separator|assign|file|source|include|exec)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "awk with safe flags only; no -l/--load (dynamic extensions), no -d/-D/-o/-p (file-writing/debug flags); reads stdin/files to stdout"
    ]

-- | nix: allow sandboxed builds and read-only queries.
-- Host-execution subcommands (run, develop, repl, fmt) and
-- destructive store operations fall through to ask.
-- shell --command/-c recurses into the subcommand; nix shell
-- without --command (interactive) still falls through to ask.
nixRules :: Node
nixRules =
  match
    command
    [ [r|nix\s+(?:build|eval|search|log|path-info|hash|why-depends|print-dev-env|doctor|help|help-stores)(?:\s+.*)?|]
        ~> allow "nix build/eval/query subcommand — sandboxed or read-only"
    , [r|nix\s+flake\s+(?:check|show|update|lock|metadata|info|archive|prefetch|prefetch-inputs|clone)(?:\s+.*)?|]
        ~> allow "nix flake query/update — sandboxed, read-only, or updates lock file"
    , [r|nix\s+store\s+(?:cat|dump-path|info|ls|diff-closures|verify|path-from-hash-part)(?:\s+.*)?|]
        ~> allow "nix store read-only query"
    , [r|nix\s+derivation\s+show(?:\s+.*)?|]
        ~> allow "nix derivation show — read-only"
    , [r|nix\s+nar\s+(?:cat|dump-path|ls)(?:\s+.*)?|]
        ~> allow "nix nar read-only inspection"
    , [r|nix\s+shell|] <> safeNixShellArgs <> [r|\s+(?:--command|-c)\s+(?P<subcmd>.+)|]
        ~> recurse [(Command, "$subcmd")]
    ]

-- | Single safe nix-shell argument (flag or installable).
-- Only clearly safe flags: logging/display, restrictive, env management,
-- pure evaluation inputs, and installables.
-- Excluded (fall through to ask): --impure, --repair, --debugger,
-- --commit-lock-file, --recreate-lock-file, --update-input,
-- --output-lock-file, --file/-f, --expr, --override-input,
-- --override-flake, --include/-I, --inputs-from, --option.
safeNixShellArg :: Text
safeNixShellArg = [r|--(?:no-registries|no-use-registries|no-update-lock-file|no-write-lock-file|debug|print-build-logs|quiet|verbose|help|offline|version|ignore-env|refresh)(?=\s|$)|-[Lvi](?=\s|$)|--(?:log-format|keep-env-var|unset-env-var|reference-lock-file|eval-store|arg-from-stdin)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|-[ku]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:arg|argstr|arg-from-file|set-env-var)\s+(?:'[^']*'|"[^"]*"|\S+)\s+(?:'[^']*'|"[^"]*"|\S+)|-s\s+(?:'[^']*'|"[^"]*"|\S+)\s+(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)|]

-- | Zero or more safe nix-shell arguments.
safeNixShellArgs :: Text
safeNixShellArgs = [r|(\s+(?:|] <> safeNixShellArg <> [r|))*|]

-- | nix-shell: sets up build environments from Nix expressions.
-- With -p (ad-hoc packages from nixpkgs), package building is
-- sandboxed and there is no shellHook. --run/--command execute
-- a subcommand — recurse to evaluate it.
-- Without -p, evaluates local Nix expressions (shell.nix/default.nix)
-- which may contain shellHook with arbitrary code — falls through to ask.
-- Without --run/--command, drops to interactive shell — falls through to ask.
nixShellRules :: Node
nixShellRules =
  match
    command
    [ -- Require -p/--packages as a standalone token (ad-hoc mode, no shellHook).
      -- Without -p, nix-shell evaluates local Nix expressions whose
      -- shellHook can execute arbitrary code — falls through to ask.
      [r|nix-shell\s+(?:\S+\s+)*(?:-p|--packages)\s+.*|] ~> nixShellRunRules
    ]

-- | Extract --run/--command argument from nix-shell -p command and recurse.
-- Without --run/--command, nix-shell drops to interactive shell — falls
-- through to ask.
nixShellRunRules :: Node
nixShellRunRules =
  match
    command
    [ -- Single-quoted --run/--command argument: strip quotes and recurse
      [r|.*(?:--run|--command)\s+'(?P<subcmd>[^']*)'(?:\s+.*)?|]
        ~> recurse [(Command, "$subcmd")]
    , -- Double-quoted --run/--command argument: strip quotes and recurse
      [r|.*(?:--run|--command)\s+"(?P<subcmd>[^"]*)"(?:\s+.*)?|]
        ~> recurse [(Command, "$subcmd")]
    , -- Unquoted --run/--command argument: recurse directly
      [r|.*(?:--run|--command)\s+(?P<subcmd>\S+)(?:\s+.*)?|]
        ~> recurse [(Command, "$subcmd")]
    ]

-- | nix-store: allow read-only queries and sandboxed builds.
-- Destructive operations (gc, delete) and store modifications fall
-- through to ask.
nixStoreRules :: Node
nixStoreRules =
  match
    command
    [ [r|nix-store\s+(?:-q|--query|--verify|--verify-path|--dump|--export|--read-log|--dump-db|--print-env)(?:\s+.*)?|]
        ~> allow "nix-store read-only query or export"
    , [r|nix-store\s+(?:-r|--realise)(?:\s+.*)?|]
        ~> allow "nix-store realise — builds in Nix sandbox"
    ]

-- | ghc: allow compilation with known-safe flags only.
-- Dangerous flags that fall through to ask: -e (eval), --run,
-- --interactive (REPL), --frontend (plugin), -pgm* (substitute
-- external programs), -fplugin* (compiler plugins), -ghci-script
-- (execute GHCi commands), @file (response files bypass flag checking).
ghcRules :: Node
ghcRules =
  match
    command
    [ [r|ghc\s+(?P<args>.+)|] ~> ghcArgRules
    , "ghc" ~> allow "ghc with no arguments shows usage"
    ]

ghcArgRules :: Node
ghcArgRules =
  match
    (Variable "args")
    [ safeGhcFlags ~> allow "ghc compilation with known-safe flags only"
    ]

-- | Single safe GHC flag unit. Organized by prefix family:
-- -X (extensions), -W/-w (warnings), -d (debug/dump), -f except
-- -fplugin (features), -opt (sub-tool options), -O (optimization),
-- phase stops, verbosity/parallelism, paths, boolean keywords,
-- flags with arguments, long flags, and source files.
safeGhcFlag :: Text
safeGhcFlag = [r|-X\S+|-W\S*|-w(?=\s|$)|-d\S+|-f(?!plugin)\S+|-opt\S+|-O[012]?(?=\s|$)|-[cSECMFg](?=\s|$)|-[vj]\d*(?=\s|$)|-[Hi]\S*|-[IlLDU]\S+|-(?:auto|auto-all|caf-all|dynamic|static|shared|staticlib|threaded|single-threaded|prof|debug|eventlog|pie|no-pie|rdynamic|cpp|no-hs-main|no-link|split-sections|no-split-sections|hide-all-packages|no-auto-link-packages)(?=\s|$)|-(?:keep-\S+|no-keep-\S+)(?=\s|$)|-(?:rtsopts(?:=\S+)?|no-rtsopts|no-rtsopts-suggestions|with-rtsopts=\S+)(?=\s|$)|-pgm[cl]-supports-no-pie(?=\s|$)|-(?:o|odir|hidir|stubdir|dumpdir|outputdir|osuf|hisuf|hcsuf|main-is|package|package-db|package-id|package-env|hide-package|this-unit-id|this-package-name|unit|working-dir|framework|framework-path|dylib-install-name|tmpdir|x|hpcdir)\s+(?:'[^']*'|"[^"]*"|\S+)|-o\S+|--(?:make|info|help|version|numeric-version|show-iface|show-options)(?=\s|$)|--print-\S+(?=\s|$)|(?:'[^']*'|"[^"]*"|[^-@\s]\S*)|]

-- | Zero or more safe GHC flags.
safeGhcFlags :: Text
safeGhcFlags = [r|(\s*(?:|] <> safeGhcFlag <> [r|))*\s*|]

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

-- | ss: socket statistics. Allow known-safe inspection flags.
-- -K/--kill (forcibly close sockets) and -D/--diag (dump to file) fall
-- through to ask.
ssRules :: Node
ssRules =
  match
    command
    [ [r|ss\s+.*(?:-K|--kill).*|]
        ~> ask "ss --kill forcibly closes sockets"
    , [r|ss\s+.*(?:-D|--diag).*|]
        ~> ask "ss --diag writes raw socket data to a file"
    , [r|ss(\s+(-[hVnralBoempiTsbEZz460tMSudwxHQO]+(?=\s|$)|-[NfAF]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:help|version|numeric|resolve|all|listening|bound-inactive|options|extended|memory|processes|threads|info|tipcinfo|summary|tos|cgroup|bpf|bpf-maps|events|context|contexts|ipv4|ipv6|packet|tcp|mptcp|sctp|udp|dccp|raw|unix|tipc|vsock|xdp|no-header|no-queues|oneline|inet-sockopt)(?=\s|$)|--(?:net|family|query|socket|filter|bpf-map-id)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "ss with only known-safe socket inspection flags, no --kill or --diag"
    ]

-- | strace: system call tracer. In command mode, executes and traces
-- a command — recurse into the subcommand. In attach mode (-p PID),
-- observes an existing process read-only.
-- Dangerous flags fall through to ask:
--   -e inject/fault, --inject/--fault (syscall tampering)
--   --kill-on-exit (kills tracees)
--   -o/--output (writes trace to file)
--   -u/--user (runs as different user)
straceRules :: Node
straceRules =
  match
    command
    [ [r|strace\s+.*(?:-e\s+(?:inject|fault)|--(?:inject|fault)=).*|]
        ~> ask "strace syscall injection/fault tampering can modify traced process behavior"
    , [r|strace\s+.*--kill-on-exit.*|]
        ~> ask "strace --kill-on-exit kills all traced processes when strace exits"
    , [r|strace\s+.*(?:-o\s|--output(?:=|\s)).*|]
        ~> ask "strace -o/--output writes trace output to a file"
    , [r|strace\s+.*(?:-u\s|--user(?:=|\s)).*|]
        ~> ask "strace -u/--user runs the traced command as a different user"
    , [r|strace\s+|] <> safeStraceFlags
        ~> allow "strace with safe tracing/display flags only, no command execution"
    , [r|strace\s+|] <> safeStraceFlags <> [r|(?P<subcmd>\S+(?:\s+.*)?)|]
        ~> recurse [(Command, "$subcmd")]
    , "strace" ~> allow "strace with no arguments shows usage help"
    ]

-- | Single safe strace flag alternation.
safeStraceFlag :: Text
safeStraceFlag = [r|-[ACcdfhiknNqrtTvVwxyYzZ]+(?=\s|$)|-D{1,3}(?=\s|$)|-[abIOPsSUX]\s+(?:'[^']*'|"[^"]*"|\S+)|-E\s+(?:'[^']*'|"[^"]*"|\S+)|-e\s+(?!inject|fault)(?:'[^']*'|"[^"]*"|\S+)|-p\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:follow-forks|output-separately|output-append-mode|seccomp-bpf|always-show-pid|no-abbrev|instruction-pointer|syscall-number|arg-names|successful-only|failed-only|summary-only|summary|summary-wall-clock|debug|help|version)(?=\s|$)|--(?:daemonize|stack-trace|quiet|relative-timestamps|absolute-timestamps|syscall-times|strings-in-hex|decode-fds|decode-pids|tips)(?:(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)|--(?:stack-trace-frame-limit|syscall-limit|columns|string-limit|const-print-style|interruptible|summary-syscall-overhead|summary-sort-by|summary-columns|trace|signal|status|trace-fds|trace-path|abbrev|verbose|raw|read|write|kvm|namespace|detach-on|env|argv0|attach)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|]

-- | Zero or more safe strace flags.
safeStraceFlags :: Text
safeStraceFlags = [r|(\s*(?:|] <> safeStraceFlag <> [r|))*\s*|]

-- | curl: allow fetching with known-safe flags that cannot send data,
-- authenticate, set custom headers, upload files, or write to disk.
-- Flags that fall through to ask: -d/--data* (request body), -F/--form*
-- (multipart upload), --json (JSON body), -T/--upload-file, -H/--header
-- (custom headers could leak auth tokens), -b/--cookie (sends cookies),
-- -e/--referer, -u/--user (credentials), -o/-O/--output/--remote-name
-- (file writes), -D/--dump-header, --trace/--trace-ascii, -c/--cookie-jar,
-- -K/--config (arbitrary options), -X/--request (method change),
-- -n/--netrc (credential file), --variable/--expand-* (variable expansion),
-- -x/--proxy (proxy sees traffic), --next (resets state).
curlRules :: Node
curlRules =
  match
    command
    [ [r|curl(\s+(-[sSfgLIikv46NZRqVMh#]+(?=\s|$)|-[mYyrAzw]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:silent|show-error|fail|fail-early|fail-with-body|globoff|location|head|include|insecure|verbose|ipv4|ipv6|no-buffer|progress-bar|no-progress-meter|parallel|parallel-immediate|compressed|compressed-ssh|raw|path-as-is|tcp-nodelay|tcp-fastopen|no-keepalive|no-sessionid|no-alpn|no-npn|http0\.9|http1\.0|http1\.1|http2|http2-prior-knowledge|http3|http3-only|styled-output|no-styled-output|ca-native|help|version|manual|crlf|disable|disallow-username-in-url|remote-time|retry-connrefused|retry-all-errors|tr-encoding|xattr|ssl|ssl-reqd|ssl-allow-beast|ssl-no-revoke|ssl-revoke-best-effort|ssl-auto-client-cert|tlsv1|tlsv1\.[0-3]|sslv[23]|haproxy-protocol)(?=\s|$)|--(?:max-time|connect-timeout|max-redirs|max-filesize|retry|retry-delay|retry-max-time|speed-limit|speed-time|limit-rate|keepalive-time|keepalive-cnt|interface|local-port|ip-tos|resolve|connect-to|dns-interface|dns-ipv4-addr|dns-ipv6-addr|dns-servers|doh-url|unix-socket|abstract-unix-socket|range|user-agent|proto|proto-default|proto-redir|tls-max|cacert|capath|crlfile|ciphers|tls13-ciphers|curves|pinnedpubkey|parallel-max|write-out|expect100-timeout|happy-eyeballs-timeout-ms|rate|time-cond)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "curl with only known-safe fetching/display flags — no data-sending, auth, header, upload, or file-writing flags"
    , "curl" ~> allow "curl with no arguments shows usage"
    ]

-- | Git command prefix: "git" followed by zero or more safe global options.
-- -C <path> changes directory before running, which is safe.
gitPrefix :: Text
gitPrefix = [r|git(?:\s+-C\s+(?:'[^']*'|"[^"]*"|\S+))*\s+|]

-- | git: allow read-only subcommands unconditionally (no flags on these
-- can write).  Allow add/commit as local, reversible operations.
-- Everything else (push, reset, checkout, rebase, merge, clean, etc.)
-- falls through to ask.
gitRules :: Node
gitRules =
  match
    command
    [ gitPrefix <> [r|(?:status|diff|log|show|blame|shortlog|describe|rev-parse|rev-list|ls-files|ls-tree|cat-file|name-rev|merge-base|for-each-ref|check-ignore)(?:\s+.*)?|]
        ~> allow "read-only git query, no flags can write or modify state"
    , gitPrefix <> [r|branch(?:\s+.*)?|] ~> gitBranchRules
    , gitPrefix <> [r|tag(?:\s+.*)?|] ~> gitTagRules
    , gitPrefix <> [r|remote(?:\s+.*)?|] ~> gitRemoteRules
    , gitPrefix <> [r|worktree(?:\s+.*)?|] ~> gitWorktreeRules
    , gitPrefix <> [r|(?:add|commit)(?:\s+.*)?|]
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
    [ gitPrefix <> [r|branch(\s+(-[avrvi]+(?=\s|$)|--(?:all|remotes|verbose|show-current|no-color|no-column|ignore-case)(?=\s|$)|--(?:list|merged|no-merged|contains|no-contains)(?:(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)|--(?:sort|format|color|column|points-at|abbrev)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)))*\s*|]
        ~> allow "git branch with only read-only listing and query flags"
    ]

-- | git tag: allow only known read-only listing, query, and verify flags.
-- Mutation flags (-d, -a, -s, -u, -f, -m, -F, --delete, --force) and bare
-- tag names fall through to ask.
gitTagRules :: Node
gitTagRules =
  match
    command
    [ gitPrefix <> [r|tag(\s+(-n\d*(?=\s|$)|--(?:no-color|no-column|ignore-case)(?=\s|$)|--(?:list|verify|contains|no-contains|points-at|merged|no-merged|sort|format|color|column|abbrev)(?:(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)|-[lv](?:\s+(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)))*\s*|]
        ~> allow "git tag with only read-only listing, query, and verify flags"
    ]

-- | git remote: allow read-only listing and query subcommands.
-- Mutation subcommands (add, rename, remove/rm, set-head, set-branches,
-- set-url, prune, update) fall through to ask.
gitRemoteRules :: Node
gitRemoteRules =
  match
    command
    [ gitPrefix <> [r|remote(\s+(-v|--verbose)(?=\s|$))*\s*|]
        ~> allow "git remote listing, read-only display of remote names and URLs"
    , gitPrefix <> [r|remote\s+show(?:\s+(?:-n|--no-query)(?=\s|$))*(?:\s+(?:'[^']*'|"[^"]*"|\S+))*\s*|]
        ~> allow "git remote show, read-only display of remote details"
    , gitPrefix <> [r|remote\s+get-url(?:\s+(?:--push|--all)(?=\s|$))*\s+(?:'[^']*'|"[^"]*"|\S+)\s*|]
        ~> allow "git remote get-url, reads URL from local config"
    ]

-- | git worktree: allow read-only listing, protective lock, and add
-- with safe flags. -B (force-reset branch) falls through to ask.
-- remove/move/prune/repair/unlock fall through to ask as they delete
-- or modify state.
gitWorktreeRules :: Node
gitWorktreeRules =
  match
    command
    [ gitPrefix <> [r|worktree\s+list(?:\s+.*)?|]
        ~> allow "git worktree list, read-only display of worktrees"
    , gitPrefix <> [r|worktree\s+lock(?:\s+.*)?|]
        ~> allow "git worktree lock, adds pruning protection only"
    , gitPrefix <> [r|worktree\s+add(\s+(-[fq](?=\s|$)|-b\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:detach|checkout|no-checkout|lock|orphan|track|no-track|guess-remote|no-guess-remote|quiet|force)(?=\s|$)|--reason\s+(?:'[^']*'|"[^"]*"|\S+)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "git worktree add with known-safe flags, no -B which can force-reset existing branches"
    , gitPrefix <> [r|worktree\s+(?:remove|move|prune|repair|unlock)(?:\s+.*)?|]
        ~> ask "git worktree mutation: may delete directories, move paths, remove safety guards, or modify administrative data"
    ]

-- | gh (GitHub CLI): allow read-only queries, ask for mutations.
ghRules :: Node
ghRules =
  match
    command
    [ [r|gh\s+pr\s+(?:list|ls|view|diff|checks|status)(?:\s+.*)?|]
        ~> allow "read-only GitHub PR query, all flags are filters or display options"
    , [r|gh\s+issue\s+(?:list|view|status)(?:\s+.*)?|]
        ~> allow "read-only GitHub issue query, all flags are filters or display options"
    , [r|gh\s+run\s+(?:list|view)(?:\s+.*)?|]
        ~> allow "read-only GitHub Actions run query, all flags are filters or display options"
    , [r|gh\s+repo\s+(?:view|list)(?:\s+.*)?|]
        ~> allow "read-only GitHub repository query, all flags are display options"
    , [r|gh\s+search\s+(?:repos|issues|prs|commits|code)(?:\s+.*)?|]
        ~> allow "read-only GitHub search, all flags are filters or display options"
    , [r|gh\s+release\s+(?:list|view)(?:\s+.*)?|]
        ~> allow "read-only GitHub release query, all flags are display options"
    , [r|gh\s+status(?:\s+.*)?|]
        ~> allow "read-only GitHub status overview, all flags are display options"
    , -- Side-effect subcommands: explicit ask per principle #11.
      [r|gh\s+pr\s+(?:create|close|merge|comment|review|edit|reopen|checkout|lock|unlock|update-branch|revert|ready)(?:\s+.*)?|]
        ~> ask "gh pr mutation command"
    , [r|gh\s+issue\s+(?:create|close|comment|edit|lock|unlock|delete|transfer|develop|pin|unpin|reopen)(?:\s+.*)?|]
        ~> ask "gh issue mutation command"
    , [r|gh\s+api(?:\s+.*)?|]
        ~> ask "gh api can make arbitrary HTTP requests including mutations"
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

-- | systemctl global option prefix: "systemctl" followed by zero or more
-- known-safe global options (display filters, output formatting, query targets).
-- Mutation-relevant flags (--force, --now, --runtime, etc.) are excluded.
systemctlPrefix :: Text
systemctlPrefix = [r|systemctl(?:\s+(?:-(?:l|a|q|r)(?=\s|$)|--(?:user|system|no-pager|no-ask-password|plain|full|all|quiet|value|failed|recursive|reverse|after|before|with-dependencies|show-types)(?=\s|$)|--(?:type|state|property|lines|output|timestamp|legend|host|machine)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|-[tpnoPHM]\s+(?:'[^']*'|"[^"]*"|\S+)))*\s+|]

-- | systemctl: allow read-only introspection subcommands.
-- Mutation subcommands (start/stop/restart/enable/disable/etc.) and
-- system state changes (halt/poweroff/reboot) fall through to ask.
systemctlRules :: Node
systemctlRules =
  match
    command
    [ systemctlPrefix <> [r|(?:list-units|list-automounts|list-paths|list-sockets|list-timers|is-active|is-failed|is-enabled|is-system-running|status|show|cat|help|list-dependencies|whoami|list-unit-files|list-machines|list-jobs|get-default|show-environment)(?:\s+.*)?|]
        ~> allow "systemctl read-only subcommand, no flags can write or modify state"
    ]

-- | journalctl: allow known-safe read-only flags (filtering, output
-- formatting, display options).  Mutation flags are explicitly asked.
journalctlRules :: Node
journalctlRules =
  match
    command
    [ [r|journalctl\s+.*--(?:rotate|vacuum-size|vacuum-time|vacuum-files|flush|sync|setup-keys|update-catalog|cursor-file|relinquish-var|smart-relinquish-var).*|]
        ~> ask "journalctl with mutation flag: may rotate/delete journal files, flush data, or modify catalog/FSS state"
    , [r|journalctl(\s+(-[aefklmqrxhN]+(?=\s|$)|-(?:c|D|g|i|n|o|p|S|t|T|u|U|M|F)\s+(?:'[^']*'|"[^"]*"|\S+)|-[bI](?:\s+(?:'[^']*'|"[^"]*"|[^-\s]\S*))?(?=\s|$)|--(?:system|user|merge|no-pager|no-full|full|no-tail|no-hostname|utc|show-cursor|truncate-newline|reverse|catalog|all|follow|quiet|pager-end|dmesg|fields|list-boots|list-invocations|disk-usage|verify|header|version|help)(?=\s|$)|--case-sensitive(?:=\S+)?(?=\s|$)|--boot(?:(?:=(?:'[^']*'|"[^"]*"|\S+)|\s+(?:'[^']*'|"[^"]*"|[^-\s]\S*)))?(?=\s|$)|--(?:since|until|cursor|after-cursor|unit|user-unit|identifier|exclude-identifier|facility|priority|grep|invocation|namespace|directory|file|root|image|image-policy|output|output-fields|lines|machine|field|verify-key)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)|--(?:list-catalog|dump-catalog)(?:\s+(?:'[^']*'|"[^"]*"|\S+))?(?=\s|$)|(?:'[^']*'|"[^"]*"|[^-\s]\S*)))*\s*|]
        ~> allow "journalctl with only known-safe read-only flags"
    ]

-- | redis-cli: Redis command-line client. Allow known read-only Redis
-- commands and read-only monitoring/analysis modes. Ask for flags that
-- execute scripts (--eval, --ldb), write files (--rdb), send raw protocol
-- (--pipe), manage clusters (--cluster), or simulate loads (--replica,
-- --lru-test). Interactive mode (no command) falls through to ask.
redisCliRules :: Node
redisCliRules =
  match
    command
    [ -- Dangerous flags: explicitly ask per principle #11
      [r|redis-cli\s+.*(?:--pipe|--eval|--ldb|--ldb-sync-mode|--rdb|--functions-rdb|--cluster|--replica|--lru-test)(?:\s|$).*|]
        ~> ask "redis-cli with flag that can execute scripts, dump data to files, or modify cluster/server state"
    , -- Read-only analysis/monitoring modes
      [r|redis-cli|] <> safeRedisCliOpts <> [r|\s+--(?:scan|bigkeys|memkeys|keystats|hotkeys|stat|latency|latency-history|latency-dist|intrinsic-latency)(?:\s+.*)?|]
        ~> allow "redis-cli read-only analysis or monitoring mode"
    , -- Known read-only Redis commands
      [r|redis-cli|] <> safeRedisCliOpts <> [r|\s+(?:get|mget|exists|type|ttl|pttl|keys|scan|dbsize|info|ping|echo|time|randomkey|strlen|getrange|llen|lrange|lindex|scard|smembers|sismember|srandmember|sunion|sinter|sdiff|hget|hgetall|hkeys|hvals|hlen|hexists|hmget|zcard|zcount|zrange|zrangebyscore|zrangebylex|zrank|zrevrank|zscore|zrevrange|zrevrangebyscore|zrevrangebylex|xlen|xrange|xrevrange|xinfo|dump|object|command|pubsub|geopos|geodist|geohash|geosearch|bitcount|bitpos|getbit|lpos|smismember|zlexcount|zmscore|substr|pfcount|sintercard)(?:\s+.*)?|]
        ~> allow "redis-cli with known read-only Redis command"
    ]

-- | Single safe redis-cli connection/formatting flag.
-- Excluded (fall through to ask): --pipe, --eval, --ldb, --ldb-sync-mode,
-- --rdb, --functions-rdb, --cluster, --replica, --lru-test.
safeRedisCliOpt :: Text
safeRedisCliOpt = [r|-[2346cex](?=\s|$)|-[ahDdinprstuX]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:raw|no-raw|csv|json|quoted-json|verbose|no-auth-warning|tls|insecure|quoted-input|askpass|help|version)(?=\s|$)|--(?:user|pass|sni|cacert|cacertdir|cert|key|tls-ciphers|tls-ciphersuites|show-pushes|pattern|quoted-pattern|count|cursor|top|memkeys-samples|keystats-samples)(?:\s+(?:'[^']*'|"[^"]*"|\S+))|]

-- | Zero or more safe redis-cli flags.
safeRedisCliOpts :: Text
safeRedisCliOpts = [r|(\s+(?:|] <> safeRedisCliOpt <> [r|))*|]

-- | cabal: allow compile-only and read-only subcommands.
-- test/bench/run/exec/repl/clean/install fall through to default ask.
cabalRules :: Node
cabalRules =
  match
    command
    [ [r|cabal\s+(?:(?:v[12]-|new-)?(?:build|haddock(?:-project)?|sdist|freeze|gen-bounds|configure|target)|list|info|path|list-bin|outdated|check|help)(?:\s+.*)?|]
        ~> allow "compile/query subcommand, does not execute project code, delete files, install, or upload"
    , [r|cabal\s+(?:upload|report)(?:\s+.*)?|]
        ~> ask "uploads to remote server"
    , [r|cabal\s+(?:update|fetch|get|unpack)(?:\s+.*)?|]
        ~> ask "downloads from network"
    , [r|cabal\s+init(?:\s+.*)?|]
        ~> ask "creates new package files"
    , [r|cabal\s+user-config(?:\s+.*)?|]
        ~> ask "modifies global cabal configuration"
    ]

-- | pkexec: strip "pkexec" prefix, recurse into subcommand.
pkexecRules :: Node
pkexecRules =
  match
    command
    [ [r|pkexec\s+(?P<subcmd>.+)|] ~> recurse [(Command, "$subcmd")]
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
    [ [r|sudo\s+(?P<subcmd>.+)|] ~> recurse [(Command, "$subcmd")]
    ]

-- | env K=V ...: strip env and variable assignments, recurse.
envRules :: Node
envRules =
  match
    command
    [ [r|env\s+(?P<subcmd>\S+=\S+\s+.+)|] ~> recurse [(Command, "$subcmd")]
    ]

-- | bash -c CMD: extract and recurse into CMD.
bashRules :: Node
bashRules =
  match
    command
    [ [r|bash\s+-c\s+(?P<subcmd>.+)|] ~> recurse [(Command, "$subcmd")]
    ]

-- | sh -c CMD: extract and recurse into CMD.
shRules :: Node
shRules =
  match
    command
    [ [r|sh\s+-c\s+(?P<subcmd>.+)|] ~> recurse [(Command, "$subcmd")]
    ]

-- | fish -c CMD: extract and recurse into CMD.
-- fish -n/--no-execute: syntax check only, no commands are executed.
fishRules :: Node
fishRules =
  match
    command
    [ [r|fish\s+(?:-n|--no-execute)(?:\s+.*)?|]
        ~> allow "fish --no-execute only parses for syntax errors, never executes commands"
    , [r|fish\s+-c\s+(?P<subcmd>.+)|] ~> recurse [(Command, "$subcmd")]
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
    [ [r|xargs(?:\s+(?:-[0rxtp](?=\s|$)|--(?=\s|$)|-I(?:'[^']*'|"[^"]*"|\S+)|-[nLPsdEIa]\s+(?:'[^']*'|"[^"]*"|\S+)|--(?:null|no-run-if-empty|verbose|interactive|open-tty|help|version|exit)(?=\s|$)|--(?:max-args|max-lines|max-procs|max-chars|delimiter|eof|replace|arg-file|process-slot-var)(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)))*\s+(?P<subcmd>.+)|]
        ~> recurse [(Command, "$subcmd --unrecognized-flag-injected-by-xargs-rule")]
    ]
