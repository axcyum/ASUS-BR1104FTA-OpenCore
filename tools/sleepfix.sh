#!/bin/sh
# スリープ設定を Hackintosh 向けに整える (1 回だけ実行):  sudo sh /Volumes/OPENCORE/sleepfix.sh
# 休止状態 (hibernate) / standby / Power Nap を止め、純粋なスリープだけにする。
# 元に戻す: sudo pmset restoredefaults
if [ "$(id -u)" != "0" ]; then echo "sudo で実行してください"; exit 1; fi
pmset -a hibernatemode 0
pmset -a standby 0
pmset -a autopoweroff 0
pmset -a powernap 0
pmset -a tcpkeepalive 0
pmset -a proximitywake 0
pmset -a ttyskeepawake 0
rm -f /var/vm/sleepimage 2>/dev/null
pmset -g
echo "done"
