set -e
. cmd.sh
. path.sh

nj=30
ku=data/train_nodup_cleaned
sin=data/train_tri5_cleaned

for i in 1 2 3; do 
  steps/cleanup/clean_and_segment_data.sh \
    --nj $nj \
    $ku data/lang_sp exp/tri5 exp/tri5_cleanup $sin
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
		$sin data/lang_sp exp/tri5 exp/tri5_ali
  steps/train_sat.sh  --cmd "$train_cmd" \
    11500 200000 $sin data/lang_sp exp/tri5_ali exp/tri5
  (
    graph_dir=exp/tri5/graph_sp
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang_sp exp/tri5 $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/train_dev exp/tri5/decode_train_dev_sp
  )
  rm -rf $ku
  mv $sin $ku
done
