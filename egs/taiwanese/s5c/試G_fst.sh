#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

# # Now train the language models.
LM='tshi3/lang/語言模型.lm'

LANG_DIR='tshi3/lang_new_g'

utils/prepare_lang.sh tshi3/local/dict "<UNK>"  tshi3/local/lang $LANG_DIR

cat $LM | utils/find_arpa_oovs.pl $LANG_DIR/words.txt  > $LANG_DIR/arpa_oov.txt
cat $LM | \
  grep -v '<s> <s>' | \
  grep -v '</s> <s>' | \
  grep -v '</s> </s>' | \
  arpa2fst - | fstprint | \
  utils/remove_oovs.pl $LANG_DIR/arpa_oov.txt | \
  utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=$LANG_DIR/words.txt \
    --osymbols=$LANG_DIR/words.txt  --keep_isymbols=false --keep_osymbols=false | \
   fstrmepsilon | fstarcsort > $LANG_DIR/G.fst

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
graph_dir=exp/tri4/graph_new_g
$train_cmd $graph_dir/mkgraph.log \
  utils/mkgraph.sh $LANG_DIR exp/tri4 $graph_dir
(
  steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir $tshi3 exp/tri4/decode_new_g
)
(
  steps/decode.sh --nj 1 --cmd "$decode_cmd" \
    --config conf/decode.config \
    --iter 4 \
    $graph_dir $tshi3 exp/tri4_mpe/decode_new_g
)
