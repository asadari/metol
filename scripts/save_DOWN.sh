#!/bin/bash
/opt/usr/nx-ks/popup_ok "EV+DN 프리셋을 저장할까요?" 저장 취소; [  $? -eq 255 ] || exit
[ -d "/sdcard/presets" ] || mkdir /sdcard/presets
prefman save_file 0 /sdcard/presets/preset0_down1
prefman save_file 0 /sdcard/presets/preset0_down2
sync
sync
sync
/opt/usr/nx-ks/popup_timeout  " [ EV+DN SAVED  ] " 2 
exit
