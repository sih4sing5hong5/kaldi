#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error
data=ver5.4
(
  rm -f $data/dict.ver5.4/lexiconp.txt
  utils/prepare_lang.sh $data/dict.ver5.4 "<unk>"  $data/local/lang ver5.4/lang_dict
  
  LM_GZ=ver5.4/cc_10k.1gpr.arpa.gz
  # cat ver5.4/cc_10k.1gpr.arpa | gzip > $LM_GZ
  utils/format_lm.sh $data/lang_dict $LM_GZ $data/dict.ver5.4/lexicon.txt $data/lang

  
  LM3_GZ=ver5.4/cc_10k.3gpr.arpa.gz
  # cat ver5.4/cc_10k.1gpr.arpa | gzip > $LM3_GZ
  utils/build_const_arpa_lm.sh $LM3_GZ $data/lang $data/lang-3grams
  
  graph_dir=exp/nnet3_chain/graph
  $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh $data/lang exp/nnet3_chain $graph_dir
  
)
exit 0
tshi3=$2

graph_dir=$1
decode_dir=$3
# mkdir -p $3
mkdir -p $decode_dir/scoring/
(
  nnet3-latgen-faster \
  --frame-subsampling-factor=3 \
  --frames-per-chunk=50 \
  --extra-left-context=0 \
  --extra-right-context=0 \
  --extra-left-context-initial=-1 \
  --extra-right-context-final=-1 \
  --minimize=false --max-active=7000 \
  --min-active=200 \
  --beam=15.0 --lattice-beam=8.0 --acoustic-scale=1.0 \
  --allow-partial=true \
  --word-symbol-table=exp/nnet3_chain/words.txt \
  exp/nnet3_chain/final.mdl \
  exp/nnet3_chain/HCLG.fst \
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:$tshi3/utt2spk scp:$tshi3/cmvn.scp scp:$tshi3/feats.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >exp/nnet3_chain/lat.1.gz" 2>&1 | tee $decode_dir/a.log
  # cat $decode_dir/a.log | grep ^0 > $decode_dir/scoring/7.0.0.txt
)

# (
#   steps/nnet3/decode.sh --nj 1 --cmd "$decode_cmd" \
#     --acwt 1.0 \
#     --post_decode_acwt 10.0 \
#     --skip_diagnostics true \
#     --stage 3 \
#     --scoring_opts '--min_lmwt 6 --max_lmwt 20' \
#     --config conf/decode.config \
#     $graph_dir $tshi3 $decode_dir
# )

lattice-best-path --word-symbol-table=$graph_dir/words.txt \
  "ark:gunzip -c exp/nnet3_chain/lat.1.gz|" ark,t:- \
  | utils/int2sym.pl -f 2- $graph_dir/words.txt \
  | tee $decode_dir/scoring/7.0.0.txt
