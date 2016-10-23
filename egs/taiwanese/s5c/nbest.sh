gzip -cd exp/tri4/decode_tshi3_data_lang/lat.1.gz | /home/johndoe/phoneme/kaldi/src/latbin/lattice-to-nbest --acoustic-scale=0.1 --n=10 ark:- ark:- | /home/johndoe/phoneme/kaldi/src/latbin/nbest-to-linear ark:- ark,t:1.ali ark,t:1.words ark,t:1.lmscore ark,t:1.acscore
cat 1.words | utils/int2sym.pl -f 2- data/lang/words.txt  | less
