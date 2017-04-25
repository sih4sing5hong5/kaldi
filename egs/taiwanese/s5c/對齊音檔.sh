#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

tshi3=$2
tshi3='tui3tse5/train'
lang='tui3tse5/lang_dict'
(
  utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

  utils/fix_data_dir.sh $tshi3

  mfccdir=$tshi3/mfcc
  make_mfcc_dir=$tshi3/make_mfcc/

  steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
   $tshi3 $make_mfcc_dir $mfccdir
  steps/compute_cmvn_stats.sh $tshi3 $make_mfcc_dir $mfccdir
)

cp data/local/dict/[^l]* tui3tse5/local/dict
utils/prepare_lang.sh tui3tse5/local/dict "<UNK>"  tui3tse5/local/lang $lang

steps/align_fmllr.sh --beam 100 --retry-beam 150 --nj 1 --cmd "$train_cmd" \
  $tshi3 $lang exp/tri5.2 exp/tui3tse5_ali

steps/get_train_ctm.sh $tshi3 $lang exp/tui3tse5_ali