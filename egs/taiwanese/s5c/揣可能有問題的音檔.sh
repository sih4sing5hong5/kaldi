set -e # exit on error

grep WARN exp/{tri1,tri2,tri3,tri4}/log/align.* | \
  grep tong | \
  sed 's/.*\(tong.*ku[0-9]*\).*/\1/g' | \
  sort | \
  uniq -c > king3ko3.pio2

if [ $# -eq 0 ]; then
  cat king3ko3.pio2 | awk '{print $1}' | sort -n | uniq -c | less
else
  cat king3ko3.pio2 | \
    awk -v liong7=$1 '{if($1>=liong7)print $2}' | \
    tee bo5-ai3.pio2
fi

