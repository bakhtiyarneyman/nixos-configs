#!/usr/bin/env bash
set -euo pipefail

BINARY="${1:-result/bin/claude-permission-hook}"

pass=0
fail=0

assert_verdict() {
  local cmd="$1"
  local expected="$2"
  local input="{\"tool_input\":{\"command\":$(echo -n "$cmd" | jq -Rs .)}}"
  local output
  output=$(echo "$input" | "$BINARY" 2>/dev/null)
  local actual
  actual=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision')
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: '$cmd' -> $actual"
    pass=$((pass + 1))
  else
    local reason
    reason=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')
    echo "  FAIL: '$cmd' -> expected $expected, got $actual ($reason)"
    fail=$((fail + 1))
  fi
}

echo "=== claude-permission-hook tests ==="
echo "Binary: $BINARY"
echo

echo "-- Pure builtins (should allow) --"
assert_verdict "echo hello" allow
assert_verdict "printf '%s\n' foo" allow
assert_verdict "true" allow
assert_verdict "false" allow
assert_verdict "test -f /etc/passwd" allow
assert_verdict "cd /tmp" allow
assert_verdict "cd" allow

echo
echo "-- Read-only inspection (should allow) --"
assert_verdict "cat /etc/passwd" allow
assert_verdict "head -n5 /etc/passwd" allow
assert_verdict "tail -1 /etc/passwd" allow
assert_verdict "wc -l /etc/passwd" allow
assert_verdict "stat /etc/passwd" allow

echo
echo "-- System queries (should allow) --"
assert_verdict "ls -la /tmp" allow
assert_verdict "whoami" allow
assert_verdict "pwd" allow
assert_verdict "hostname" allow
assert_verdict "uname -a" allow
assert_verdict "date" allow
assert_verdict "id" allow

echo
echo "-- Search (should allow) --"
assert_verdict "grep -r foo ." allow
assert_verdict "rg foo" allow

echo
echo "-- Manual pages (should allow) --"
assert_verdict "man find" allow

echo
echo "-- Uniq (should allow) --"
assert_verdict "uniq" allow
assert_verdict "uniq -c" allow
assert_verdict "uniq -d -i input.txt" allow

echo
echo "-- Sort (should allow without -o/--compress-program) --"
assert_verdict "sort" allow
assert_verdict "sort -n -r" allow
assert_verdict "sort -t: -k2 /etc/passwd" allow
assert_verdict "sort -o output.txt input.txt" ask
assert_verdict "sort --compress-program=gzip bigfile" ask

echo
echo "-- Sed: safe flags (should allow) --"
assert_verdict "sed 's/foo/bar/' file" allow
assert_verdict "sed -n 's/foo/bar/p' file" allow
assert_verdict "sed -e 's/foo/bar/' -e 's/baz/qux/' file" allow
assert_verdict "sed -E 's/[0-9]+/NUM/g'" allow
assert_verdict "sed --sandbox 's/foo/bar/'" allow
assert_verdict "sed -f script.sed input.txt" allow

echo
echo "-- Sed: in-place edit (should ask) --"
assert_verdict "sed -i 's/foo/bar/' file" ask
assert_verdict "sed --in-place 's/foo/bar/' file" ask
assert_verdict "sed -i.bak 's/foo/bar/' file" ask

echo
echo "-- Nix: safe subcommands (should allow) --"
assert_verdict "nix build" allow
assert_verdict "nix build .#foo" allow
assert_verdict "nix eval .#lib.version" allow
assert_verdict "nix search nixpkgs hello" allow
assert_verdict "nix flake check" allow
assert_verdict "nix flake show" allow
assert_verdict "nix flake update" allow
assert_verdict "nix store ls --store /nix/store abc" allow
assert_verdict "nix derivation show /nix/store/foo.drv" allow
assert_verdict "nix nar ls /path/to/file.nar" allow
assert_verdict "nix path-info /nix/store/foo" allow
assert_verdict "nix-build ." allow
assert_verdict "alejandra ." allow

