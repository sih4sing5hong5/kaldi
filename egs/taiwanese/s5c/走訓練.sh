#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error

STAGE=0
if [ -f ./stage.sh ]; then
  # echo 'export STAGE=1' > stage.sh
  . stage.sh
fi
echo "stage = $STAGE"


nj=16

# GMM Acoustic model parameters
numLeaves=3000
numGauss=30000


if [ $STAGE -le 1 ]; then
  utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
fi

if [ $STAGE -le 2 ]; then
  rm -rf data/lang_train
  mkdir -p data/tmp
  utils/prepare_lang.sh data/local/dict "<UNK>"  data/tmp/lang_train data/lang_train
fi

# Now make MFCC features.
if [ $STAGE -le 6 ]; then
  # mfccdir should be some place with a largish disk where you
  # want to store MFCC features.
  for i in train; do
    data_dir=data/$i
    make_mfcc_log=data/mfcc_log/$i
    mfccdir=data/mfcc/$i
    rm -rf $make_mfcc_log $mfccdir
    mkdir -p $make_mfcc_log $mfccdir
    utils/fix_data_dir.sh $data_dir
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
     $data_dir $make_mfcc_log $mfccdir
    steps/compute_cmvn_stats.sh $data_dir $make_mfcc_log $mfccdir
  done
fi

## Starting basic training on MFCC features
if [ $STAGE -le 10 ]; then
  steps/train_mono.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_train exp/mono
fi

if [ $STAGE -le 11 ]; then
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_train exp/mono exp/mono_ali

  steps/train_deltas.sh --cmd "$train_cmd" \
    $numLeaves $numGauss data/train data/lang_train exp/mono_ali exp/tri1

fi

if [ $STAGE -le 12 ]; then
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_train exp/tri1 exp/tri1_ali

  steps/train_deltas.sh --cmd "$train_cmd" \
    $numLeaves $numGauss data/train data/lang_train exp/tri1_ali exp/tri2

fi

# From now, we start using all of the data (except some duplicates of common
# utterances, which don't really contribute much).
if [ $STAGE -le 13 ]; then
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_train exp/tri2 exp/tri2_ali

  # Do another iteration of LDA+MLLT training, on all the data.
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    $numLeaves $numGauss data/train data/lang_train exp/tri2_ali exp/tri3

fi

# Train tri4, which is LDA+MLLT+SAT, on all the (nodup) data.
if [ $STAGE -le 15 ]; then
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_train exp/tri3 exp/tri3_ali

  steps/train_sat.sh  --cmd "$train_cmd" \
    $numLeaves $numGauss data/train data/lang_train exp/tri3_ali exp/tri4

fi

exit 0


if [ $STAGE -le 16 ]; then
  steps/cleanup/clean_and_segment_data.sh \
    --nj $nj \
    data/train data/lang_train exp/tri4 exp/tri4_cleanup data/train_cleaned
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train_cleaned data/lang_train exp/tri4 exp/tri4_cleaned_ali
  steps/train_sat.sh  --cmd "$train_cmd" \
    $numLeaves $numGauss data/train_cleaned data/lang_train exp/tri4_cleaned_ali exp/tri5
fi

# Prepare tri4_ali for other training
if [ $STAGE -le 19 ]; then
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train data/lang_train exp/tri4 exp/tri4_ali
fi


# # Dan's nnet recipe
# # local/nnet2/run_nnet2.sh --has-fisher $has_fisher
# if [[ $STAGE -le 110 ]]; then
#   steps/nnet2/train_pnorm_accel2.sh \
#     --cmd "$decode_cmd" --stage -10 \
#     --num-threads 1 --minibatch-size 512 \
#     --mix-up 20000 --samples-per-iter 300000 \
#     --num-epochs 15 \
#     --initial-effective-lrate 0.005 --final-effective-lrate 0.0002 \
#     --num-jobs-initial 3 --num-jobs-final 10 --num-hidden-layers 5 \
#     --pnorm-input-dim 5000  --pnorm-output-dim 500 \
#     data/train data/lang_train exp/tri4_ali exp/nnet2_5
#   # --parallel-opts "$parallel_opts"

#   steps/nnet2/decode.sh --cmd "$decode_cmd" --nj 30 \
#     --config conf/decode.config \
#     --transform-dir exp/tri4/decode_train_dev \
#     exp/tri4/graph data/train \
#     exp/nnet2_5/decode_train_dev

#   steps/nnet2/decode.sh --cmd "$decode_cmd" --nj 30 \
#     --config conf/decode.config \
#     --transform-dir exp/tri4/decode_train_dev_sp \
#     exp/tri4/graph_sp data/train \
#     exp/nnet2_5/decode_train_dev
# fi

# Dan's nnet recipe with online decoding.
# local/online/run_nnet2_ms.sh --has-fisher $has_fisher

# demonstration script for resegmentation.
# local/run_resegment.sh

# demonstration script for raw-fMLLR.  You should probably ignore this.
# local/run_raw_fmllr.sh

# nnet3 LSTM recipe
# local/nnet3/run_lstm.sh

# nnet3 BLSTM recipe
# local/nnet3/run_lstm.sh --affix bidirectional \
#	                  --lstm-delay " [-1,1] [-2,2] [-3,3] " \
#                         --label-delay 0 \
#                         --cell-dim 1024 \
#                         --recurrent-projection-dim 128 \
#                         --non-recurrent-projection-dim 128 \
#                         --chunk-left-context 40 \
#                         --chunk-right-context 40

# bash 看結果.sh
