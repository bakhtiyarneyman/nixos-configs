''
  mkdir -p $out/src/conf.d

  cd $src
  for f in $(find . -regex ".*\.fish")
  do
    cp --parents --no-preserve=mode,ownership,timestamps $f $out/src || exit 1
  done
  # The sort is a hack that puts functions before conf.d. We want this because z invokes functions
  # on load.
  find $out/src -regex ".*\.fish" |\
    grep -v -E "(/test/|uninstall)" |\
    sed -e "s/^/source /" |\
    env LC_COLLATE=C sort --reverse >\
    $out/loadPlugin.fish
''
