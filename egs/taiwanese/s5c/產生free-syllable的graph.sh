#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error


data='data'
lang=${data}/lang_free
lang_log=${lang}_log
nj=1

mkdir -p ${data}/local/free-syllable/dict
cp ${data}/local/dict/[^l]* ${data}/local/free-syllable/dict
cp ${data}/local/free-syllable/lexicon.txt ${data}/local/free-syllable/dict

rm -rf $lang_log $lang
utils/prepare_lang.sh ${data}/local/free-syllable/dict "" $lang_log $lang

cat data/local/free-syllable/uniform.fst | \
  fstcompile --isymbols=$lang/words.txt --osymbols=$lang/words.txt --keep_isymbols=false --keep_osymbols=false | \
  fstarcsort --sort_type=ilabel > $lang/G.fst

for x in exp/tri4 ; do
    graph_dir=$x/graph_free
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $lang $x $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/train_dev $x/decode_free_syllable
 done;