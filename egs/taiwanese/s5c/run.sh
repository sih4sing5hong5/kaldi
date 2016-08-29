#!/bin/bash

. cmd.sh
. path.sh

# This setup was modified from egs/swbd/s5c, with the following changes:

set -e # exit on error
has_fisher=false
# get corpus by 匯出Kaldi 格式資料
for x in data/train/*; do
    sort $x -o $x
done
utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt

utils/prepare_lang.sh data/local/dict "<UNK>"  data/local/lang data/lang

# # Now train the language models.

# # Compiles G for trigram LM
# LM=data/local/lm/sw1.o3g.kn.gz
LM='data/lang/lm.arpa'
cat $LM | utils/find_arpa_oovs.pl data/lang/words.txt  > data/lang/oov.txt
cat $LM | \
    grep -v '<s> <s>' | \
    grep -v '</s> <s>' | \
    grep -v '</s> </s>' | \
    arpa2fst - | fstprint | \
    utils/remove_oovs.pl data/lang/oov.txt | \
    utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/lang/words.txt \
      --osymbols=data/lang/words.txt  --keep_isymbols=false --keep_osymbols=false | \
     fstrmepsilon > data/test/G.fst

# Now make MFCC features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=mfcc
for x in train; do
  steps/make_mfcc.sh --nj 20 --cmd "$train_cmd" \
   data/$x exp/make_mfcc/$x $mfccdir
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
#  utils/validate_data_dir.sh data/$x
  utils/fix_data_dir.sh data/$x
done

# Use the first 4k sentences as dev set.  Note: when we trained the LM, we used
# the 1st 10k sentences as dev set, so the 1st 4k won't have been used in the
# LM training data.   However, they will be in the lexicon, plus speakers
# may overlap, so it's still not quite equivalent to a test set.
utils/subset_data_dir.sh --first data/train 4000 data/train_dev # 5hr 6min
n=$[`cat data/train/segments | wc -l` - 4000]
utils/subset_data_dir.sh --last data/train $n data/train_nodev

# Now-- there are 260k utterances (313hr 23min), and we want to start the
# monophone training on relatively short utterances (easier to align), but not
# only the shortest ones (mostly uh-huh).  So take the 100k shortest ones, and
# then take 30k random utterances from those (about 12hr)
utils/subset_data_dir.sh --shortest data/train_nodev 100000 data/train_100kshort
utils/subset_data_dir.sh data/train_100kshort 30000 data/train_30kshort

# Take the first 100k utterances (just under half the data); we'll use
# this for later stages of training.
utils/subset_data_dir.sh --first data/train_nodev 100000 data/train_100k
utils/data/remove_dup_utts.sh 200 data/train_100k data/train_100k_nodup  # 110hr

# Finally, the full training set:
utils/data/remove_dup_utts.sh 300 data/train_nodev data/train_nodup  # 286hr
## Starting basic training on MFCC features
steps/train_mono.sh --nj 30 --cmd "$train_cmd" \
  data/train_30kshort data/lang_nosp exp/mono

steps/align_si.sh --nj 30 --cmd "$train_cmd" \
  data/train_100k_nodup data/lang_nosp exp/mono exp/mono_ali

steps/train_deltas.sh --cmd "$train_cmd" \
  3200 30000 data/train_100k_nodup data/lang_nosp exp/mono_ali exp/tri1

(
  graph_dir=exp/tri1/graph_nosp_sw1_tg
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh data/lang_nosp_sw1_tg exp/tri1 $graph_dir
  steps/decode_si.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
    $graph_dir data/eval2000 exp/tri1/decode_eval2000_nosp_sw1_tg
) &

steps/align_si.sh --nj 30 --cmd "$train_cmd" \
  data/train_100k_nodup data/lang_nosp exp/tri1 exp/tri1_ali

steps/train_deltas.sh --cmd "$train_cmd" \
  4000 70000 data/train_100k_nodup data/lang_nosp exp/tri1_ali exp/tri2

(
  # The previous mkgraph might be writing to this file.  If the previous mkgraph
  # is not running, you can remove this loop and this mkgraph will create it.
  while [ ! -s data/lang_nosp_sw1_tg/tmp/CLG_3_1.fst ]; do sleep 60; done
  sleep 20; # in case still writing.
  graph_dir=exp/tri2/graph_nosp_sw1_tg
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh data/lang_nosp_sw1_tg exp/tri2 $graph_dir
  steps/decode.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
    $graph_dir data/eval2000 exp/tri2/decode_eval2000_nosp_sw1_tg
) &

# The 100k_nodup data is used in neural net training.
steps/align_si.sh --nj 30 --cmd "$train_cmd" \
  data/train_100k_nodup data/lang_nosp exp/tri2 exp/tri2_ali_100k_nodup

# From now, we start using all of the data (except some duplicates of common
# utterances, which don't really contribute much).
steps/align_si.sh --nj 30 --cmd "$train_cmd" \
  data/train_nodup data/lang_nosp exp/tri2 exp/tri2_ali_nodup

# Do another iteration of LDA+MLLT training, on all the data.
steps/train_lda_mllt.sh --cmd "$train_cmd" \
  6000 140000 data/train_nodup data/lang_nosp exp/tri2_ali_nodup exp/tri3

(
  graph_dir=exp/tri3/graph_nosp_sw1_tg
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh data/lang_nosp_sw1_tg exp/tri3 $graph_dir
  steps/decode.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
    $graph_dir data/eval2000 exp/tri3/decode_eval2000_nosp_sw1_tg
) &

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
steps/get_prons.sh --cmd "$train_cmd" data/train_nodup data/lang_nosp exp/tri3
utils/dict_dir_add_pronprobs.sh --max-normalize true \
  data/local/dict_nosp exp/tri3/pron_counts_nowb.txt exp/tri3/sil_counts_nowb.txt \
  exp/tri3/pron_bigram_counts_nowb.txt data/local/dict

utils/prepare_lang.sh data/local/dict "<unk>" data/local/lang data/lang
LM=data/local/lm/sw1.o3g.kn.gz
srilm_opts="-subset -prune-lowprobs -unk -tolower -order 3"
utils/format_lm_sri.sh --srilm-opts "$srilm_opts" \
  data/lang $LM data/local/dict/lexicon.txt data/lang_sw1_tg
LM=data/local/lm/sw1_fsh.o4g.kn.gz
if $has_fisher; then
  utils/build_const_arpa_lm.sh $LM data/lang data/lang_sw1_fsh_fg
fi

(
  graph_dir=exp/tri3/graph_sw1_tg
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh data/lang_sw1_tg exp/tri3 $graph_dir
  steps/decode.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
    $graph_dir data/eval2000 exp/tri3/decode_eval2000_sw1_tg
) &

# Train tri4, which is LDA+MLLT+SAT, on all the (nodup) data.
steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
  data/train_nodup data/lang exp/tri3 exp/tri3_ali_nodup


steps/train_sat.sh  --cmd "$train_cmd" \
  11500 200000 data/train_nodup data/lang exp/tri3_ali_nodup exp/tri4

(
  graph_dir=exp/tri4/graph_sw1_tg
  $train_cmd $graph_dir/mkgraph.log \
    utils/mkgraph.sh data/lang_sw1_tg exp/tri4 $graph_dir
  steps/decode_fmllr.sh --nj 30 --cmd "$decode_cmd" \
    --config conf/decode.config \
    $graph_dir data/eval2000 exp/tri4/decode_eval2000_sw1_tg
  # Will be used for confidence calibration example,
  steps/decode_fmllr.sh --nj 30 --cmd "$decode_cmd" \
    $graph_dir data/train_dev exp/tri4/decode_dev_sw1_tg
) &
wait

if $has_fisher; then
  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
    data/lang_sw1_{tg,fsh_fg} data/eval2000 \
    exp/tri4/decode_eval2000_sw1_{tg,fsh_fg}
fi

# MMI training starting from the LDA+MLLT+SAT systems on all the (nodup) data.
steps/align_fmllr.sh --nj 50 --cmd "$train_cmd" \
  data/train_nodup data/lang exp/tri4 exp/tri4_ali_nodup

steps/make_denlats.sh --nj 50 --cmd "$decode_cmd" \
  --config conf/decode.config --transform-dir exp/tri4_ali_nodup \
  data/train_nodup data/lang exp/tri4 exp/tri4_denlats_nodup

# 4 iterations of MMI seems to work well overall. The number of iterations is
# used as an explicit argument even though train_mmi.sh will use 4 iterations by
# default.
num_mmi_iters=4
steps/train_mmi.sh --cmd "$decode_cmd" \
  --boost 0.1 --num-iters $num_mmi_iters \
  data/train_nodup data/lang exp/tri4_{ali,denlats}_nodup exp/tri4_mmi_b0.1

for iter in 1 2 3 4; do
  (
    graph_dir=exp/tri4/graph_sw1_tg
    decode_dir=exp/tri4_mmi_b0.1/decode_eval2000_${iter}.mdl_sw1_tg
    steps/decode.sh --nj 30 --cmd "$decode_cmd" \
      --config conf/decode.config --iter $iter \
      --transform-dir exp/tri4/decode_eval2000_sw1_tg \
      $graph_dir data/eval2000 $decode_dir
  ) &
done
wait

if $has_fisher; then
  for iter in 1 2 3 4;do
    (
      steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
        data/lang_sw1_{tg,fsh_fg} data/eval2000 \
        exp/tri4_mmi_b0.1/decode_eval2000_${iter}.mdl_sw1_{tg,fsh_fg}
    ) &
  done
fi

# Now do fMMI+MMI training
steps/train_diag_ubm.sh --silence-weight 0.5 --nj 50 --cmd "$train_cmd" \
  700 data/train_nodup data/lang exp/tri4_ali_nodup exp/tri4_dubm

steps/train_mmi_fmmi.sh --learning-rate 0.005 \
  --boost 0.1 --cmd "$train_cmd" \
  data/train_nodup data/lang exp/tri4_ali_nodup exp/tri4_dubm \
  exp/tri4_denlats_nodup exp/tri4_fmmi_b0.1

for iter in 4 5 6 7 8; do
  (
    graph_dir=exp/tri4/graph_sw1_tg
    decode_dir=exp/tri4_fmmi_b0.1/decode_eval2000_it${iter}_sw1_tg
    steps/decode_fmmi.sh --nj 30 --cmd "$decode_cmd" --iter $iter \
      --transform-dir exp/tri4/decode_eval2000_sw1_tg \
      --config conf/decode.config $graph_dir data/eval2000 $decode_dir
  ) &
done
wait

if $has_fisher; then
  for iter in 4 5 6 7 8; do
    (
      steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
        data/lang_sw1_{tg,fsh_fg} data/eval2000 \
        exp/tri4_fmmi_b0.1/decode_eval2000_it${iter}_sw1_{tg,fsh_fg}
    ) &
  done
fi

# this will help find issues with the lexicon.
# steps/cleanup/debug_lexicon.sh --nj 300 --cmd "$train_cmd" data/train_nodev data/lang exp/tri4 data/local/dict/lexicon.txt exp/debug_lexicon

# SGMM system.
# local/run_sgmm2.sh $has_fisher

# Karel's DNN recipe on top of fMLLR features
# local/nnet/run_dnn.sh --has-fisher $has_fisher

# Dan's nnet recipe
# local/nnet2/run_nnet2.sh --has-fisher $has_fisher

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

# getting results (see RESULTS file)
# for x in 1 2 3a 3b 4a; do grep 'Percent Total Error' exp/tri$x/decode_eval2000_sw1_tg/score_*/eval2000.ctm.filt.dtl | sort -k5 -g | head -1; done
