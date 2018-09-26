#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

STAGE=0
nj=4

lang=$1 # data/lang_free
if [ $# != 2 ]; then
  test_dir=data/dev
else
  test_dir=$2
fi


# Now make MFCC features.
if [ $STAGE -le 6 ]; then
  utils/utt2spk_to_spk2utt.pl $test_dir/utt2spk > $test_dir/spk2utt
  make_mfcc_log=mfcc/log/$test_dir
  mfccdir=mfcc/$test_dir
  rm -rf $make_mfcc_log $mfccdir
  mkdir -p $make_mfcc_log $mfccdir
  utils/fix_data_dir.sh $test_dir

    utils/copy_data_dir.sh $test_dir ${test_dir}_hires

    steps/make_mfcc_pitch.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" ${test_dir}_hires $make_mfcc_log $mfccdir
    steps/compute_cmvn_stats.sh ${test_dir}_hires $make_mfcc_log $mfccdir 

    utils/fix_data_dir.sh ${test_dir}_hires
    # create MFCC data dir without pitch to extract iVector
    utils/data/limit_feature_dim.sh 0:39 ${test_dir}_hires ${test_dir}_hires_nopitch 
    steps/compute_cmvn_stats.sh ${test_dir}_hires_nopitch $make_mfcc_log $mfccdir
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
      ${test_dir}_hires_nopitch exp/nnet3/extractor \
      exp/nnet3/ivectors_test

fi

if [ $STAGE -le 10 ]; then
  dir=exp/chain/tdnn_1a_sp/
  graph_dir=$dir/graph
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh --self-loop-scale 1.0 $lang $dir $graph_dir
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
      --nj $nj --cmd "$decode_cmd" \
      --online-ivector-dir exp/nnet3/ivectors_test \
      $graph_dir ${test_dir}_hires $dir/decode_train_dev 
fi

