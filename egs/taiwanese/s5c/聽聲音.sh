#!/bin/bash

set -e # exit on error

if [ ! $# -eq 1 ]; then
  echo '愛參數'
  exit 1
fi

if [ -x "gshuf" ];then
  echo gshuf
else
  echo shuf
fi

lai5thiann1=`cat $1 | \
  awk '{print $1}' | \
  grep -vwF -f 有問題的音檔.表 | \
  grep -vwF -f 無問題的音檔.表 | \
  gshuf -n 50 |\
  sort | \
  cat`

for i in $lai5thiann1; do
  bash 揣聲音.sh $i
	while true ; do
    read -p "e好，f無好?" yn
    if [ "$yn" = "e" ]; then
      echo "$i" >> 無問題的音檔.表
      break
    elif  [ "$yn" = "f" ]; then
      echo "$i" >> 有問題的音檔.表
      break
    else
      echo '無採用'
      play aa.wav 2> /dev/null
    fi
    echo
  done
done