echo
echo "-- Nix: host execution / destructive (should ask) --"
assert_verdict "nix run .#foo" ask
assert_verdict "nix develop" ask
assert_verdict "nix shell nixpkgs#hello" ask
assert_verdict "nix repl" ask
assert_verdict "nix fmt" ask
assert_verdict "nix profile install nixpkgs#hello" ask
assert_verdict "nix store gc" ask
assert_verdict "nix store delete /nix/store/foo" ask
assert_verdict "nix flake init" ask

echo
echo "-- Nix shell --command: safe subcommand (should allow via recurse) --"
assert_verdict "nix shell nixpkgs#hello --command cat /etc/passwd" allow
assert_verdict "nix shell nixpkgs#hello -c ls -la" allow
assert_verdict "nix shell nixpkgs#hello nixpkgs#cowsay --command echo hi" allow
assert_verdict "nix shell nixpkgs#hello --verbose --command cat /etc/passwd" allow
assert_verdict "nix shell nixpkgs#hello -L --no-write-lock-file --command ls" allow

echo
echo "-- Nix shell --command: unsafe subcommand (should ask/deny via recurse) --"
assert_verdict "nix shell nixpkgs#hello --command rm foo" ask
assert_verdict "nix shell nixpkgs#hello --command rm -rf /" deny

echo
echo "-- Nix shell --command: unsafe nix flags (should ask) --"
assert_verdict "nix shell --impure nixpkgs#hello --command ls" ask
assert_verdict "nix shell --option sandbox false nixpkgs#hello --command ls" ask
assert_verdict "nix shell --expr 'import <nixpkgs> {}' --command ls" ask
assert_verdict "nix shell -f ./default.nix --command ls" ask
assert_verdict "nix shell --override-input nixpkgs github:evil/nixpkgs --command ls" ask
assert_verdict "nix shell -I nixpkgs=./evil --command ls" ask

echo
echo "-- Nix shell: no --command (interactive, should ask) --"
assert_verdict "nix shell nixpkgs#hello" ask
assert_verdict "nix shell nixpkgs#hello --verbose" ask

echo
echo "-- Nix-store: safe operations (should allow) --"
assert_verdict "nix-store -q --references /nix/store/foo" allow
assert_verdict "nix-store -r /nix/store/foo.drv" allow
assert_verdict "nix-store --verify" allow
assert_verdict "nix-store --read-log /nix/store/foo" allow

echo
echo "-- Nix-store: destructive (should ask) --"
assert_verdict "nix-store --gc" ask
assert_verdict "nix-store --delete /nix/store/foo" ask
assert_verdict "nix-store --optimise" ask

echo
echo "-- GHC: safe compilation (should allow) --"
assert_verdict "ghc -c -O2 src/Main.hs" allow
assert_verdict "ghc --make -o hook src/Main.hs" allow
assert_verdict "ghc -Wall -Werror -XOverloadedStrings file.hs" allow
assert_verdict "ghc -fforce-recomp -fPIC -dynamic src/Main.hs" allow
assert_verdict "ghc -ddump-simpl file.hs" allow
assert_verdict "ghc -v3 -j4 file.hs" allow
assert_verdict "ghc -package text -isrc file.hs" allow
assert_verdict "ghc" allow

echo
echo "-- GHC: code execution flags (should ask) --"
assert_verdict 'ghc -e "putStrLn hello"' ask
assert_verdict "ghc --interactive" ask
assert_verdict "ghc -O2 --run file.hs" ask
assert_verdict "ghc -pgmF /bin/evil file.hs" ask
assert_verdict "ghc -pgmc /usr/bin/gcc file.hs" ask
assert_verdict "ghc -fplugin=Evil file.hs" ask
assert_verdict "ghc -fplugin-library=evil.so file.hs" ask
assert_verdict "ghc --frontend Evil file.hs" ask
assert_verdict "ghc -ghci-script evil.ghci file.hs" ask
assert_verdict "ghc @opts.txt file.hs" ask

