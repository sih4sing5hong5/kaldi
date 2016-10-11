set -e # exit on error

grep WARN exp/{tri1,tri2,tri3,tri4}/log/align.* | \
  grep tong | \
  sed 's/.*\(tong.*ku[0-9]*\).*/\1/g' | \
  sort -u > bo5-ai3.pio2

