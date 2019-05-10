#!/bin/bash
# To install Google's webp conversion library using Homebrew.
# run `brew install webp`
# You should now be able to use the `cwebp` command.
#
find ./ -type f -name  "*.jpg" |
  while read jpg
  do
    webp="${jpg/%jpg/webp}";
    if [ ! -f "$webp" ]; then
      echo "The webp version does not exist";
      cwebp -q 80 "$jpg" -o "$webp";
    fi
done

find ./ -type f -name  "*.jpeg" |
  while read jpeg
  do
    webp="${jpeg/%jpeg/webp}";
    if [ ! -f "$webp" ]; then
      echo "The webp version does not exist";
      cwebp -q 80 "$jpeg" -o "$webp";
    fi
done

find ./ -type f -name  "*.png" |
  while read png
  do
    webp="${png/%png/webp}";
    if [ ! -f "$webp" ]; then
      echo "The webp version does not exist";
      cwebp -q 80 "$png" -o "$webp";
    fi
done
