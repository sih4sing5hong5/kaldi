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
  gshuf -n 100`

for i in $lai5thiann1; do
	echo bash 揣聲音.sh $i
  read -p "a好，b無好?" yn
  if [ $yn = "a" ]; then
    echo "$i" >> 無問題的音檔.表
  elif  [ $yn = "b" ]; then
    echo "$i" >> 有問題的音檔.表
  else
    echo '無採用'
  fi
  echo
done
