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
# Acoustic model parameters
numLeavesTri1=2500
numGaussTri1=15000
numLeavesMLLT=2500
numGaussMLLT=15000
numLeavesSAT=2500
numGaussSAT=15000
numGaussUBM=1400
numLeavesSGMM=18000
numGaussSGMM=60000

# get corpus by 匯出Kaldi 格式資料

if [ $STAGE -le 1 ]; then
  utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
fi

if [ $STAGE -le 2 ]; then
  rm -rf data/lang data/lang_dict
  utils/prepare_lang.sh data/local/dict "<UNK>"  data/local/lang data/lang_dict
fi

LM='data/local/lm/語言模型.lm'
LM_GZ='data/local/lm/語言模型.lm.gz'
# # Now train the language models.
if [ $STAGE -le 3 ]; then
  cat $LM | gzip > $LM_GZ
  utils/format_lm.sh data/lang_dict $LM_GZ data/local/dict/lexicon.txt data/lang
fi

# Split corpus for test and mono_train
if [ $STAGE -le 4 ]; then
  # Use the first 4k sentences as dev set.  Note: when we trained the LM, we used
  # the 1st 10k sentences as dev set, so the 1st 4k won't have been used in the
  # LM training data.   However, they will be in the lexicon, plus speakers
  # may overlap, so it's still not quite equivalent to a test set.
  rm -rf data/train_dev data/train_nodev
  #utils/subset_data_dir.sh --first data/train 4000 data/train_dev # 5hr 6min
  ln -s ../tshi3/train data/train_dev
  n=$[`cat data/train/segments | wc -l` - 4000]
  utils/subset_data_dir.sh --last data/train $n data/train_nodev
fi

if [ $STAGE -le 5 ]; then
  if [ -f 有問題的音檔.表 ]; then
    cat 有問題的音檔.表 > ai3the7tiau7.pio2
    for x in data/train_nodev/utt2spk; do
		cat $x | grep -wF -f ai3the7tiau7.pio2 | \
        grep -vwF -f 無問題的音檔.表 > $x.bo
      #for i in 1 2 3; do
		#  cat $x | grep -wF -f $x.bo -A 1 -B 1 | \
		#    grep -vwF -f 無問題的音檔.表 > $x.bo5
		#  mv $x.bo5 $x.bo
		#done
      cat $x | grep -vwF -f  $x.bo > $x.tmp
      mv $x.tmp $x
    done
  fi
fi

# Now make MFCC features.
if [ $STAGE -le 6 ]; then
  # mfccdir should be some place with a largish disk where you
  # want to store MFCC features.
  for i in train_dev train_nodev; do
    data_dir=data/$i
    make_mfcc_log=exp/make_mfcc/$i
    mfccdir=mfcc/$i
    rm -rf $make_mfcc_log $mfccdir
    utils/fix_data_dir.sh $data_dir
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" \
     $data_dir $make_mfcc_log $mfccdir
    steps/compute_cmvn_stats.sh $data_dir $make_mfcc_log $mfccdir
  done
fi

if [ $STAGE -le 7 ]; then
  # Now-- there are 260k utterances (313hr 23min), and we want to start the
  # monophone training on relatively short utterances (easier to align), but not
  # only the shortest ones (mostly uh-huh).  So take the 100k shortest ones, and
  # then take 30k random utterances from those (about 12hr)
  utils/subset_data_dir.sh --shortest data/train_nodev 100000 data/train_100kshort
  utils/subset_data_dir.sh data/train_100kshort 30000 data/train_30kshort

  # Take the first 100k utterances (just under half the data); we'll use
  # this for later STAGEs of training.
  utils/subset_data_dir.sh --first data/train_nodev 100000 data/train_100k
  utils/data/remove_dup_utts.sh 200 data/train_100k data/train_100k_nodup  # 110hr

  # Finally, the full training set:
  utils/data/remove_dup_utts.sh 300 data/train_nodev data/train_nodup  # 286hr
fi

## Starting basic training on MFCC features
if [ $STAGE -le 10 ]; then
  steps/train_mono.sh --nj $nj --cmd "$train_cmd" \
    data/train_30kshort data/lang exp/mono
fi

if [ $STAGE -le 11 ]; then
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train_100k_nodup data/lang exp/mono exp/mono_ali

  steps/train_deltas.sh --cmd "$train_cmd" \
    3200 30000 data/train_100k_nodup data/lang exp/mono_ali exp/tri1

  (
    graph_dir=exp/tri1/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang exp/tri1 $graph_dir
    steps/decode_si.sh --nj $nj --cmd "$decode_cmd" --config conf/decode.config \
      $graph_dir data/train_dev exp/tri1/decode_train_dev
  )