echo
echo "-- Cabal: safe compile/query subcommands (should allow) --"
assert_verdict "cabal build" allow
assert_verdict "cabal build all" allow
assert_verdict "cabal v2-build" allow
assert_verdict "cabal new-build" allow
assert_verdict "cabal haddock" allow
assert_verdict "cabal haddock-project" allow
assert_verdict "cabal v2-haddock-project" allow
assert_verdict "cabal sdist" allow
assert_verdict "cabal freeze" allow
assert_verdict "cabal gen-bounds" allow
assert_verdict "cabal configure" allow
assert_verdict "cabal target lib:foo" allow
assert_verdict "cabal list aeson" allow
assert_verdict "cabal info aeson" allow
assert_verdict "cabal path" allow
assert_verdict "cabal list-bin foo" allow
assert_verdict "cabal outdated" allow
assert_verdict "cabal check" allow
assert_verdict "cabal help" allow

echo
echo "-- Cabal: code execution (should ask via fall-through) --"
assert_verdict "cabal test" ask
assert_verdict "cabal v2-test" ask
assert_verdict "cabal bench" ask
assert_verdict "cabal run foo" ask
assert_verdict "cabal exec -- foo" ask
assert_verdict "cabal repl" ask
assert_verdict "cabal v2-run foo" ask

echo
echo "-- Cabal: destructive/install (should ask via fall-through) --"
assert_verdict "cabal clean" ask
assert_verdict "cabal install foo" ask
assert_verdict "cabal v2-install foo" ask

echo
echo "-- Cabal: network/config (should ask explicitly) --"
assert_verdict "cabal upload dist/foo.tar.gz" ask
assert_verdict "cabal report" ask
assert_verdict "cabal update" ask
assert_verdict "cabal fetch aeson" ask
assert_verdict "cabal get aeson" ask
assert_verdict "cabal init" ask
assert_verdict "cabal user-config diff" ask

echo
echo "-- Recurse: sudo (should allow if subcommand is safe) --"
assert_verdict "sudo ls /root" allow
assert_verdict "sudo cat /etc/shadow" allow

echo
echo "-- Recurse: sudo with unsafe subcommand (should ask) --"
assert_verdict "sudo rm foo.txt" ask

echo
echo "-- Deny: catastrophic commands --"
assert_verdict "rm -rf /" deny
assert_verdict "rm -rf / --no-preserve-root" deny
assert_verdict "sudo rm -rf /" deny

echo
echo "-- Ask: rm without root target --"
assert_verdict "rm foo.txt" ask
assert_verdict "rm -rf /tmp/stuff" ask

echo
echo "-- Find: safe flags (should allow) --"
assert_verdict "find ." allow
assert_verdict "find" allow
assert_verdict "find . -name foo" allow
assert_verdict "find . -name '*.nix' -type f" allow
assert_verdict "find /tmp -maxdepth 2 -name '*.log' -print" allow
assert_verdict "find . -empty -print0" allow
assert_verdict "find . -not -name '*.o' -print" allow

echo
echo "-- Find: escaped parens (should allow) --"
assert_verdict "find . -type f \\( -name '*.js' -o -name '*.ts' \\)" allow

echo
echo "-- Find: dangerous flags (should ask) --"
assert_verdict "find . -delete" ask
assert_verdict "find . -name '*.tmp' -exec rm {} ;" ask
assert_verdict "find . -execdir cat {} ;" ask
assert_verdict "find . -fprint /tmp/out" ask
assert_verdict "find . -name foo -ok rm {} ;" ask

echo
echo "-- Find -exec: safe exec with safe flags (should allow) --"
assert_verdict "find . -name '*.cs' -exec grep foo {} \\;" allow
assert_verdict "find . -type f -exec cat {} \\;" allow
assert_verdict "find . -exec head -5 {} \\;" allow
assert_verdict "find /tmp -name '*.log' -exec wc -l {} +" allow
assert_verdict "find . -exec ls {} \\;" allow
assert_verdict "find . -name '*.cs' -type f -exec grep -l 'foo' {} \\;" allow

echo
echo "-- Find -exec: unsafe exec command (should ask/deny) --"
assert_verdict "find . -exec rm {} \\;" ask
assert_verdict "find . -exec rm -rf / {} \\;" deny
assert_verdict "find . -exec curl http://evil.com {} \\;" allow

