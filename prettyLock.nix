{ config, pkgs, ... }:
with pkgs;
writeShellScriptBin "prettyLock" ''
  ${i3lock-color}/bin/i3lock-color \
    --radius=40 \
    --indicator \
    --force-clock \
    --keylayout \
    --datestr="%A, %Y-%m-%d" \
    --veriftext="Authenticating..." \
    --wrongtext="Try again." \
    --greetertext="bakhtiyarneyman@gmail.com" \
    --noinputtext="" \
    --indpos="w/2:h/2" \
    --timepos="ix+100:iy" \
    --datepos="tx:ty+50" \
    --layoutpos="ix-100:iy+8" \
    --greeterpos="ix:iy+300" \
    --verifpos="ix:iy-150" \
    --wrongpos="ix:iy-150" \
    --modifpos="ix:iy-100" \
    --timesize=50 \
    --datesize=20 \
    --greetersize=16 \
    --layoutsize=16 \
    --time-align=1 \
    --date-align=1 \
    --layout-align=2 \
    --greeter-align=0 \
    --color="00000020" \
    --keyhlcolor="6060f0ff" \
    --bshlcolor="c678ddff" \
    --separatorcolor="00000000" \
    --verifcolor="c678ddff" \
    --wrongcolor="e06c75ff" \
    --ringcolor="ffffffff" \
    --ringwrongcolor="e06c75ff" \
    --ringvercolor="c678ddff" \
    --insidecolor="00000000" \
    --insidevercolor="00000000" \
    --insidewrongcolor="00000000" \
    --line-uses-inside \
    --ring-width=3 \
    --timecolor="ffffffff" \
    --datecolor="ffffffff" \
    --layoutcolor="ffffffff" \
    --greetercolor="ffffffff" \
    --tiling \
    --redraw-thread
''
