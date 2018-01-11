#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error


data='data'
data_name=`basename $1`
decode_dir=decode_free_syllable_${data_name}
lang=${data}/lang_free
mkdir -p ${data}/tmp
lang_log=${data}/tmp/lang_free
nj=1

mkdir -p ${data}/local/free-syllable/dict
rm -rf ${data}/local/free-syllable/dict/*
cp ${data}/local/dict/[^l]* ${data}/local/free-syllable/dict
cp ${data}/local/free-syllable/lexicon.txt ${data}/local/free-syllable/dict

rm -rf $lang_log $lang
utils/prepare_lang.sh ${data}/local/free-syllable/dict "" $lang_log $lang

cat data/local/free-syllable/uniform.fst | \
  fstcompile --isymbols=$lang/words.txt --osymbols=$lang/words.txt --keep_isymbols=false --keep_osymbols=false | \
  fstarcsort --sort_type=ilabel > $lang/G.fst

echo "tso3 ho2 ti7 $lang"