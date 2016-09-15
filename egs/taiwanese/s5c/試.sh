#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error


graph_dir=exp/tri4/graph_tshi3
# # Now train the language models.
if [ $# -eq 1 ]; then
  LM_GZ='tshi3/lang/語言模型.lm.gz'
  utils/build_const_arpa_lm.sh $LM_GZ \
   data/lang tshi3/lang
fi
if [ $# -eq 2 ]; then
  utils/prepare_lang.sh tshi3/local/dict "<UNK>"  tshi3/local/lang tshi3/lang
  # # Compiles G for trigram LM
  LM='tshi3/lang/語言模型.lm'
  cat $LM | utils/find_arpa_oovs.pl tshi3/lang/words.txt  > tshi3/lang/arpa_oov.txt
  cat $LM | \
      grep -v '<s> <s>' | \
      grep -v '</s> <s>' | \
      grep -v '</s> </s>' | \
      arpa2fst - | fstprint | \
      utils/remove_oovs.pl tshi3/lang/arpa_oov.txt | \
      utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=tshi3/lang/words.txt \
        --osymbols=tshi3/lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
       fstrmepsilon | fstarcsort > tshi3/lang/G.fst

    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh tshi3/lang exp/tri4 $graph_dir
fi

tshi3='tshi3/train'

utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

utils/fix_data_dir.sh $tshi3

mfccdir=tshi3/mfcc
make_mfcc_dir=exp/make_mfcc/tshi3
rm -rf $mfccdir make_mfcc_dir

steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
 $tshi3 $make_mfcc_dir $mfccdir
steps/compute_cmvn_stats.sh $tshi3 $make_mfcc_dir $mfccdir

graph_dir=exp/tri4/graph
(
steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" \
  --config conf/decode.config \
  $graph_dir $tshi3 exp/tri4/decode_tshi3

# steps/decode_sgmm2.sh --nj $dev_nj --cmd "$decode_cmd" \
#   --transform-dir exp/tri3b/decode_dev \
#   exp/sgmm2_5b2/graph data/dev exp/sgmm2_5b2/decode_dev

steps/lmrescore_const_arpa.sh  --cmd "$decode_cmd" \
  data/lang tshi3/lang $tshi3 \
  exp/tri4/decode_tshi3 exp/tri4/decode_tshi3.rescored

# steps/decode_sgmm2.sh --nj $dev_nj --cmd "$decode_cmd" \
#   --transform-dir exp/tri4/decode_tshi3 \
#   exp/tri4/graph_big $tshi3 tri4/decode_tshi3.big

)