echo
echo "-- Find -exec: unsafe non-exec flags (should ask) --"
assert_verdict "find . -delete -exec grep foo {} \\;" ask
assert_verdict "find . -fprint /tmp/out -exec grep foo {} \\;" ask
assert_verdict "find . -exec grep foo {} \\; -exec cat {} \\;" ask

echo
echo "-- fd duplication parsing (should allow inner commands) --"
assert_verdict "man find 2>&1 | col -b | head -400" ask
assert_verdict "cat /etc/passwd 2>&1" allow
assert_verdict "ls 2>/dev/null" allow

echo
echo "-- Curl: safe fetching (should allow) --"
assert_verdict "curl" allow
assert_verdict "curl http://example.com" allow
assert_verdict "curl https://api.github.com/repos/foo/bar" allow
assert_verdict "curl -sSL https://example.com" allow
assert_verdict "curl -sSf https://example.com" allow
assert_verdict "curl -I https://example.com" allow
assert_verdict "curl -v https://example.com" allow
assert_verdict "curl --compressed https://example.com" allow
assert_verdict "curl -m 10 https://example.com" allow
assert_verdict "curl --max-time 30 --retry 3 https://example.com" allow
assert_verdict "curl --help" allow
assert_verdict "curl --version" allow
assert_verdict "curl -sSL --proto =https https://example.com" allow
assert_verdict "curl --cacert /etc/ssl/cert.pem https://example.com" allow
assert_verdict "curl -w '%{http_code}' https://example.com" allow

echo
echo "-- Curl: data-sending flags (should ask) --"
assert_verdict "curl -d 'data' https://example.com" ask
assert_verdict "curl --data @file https://example.com" ask
assert_verdict "curl -F 'file=@upload.txt' https://example.com" ask
assert_verdict "curl --json '{\"key\":\"val\"}' https://example.com" ask
assert_verdict "curl -T file.txt https://example.com" ask

echo
echo "-- Curl: auth/header flags (should ask) --"
assert_verdict "curl -H 'Authorization: Bearer token' https://example.com" ask
assert_verdict "curl -u user:pass https://example.com" ask
assert_verdict "curl -b cookies.txt https://example.com" ask
assert_verdict "curl -n https://example.com" ask

echo
echo "-- Curl: file-writing flags (should ask) --"
assert_verdict "curl -o output.html https://example.com" ask
assert_verdict "curl -O https://example.com/file.txt" ask
assert_verdict "curl -D headers.txt https://example.com" ask
assert_verdict "curl -c cookies.txt https://example.com" ask
assert_verdict "curl --trace trace.log https://example.com" ask

echo
echo "-- Curl: method/config/variable flags (should ask) --"
assert_verdict "curl -X POST https://example.com" ask
assert_verdict "curl -K config.txt" ask
assert_verdict "curl --variable '%SECRET' https://example.com" ask

echo
echo "-- Curl: xargs with curl (should ask — probe flag fails) --"
assert_verdict "xargs curl http://example.com" ask

echo
echo "-- Systemctl: read-only subcommands (should allow) --"
assert_verdict "systemctl cat foo.service" allow
assert_verdict "systemctl --user status sshd.service" allow
assert_verdict "systemctl --no-pager list-units" allow
assert_verdict "systemctl show --property=MainPID sshd.service" allow
assert_verdict "systemctl is-active sshd.service" allow
assert_verdict "systemctl list-unit-files" allow
assert_verdict "systemctl get-default" allow
assert_verdict "systemctl show-environment" allow

echo
echo "-- Systemctl: mutation subcommands (should ask) --"
assert_verdict "systemctl restart sshd.service" ask
assert_verdict "systemctl enable foo.service" ask
assert_verdict "systemctl daemon-reload" ask
assert_verdict "systemctl start foo.service" ask
assert_verdict "systemctl stop foo.service" ask
assert_verdict "systemctl reboot" ask
assert_verdict "systemctl set-environment FOO=bar" ask

