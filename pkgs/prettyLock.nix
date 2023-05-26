{ config, pkgs, ... }:
with pkgs;
writeShellScriptBin "prettyLock" ''
  ${swaylock}/bin/swaylock \
    --indicator-radius=40 \
    --show-failed-attempts \
    --image=${../wallpaper.jpg} \
    --color="000000ff" \
    --key-hl-color="6060f0ff" \
    --bs-hl-color="c678ddff" \
    --separator-color="00000000" \
    --text-ver-color="c678ddff" \
    --text-wrong-color="e06c75ff" \
    --text-clear-color="56b6c2ff" \
    --ring-color="ffffffff" \
    --ring-wrong-color="e06c75ff" \
    --ring-ver-color="c678ddff" \
    --ring-clear-color="56b6c2ff" \
    --inside-color="00000000" \
    --inside-ver-color="00000000" \
    --inside-wrong-color="00000000" \
    --inside-clear-color="00000000" \
    --layout-bg-color="00000000" \
    --line-uses-inside \
    --indicator-thickness=3
''
