#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

STAGE=0
nj=4

lang=$1 # data/lang_free

# Now make MFCC features.
if [ $STAGE -le 6 ]; then
  utils/utt2spk_to_spk2utt.pl data/dev/utt2spk > data/dev/spk2utt
  for i in dev; do
    data_dir=data/$i
    make_mfcc_log=data/mfcc_log/$i
    mfccdir=data/mfcc/$i
    rm -rf $make_mfcc_log $mfccdir
    mkdir -p $make_mfcc_log $mfccdir
    utils/fix_data_dir.sh $data_dir
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
     $data_dir $make_mfcc_log $mfccdir
    steps/compute_cmvn_stats.sh $data_dir $make_mfcc_log $mfccdir
  done
fi

if [ $STAGE -le 10 ]; then
  (
    graph_dir=exp/tri1/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $lang exp/tri1 $graph_dir
    steps/decode_si.sh --nj $nj --cmd "$decode_cmd" --config conf/decode.config \
      $graph_dir data/dev exp/tri1/decode_train_dev
  ) &
  (
    graph_dir=exp/tri2/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $lang exp/tri2 $graph_dir
    steps/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode.config \
      $graph_dir data/dev exp/tri2/decode_train_dev
  ) &
  (
    graph_dir=exp/tri3/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $lang exp/tri3 $graph_dir
    steps/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode.config \
      $graph_dir data/dev exp/tri3/decode_train_dev
  ) &
  (
    graph_dir=exp/tri4/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $lang exp/tri4 $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/dev exp/tri4/decode_train_dev
  ) &
fi

exit 0

if [ $STAGE -le 11 ]; then
  (
    graph_dir=exp/tri5/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $lang exp/tri5 $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/dev exp/tri5/decode_train_dev
  )
fi