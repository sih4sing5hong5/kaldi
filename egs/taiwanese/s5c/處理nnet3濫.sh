#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error
data=ver5-lam7
tai5_data=ver5-tai5
hua5_data=ver5-hua5
tmp_dir=$data/txt
(
  mkdir -p $tmp_dir $data/dict

  cp $tai5_data/dict/* $data/dict/
  cat $tai5_data/dict/lexicon.txt $hua5_data/dict/lexicon.txt | \
    sort -u | \
    cat > $data/dict/lexicon.txt
  rm -f $data/dict/lexiconp.txt
  utils/prepare_lang.sh $data/dict "<unk>"  $data/local/lang $data/lang_dict
 
  LM=$data/sui1.lm
  LM3=$data/sui3.lm
  ngram -lm $tai5_data/sui1.lm -mix-lm ${hua5_data}/in1bun5.1gpr.arpa.gz -lambda 0.5 \
    -write-lm $LM
  ngram -lm $tai5_data/sui3.lm -mix-lm ${hua5_data}/in1bun5.3gpr.arpa.gz -lambda 0.5 \
    -write-lm $LM3
  
  LM_GZ=$LM.gz
  cat $LM | gzip > $LM_GZ
  utils/format_lm.sh $data/lang_dict $LM_GZ $data/dict/lexicon.txt $data/lang

  LM3_GZ=$LM3.gz
  cat $LM3 | gzip > $LM3_GZ
  utils/build_const_arpa_lm.sh $LM3_GZ $data/lang $data/lang-3grams
  
  graph_dir=exp/nnet3_chain/graph_lam7
  $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $data/lang exp/nnet3_chain $graph_dir  
)
