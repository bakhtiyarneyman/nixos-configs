{
  runCommand,
  fish,
  python3,
  shpool,
}:
runCommand "shpool-integration" {nativeBuildInputs = [fish python3];} ''
  mkdir -p $out/bin $out/share/fish/vendor_completions.d
  substitute ${../scripts/shpool-client} $out/bin/shpool \
    --replace-fail 'shutil.which("shpool")' '"${shpool}/bin/shpool"'
  cp ${../scripts/shpool-session-info} $out/bin/shpool-session-info
  substitute ${../alacritty-shpool} $out/bin/alacritty-shpool \
    --replace-fail '/etc/nixos/scripts/shpool-client' "$out/bin/shpool" \
    --replace-fail 'shpool list' '${shpool}/bin/shpool list'
  substitute ${../scripts/shpool-session-info.fish} $out/share/fish/shpool.fish \
    --replace-fail '/etc/nixos/scripts/shpool-session-info' "$out/bin/shpool-session-info"
  substitute ${../scripts/shpool-completions.fish} $out/share/fish/vendor_completions.d/shpool.fish \
    --replace-fail '/etc/nixos/scripts/shpool-session-info' "$out/bin/shpool-session-info" \
    --replace-fail 'command shpool' 'command ${shpool}/bin/shpool'
  chmod +x $out/bin/*
  patchShebangs $out/bin
''
