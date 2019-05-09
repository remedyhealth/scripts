#!/bin/bash
files=$(find ./ -name '*.jpg')
for jpg in $files
do
  webp=${jpg/%jpg/webp}
  if [ ! -f $webp ]; then
    echo "The webp version does not exist";
  fi
done

files=$(find ./ -name '*.jpeg')
for jpg in $files
do
  webp=${jpg/%jpeg/webp}
  if [ ! -f $webp ]; then
    echo "The webp version does not exist";
  fi
done
