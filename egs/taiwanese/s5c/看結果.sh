#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

for x in tri1 tri2 tri3 tri4 tri4_mmi_b0.1 tri4_fmmi_b0.1; do
  echo "$x:"
  cat exp/$x/decode_train_dev/wer_* | grep WER | sort -g | head -n 1
done
