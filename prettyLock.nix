{ config, pkgs, ... }:
with pkgs;
writeShellScriptBin "prettyLock" ''
  ${i3lock-color}/bin/i3lock-color \
    --radius=40 \
    --indicator \
    --force-clock \
    --keylayout \
    --datestr="%A, %Y-%m-%d" \
    --verif-text="Authenticating..." \
    --wrong-text="Try again." \
    --greeter-text="bakhtiyarneyman@gmail.com" \
    --noinput-text="" \
    --ind-pos="w/2:h/2" \
    --time-pos="ix+100:iy" \
    --date-pos="tx:ty+50" \
    --layout-pos="ix-100:iy+8" \
    --greeter-pos="ix:iy+300" \
    --verif-pos="ix:iy-150" \
    --wrong-pos="ix:iy-150" \
    --modif-pos="ix:iy-100" \
    --time-size=50 \
    --date-size=20 \
    --greeter-size=16 \
    --layout-size=16 \
    --time-align=1 \
    --date-align=1 \
    --layout-align=2 \
    --greeter-align=0 \
    --color="00000020" \
    --keyhl-color="6060f0ff" \
    --bshl-color="c678ddff" \
    --separator-color="00000000" \
    --verif-color="c678ddff" \
    --wrong-color="e06c75ff" \
    --ring-color="ffffffff" \
    --ringwrong-color="e06c75ff" \
    --ringver-color="c678ddff" \
    --inside-color="00000000" \
    --insidever-color="00000000" \
    --insidewrong-color="00000000" \
    --time-color="ffffffff" \
    --date-color="ffffffff" \
    --layout-color="ffffffff" \
    --greeter-color="ffffffff" \
    --line-uses-inside \
    --ring-width=3 \
    --tiling \
    --redraw-thread
''
