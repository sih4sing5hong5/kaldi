#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

if [ $# -ne 1 ]; then
  echo "$0 arpa"
  exit 1
fi

# # Now train the language models.
LM=$1
LM_GZ='tshi3/local/lm/format_lm.arpa.gz'
mkdir -p 'tshi3/local/lm/'

LANG_DIR='tshi3/lang_format_lm'

cat $LM | gzip > $LM_GZ
rm -rf $LANG_DIR
utils/format_lm.sh data/lang_sp $LM_GZ data/local/dict/lexicon.txt $LANG_DIR

tshi3='tshi3/train'
(
  utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

  utils/fix_data_dir.sh $tshi3

  mfccdir=tshi3/mfcc/format_lm
  make_mfcc_dir=exp/make_mfcc/tshi3_format_lm
  rm -rf $mfccdir $make_mfcc_dir

  steps/make_mfcc.sh --nj 16 --cmd "$train_cmd" \
   $tshi3 $make_mfcc_dir $mfccdir
  steps/compute_cmvn_stats.sh $tshi3 $make_mfcc_dir $mfccdir
)
graph_dir=exp/tri4/graph_format_lm
rm -rf $graph_dir
$train_cmd $graph_dir/mkgraph.log \
  utils/mkgraph.sh $LANG_DIR exp/tri4 $graph_dir
(
  steps/decode_fmllr.sh --nj 16 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir $tshi3 exp/tri4/decode_format_lm
)
graph_dir=exp/tri5/graph_format_lm
rm -rf $graph_dir
$train_cmd $graph_dir/mkgraph.log \
  utils/mkgraph.sh $LANG_DIR exp/tri5 $graph_dir
(
  steps/decode_fmllr.sh --nj 16 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir $tshi3 exp/tri5/decode_format_lm
)
for i in 1 2 3 4 5; do
graph_dir=exp/tri5.$i/graph_format_lm
rm -rf $graph_dir
$train_cmd $graph_dir/mkgraph.log \
  utils/mkgraph.sh $LANG_DIR exp/tri5.$i $graph_dir
(
  steps/decode_fmllr.sh --nj 16 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir $tshi3 exp/tri5.$i/decode_format_lm
)
done
