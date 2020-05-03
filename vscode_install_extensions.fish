#!/run/current-system/sw/bin/fish
for ext in (cat vscode_extensions.txt)
  code --install-extension $ext
end 