echo
echo "-- Git: read-only (should allow) --"
assert_verdict "git status" allow
assert_verdict "git diff" allow
assert_verdict "git log --oneline -5" allow

echo
echo "-- Git: local writes (should allow) --"
assert_verdict "git add ." allow
assert_verdict "git commit -m 'test'" allow

echo
echo "-- Git: branch listing (should allow) --"
assert_verdict "git branch" allow
assert_verdict "git branch -a" allow
assert_verdict "git branch -r" allow
assert_verdict "git branch -v" allow
assert_verdict "git branch -vv" allow
assert_verdict "git branch --show-current" allow
assert_verdict "git branch --list" allow
assert_verdict "git branch --contains abc123" allow
assert_verdict "git branch --merged main" allow
assert_verdict "git branch --sort=-committerdate" allow
assert_verdict "git branch -a -v --sort=-committerdate" allow

echo
echo "-- Git: branch mutation (should ask) --"
assert_verdict "git branch newbranch" ask
assert_verdict "git branch -d foo" ask
assert_verdict "git branch -D foo" ask
assert_verdict "git branch -m old new" ask
assert_verdict "git branch -M old new" ask
assert_verdict "git branch -c foo bar" ask
assert_verdict "git branch --set-upstream-to=origin/main" ask
assert_verdict "git branch --unset-upstream" ask
assert_verdict "git branch --edit-description" ask

echo
echo "-- Git: tag listing (should allow) --"
assert_verdict "git tag" allow
assert_verdict "git tag -l" allow
assert_verdict "git tag -l 'v1.*'" allow
assert_verdict "git tag -n5" allow
assert_verdict "git tag -v v1.0" allow
assert_verdict "git tag --sort=-creatordate" allow
assert_verdict "git tag --contains abc123" allow
assert_verdict "git tag -l --sort=refname --column=always" allow

echo
echo "-- Git: tag mutation (should ask) --"
assert_verdict "git tag v1.0" ask
assert_verdict "git tag -a v1.0 -m 'release'" ask
assert_verdict "git tag -d v1.0" ask
assert_verdict "git tag -f v1.0" ask
assert_verdict "git tag -s v1.0" ask

echo
echo "-- Git: -C global option (should allow) --"
assert_verdict "git -C /etc/nixos status" allow
assert_verdict "git -C /etc/nixos diff foo" allow
assert_verdict "git -C /etc/nixos log --oneline -5" allow
assert_verdict "git -C /etc/nixos branch -a" allow
assert_verdict "git -C /etc/nixos tag -l" allow
assert_verdict "git -C /etc/nixos add ." allow
assert_verdict "git -C /etc/nixos push" ask

echo
echo "-- Git: worktree read-only (should allow) --"
assert_verdict "git worktree list" allow
assert_verdict "git worktree list -v" allow
assert_verdict "git worktree list --porcelain" allow

echo
echo "-- Git: worktree lock (should allow) --"
assert_verdict "git worktree lock /tmp/wt" allow
assert_verdict "git worktree lock --reason 'on USB' /tmp/wt" allow

echo
echo "-- Git: worktree add safe (should allow) --"
assert_verdict "git worktree add /tmp/wt" allow
assert_verdict "git worktree add -b feature /tmp/wt" allow
assert_verdict "git worktree add --detach /tmp/wt HEAD" allow
assert_verdict "git worktree add -f --lock /tmp/wt main" allow
assert_verdict "git worktree add -q --orphan /tmp/wt" allow
assert_verdict "git -C /etc/nixos worktree add /tmp/wt" allow

echo
echo "-- Git: worktree add -B (should ask) --"
assert_verdict "git worktree add -B feature /tmp/wt" ask

echo
echo "-- Git: worktree mutation (should ask) --"
assert_verdict "git worktree remove /tmp/wt" ask
assert_verdict "git worktree move /tmp/wt /tmp/wt2" ask
assert_verdict "git worktree prune" ask
assert_verdict "git worktree repair" ask
assert_verdict "git worktree unlock /tmp/wt" ask

