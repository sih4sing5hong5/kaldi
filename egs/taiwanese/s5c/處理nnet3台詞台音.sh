#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error
data=ver5-tai5
tmp_dir=$data/tai5
(
  mkdir -p $tmp_dir

  rm -f $data/dict.ver5.4/lexiconp.txt
  utils/prepare_lang.sh $data/dict.ver5.4 "<unk>"  $data/local/lang $data/lang_dict
 
  ngram-count -text $data/語言模型.txt -order 1 \
    -write $tmp_dir/語言模型.count

  cat $tmp_dir/語言模型.count | \
    sort -rnk 2 | \
    head -n 5000 | \
    awk '{print $1}' | \
    cat > $tmp_dir/頭前5000詞.vocab

  LM=$data/sui1.lm
  LM3=$data/sui3.lm
  ngram-count -text $data/語言模型.txt -order 3 \
    -vocab $tmp_dir/頭前5000詞.vocab \
    -prune 1e-4 -lm $LM
  ngram-count -text $data/語言模型.txt -order 3 \
    -vocab $tmp_dir/頭前5000詞.vocab \
    -prune 1e-7 -lm $LM3

  LM_GZ=$LM.gz
  cat $LM | gzip > $LM_GZ
  utils/format_lm.sh $data/lang_dict $LM_GZ $data/dict.ver5.4/lexicon.txt $data/lang

  LM3_GZ=$LM3.gz
  cat $LM3 | gzip > $LM3_GZ
  utils/build_const_arpa_lm.sh $LM3_GZ $data/lang $data/lang-3grams
  
  graph_dir=exp/nnet3_chain/graph_tai5
  $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $data/lang exp/nnet3_chain $graph_dir  
)
