#!/bin/sh
# macOS 側の診断情報を USB (このスクリプトと同じ場所) に保存する。
# 実行: sudo sh /Volumes/OPENCORE/diag.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$DIR/diag-$TS.txt"
IOREG="$DIR/diag-$TS-ioreg.txt"

sec() { printf '\n===== %s =====\n' "$1" >> "$OUT"; }

: > "$OUT"
sec "system"
sw_vers >> "$OUT" 2>&1
uname -a >> "$OUT" 2>&1
id -u >> "$OUT" 2>&1

sec "nvram boot-args / csr"
nvram boot-args >> "$OUT" 2>&1
nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:csr-active-config >> "$OUT" 2>&1
csrutil status >> "$OUT" 2>&1

sec "loaded kexts (non-Apple)"
kmutil showloaded 2>/dev/null | grep -v ' com\.apple\.' >> "$OUT"
printf '\n-- apple graphics / i2c / hid --\n' >> "$OUT"
kmutil showloaded 2>/dev/null | grep -i -E 'Intel|Graphics|Framebuffer|IOAccelerator|IONDRV|I2C|LPSS|HIDEvent|Backlight|AGDP' >> "$OUT"

sec "donor kexts present on disk"
ls -d /System/Library/Extensions/AppleIntel*Graphics* /System/Library/Extensions/AppleIntelTGL* >> "$OUT" 2>&1
printf '\n-- /Library/GPUBundles --\n' >> "$OUT"
ls -la /Library/GPUBundles >> "$OUT" 2>&1
printf '\n-- GPU bundles in /System/Library/Extensions --\n' >> "$OUT"
ls -d /System/Library/Extensions/*TGL*.bundle /System/Library/Extensions/*ICL*.bundle >> "$OUT" 2>&1

ioreg -l -w0 > "$IOREG" 2>&1

sec "ioreg: graphics device node (GFX0/IGPU)"
ioreg -l -w0 -r -n GFX0 2>/dev/null | cut -c1-500 | head -n 150 >> "$OUT"
ioreg -l -w0 -r -n IGPU 2>/dev/null | cut -c1-500 | head -n 150 >> "$OUT"

sec "ioreg: WhateverXe / Lilu / framebuffer"
grep -n -i -E 'WhateverXe|WEX[A-Z]|Lilu|AppleIntelFramebuffer|AppleIntelTGL|IntelAccelerator|IONDRVFramebuffer|AppleBacklight|IOAccelerator|class-code" = <0000030' "$IOREG" | cut -c1-400 | head -n 250 >> "$OUT"

sec "ioreg: I2C / trackpad"
grep -n -i -E 'VoodooI2C|VoodooGPIO|VoodooInput|I2C[0-9]@|TPD[0-9]|ETPD|ASUP|ASUE|ELAN|PNP0C50|INTC1057|AppleIntelLpssI2C|pci8086,54e[89b]' "$IOREG" | cut -c1-400 | head -n 250 >> "$OUT"

sec "kernel log since boot (filtered)"
log show --last boot --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS[c] "lilu" OR eventMessage CONTAINS[c] "wex" OR eventMessage CONTAINS[c] "WhateverXe" OR eventMessage CONTAINS[c] "voodoo" OR eventMessage CONTAINS[c] "i2c" OR eventMessage CONTAINS[c] "gpio" OR eventMessage CONTAINS[c] "TGL" OR eventMessage CONTAINS[c] "IGPU" OR eventMessage CONTAINS[c] "framebuffer" OR eventMessage CONTAINS[c] "IntelAccelerator" OR eventMessage CONTAINS[c] "AlderLake")' \
  2>&1 | cut -c1-500 | head -n 1500 >> "$OUT"

sec "dmesg (filtered)"
dmesg 2>&1 | grep -i -E 'lilu|wex|whateverxe|voodoo|i2c|gpio|tgl|igpu|framebuffer|accelerator|alderlake' | cut -c1-500 | head -n 600 >> "$OUT"

sec "system_profiler displays"
system_profiler SPDisplaysDataType >> "$OUT" 2>&1

sync
echo "saved: $OUT"
echo "saved: $IOREG"
