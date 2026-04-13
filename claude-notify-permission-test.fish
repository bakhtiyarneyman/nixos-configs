#!/usr/bin/env fish
# Tests for claude-notify-permission formatting pipeline.

set pass 0
set fail 0

function assert_eq -a label expected actual
    if test "$expected" = "$actual"
        echo "  PASS: $label"
        set -g pass (math $pass + 1)
    else
        echo "  FAIL: $label"
        echo "    expected: $(string escape -- $expected)"
        echo "    actual:   $(string escape -- $actual)"
        set -g fail (math $fail + 1)
    end
end

echo "=== claude-notify-permission tests ==="
echo

# --- Fix 1: sed splitting produces actual newlines (not literal \n) ---
echo "-- sed+shfmt splitting --"

set -l split_sed 's/ && / \\\\\n  \&\& /g; s/ || / \\\\\n  || /g; s/ | / \\\\\n  | /g'

set result (echo 'echo 123 | rm foo' | sed $split_sed | shfmt -bn -i 2 - | string collect)
assert_eq "pipe splits into two lines" 2 (echo $result | wc -l | string trim)

set result (echo 'a && b || c' | sed $split_sed | shfmt -bn -i 2 - | string collect)
assert_eq "&&/|| splits into three lines" 3 (echo $result | wc -l | string trim)

set result (echo 'echo hello' | sed $split_sed | shfmt -bn -i 2 - | string collect)
assert_eq "no operators stays one line" 1 (echo $result | wc -l | string trim)

# Verify backslash at end of continuation lines
set result (echo 'a | b' | sed $split_sed | shfmt -bn -i 2 - | string collect)
set first_line (echo $result | head -1)
assert_eq "continuation line ends with backslash" '\\' (string sub -s -1 -- $first_line)

# --- Fix 2: xml_escape encodes backslashes as &#92; ---
echo
echo "-- xml_escape backslash encoding --"

set -l xml_escape 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\\\\/\\&#92;/g'

assert_eq "bare backslash becomes entity" '&#92;' (printf '%s' '\\' | sed $xml_escape)
assert_eq "backslash-n becomes entity-n" '&#92;n' (printf '%s' '\\n' | sed $xml_escape)
assert_eq "ampersand still escaped" '&amp;' (printf '%s' '&' | sed $xml_escape)
assert_eq "less-than still escaped" '&lt;' (printf '%s' '<' | sed $xml_escape)
assert_eq "greater-than still escaped" '&gt;' (printf '%s' '>' | sed $xml_escape)
assert_eq "no backslash unchanged" 'hello' (printf '%s' 'hello' | sed $xml_escape)

# Combined: backslash before &
assert_eq "backslash-ampersand" '&#92;&amp;' (printf '%s' '\\&' | sed $xml_escape)

echo
echo "=== Results: $pass passed, $fail failed ==="
if test $fail -gt 0
    exit 1
end
