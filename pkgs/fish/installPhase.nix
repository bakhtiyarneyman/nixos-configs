''
  mkdir -p $out/src/conf.d

  cd $src
  for f in $(find . -regex ".*\.fish")
  do
    cp --parents --no-preserve=mode,ownership,timestamps $f $out/src || exit 1
  done
  # The sort is a hack that tries to put files that start with an underscore ahead of those that
  # don't. We want this because z invokes functions on load so we want them to load in correct order.
  find $out/src -regex ".*\.fish" |\
    grep -v -E "(/test/|uninstall)" |\
    sed -e "s/^/source /" |\
    env LC_COLLATE=C sort >\
    $out/loadPlugin.fish
''