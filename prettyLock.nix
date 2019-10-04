{ config, pkgs, ... }:
with pkgs;
writeShellScriptBin "prettyLock" ''
  ${i3lock-color}/bin/i3lock-color \
      --image=${./wallpaper.jpg} \
      --radius=40 \
      --indicator \
      --clock \
      --keylayout \
      --indpos="w/2:h/2" \
      --timepos="ix+100:iy" \
      --datepos="tx:ty+50" \
      --datestr="%A, %Y-%m-%d" \
      --timesize=50 \
      --datesize=20 \
      --layoutsize=15 \
      --keyhlcolor=6060f0ff \
      --bshlcolor=000000ff \
      --separatorcolor=00000000 \
      --ringcolor=ffffffff \
      --ringvercolor=ff8000ff \
      --ringwrongcolor=f00000ff \
      --insidecolor=00000000 \
      --insidevercolor=00000000 \
      --insidewrongcolor=00000000 \
      --line-uses-inside \
      --ring-width=3 \
      --veriftext="" \
      --wrongtext="" \
      --noinputtext="" \
      --timecolor="ffffffff" \
      --datecolor="ffffffff" \
      --layoutcolor="ffffffff" \
      --time-align=1 \
      --date-align=1 \
      --time-align=1 \
      --layout-align=1 \
      --tiling
''
