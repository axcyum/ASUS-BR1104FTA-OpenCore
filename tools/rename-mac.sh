#!/bin/sh
# Change the model name shown in "About This Mac" (per user, no system files touched).
# Run as the logged-in user (NOT with sudo):  sh /Volumes/OPENCORE/rename-mac.sh
NAME="ASUS ExpertBook BR1104FTA"
PLIST="$HOME/Library/Preferences/com.apple.SystemProfiler.plist"

SERIAL="$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}')"
if [ -z "$SERIAL" ]; then echo "serial not found"; exit 1; fi

# About This Mac caches the marketing name under "<serial suffix>-<locale>".
# Write every suffix length / locale combination it is known to use.
for n in 3 4; do
  SUF="$(printf '%s' "$SERIAL" | tail -c "$n")"
  for LOC in ja-JP_JP ja-JP en-US_US en-US en_US; do
    /usr/libexec/PlistBuddy -c "Delete ':CPU Names:$SUF-$LOC'" "$PLIST" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add ':CPU Names' dict" "$PLIST" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add ':CPU Names:$SUF-$LOC' string $NAME" "$PLIST"
  done
done

killall cfprefsd 2>/dev/null
killall "System Information" "System Settings" 2>/dev/null
echo "done: $NAME  (reopen About This Mac)"
/usr/libexec/PlistBuddy -c "Print ':CPU Names'" "$PLIST"
