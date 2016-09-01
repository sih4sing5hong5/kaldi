#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error
# get corpus by 匯出Kaldi 格式資料
for x in data/test/*; do
    sort $x -o $x
done
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt

# # Now train the language models.

# # Compiles G for trigram LM
# LM=data/local/lm/sw1.o3g.kn.gz
LM='data/lang/語言模型.lm'
mkdir -p data/test
cat $LM | utils/find_arpa_oovs.pl data/lang/words.txt  > data/lang/oov.txt
cat $LM | \
    grep -v '<s> <s>' | \
    grep -v '</s> <s>' | \
    grep -v '</s> </s>' | \
    arpa2fst - | fstprint | \
    utils/remove_oovs.pl data/lang/oov.txt | \
    utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/lang/words.txt \
      --osymbols=data/lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
     fstrmepsilon > data/lang/G.fst


utils/prepare_lang.sh data/local/dict "<UNK>"  data/local/lang data/lang
# Now make MFCC features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=mfcc
for x in test; do
  steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" \
   data/$x exp/make_mfcc/$x $mfccdir
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
#  utils/validate_data_dir.sh data/$x
  utils/fix_data_dir.sh data/$x
done

graph_dir=exp/tri1/graph_nosp_sw1_tg
$train_cmd $graph_dir/mkgraph.log \
  utils/mkgraph.sh data/lang exp/tri1 $graph_dir
steps/decode_si.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
  $graph_dir data/test exp/tri1/decode_test

