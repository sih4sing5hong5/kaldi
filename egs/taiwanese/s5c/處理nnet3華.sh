#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error
data=ver5-hua5
data_tai5=ver5-tai5
(
  mkdir -p $data
  rm -f $data/dict/lexiconp.txt
  utils/prepare_lang.sh $data/dict "<unk>"  $data/local/lang $data/lang_dict
  
  LM_ib=$data_tai5/in1bun5.lm

  LM_KU=ver5.4/cc_10k.1gpr.arpa
  LM=ver5.4/in1bun5.1gpr.arpa
  LM_GZ=ver5.4/in1bun5.1gpr.arpa.gz
  ngram -lm $LM_KU -mix-lm $LM_ib -lambda 0.05 \
    -write-lm $LM
  cat $LM | gzip > $LM_GZ
  utils/format_lm.sh $data/lang_dict $LM_GZ $data/dict/lexicon.txt $data/lang

  
  LM3_KU=ver5.4/cc_10k.3gpr.arpa
  LM3=ver5.4/in1bun5.3gpr.arpa
  LM3_GZ=ver5.4/in1bun5.3gpr.arpa.gz
  ngram -lm $LM3_KU -mix-lm $LM_ib -lambda 0.05 \
    -write-lm $LM3
  cat $LM3 | gzip > $LM3_GZ
  utils/build_const_arpa_lm.sh $LM3_GZ $data/lang $data/lang-3grams
  
  graph_dir=exp/nnet3_chain/graph_hua5
  $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $data/lang exp/nnet3_chain $graph_dir
  
)