fi

if [ $STAGE -le 12 ]; then
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train_100k_nodup data/lang exp/tri1 exp/tri1_ali

  steps/train_deltas.sh --cmd "$train_cmd" \
    4000 70000 data/train_100k_nodup data/lang exp/tri1_ali exp/tri2

  (
    graph_dir=exp/tri2/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang exp/tri2 $graph_dir
    steps/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode.config \
      $graph_dir data/train_dev exp/tri2/decode_train_dev
  )
fi

# From now, we start using all of the data (except some duplicates of common
# utterances, which don't really contribute much).
if [ $STAGE -le 13 ]; then
  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train_nodup data/lang exp/tri2 exp/tri2_ali

  # Do another iteration of LDA+MLLT training, on all the data.
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    6000 140000 data/train_nodup data/lang exp/tri2_ali exp/tri3

  (
    graph_dir=exp/tri3/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang exp/tri3 $graph_dir
    steps/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode.config \
      $graph_dir data/train_dev exp/tri3/decode_train_dev
  )
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $STAGE -le 14 ]; then
  rm -rf data/local/dict_sp data/local/lang_sp data/lang_sp
  steps/get_prons.sh --cmd "$train_cmd" data/train_nodup data/lang exp/tri3
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict exp/tri3/pron_counts_nowb.txt exp/tri3/sil_counts_nowb.txt \
    exp/tri3/pron_bigram_counts_nowb.txt data/local/dict_sp
  # Like stage 2
  utils/prepare_lang.sh data/local/dict_sp "<UNK>"  data/local/lang_sp data/lang_dict_sp
  # Like stage 3
  utils/format_lm.sh data/lang_dict_sp $LM_GZ data/local/dict_sp/lexicon.txt data/lang_sp

  (
    graph_dir=exp/tri3/graph_sp
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang_sp exp/tri3 $graph_dir
    steps/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode.config \
      $graph_dir data/train_dev exp/tri3/decode_train_dev_sp
  )
fi

# Train tri4, which is LDA+MLLT+SAT, on all the (nodup) data.
if [ $STAGE -le 15 ]; then
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train_nodup data/lang exp/tri3 exp/tri3_ali

  steps/train_sat.sh  --cmd "$train_cmd" \
    11500 200000 data/train_nodup data/lang exp/tri3_ali exp/tri4

  (
    graph_dir=exp/tri4/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang exp/tri4 $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/train_dev exp/tri4/decode_train_dev
  )
  (
    graph_dir=exp/tri4/graph_sp
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang_sp exp/tri4 $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/train_dev exp/tri4/decode_train_dev_sp
  )
fi

if [ $STAGE -le 16 ]; then
  steps/cleanup/clean_and_segment_data.sh \
    --nj $nj \
    data/train_nodup data/lang_sp exp/tri4 exp/tri4_cleanup data/train_nodup_cleaned
fi

if [ $STAGE -le 17 ]; then
  #utils/split_data.sh data/train_nodup_cleaned/ $nj
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train_nodup_cleaned data/lang_sp exp/tri4 exp/tri4_ali
  steps/train_sat.sh  --cmd "$train_cmd" \
    11500 200000 data/train_nodup_cleaned data/lang_sp exp/tri4_ali exp/tri5
  (
    graph_dir=exp/tri5/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang exp/tri5 $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/train_dev exp/tri5/decode_train_dev
  )
  (
    graph_dir=exp/tri5/graph_sp
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang_sp exp/tri5 $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/train_dev exp/tri5/decode_train_dev_sp
  )
fi
if [ $STAGE -le 18 ]; then
  bash 清語料.sh
fi

# Prepare tri4_ali for other training
if [ $STAGE -le 19 ]; then
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train_nodup data/lang exp/tri4 exp/tri4_ali

  steps/make_denlats.sh --nj $nj --cmd "$decode_cmd" \
    --config conf/decode.config --transform-dir exp/tri4_ali \
    data/train_nodup data/lang exp/tri4 exp/tri4_denlats
fi

