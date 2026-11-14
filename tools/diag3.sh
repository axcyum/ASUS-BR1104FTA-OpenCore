#!/bin/sh
# 3 回目の診断: タッチパッド(VoodooI2C DEBUG) / Wi-Fi(itlwm) / Bluetooth / バッテリー / GPU
# 実行: sudo sh /Volumes/OPENCORE/diag3.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$DIR/diag3-$TS.txt"
sec() { printf '\n===== %s =====\n' "$1" >> "$OUT"; }
: > "$OUT"

sec "boot"
sysctl kern.boottime >> "$OUT" 2>&1
nvram boot-args >> "$OUT" 2>&1

sec "loaded non-Apple kexts"
kmutil showloaded 2>/dev/null | grep -v ' com\.apple\.' >> "$OUT"

sec "kernel log: VoodooI2C (DEBUG build)"
log show --last boot --info --debug --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS "VoodooI2C" OR eventMessage CONTAINS "VoodooGPIO" OR eventMessage CONTAINS "VoodooInput")' \
  2>&1 | cut -c1-500 | head -n 1500 >> "$OUT"

sec "kernel log: itlwm / Bluetooth"
log show --last boot --info --debug --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS[c] "itlwm" OR eventMessage CONTAINS "iwx" OR eventMessage CONTAINS "iwm" OR eventMessage CONTAINS "IntelBluetooth" OR eventMessage CONTAINS "BlueToolFixup" OR eventMessage CONTAINS "IntelBTPatcher")' \
  2>&1 | cut -c1-500 | head -n 600 >> "$OUT"

sec "kernel log: battery / EC / SMC"
log show --last boot --info --debug --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS "SMCBatteryManager" OR eventMessage CONTAINS "ECEnabler" OR eventMessage CONTAINS "VirtualSMC" OR eventMessage CONTAINS "BrightnessKeys")' \
  2>&1 | cut -c1-500 | head -n 400 >> "$OUT"

sec "network interfaces"
ifconfig -a >> "$OUT" 2>&1

sec "bluetooth"
system_profiler SPBluetoothDataType >> "$OUT" 2>&1
ioreg -p IOUSB -l -w0 | grep -E '"USB Product Name"|"idVendor"|"idProduct"|\+-o ' | head -n 80 >> "$OUT"

sec "battery"
pmset -g batt >> "$OUT" 2>&1
ioreg -r -c AppleSmartBattery -w0 2>/dev/null | cut -c1-300 | head -n 60 >> "$OUT"

sec "trackpad nodes"
ioreg -l -w0 | grep -E 'VoodooI2CDeviceNub|VoodooI2CHIDDevice|VoodooI2CMultitouch|ASUP1201|ILIT2901' | cut -c1-300 >> "$OUT"

sec "GPU (WhateverXe fix build)"
ioreg -lw0 -r -n IGPU -d1 | grep -E '"(N97FramebufferStartAccepted|N97NativeBootSource|N97NativeStartAllowed|WEXDisplay13BootHandoff)"' >> "$OUT"
ioreg -l -w0 | grep -c -E 'class (IntelAccelerator|IGAccel)' >> "$OUT" 2>&1
log show --last boot --style compact --predicate 'processID == 0 AND (eventMessage CONTAINS "admitted with native mode 0" OR eventMessage CONTAINS "WhateverXe" OR eventMessage CONTAINS "IntelAccelerator")' 2>&1 | cut -c1-400 | head -n 200 >> "$OUT"
system_profiler SPDisplaysDataType >> "$OUT" 2>&1

sync
echo "saved: $OUT"