echo
echo "-- Git: remote/destructive (should ask) --"
assert_verdict "git push" ask
assert_verdict "git reset --hard" ask

echo
echo "-- Ask: destructive but not catastrophic --"
assert_verdict "mkfs /dev/sda1" deny
assert_verdict "dd if=/dev/zero of=/dev/sda" deny

echo
echo "-- Overwrite: /dev/null (should allow) --"
assert_verdict "echo hello > /dev/null" allow

echo
echo "-- Overwrite: new file (should allow) --"
NEWFILE=$(mktemp -u)  # generate name without creating
assert_verdict "echo hello > $NEWFILE" allow

echo
echo "-- Overwrite: existing file (should ask) --"
EXISTFILE=$(mktemp)   # actually create the file
assert_verdict "echo hello > $EXISTFILE" ask
rm -f "$EXISTFILE"

echo
echo "-- Xargs: unconditionally safe subcommand (should allow) --"
assert_verdict 'xargs grep -l "InfluxDB\|Timeseries"' allow
assert_verdict "xargs -0 cat" allow
assert_verdict "xargs -n 1 head" allow
assert_verdict "xargs ls" allow
assert_verdict "xargs -I {} stat {}" allow
assert_verdict "xargs -I{} basename {}" allow
assert_verdict "ls /home/bakhtiyar/code/neurasium/backend/server/api/mutations/src/*.rs 2>/dev/null | xargs -I{} basename {} .rs | sort" allow

echo
echo "-- Xargs: conditionally safe subcommand (should ask) --"
assert_verdict "xargs rm" ask
assert_verdict "xargs find . -delete" ask
assert_verdict "xargs sort -o out" ask

echo
echo "-- Xargs: unknown subcommand (should ask) --"
assert_verdict "xargs curl http://example.com" ask

echo
echo "-- Xargs: unknown xargs flags (should ask) --"
assert_verdict "xargs --unknown-flag grep foo" ask

echo
echo "-- Heredoc: basic (should allow) --"
assert_verdict $'cat << EOF\nhello\nEOF' allow
assert_verdict $'cat << \'EOF\'\nhello\nEOF' allow
assert_verdict $'cat << "EOF"\nhello\nEOF' allow
assert_verdict $'cat <<EOF\nhello\nEOF' allow
assert_verdict $'cat <<- EOF\n\thello\nEOF' allow
assert_verdict $'cat <<- EOF\n\thello\n\tEOF' allow

echo
echo "-- Heredoc: body not evaluated as commands --"
assert_verdict $'cat << EOF\nrm -rf /\nEOF' allow
assert_verdict $'cat << EOF\ncurl http://evil.com\nEOF' allow

echo
echo "-- Heredoc: empty body --"
assert_verdict $'cat << EOF\nEOF' allow

echo
echo "-- Heredoc: body line resembles but isn't delimiter --"
assert_verdict $'cat << EOF\nEOFish\nEOF' allow

echo
echo "-- Heredoc: no body (at end of input) --"
assert_verdict 'cat << EOF' allow

echo
echo "-- Heredoc: redirect AFTER delimiter (should detect overwrite) --"
HFILE=$(mktemp)
assert_verdict $'cat << EOF > '"$HFILE"$'\nhello\nEOF' ask
rm -f "$HFILE"

echo
echo "-- Heredoc: redirect before delimiter (already worked) --"
HFILE2=$(mktemp)
assert_verdict $'cat > '"$HFILE2"$' << EOF\nhello\nEOF' ask
rm -f "$HFILE2"

echo
echo "-- Heredoc: append after delimiter --"
assert_verdict $'cat << EOF >> /tmp/out\nhello\nEOF' ask

echo
echo "-- Heredoc: FD redirect after delimiter --"
assert_verdict $'cat << EOF 2>/dev/null\nhello\nEOF' allow

echo
echo "-- Heredoc: followed by safe command --"
assert_verdict $'cat << EOF\nhello\nEOF\nls' allow

echo
echo "-- Heredoc: followed by unsafe command --"
assert_verdict $'cat << EOF\nhello\nEOF\nrm foo' ask

