#!/bin/sh
# 5 回目の診断: オーディオ (AppleALC + SimpleHDA) とタッチスクリーン
# 実行: sudo sh /Volumes/OPENCORE/diag5.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$DIR/diag5-$TS.txt"
sec() { printf '\n===== %s =====\n' "$1" >> "$OUT"; }
: > "$OUT"

sec "boot"
nvram boot-args >> "$OUT" 2>&1
kmutil showloaded 2>/dev/null | grep -i -E 'AppleALC|SimpleHDA|AppleHDA|IOHDA|DspFunc|IOAudio|Voodoo|Lilu' >> "$OUT"

sec "audio: controller node"
ioreg -l -w0 -r -n HDAS 2>/dev/null | cut -c1-300 | head -n 120 >> "$OUT"
ioreg -l -w0 -r -n HDEF 2>/dev/null | cut -c1-300 | head -n 120 >> "$OUT"

sec "audio: codec ids"
ioreg -l -w0 | grep -E 'IOHDACodecVendorID|IOHDACodecRevisionID|IOHDACodecAddress|"alc-layout-id"|"layout-id"|"alc-|"PinConfigurations"|class AppleHDA|class IOHDACodec|class AppleHDACodec' | cut -c1-260 | head -n 60 >> "$OUT"

sec "audio: devices"
system_profiler SPAudioDataType >> "$OUT" 2>&1

sec "audio: kernel log"
log show --last boot --info --debug --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS[c] "AppleALC" OR eventMessage CONTAINS[c] "alc:" OR eventMessage CONTAINS[c] "SimpleHDA" OR eventMessage CONTAINS[c] "shda" OR eventMessage CONTAINS "AppleHDA" OR eventMessage CONTAINS "HDAS" OR eventMessage CONTAINS "IOHDA" OR eventMessage CONTAINS[c] "codec")' \
  2>&1 | cut -c1-400 | head -n 300 >> "$OUT"

sec "touchscreen / trackpad"
ioreg -l -w0 | grep -E 'VoodooI2CDeviceNub|VoodooI2CHIDDevice|VoodooI2CMultitouch|VoodooI2CTouchscreen|"Interrupt Mode"|"i2cAddress"|ASUP1201|ILIT2901' | cut -c1-260 >> "$OUT"
log show --last boot --info --debug --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS "VoodooI2C" OR eventMessage CONTAINS "TPL1")' \
  2>&1 | cut -c1-400 | head -n 200 >> "$OUT"

sync
echo "saved: $OUT"
