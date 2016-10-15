set -e # exit on error

grep WARN exp/{mono,tri1,tri2,tri3,tri4}{,_ali}/log/a* | \
  grep tong | \
  sed 's/.*\(tong.*ku[0-9]*\).*/\1/g' | \
  grep -vwF -f 有問題的音檔.表 | \
  grep -vwF -f 無問題的音檔.表 | \
  sort | \
  uniq -c > king3ko3.pio2

if [ $# -eq 0 ]; then
  cat king3ko3.pio2 | awk '{print $1}' | sort -n | uniq -c | less
else
  cat king3ko3.pio2 | \
    awk -v liong7=$1 '{if($1>=liong7)print $2}' | \
    cat > bo5-ai3.pio2
fi

