#!/bin/bash

. cmd.sh
. path.sh

set -e # exit on error

nj=16


gua7gi2_data='sui2'

data='data'
# data_free=$1
# data_name=`basename $1`
# decode_dir=decode_free_syllable_${data_name}
# lang=${data}/lang_free
# lang_log=${lang}_log

mkdir -p ${data}/local/gua7gi2/dict
rm -rf ${data}/local/gua7gi2/dict/*
cp ${data}/local/dict/[^l]* ${data}/local/gua7gi2/dict
cat ${gua7gi2_data}/lexicon.txt | \
  grep -v tide | \
  grep -v ɨ | \
  grep -v 6 | \
  grep -v '　' | \
  grep -v 他把財產揮霍光光 | \
  grep -v a9 | \
  grep -v coat | \
  grep -v decorated | \
  grep -v eⁿ0 | \
  grep -v fall | \
  grep -v flowers | \
  grep -v for | \
  grep -v fruit | \
  grep -v funerals\) | \
  grep -v gum | \
  grep -v iⁿ8 | \
  grep -v i9 | \
  grep -v kā | \
  grep -v like | \
  grep -v m̩3 | \
  grep -v mirror | \
  grep -v n9 | \
  grep -v ŋ̩8 | \
  grep -v oⁿ7 | \
  grep -v phone | \
  grep -v phut-liáu-liáu. | \
  grep -v puzzle | \
  grep -v train | \
  grep -v tsâi-sán | \
  grep -v uⁿ4 | \
  grep -v u9 | \
  grep -v \(used | \
  grep -v water | \
  grep -v with | \
  grep -v 一波又起 | \
  grep -v 一邊低 | \
  grep -v 一邊輕 | \
  grep -v 一頭小 | \
  grep -v 他把財產揮霍光光。 | \
  grep -v 小眼睛 | \
  grep -v 怯於公戰 | \
  grep -v 惡向膽邊生 | \
  grep -v 站沒站相 | \
  grep -v 自賣自誇 | \
  grep -v 西一串 | \
  grep -v 賺一個 | \
  grep -v 路人皆知 | \
  grep -v 閉一隻眼 | \
  cat > ${data}/local/gua7gi2/dict/lexicon.txt


rm -rf data/lang_gua7gi2 data/lang_dict_gua7gi2
utils/prepare_lang.sh data/local/gua7gi2/dict/ "<UNK>"  data/local/gua7gi2/lang data/lang_dict_gua7gi2

LM="${gua7gi2_data}/output.lm"
LM_GZ="${gua7gi2_data}/text.lm.gz"

# # Now train the language models.
cat $LM | gzip > $LM_GZ
utils/format_lm.sh data/lang_dict_gua7gi2 $LM_GZ data/local/gua7gi2/dict/lexicon.txt data/lang_gua7gi2


(
  graph_dir=exp/tri4/graph_gua7gi2
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh data/lang_gua7gi2 exp/tri4 $graph_dir
  # steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
  #   --config conf/decode.config \
    # $graph_dir data/train_dev exp/tri4/decode_train_dev
)
