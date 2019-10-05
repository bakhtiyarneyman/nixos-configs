mkdir -p $out/src
cd $src
for f in $(find . -regex ".*\.fish")
do
  # Can't preserve the folder structure. This gives permission errors for some reason.
  # cp --parents $f $out/src
  cp $f $out/src
done
find $out/src -regex ".*\.fish" | sed -e "s/^/source /" > $out/loadPlugin.fish
