#!/bin/bash

. cmd.sh
. path.sh

# 服務來試nnet3.sh decode_nnet3.sh exp/chain/tdnn_1a_sp/graph/ hethong/lang-3grams/ data/train_free exp/chain/tdnn_1a_sp/decode_tshi

set -e # exit on error

tshi3=$3
(
  utils/utt2spk_to_spk2utt.pl $tshi3/utt2spk > $tshi3/spk2utt

  utils/fix_data_dir.sh $tshi3

  mfccdir=$tshi3/mfcc
  make_mfcc_log=$tshi3/make_mfcc/


    utils/copy_data_dir.sh $tshi3 ${tshi3}_hires

    steps/make_mfcc_pitch.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" ${tshi3}_hires $make_mfcc_log $mfccdir
    steps/compute_cmvn_stats.sh ${tshi3}_hires $make_mfcc_log $mfccdir 

    utils/fix_data_dir.sh ${tshi3}_hires
    # create MFCC data dir without pitch to extract iVector
    utils/data/limit_feature_dim.sh 0:39 ${tshi3}_hires ${tshi3}_hires_nopitch 
    steps/compute_cmvn_stats.sh ${tshi3}_hires_nopitch $make_mfcc_log $mfccdir
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
      ${tshi3}_hires_nopitch exp/nnet3/extractor \
      exp/nnet3/ivectors_test
)
graph_dir=$1
lang_dir=$2
# lang_dir=ver5.4/lang-3grams
decode_dir=$4
# mkdir -p $3
mkdir -p $decode_dir/scoring/
(
  nnet3-latgen-faster \
  --frame-subsampling-factor=3 \
  --frames-per-chunk=51 \
  --extra-left-context=0 \
  --extra-right-context=0 \
  --extra-left-context-initial=-1 \
  --extra-right-context-final=-1 \
  --minimize=false --max-active=7000 \
  --min-active=200 \
  --beam=15.0 --lattice-beam=8.0 --acoustic-scale=1.0 \
  --allow-partial=true \
  --word-symbol-table=$graph_dir/words.txt \
  exp/nnet3_chain/final.mdl \
  $graph_dir/HCLG.fst \
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:${tshi3}_hires/utt2spk scp:${tshi3}_hires/cmvn.scp scp:${tshi3}_hires/feats.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c > $decode_dir/lat1.1.gz" 2>&1 | tee $decode_dir/a.log
  # cat $decode_dir/a.log | grep ^0 > $decode_dir/scoring/7.0.0.txt
)

lattice-lmrescore --lm-scale=-1.0 \
  "ark:gunzip -c $decode_dir/lat1.1.gz|" \
  "fstproject --project_output=true $lang_dir/G.fst |" \
  ark:- | \
  lattice-lmrescore-const-arpa --lm-scale=1.0 \
     ark:- \
     $lang_dir/G.carpa \
     "ark,t:|gzip -c> $decode_dir/lat3.1.gz"

lattice-scale --inv-acoustic-scale=13 "ark:gunzip -c $decode_dir/lat3.1.gz|" ark:- | \
        lattice-add-penalty --word-ins-penalty=0.0 ark:- ark:- | \
        lattice-best-path --word-symbol-table=$graph_dir/words.txt ark:- ark,t:- | \
        utils/int2sym.pl -f 2- $graph_dir/words.txt | \
        tee $decode_dir/scoring/7.0.0.txt
# lattice-best-path --word-symbol-table=$graph_dir/words.txt \
#   "ark:gunzip -c $decode_dir/lat3.1.gz|" ark,t:- \
#   | utils/int2sym.pl -f 2- $graph_dir/words.txt \
#   | tee $decode_dir/scoring/7.0.0.txt

# cp $decode_dir/lat3.1.gz $decode_dir/lat.1.gz
# steps/score_kaldi.sh ${tshi3}_hires $graph_dir $decode_dir