# Do MPE from voxforge
if [[ $STAGE -le 20 ]]; then
  steps/train_mpe.sh data/train_nodup data/lang exp/tri4_ali exp/tri4_denlats exp/tri4_mpe
  (
    for iter in 1 2 3 4; do
      graph_dir=exp/tri4/graph
      decode_dir=exp/tri4_mpe/decode_train_dev_it${iter}
      steps/decode.sh --config conf/decode.config --iter ${iter} --nj $nj --cmd "$decode_cmd" \
         --transform-dir exp/tri4/decode_train_dev $graph_dir data/train_dev $decode_dir
    done
  )
  (
    for iter in 1 2 3 4; do
      graph_dir=exp/tri4/graph_sp
      decode_dir=exp/tri4_mpe/decode_train_dev_sp_it${iter}
      steps/decode.sh --config conf/decode.config --iter ${iter} --nj $nj --cmd "$decode_cmd" \
         --transform-dir exp/tri4/decode_train_dev_sp $graph_dir data/train_dev $decode_dir
    done
  )
fi

# MMI training starting from the LDA+MLLT+SAT systems on all the (nodup) data.
if [ $STAGE -le 30 ]; then
  # 4 iterations of MMI seems to work well overall. The number of iterations is
  # used as an explicit argument even though train_mmi.sh will use 4 iterations by
  # default.
  num_mmi_iters=4
  steps/train_mmi.sh --cmd "$decode_cmd" \
    --boost 0.1 --num-iters $num_mmi_iters \
    data/train_nodup data/lang exp/tri4_{ali,denlats} exp/tri4_mmi_b0.1

  (
    for iter in 1 2 3 4; do
      graph_dir=exp/tri4/graph
      decode_dir=exp/tri4_mmi_b0.1/decode_train_dev_it${iter}
      steps/decode.sh --nj $nj --cmd "$decode_cmd" \
        --config conf/decode.config --iter $iter \
        --transform-dir exp/tri4/decode_train_dev \
        $graph_dir data/train_dev $decode_dir
    done
  )
  (
    for iter in 1 2 3 4; do
      graph_dir=exp/tri4/graph_sp
      decode_dir=exp/tri4_mmi_b0.1/decode_train_dev_sp_it${iter}
      steps/decode.sh --nj $nj --cmd "$decode_cmd" \
        --config conf/decode.config --iter $iter \
        --transform-dir exp/tri4/decode_train_dev_sp \
        $graph_dir data/train_dev $decode_dir
    done
  )
fi

# Now do fMMI+MMI training
if [ $STAGE -le 40 ]; then
  steps/train_diag_ubm.sh --silence-weight 0.5 --nj $nj --cmd "$train_cmd" \
    700 data/train_nodup data/lang exp/tri4_ali exp/tri4_dubm

  steps/train_mmi_fmmi.sh --learning-rate 0.005 \
    --boost 0.1 --cmd "$train_cmd" \
    data/train_nodup data/lang exp/tri4_ali exp/tri4_dubm \
    exp/tri4_denlats exp/tri4_fmmi_b0.1
  (
    for iter in 4 5 6 7 8; do
      graph_dir=exp/tri4/graph
      decode_dir=exp/tri4_fmmi_b0.1/decode_train_dev_it${iter}
      steps/decode_fmmi.sh --nj $nj --cmd "$decode_cmd" --iter $iter \
        --transform-dir exp/tri4/decode_train_dev \
        --config conf/decode.config $graph_dir data/train_dev $decode_dir
    done
  )
  (
    for iter in 4 5 6 7 8; do
      graph_dir=exp/tri4/graph_sp
      decode_dir=exp/tri4_fmmi_b0.1/decode_train_dev_sp_it${iter}
      steps/decode_fmmi.sh --nj $nj --cmd "$decode_cmd" --iter $iter \
        --transform-dir exp/tri4/decode_train_dev_sp \
        --config conf/decode.config $graph_dir data/train_dev $decode_dir
    done
  )
fi

# SGMM2 Training & Decoding from timit
if [[ $STAGE -le 50 ]]; then
  # exp/tri3_ali +> tri4_ali
  # exp/ubm4 => tri4_dubm
  # sgmm2_4 => tri4_sgmm2
  steps/train_ubm.sh --cmd "$train_cmd" $numGaussUBM data/train_nodup data/lang \
    exp/tri4_ali exp/tri4_ubm

  # steps/train_sgmm2.sh is old version
  steps/train_sgmm2_group.sh --cmd "$train_cmd" $numLeavesSGMM $numGaussSGMM \
   data/train_nodup data/lang exp/tri4_ali exp/tri4_ubm/final.ubm exp/tri4_sgmm2

  (
    graph_dir=exp/tri4_sgmm2/graph
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang exp/tri4_sgmm2 $graph_dir

    steps/decode_sgmm2.sh --nj $nj --cmd "$decode_cmd"\
     --transform-dir exp/tri4/decode_train_dev $graph_dir data/train_dev \
     exp/tri4_sgmm2/decode_train_dev
  )
  (
    graph_dir=exp/tri4_sgmm2/graph_sp
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang_sp exp/tri4_sgmm2 $graph_dir

    steps/decode_sgmm2.sh --nj $nj --cmd "$decode_cmd"\
     --transform-dir exp/tri4/decode_train_dev_sp $graph_dir data/train_dev \
     exp/tri4_sgmm2/decode_train_dev_sp
  )
