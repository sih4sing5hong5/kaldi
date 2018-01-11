#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

for x in exp/{tri1,tri2,tri3,tri4}/decode_train_dev* ; do
  echo "$x:"
  cat $x/wer_* | grep WER | ./utils/best_wer.sh 
done