echo
echo "-- Heredoc: multiple heredocs on one command --"
assert_verdict $'cat << A << B\nbody1\nA\nbody2\nB' allow

echo
echo "-- Heredoc: in pipeline (body not consumed at pipe, conservative ask) --"
assert_verdict $'cat << EOF | grep hello\nhello\nEOF' ask

echo
echo "-- Heredoc: inside command substitution (should allow) --"
assert_verdict $'echo "$(cat <<\'EOF\'\nhello\nEOF\n)"' allow
assert_verdict $'echo "$(cat <<EOF\nhello\nEOF\n)"' allow

echo
echo "-- Heredoc: in command substitution with special chars in body --"
assert_verdict $'echo "$(cat <<\'EOF\'\nit\'s got quotes\nEOF\n)"' allow
assert_verdict $'echo "$(cat <<\'EOF\'\nparens ) ( here\nEOF\n)"' allow
assert_verdict $'echo "$(cat <<\'EOF\'\nangles <foo@bar.com>\nEOF\n)"' allow

echo
echo "-- Heredoc: in command substitution chained with other commands --"
assert_verdict $'git commit -m "$(cat <<\'EOF\'\nmessage\nEOF\n)" && git status' allow

echo
echo "-- Heredoc: in command substitution with unsafe chained command --"
assert_verdict $'echo "$(cat <<\'EOF\'\nhello\nEOF\n)" && rm foo' ask

echo
echo "-- ANSI-C quoting: basic (should allow) --"
assert_verdict "echo \$'hello'" allow
assert_verdict "echo \$'hello world'" allow

echo
echo "-- ANSI-C quoting: with backslash escapes --"
assert_verdict "echo \$'it\\'s'" allow
assert_verdict "echo \$'line1\\nline2'" allow
assert_verdict "echo \$'tab\\there'" allow

echo
echo "-- ANSI-C quoting: inside double quotes --"
assert_verdict "echo \"prefix \$'it\\'s' suffix\"" allow

echo
echo "-- ANSI-C quoting: inside command substitution --"
assert_verdict "echo \$(echo \$'hello')" allow

echo
echo "-- ANSI-C quoting: chained with other commands --"
assert_verdict "echo \$'hello' && echo \$'world'" allow
assert_verdict "echo \$'hello' && rm foo" ask

echo
echo "-- ANSI-C quoting: in unsafe context --"
assert_verdict "rm \$'some file'" ask

echo
echo "-- Strace: safe tracing of safe commands (should allow) --"
assert_verdict "strace ls" allow
assert_verdict "strace -f -e trace=open cat /etc/passwd" allow
assert_verdict "strace -c ls" allow
assert_verdict "strace --help" allow
assert_verdict "strace -f -s 256 -e trace=file ls -la" allow

echo
echo "-- Strace: attach mode (should allow) --"
assert_verdict "strace -p 12345" allow
assert_verdict "strace -f -p 12345" allow

echo
echo "-- Strace: dangerous flags (should ask) --"
assert_verdict "strace -e inject=write:error=ENOSPC ls" ask
assert_verdict "strace -e fault=write ls" ask
assert_verdict "strace --inject=write:error=EIO ls" ask
assert_verdict "strace --fault=write ls" ask
assert_verdict "strace --kill-on-exit ls" ask
assert_verdict "strace -o /tmp/trace ls" ask
assert_verdict "strace --output=/tmp/trace ls" ask
assert_verdict "strace -u nobody ls" ask
assert_verdict "strace --user=nobody ls" ask

echo
echo "-- Strace: unsafe subcommand (should ask) --"
assert_verdict "strace rm foo" ask
assert_verdict "strace -f wget http://evil.com" ask

echo
echo "-- Strace: catastrophic subcommand (should deny) --"
assert_verdict "strace rm -rf /" deny

echo
echo "-- Append: redirects (should ask) --"
assert_verdict "echo hello >> /tmp/out" ask

echo
echo "=== Results: $pass passed, $fail failed ==="
if [ "$fail" -gt 0 ]; then
  exit 1
fi
