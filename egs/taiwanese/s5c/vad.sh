#!/bin/bash
# Copyright 2017-2018  David Snyder
#           2017-2018  Matthew Maciejewski
# Apache 2.0.
#
# This is still a work in progress, but implements something similar to
# Greg Sell's and Daniel Garcia-Romero's iVector-based diarization system
# in 'Speaker Diarization With PLDA I-Vector Scoring And Unsupervised
# Calibration'.  The main difference is that we haven't implemented the
# VB resegmentation yet.



. ./cmd.sh
. ./path.sh

set -e # exit on error

tshi3="$1"
nj=1

mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc
stage=0


if [ $stage -le 1 ]; then
  # The script local/make_callhome.sh splits callhome into two parts, called
  # callhome1 and callhome2.  Each partition is treated like a held-out
  # dataset, and used to estimate various quantities needed to perform
  # diarization on the other part (and vice versa).
  utils/fix_data_dir.sh $tshi3
  cp ../../callhome_diarization/v2/conf/vad.conf conf/

  
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj $nj \
    --cmd "$train_cmd" --write-utt2num-frames true \
    $tshi3 exp/make_mfcc $mfccdir
  utils/fix_data_dir.sh $tshi3

  ../../callhome_diarization/v2/sid/compute_vad_decision.sh \
    --nj $nj --cmd "$train_cmd" \
    $tshi3 exp/make_vad $vaddir
  utils/fix_data_dir.sh $tshi3

  echo "0.01" > $tshi3/frame_shift
  ../../callhome_diarization/v2/diarization/vad_to_segments.sh \
    --nj $nj --cmd "$train_cmd" \
    $tshi3 ${tshi3}_segmented
  # The sre dataset is a subset of train
#  mkdir data/sre -p
#  cp $tshi3/{feats,vad}.scp data/sre/
#  utils/fix_data_dir.sh data/sre

  # Create segments for ivector extraction for PLDA training data.
#  echo "0.01" > data/sre/frame_shift
#  vad_to_segments.sh --nj $nj --cmd "$train_cmd" \
#    data/sre data/sre_segmented
fi
