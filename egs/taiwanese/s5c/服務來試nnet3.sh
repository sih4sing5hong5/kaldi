#!/bin/bash

. cmd.sh
. path.sh

# 服務來試.sh exp/model/graph_sp data/train exp/model/decode_hok8bu7_1

set -e # exit on error

tshi3=$2
# (
#   utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

#   utils/fix_data_dir.sh  $tshi3

#   mfccdir=$tshi3/mfcc
#   make_mfcc_dir=$tshi3/make_mfcc/

#   steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" \
#    $tshi3 $make_mfcc_dir $mfccdir
#   steps/compute_cmvn_stats.sh $tshi3 $make_mfcc_dir $mfccdir
# )
graph_dir=$1
decode_dir=$3
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
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:s5c-twisas/utt2spk scp:s5c-twisas/cmvn.scp scp:s5c-twisas/feats.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >exp/nnet3_chain/lat.1.gz" 
)
