. ./path.sh

for last; do true; done

grep "$last" data/train/segments
grep "$last" data/train/text  -A 2 -B 2
echo
grep "$last" data/train/text | sed 's/^[^ ]* //g'
echo

grep "$last" data/train/segments | head -n 1 | tail -n 1 | \
  sed 's/tong.*ku//g' | \
  extract-segments "scp:data/train/wav.scp" "-" "ark:-" >aa 2> /dev/null
sox -r 16000 -e signed -b 16 -c 1 -t raw aa aa.wav
normalize-audio aa.wav
play aa.wav 2> /dev/null
