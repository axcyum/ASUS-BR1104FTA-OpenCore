#!/bin/sh
# 4 回目の診断: タッチパッド修正の確認 + スリープ/復帰失敗の原因切り分け
# 使い方:
#   1) 起動後すぐ:            sudo sh /Volumes/OPENCORE/diag4.sh
#   2) スリープ → 復帰失敗 → 強制再起動した直後にもう一度:  sudo sh /Volumes/OPENCORE/diag4.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$DIR/diag4-$TS.txt"
sec() { printf '\n===== %s =====\n' "$1" >> "$OUT"; }
: > "$OUT"

sec "boot"
sw_vers >> "$OUT" 2>&1
sysctl kern.boottime kern.sleeptime kern.waketime kern.wakereason kern.shutdownreason >> "$OUT" 2>&1
nvram boot-args >> "$OUT" 2>&1

sec "trackpad: VoodooI2C nubs (expect Interrupt Mode / i2cAddress / VoodooI2CHIDDevice)"
kmutil showloaded 2>/dev/null | grep -i -E 'Voodoo' >> "$OUT"
ioreg -l -w0 | grep -E 'VoodooI2CDeviceNub|VoodooI2CHIDDevice|VoodooI2CMultitouch|VoodooInput|"Interrupt Mode"|"i2cAddress"|"gpioPin"|ASUP1201|ILIT2901' | cut -c1-260 >> "$OUT"

sec "trackpad: kernel log"
log show --last boot --info --debug --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS "VoodooI2C" OR eventMessage CONTAINS "VoodooGPIO" OR eventMessage CONTAINS "VoodooInput" OR eventMessage CONTAINS "TPD0" OR eventMessage CONTAINS "TPL1")' \
  2>&1 | cut -c1-400 | head -n 300 >> "$OUT"

sec "pmset settings"
pmset -g >> "$OUT" 2>&1
pmset -g cap >> "$OUT" 2>&1
pmset -g assertions 2>&1 | head -n 60 >> "$OUT"

sec "IOPMrootDomain (sleep type / deep idle / failure)"
ioreg -rd1 -c IOPMrootDomain -w0 | grep -E 'DeepIdle|Sleep|Wake|Hibernate|Failure|Standby|SystemCapab|AppleClamshell|System Boot' | cut -c1-400 >> "$OUT"

sec "pmset -g log: sleep / wake / failure (last 7 days)"
pmset -g log 2>/dev/null | grep -E 'Sleep  |Wake  |DarkWake|Failure|failure|Start  |Shutdown|Restart|EFI|Bootrom|drivers failed|WakeDetails|HibernateStats|Entering Sleep|Wake from' | tail -n 250 | cut -c1-400 >> "$OUT"

sec "kernel log around sleep entry of the last 3 hours (previous boots included)"
log show --last 3h --info --style compact \
  --predicate 'processID == 0 AND (eventMessage CONTAINS[c] "sleep" OR eventMessage CONTAINS[c] "wake" OR eventMessage CONTAINS "setPowerState" OR eventMessage CONTAINS "PMRD" OR eventMessage CONTAINS "IOPM" OR eventMessage CONTAINS "ACPI S" OR eventMessage CONTAINS "hibernate" OR eventMessage CONTAINS "IGFB" OR eventMessage CONTAINS "IGPU" OR eventMessage CONTAINS "xHC" OR eventMessage CONTAINS "disk")' \
  2>&1 | cut -c1-400 | tail -n 700 >> "$OUT"

sec "panic / sleep-wake failure reports"
ls -la /Library/Logs/DiagnosticReports 2>/dev/null | tail -n 40 >> "$OUT"
for f in $(ls -t /Library/Logs/DiagnosticReports/*.panic /Library/Logs/DiagnosticReports/Kernel*.panic /Library/Logs/DiagnosticReports/Sleep* /Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head -n 4); do
  printf '\n----- %s -----\n' "$f" >> "$OUT"
  head -c 12000 "$f" >> "$OUT"
done
printf '\n-- nvram panic info --\n' >> "$OUT"
nvram -p 2>/dev/null | grep -i -E 'panic|aapl,panic|wake-failure|SleepWakeFailure|IOPM' | cut -c1-300 >> "$OUT"

sec "boot disk / USB"
diskutil info / 2>&1 | grep -E 'Device Node|Protocol|Device Location|Removable|Solid|Volume Name' >> "$OUT"
ioreg -p IOUSB -w0 | head -n 30 >> "$OUT"
kmutil showloaded 2>/dev/null | grep -i -E 'USBToolBox|UTB|USBMap' >> "$OUT"

sec "ACPI wake devices / RTC"
ioreg -l -w0 | grep -E '"acpi-wake-type"|"acpi-wake-gpe"|"IOPMWakeEvent"' | sort | uniq -c | head -n 30 >> "$OUT"

sync
echo "saved: $OUT"
