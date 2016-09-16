#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

# # Now train the language models.
LM='tshi3/lang/語言模型.lm'

LANG_DIR='tshi3/lang_format_sri'

utils/prepare_lang.sh tshi3/local/dict "<UNK>"  tshi3/local/lang tshi3/lang

LM_GZ='tshi3/lang/語言模型.lm.gz'
cat $LM | gzip > $LM_GZ
utils/format_lm_sri.sh tshi3/lang $LM_GZ $LANG_DIR

tshi3='tshi3/train'
(
  utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

  utils/fix_data_dir.sh $tshi3

  mfccdir=tshi3/mfcc
  make_mfcc_dir=exp/make_mfcc/tshi3
  rm -rf $mfccdir make_mfcc_dir

  steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
   $tshi3 $make_mfcc_dir $mfccdir
  steps/compute_cmvn_stats.sh $tshi3 $make_mfcc_dir $mfccdir
)
(
  graph_dir=exp/tri4/graph

  steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir $tshi3 exp/tri4/decode_tshi3

  steps/lmrescore.sh  --cmd "$decode_cmd" \
    data/lang $LANG_DIR $tshi3 \
    exp/tri4/decode_tshi3 exp/tri4/decode_tshi3.format_sri
)
