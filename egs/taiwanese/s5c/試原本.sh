#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

tshi3='tshi3/train'
(
  utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

  utils/fix_data_dir.sh $tshi3

  mfccdir=tshi3/mfcc
  make_mfcc_dir=exp/make_mfcc/tshi3
  rm -rf $mfccdir $make_mfcc_dir

  steps/make_mfcc.sh --nj 4 --cmd "$train_cmd" \
   $tshi3 $make_mfcc_dir $mfccdir
  steps/compute_cmvn_stats.sh $tshi3 $make_mfcc_dir $mfccdir
)
graph_dir=exp/tri4/graph_sp
(
  steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir $tshi3 exp/tri4/decode_tshi3_data_lang
)
(
  steps/decode.sh --nj 1 --cmd "$decode_cmd" \
    --config conf/decode.config \
    --iter 4 \
    $graph_dir $tshi3 exp/tri4_mpe/decode_tshi3_data_lang
)
