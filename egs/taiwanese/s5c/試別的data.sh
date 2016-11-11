#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

tshi3='/home/johndoe/git/kaldi/egs/taiwanese/s5c/data/train_dev'
lang='/home/johndoe/git/kaldi/egs/taiwanese/s5c/data/lang'
graph_dir=exp/tri4/graph_pah8
(
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh $lang exp/tri4 $graph_dir

  steps/decode_fmllr.sh --nj 16 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir $tshi3 exp/tri4/decode_pah8
)
