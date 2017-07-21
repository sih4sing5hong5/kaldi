#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error


data='data'
data_free=$1
data_name=`basename $1`
decode_dir=decode_free_syllable_${data_name}
lang=${data}/lang_free
lang_log=${lang}_log
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

rm -rf $data_free/split*

if [ ! -f $data_free/spk2utt ]; then
  utils/utt2spk_to_spk2utt.pl $data_free/utt2spk > $data_free/spk2utt

  utils/fix_data_dir.sh  $data_free

  mfccdir=$data_free/mfcc
  make_mfcc_dir=$data_free/make_mfcc/

  steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
   $data_free $make_mfcc_dir $mfccdir
  steps/compute_cmvn_stats.sh $data_free $make_mfcc_dir $mfccdir
fi

for x in exp/tri4 ; do
	graph_dir=$x/graph_free

	$train_cmd $graph_dir/mkgraph.log \
	  utils/mkgraph.sh $lang $x $graph_dir

	steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
	  --config conf/decode.config \
	  $graph_dir $data_free $x/$decode_dir

	steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $nj \
	  --config conf/decode.config \
	  --transform-dir $x/$decode_dir \
	  $graph_dir $data_free \
	  exp/nnet2_5/$decode_dir
done;
