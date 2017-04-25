#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

tshi3=$2
tshi3='tui3tse5/train'
lang='data/lang_sp'
(
  utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

  utils/fix_data_dir.sh  $tshi3

  mfccdir=$tshi3/mfcc
  make_mfcc_dir=$tshi3/make_mfcc/

  steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
   $tshi3 $make_mfcc_dir $mfccdir
  steps/compute_cmvn_stats.sh $tshi3 $make_mfcc_dir $mfccdir
)

steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  $tshi3 $lang exp/tri5.2 exp/tui3tse5_ali

# zcat exp/tui3tse5_ali/ali.1.gz | \
#   lattice-push ark:- ark:- | \
#   lattice-align-words data/lang_sp/phones/word_boundary.int exp/tri5.2/final.mdl ark:- ark:- | \
#   lattice-to-ctm-conf --acoustic-scale=0.1 ark:- exp/lang_sp/1.conf


zcat exp/tui3tse5_ali/ali.1.gz | \
  ali-to-post ark:- ark,t:exp/tui3tse5_ali/1.conf

zcat exp/tui3tse5_ali/ali.1.gz | \
  ali-to-phones --ctm-output --ctm-output exp/tri5.2/final.mdl ark:- exp/tui3tse5_ali/1.ctm

steps/get_train_ctm.sh $tshi3 $lang exp/tui3tse5_ali