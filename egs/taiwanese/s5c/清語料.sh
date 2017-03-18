set -e
. cmd.sh
. path.sh

nj=16
ku=data/train_nodup_cleaned
mo_ku=exp/tri5

for i in 1 2 3; do 
  sin=data/train_nodup_cleaned.$i
  mo_sin=exp/tri5.$i
  if [ $i -eq 1 ]; then
    steps/cleanup/clean_and_segment_data.sh \
      --nj $nj \
      $ku data/lang_sp $mo_ku ${mo_ku}_cleanup $sin
  else
    steps/cleanup/clean_and_segment_data.sh \
      --nj $nj --segmentation-opts "--max-junk-proportion 0.07"\
      $ku data/lang_sp $mo_ku ${mo_ku}_cleanup $sin
  fi

  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
		$sin data/lang_sp $mo_ku ${mo_ku}_ali
  steps/train_sat.sh  --cmd "$train_cmd" \
    11500 200000 $sin data/lang_sp ${mo_ku}_ali $mo_sin
  (
    graph_dir=$mo_sin/graph_sp
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh data/lang_sp $mo_sin $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir data/train_dev $mo_sin/decode_train_dev_sp
  )
  ku=$sin
  mo_ku=$mo_sin
done
