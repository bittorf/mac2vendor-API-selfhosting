#!/bin/sh
# shellcheck shell=dash
#
# this produces "mac-vendor.txt.gz",
# a compressed lookup file ~250k in size
# (~3.8% the size of original data)
#
# $ ./normalize_vendors.sh
# 6494868 bytes with 237495 lines - oui.txt (raw-data, input file)
# 1242985 bytes with  39635 lines - /tmp/tmp.kEzxWKx32S (condensed input)
#  813402 bytes with  39635 lines - /tmp/tmp.s1B3Gf4GYi (condensed-and-normalized)
#  553582 bytes with  19109 lines - /tmp/tmp.yOwgFGLNgD (lookup-table-grouped-MACs-by-vendors)
#  249920 bytes with   1050 lines - mac-vendor.txt.gz (level 15 zopfli)
#
# example usage:
# $ zgrep -w 1CED6F mac-vendor.txt.gz | cut -f2
# AVM GERMANY
#
# INFO: storing the first 3 mac-bytes in binary can safe ~7k for compressed filesize
#
# INFO: show topmost vendor registrations like:
# $ zcat mac-vendor.txt.gz | awk -F$'\t' '{n=split($1,a," "); printf "%d\t%s\n", n, $2}' | sort -t$'\t' -k1,1rn
# 2028    HUAWEI TECH
# 1533    APPLE
# 1359    CISCO SYSTEMS
#  952    SAMSUNG ELEC
#  677    INTEL


INPUT='oui.txt'
OUTPUT="$( mktemp )"     || exit 1
NORMALIZED="$( mktemp )" || exit 1
GROUPED="$( mktemp )"    || exit 1
FINAL='mac-vendor.txt.gz'

INFOTEXT1="# produced with https://github.com/bittorf/mac2vendor-API-selfhosting ($( date '+%Y-%m-%d' ))"
INFOTEXT2="# use like: zgrep -w AABBCC mac-vendor.txt.gz | cut -f2"

TAB="$( printf '\t' )"
command -v 'zopfli' >/dev/null || exit 1

show_filesize()
{
  local file="$1"
  local desc="$2"

  local size line
  size="$( wc -c <"$file" )"
  line="$( wc -l <"$file" )"

  printf '%7i %s %6i %s \n' "$size" "bytes with" "$line" "lines - $file ($desc)"
}

# e.g.:
# 286FB9     (base 16)            Nokia Shanghai Bell Co., Ltd.
# to:
# 286FB9 Nokia Shanghai Bell Co., Ltd.
grep '(base 16)' "$INPUT" |
  while read -r LINE; do {
    # shellcheck disable=SC2086
    set -- $LINE
    MAC=$1
    shift 3

    printf '%s\n' "$MAC $*"
  } done >"$OUTPUT"

show_filesize "$INPUT"  "raw-data, input file"
show_filesize "$OUTPUT" "condensed input"

./normalize_vendors.py "$OUTPUT" "$NORMALIZED" >/dev/null
show_filesize "$NORMALIZED" "condensed-and-normalized"

echo "$INFOTEXT1"  >"$GROUPED"
echo "$INFOTEXT2" >>"$GROUPED"
awk '
{
    mac = $1
    company = substr($0, 8)
    macs[company] = macs[company] " " mac
}
END {
    for (c in macs)
        printf "%s\t%s\n", substr(macs[c], 2), c
}
' "$NORMALIZED" | LC_ALL=C sort "-t$TAB" -k2 >>"$GROUPED"

show_filesize "$GROUPED" "lookup-table-grouped-MACs-by-vendors"

zopfli -i15 -c "$GROUPED" >"$FINAL"
show_filesize "$FINAL" "level 15 zopfli"

rm -f "$OUTPUT" "$NORMALIZED" "$GROUPED"
