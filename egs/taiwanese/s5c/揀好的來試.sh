set -e
. cmd.sh
. path.sh

nj=4
guan5=data/train_nodup_cleaned.2
mo_ku=exp/tri5.2
#utils/subset_data_dir.sh --last $guan5 30457 data/moe_liam2
for i in moe_liam2; do 
  ku=data/$i
  sin=data/king2.$i
  mo_sin=exp/king2.$i
  #steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
#		${ku} data/lang_sp $mo_ku ${mo_ku}_ali.$i
  steps/cleanup/clean_and_segment_data.sh \
    --nj $nj \
    ${ku} data/lang_sp ${mo_ku}_ali.$i ${ku}/cleanup_log $sin
#    --nj $nj --segmentation-opts "--max-junk-proportion 0.05"
#    --nj $nj --segmentation-opts "--max-junk-proportion 0.07"
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
		$sin data/lang_sp $mo_ku ${mo_ku}_ali.${i}.king2
  steps/train_sat.sh  --cmd "$train_cmd" \
    11500 200000 $sin data/lang_sp ${mo_ku}_ali.${i}.king2 $mo_sin
  (
    graph_dir=$mo_sin/graph_format_lm
    $train_cmd $graph_dir/mkgraph.log \
      utils/mkgraph.sh tshi3/lang_format_lm $mo_sin $graph_dir
    steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" \
      --config conf/decode.config \
      $graph_dir tshi3/train $mo_sin/decode_format_lm
  )
  cat $mo_sin/decode_format_lm*/wer* | grep WER | utils/best_wer.sh
done
