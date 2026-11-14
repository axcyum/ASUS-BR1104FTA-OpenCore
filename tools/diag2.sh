#!/bin/sh
# 2 回目の診断: VoodooI2C / Intel GPU アクセラレータの起動ログを集める。
# 実行: sudo sh /Volumes/OPENCORE/diag2.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$DIR/diag2-$TS.txt"

sec() { printf '\n===== %s =====\n' "$1" >> "$OUT"; }
: > "$OUT"

sec "boot time / uptime"
sysctl kern.boottime >> "$OUT" 2>&1
uptime >> "$OUT" 2>&1

sec "kernel log: Voodoo / I2C / HID"
log show --last boot --info --debug --style compact \
  --predicate 'senderImagePath CONTAINS[c] "Voodoo" OR eventMessage CONTAINS[c] "VoodooI2C" OR eventMessage CONTAINS[c] "HID descriptor" OR eventMessage CONTAINS[c] "ASUP" OR eventMessage CONTAINS[c] "ILIT"' \
  2>&1 | cut -c1-500 | head -n 1500 >> "$OUT"

sec "kernel log: Intel GPU / WhateverXe"
log show --last boot --info --debug --style compact \
  --predicate 'senderImagePath CONTAINS[c] "AppleIntelTGL" OR senderImagePath CONTAINS[c] "WhateverXe" OR senderImagePath CONTAINS[c] "IOAccelerator" OR eventMessage CONTAINS[c] "IntelAccelerator" OR eventMessage CONTAINS[c] "IGAccel" OR eventMessage CONTAINS[c] "GuC"' \
  2>&1 | cut -c1-500 | head -n 1500 >> "$OUT"

sec "loaded: VoodooI2CHID / VoodooInput / accelerator"
kmutil showloaded 2>/dev/null | grep -i -E 'VoodooI2CHID|VoodooInput|TGL|WhateverXe' >> "$OUT"
ioreg -l -w0 | grep -c -E 'class (IntelAccelerator|IGAccel)' >> "$OUT" 2>&1

sync
echo "saved: $OUT"