fi

# MMI + SGMM2 Training & Decoding from timit
if [[ $STAGE -le 51 ]]; then
  # exp/tri3_ali +> tri4_ali
  # exp/ubm4 => tri4_dubm
  # sgmm2_4 => tri4_sgmm2
  steps/align_sgmm2.sh --nj $nj --cmd "$train_cmd" \
   --transform-dir exp/tri4_ali --use-graphs true --use-gselect true \
   data/train_nodup data/lang exp/tri4_sgmm2 exp/tri4_sgmm2_ali

  steps/make_denlats_sgmm2.sh --nj $nj \
   --acwt 0.2 --lattice-beam 6.0 --beam 9.0 \
   --cmd "$decode_cmd" --transform-dir exp/tri4_ali \
   data/train_nodup data/lang exp/tri4_sgmm2_ali exp/tri4_sgmm2_denlats

  steps/train_mmi_sgmm2.sh --acwt 0.2 --cmd "$decode_cmd" \
   --transform-dir exp/tri4_ali --boost 0.1 --drop-frames true \
   data/train_nodup data/lang exp/tri4_sgmm2_ali exp/tri4_sgmm2_denlats exp/tri4_sgmm2_mmi_b0.1

  (
    for iter in 1 2 3 4; do
      steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
       --transform-dir exp/tri4/decode_train_dev data/lang data/train_dev \
       exp/tri4_sgmm2/decode_train_dev exp/tri4_sgmm2_mmi_b0.1/decode_train_dev_it$iter
    done
  )
  (
    for iter in 1 2 3 4; do
      steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
       --transform-dir exp/tri4/decode_train_dev_sp data/lang_sp data/train_dev \
       exp/tri4_sgmm2/decode_train_dev_sp exp/tri4_sgmm2_mmi_b0.1/decode_train_dev_sp_it$iter
    done
  )
fi

# this will help find issues with the lexicon.
# steps/cleanup/debug_lexicon.sh --nj $nj --cmd "$train_cmd" data/train_nodev data/lang exp/tri4 data/local/dict/lexicon.txt exp/debug_lexicon

# has_fisher=false

# if [ $STAGE -le 100 ]; then
#   # The 100k_nodup data is used in neural net training.
#   steps/align_si.sh --nj $nj --cmd "$train_cmd" \
#     data/train_100k_nodup data/lang exp/tri2 exp/tri2_ali_100k_nodup
# fi


# Karel's DNN recipe on top of fMLLR features
# local/nnet/run_dnn.sh --has-fisher $has_fisher

# Dan's nnet recipe
# local/nnet2/run_nnet2.sh --has-fisher $has_fisher

if [[ $STAGE -le 110 ]]; then
  steps/nnet2/train_pnorm_accel2.sh
  # --parallel-opts "$parallel_opts"
    --cmd "$decode_cmd" --stage -10 \
    --num-threads 1 --minibatch-size 512 \
    --mix-up 20000 --samples-per-iter 300000 \
    --num-epochs 15 \
    --initial-effective-lrate 0.005 --final-effective-lrate 0.0002 \
    --num-jobs-initial 3 --num-jobs-final 10 --num-hidden-layers 5 \
    --pnorm-input-dim 5000  --pnorm-output-dim 500 \
    data/train_nodup data/lang exp/tri5.2_ali exp/nnet2_5

  steps/nnet2/decode.sh --cmd "$decode_cmd" --nj 30 \
    --config conf/decode.config \
    --transform-dir exp/tri4/decode_train_dev \
    exp/tri4/graph data/train_dev \
    exp/nnet2_5/decode_train_dev

  steps/nnet2/decode.sh --cmd "$decode_cmd" --nj 30 \
    --config conf/decode.config \
    --transform-dir exp/tri4/decode_train_dev_sp \
    exp/tri4/graph_sp data/train_dev \
    exp/nnet2_5/decode_train_dev
fi

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

bash 看結果.sh
