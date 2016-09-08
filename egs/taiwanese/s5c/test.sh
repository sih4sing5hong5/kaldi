#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error
test_dir=train_dev

graph_dir=exp/tri1/graph_nosp_sw1_tg
$train_cmd $graph_dir/mkgraph.log \
  utils/mkgraph.sh data/lang exp/tri1 $graph_dir
steps/decode_si.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
  $graph_dir data/$test_dir exp/tri1/decode_test

